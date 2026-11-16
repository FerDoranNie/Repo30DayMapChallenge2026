# =============================================================================
# DÃ­a 13 â€” Interactions
# La red global de comercio de vida silvestre (CITES)
# -----------------------------------------------------------------------------
# Fase 1-2: leer la descarga completa "shipment-level" de CITES Trade Database
# (Trade_database_download_v2026.1.zip, 59 CSV, ~29.2 M registros), filtrar,
# armonizar volÃºmenes importador vs exportador y construir el grafo dirigido
# ponderado Exporter -> Importer.
#
# Salidas:
#   data/processed/day13_cites_network.rds
#   data/processed/day13_diagnosticos.csv
#   data/processed/day13_nodos.csv
#   data/processed/day13_rutas_top.csv
#   data/processed/day13_resumen_taxones.csv
# =============================================================================

suppressPackageStartupMessages({
  library(data.table)
  library(igraph)
})

t0 <- Sys.time()

raiz     <- normalizePath(file.path("..", ".."), mustWork = FALSE)
ruta_zip <- file.path("..", "..", "data", "raw", "day13",
                      "Trade_database_download_v2026.1.zip")
dir_tmp  <- file.path("..", "..", "data", "raw", "day13", "tmp_csv")
dir_proc <- file.path("..", "..", "data", "processed")
dir.create(dir_tmp,  showWarnings = FALSE, recursive = TRUE)
dir.create(dir_proc, showWarnings = FALSE, recursive = TRUE)

# --- ParÃ¡metros analÃ­ticos ---------------------------------------------------
ventana_anios <- 2015:2024   # se filtra despuÃ©s al graficar; aquÃ­ guardamos todo
terminos      <- c("live", "trophies", "skins")
fuentes       <- c("W", "R", "F", "C", "A", "D")  # ver mapa_fuentes abajo
# Unidades de conteo: la base trae "Number of specimens" y vacÃ­os; kg/m3/ml se excluyen.
unidades_conteo <- "Number of specimens"  # NA = blanco tras trimws

cols <- c("Year", "Taxon", "Class", "Order", "Family", "Term", "Quantity",
          "Unit", "Importer", "Exporter", "Origin", "Purpose", "Source",
          "Reporter.type")

# --- Diccionario de gremios taxonÃ³micos (5 grupos del pÃ³ster) ----------------
clase_a_grupo <- function(clase, orden, familia) {
  grupo <- rep(NA_character_, length(clase))
  cl <- toupper(ifelse(is.na(clase), "", clase))
  grupo[cl == "REPTILIA"]                                             <- "Reptiles"
  grupo[cl == "AVES"]                                                 <- "Aves"
  grupo[cl == "MAMMALIA"]                                             <- "Mamiferos"
  grupo[cl %in% c("AMPHIBIA")]                                        <- "Acuaticos_Anfibios"
  grupo[cl %in% c("ACTINOPTERI", "ACTINOPTERYGII", "ELASMOBRANCHII",
                  "CEPHALASPIDOMORPHI", "MYXINI", "HOLOCEPHALI",
                  "ANTHOZOA", "HYDROZOA", "SCLERACTINIA", "HEXACTINELLIDA",
                  "DEMOSPONGIAE", "CALCAREA", "BIVALVIA", "GASTROPODA",
                  "CEPHALOPODA", "HIRUDINOIDEA", "ECHINODERMATA", "HOLOTHUROIDEA",
                  "ASTEROIDEA", "OPHIUROIDEA", "ECHINOIDEA", "CRINOIDEA",
                  "PORIFERA", "ARACHNIDA", "INSECTA", "MALACOSTRACA",
                  "DIPLOPODA", "CHILOPODA", "CNIDARIA")]               <- "Acuaticos_Anfibios"

  # Plantas: en CITES llegan con Class vacÃ­a. Se resuelven por orden/familia.
  ordenes_planta <- c("PINALES", "CYCADALES", "ASPARAGALES", "CARYOPHYLLALES",
                      "FABALES", "ERICALES", "GENTIANALES", "LAMIALES",
                      "MALPIGHIALES", "PIPERALES", "ROSALES", "MYRTALES",
                      "SAPINDALES", "MAGNOLIALES", "AUSTROBAILEYALES",
                      "LILIALES", "POALES", "ZINGIBERALES", "COMMELINALES",
                      "SOLANALES", "BORAGINALES", "APIALES", "AQUIFOLIALES",
                      "DIPSACALES", "GARRYALES", "PROTEALES", "RANUNCULALES",
                      "SAXIFRAGALES", "VITALES", "CELASTRALES", "CORNALES",
                      "CUCURBITALES", "OXALIDALES", "SANTALALES", "ZYGOPHYLLALES")
  fam_planta <- c("ORCHIDACEAE", "CACTACEAE", "EUPHORBIACEAE", "FABACEAE",
                  "LEGUMINOSAE", "ASPARAGACEAE", "CYCADACEAE", "ZAMIACEAE",
                  "NEPENTHACEAE", "SARRACENIACEAE", "PRIMULACEAE", "RUBIACEAE",
                  "APOCYNACEAE", "TAXACEAE", "PODOCARPACEAE", "PINACEAE",
                  "CUPRESSACEAE", "ARAUCARIACEAE", "BERBERIDACEAE", "DIOSCOREACEAE",
                  "DROSERACEAE", "LILIACEAE", "MELIACEAE", "THYMELAEACEAE",
                  "PASSIFLORACEAE", "TROCHODENDRACEAE", "WELWITSCHIACEAE",
                  "AGAVACEAE", "ARECACEAE", "BROMELIACEAE", "CRASSULACEAE",
                  "DICKSONIACEAE", "CYATHEACEAE", "GNETACEAE", "STANGERIACEAE",
                  "CARYOCARACEAE", "ANACARDIACEAE", "BURSERACEAE", "MORACEAE",
                  "MAGNOLIACEAE", "THEACEAE", "OLEACEAE", "IRIDACEAE",
                  "AMARYLLIDACEAE", "HYPOXIDACEAE", "TECOPHILAEACEAE")

  vacio <- is.na(grupo)
  grupo[vacio & (toupper(ifelse(is.na(orden), "", orden)) %in% ordenes_planta)]   <- "Plantas"
  grupo[is.na(grupo) & (toupper(ifelse(is.na(familia), "", familia)) %in% fam_planta)] <- "Plantas"
  grupo[is.na(grupo)] <- "Otros"
  grupo
}

# --- Acumuladores ------------------------------------------------------------
mapa_anios   <- list()   # conteo de filas por aÃ±o (todas las filas, sin filtrar)
mapa_terminos <- list()
mapa_unidades <- list()
mapa_fuentes  <- list()
mapa_clases   <- list()
mapa_fam_sin_clase <- list()
filtros      <- list()   # cuÃ¡ntas filas caen en cada filtro
partes       <- list()   # agregados por archivo

n_archivos <- as.integer(Sys.getenv("DAY13_N_ARCHIVOS", "59"))
inicio     <- as.integer(Sys.getenv("DAY13_INICIO", "1"))
archivos <- sprintf("trade_db_%d.csv", seq(inicio, length.out = n_archivos))

for (i in seq_along(archivos)) {
  f <- archivos[i]
  utils::unzip(ruta_zip, files = f, exdir = dir_tmp, junkpaths = TRUE)
  ruta_csv <- file.path(dir_tmp, f)

  dt <- fread(ruta_csv, select = cols, na.strings = c("", "NA"),
              colClasses = list(character = c("Taxon", "Class", "Order", "Family",
                                              "Term", "Unit", "Importer", "Exporter",
                                              "Origin", "Purpose", "Source",
                                              "Reporter.type")))

  # --- DiagnÃ³sticos (sobre el universo completo) ---
  mapa_anios[[i]]    <- dt[, .N, by = Year]
  mapa_terminos[[i]] <- dt[, .N, by = Term]
  mapa_unidades[[i]] <- dt[, .N, by = Unit]
  mapa_fuentes[[i]]  <- dt[, .N, by = Source]
  mapa_clases[[i]]   <- dt[, .N, by = Class]
  mapa_fam_sin_clase[[i]] <- dt[is.na(Class), .N, by = Family]

  # --- Filtros ---
  n0 <- nrow(dt)
  dt <- dt[Year %in% ventana_anios]
  n1 <- nrow(dt)
  dt <- dt[Term %in% terminos]
  n2 <- nrow(dt)
  dt <- dt[Source %in% fuentes]
  n3 <- nrow(dt)
  dt[, Unit := trimws(Unit)][Unit == "", Unit := NA_character_]
  dt <- dt[is.na(Unit) | Unit %in% unidades_conteo]
  n4 <- nrow(dt)
  dt <- dt[grepl("^[A-Z]{2}$", Importer) & grepl("^[A-Z]{2}$", Exporter)]
  n5 <- nrow(dt)
  dt <- dt[Importer != Exporter]
  n6 <- nrow(dt)
  dt <- dt[Reporter.type %in% c("I", "E")]
  n7 <- nrow(dt)

  filtros[[i]] <- data.table(archivo = f, crudo = n0, anio = n1, termino = n2,
                             fuente = n3, unidad = n4, iso_valido = n5, flujo = n6,
                             reportero = n7)

  if (n7 == 0) { rm(dt); file.remove(ruta_csv); next }

  dt[, Quantity := as.numeric(Quantity)]
  dt[, grupo := clase_a_grupo(Class, Order, Family)]
  dt[, grupo_fuente := fcase(
    Source == "W",                  "Silvestre",
    Source == "R",                  "Rancheo",
    Source %in% c("C", "F", "D"),   "Cautiverio",
    Source == "A",                  "Propagado",
    default = "Otro")]
  dt[, reexportacion := !is.na(Origin) & grepl("^[A-Z]{2}$", Origin)]

  agg <- dt[, .(volumen = sum(Quantity, na.rm = TRUE), n_registros = .N),
            by = .(Year, Exporter, Importer, grupo, Term, grupo_fuente, reexportacion,
                   Reporter.type)]
  partes[[i]] <- agg

  rm(dt); gc(verbose = FALSE)
  file.remove(ruta_csv)

  if (i %% 10 == 0) {
    cat(sprintf("[%s] archivo %d/59 listo (%.1f min)\n", format(Sys.time(), "%H:%M:%S"),
                i, as.numeric(difftime(Sys.time(), t0, units = "mins"))))
    flush.console()
  }
}

cat("Lectura y filtrado terminados. Consolidando...\n")

diagnosticos <- rbindlist(list(
  rbindlist(mapa_anios)[,    .(N = sum(N)), by = Year ][, metrica := "anio"],
  rbindlist(mapa_terminos)[, .(N = sum(N)), by = Term ][, metrica := "termino"],
  rbindlist(mapa_unidades)[, .(N = sum(N)), by = Unit ][, metrica := "unidad"],
  rbindlist(mapa_fuentes)[,  .(N = sum(N)), by = Source][, metrica := "fuente"],
  rbindlist(mapa_clases)[,   .(N = sum(N)), by = Class][, metrica := "clase"]
), fill = TRUE)
fwrite(diagnosticos, file.path(dir_proc, "day13_diagnosticos.csv"))
fwrite(rbindlist(filtros), file.path(dir_proc, "day13_filtros_conteo.csv"))
fwrite(rbindlist(mapa_fam_sin_clase)[, .(N = sum(N)), by = Family][order(-N)][1:80],
       file.path(dir_proc, "day13_familias_sin_clase.csv"))

# --- Consolidar y armonizar importador vs exportador -------------------------
bruto <- rbindlist(partes)
rm(partes); gc(verbose = FALSE)
cat("Columnas en bruto:", paste(names(bruto), collapse = " | "), "\n")
cat("Filas en bruto:", nrow(bruto), "\n")

flujos <- dcast(bruto,
                Year + Exporter + Importer + grupo + Term + grupo_fuente + reexportacion ~
                  Reporter.type,
                value.var = "volumen", fill = 0, fun.aggregate = sum)
setnames(flujos, c("E", "I"), c("vol_exportador", "vol_importador"), skip_absent = TRUE)
if (!"vol_exportador" %in% names(flujos)) flujos[, vol_exportador := 0]
if (!"vol_importador" %in% names(flujos)) flujos[, vol_importador := 0]
# Criterio CITES: mÃ¡ximo de lo reportado por las dos partes (evita doble conteo)
flujos[, volumen := pmax(vol_exportador, vol_importador)]
flujos <- flujos[volumen > 0]

# Red de origen directo (excluye reexportaciones)
directo <- flujos[reexportacion == FALSE]

cat(sprintf("Flujos aÃ±o-paÃ­s-paÃ­s-taxÃ³n: %s filas | origen directo: %s\n",
            format(nrow(flujos), big.mark = ","),
            format(nrow(directo), big.mark = ",")))

# --- Constructor del grafo ---------------------------------------------------
construir_red <- function(base, etiqueta) {
  aristas <- base[, .(volumen = sum(volumen), n_anios = uniqueN(Year)),
                  by = .(Exporter, Importer)]
  if (nrow(aristas) == 0) return(NULL)

  grupo_dom <- base[, .(vol_grupo = sum(volumen)), by = .(Exporter, Importer, grupo)]
  grupo_dom <- grupo_dom[order(Exporter, Importer, -vol_grupo)]
  grupo_dom <- grupo_dom[, .SD[1], by = .(Exporter, Importer)]
  aristas <- merge(aristas,
                   grupo_dom[, .(Exporter, Importer, grupo_dominante = grupo, vol_grupo)],
                   by = c("Exporter", "Importer"), all.x = TRUE)

  g <- graph_from_data_frame(aristas, directed = TRUE,
                             vertices = data.table(pais = sort(unique(c(aristas$Exporter,
                                                                        aristas$Importer)))))
  V(g)$exportaciones <- strength(g, mode = "out", weights = E(g)$volumen)
  V(g)$importaciones <- strength(g, mode = "in",  weights = E(g)$volumen)
  V(g)$total         <- V(g)$exportaciones + V(g)$importaciones
  V(g)$balance       <- V(g)$exportaciones - V(g)$importaciones
  V(g)$betweenness   <- betweenness(g, directed = TRUE,
                                    weights = 1 / (E(g)$volumen + 1), normalized = TRUE)

  nodos <- data.table(pais = V(g)$name,
                      exportaciones = V(g)$exportaciones,
                      importaciones = V(g)$importaciones,
                      total = V(g)$total,
                      balance = V(g)$balance,
                      betweenness = V(g)$betweenness)
  nodos[, tipo := fifelse(balance > 0, "Exportador neto", "Importador neto")]
  setorder(nodos, -total)

  resumen <- base[, .(volumen = sum(volumen),
                      rutas = uniqueN(paste(Exporter, Importer)),
                      paises_exportadores = uniqueN(Exporter),
                      paises_importadores = uniqueN(Importer)),
                  by = grupo][order(-volumen)]

  top_rutas <- aristas[order(-volumen)][1:200]
  top_rutas[, total_exportado_origen  := nodos$exportaciones[match(Exporter, nodos$pais)]]
  top_rutas[, total_importado_destino := nodos$importaciones[match(Importer, nodos$pais)]]

  mx <- base[Exporter == "MX" | Importer == "MX"]
  mx_por_grupo <- mx[, .(exportado = sum(volumen[Exporter == "MX"]),
                         importado = sum(volumen[Importer == "MX"])), by = grupo][order(-(exportado + importado))]
  mx_resumen <- data.table(
    metrica = c("volumen_exportado_MX", "volumen_importado_MX",
                "socios_exportacion", "socios_importacion",
                "grupo_mas_exportado", "grupo_mas_importado",
                "rutas_con_MX"),
    valor = c(mx[Exporter == "MX", sum(volumen)],
              mx[Importer == "MX", sum(volumen)],
              mx[Exporter == "MX", uniqueN(Importer)],
              mx[Importer == "MX", uniqueN(Exporter)],
              mx_por_grupo[1, grupo], mx_por_grupo[order(-importado)][1, grupo],
              nrow(mx)))

  fwrite(nodos,     file.path(dir_proc, sprintf("day13_nodos_%s.csv", etiqueta)))
  fwrite(resumen,   file.path(dir_proc, sprintf("day13_resumen_taxones_%s.csv", etiqueta)))
  fwrite(top_rutas, file.path(dir_proc, sprintf("day13_rutas_top_%s.csv", etiqueta)))
  fwrite(mx_por_grupo, file.path(dir_proc, sprintf("day13_mexico_grupos_%s.csv", etiqueta)))
  writeLines(capture.output(print(mx_resumen)),
             file.path(dir_proc, sprintf("day13_mexico_resumen_%s.txt", etiqueta)))

  list(aristas = aristas, nodos = nodos, grafo = g, resumen_grupo = resumen,
       top_rutas = top_rutas, mexico = mx, mexico_por_grupo = mx_por_grupo,
       mexico_resumen = mx_resumen)
}

redes <- list(
  total     = construir_red(directo, "total"),
  silvestre = construir_red(directo[grupo_fuente == "Silvestre"], "silvestre"))

# --- Guardar -----------------------------------------------------------------
red <- list(flujos = flujos,
            redes = redes,
            diagnosticos = diagnosticos,
            filtros = rbindlist(filtros),
            parametros = list(ventana_anios = ventana_anios, terminos = terminos,
                              fuentes = fuentes, unidades = unidades_conteo,
                              zip = basename(ruta_zip), version = "2026.1",
                              fecha_proceso = Sys.time()))
saveRDS(red, file.path(dir_proc, "day13_cites_network.rds"), compress = "xz")

unlink(dir_tmp, recursive = TRUE)

cat("\n===== RESUMEN =====")
cat(sprintf("\nRegistros filtrados: %s\n",
            format(sum(rbindlist(filtros)$reportero), big.mark = ",")))
cat("\n--- Red SILVESTRE (Source = W) ---\n")
print(redes$silvestre$resumen_grupo)
cat("\nTop 10 exportadores:\n")
print(head(redes$silvestre$nodos[order(-exportaciones),
                                 .(pais, exportaciones, importaciones, balance)], 10))
cat("\nTop 10 importadores:\n")
print(head(redes$silvestre$nodos[order(-importaciones),
                                 .(pais, importaciones, exportaciones, balance)], 10))
cat("\nTop 15 rutas:\n")
print(head(redes$silvestre$aristas[order(-volumen),
                                   .(Exporter, Importer, volumen, grupo_dominante)], 15))
cat("\nMexico (silvestre):\n"); print(redes$silvestre$mexico_resumen)
cat("\nMexico por grupo:\n");   print(redes$silvestre$mexico_por_grupo)
cat(sprintf("\nTiempo total: %.1f min\n", as.numeric(difftime(Sys.time(), t0, units = "mins"))))
