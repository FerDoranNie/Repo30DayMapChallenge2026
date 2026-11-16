# =============================================================================
# Día 13 — Control de calidad: detalle taxonómico de los flujos
# Repite el filtrado del pipeline pero conservando Taxon y Term, para auditar
# qué especies sostienen los volúmenes más grandes (y detectar artefactos de
# unidad: pieles contadas como piezas, plantas propagadas, etc.).
# =============================================================================
suppressPackageStartupMessages(library(data.table))

ruta_zip <- "../../data/raw/day13/Trade_database_download_v2026.1.zip"
dir_tmp  <- "../../data/raw/day13/tmp_csv"
dir_proc <- "../../data/processed"
dir.create(dir_tmp,  showWarnings = FALSE, recursive = TRUE)

cols <- c("Year", "Taxon", "Class", "Order", "Family", "Term", "Quantity",
          "Unit", "Importer", "Exporter", "Origin", "Source", "Reporter.type")

partes <- list()
for (i in 1:59) {
  f <- sprintf("trade_db_%d.csv", i)
  unzip(ruta_zip, files = f, exdir = dir_tmp, junkpaths = TRUE)
  d <- fread(file.path(dir_tmp, f), select = cols, na.strings = c("", "NA"))
  d[, Unit := trimws(Unit)][Unit == "", Unit := NA_character_]
  d <- d[Year %in% 2015:2024 & Term %in% c("live", "trophies", "skins") &
           Source %in% c("W", "R", "F", "C", "A", "D") &
           (is.na(Unit) | Unit == "Number of specimens") &
           grepl("^[A-Z]{2}$", Importer) & grepl("^[A-Z]{2}$", Exporter) &
           Importer != Exporter & Reporter.type %in% c("I", "E")]
  if (nrow(d) == 0) { file.remove(file.path(dir_tmp, f)); next }
  d[, Quantity := as.numeric(Quantity)]
  d[, reexportacion := !is.na(Origin) & grepl("^[A-Z]{2}$", Origin)]
  partes[[i]] <- d[, .(volumen = sum(Quantity, na.rm = TRUE), n = .N),
                   by = .(Year, Exporter, Importer, Taxon, Term, Source, reexportacion)]
  file.remove(file.path(dir_tmp, f))
  if (i %% 20 == 0) cat("archivo", i, "\n")
}
detalle <- rbindlist(partes)
unlink(dir_tmp, recursive = TRUE)
saveRDS(detalle, file.path(dir_proc, "day13_detalle_taxon.rds"))
cat("Filas detalle:", nrow(detalle), "\n")

cat("\n== Top 15 combinaciones Taxon/Term en flujos silvestres directos ==\n")
print(head(detalle[Source == "W" & !reexportacion,
                   .(volumen = sum(volumen)), by = .(Taxon, Term)][order(-volumen)], 15))

cat("\n== Top 15 rutas silvestres directas con su taxón dominante ==\n")
rutas <- detalle[Source == "W" & !reexportacion,
                 .(volumen = sum(volumen)), by = .(Exporter, Importer, Taxon, Term)]
print(head(rutas[order(-volumen)], 15))

cat("\n== México: top 15 taxones importados silvestres ==\n")
print(head(detalle[Source == "W" & !reexportacion & Importer == "MX",
                   .(volumen = sum(volumen), n = sum(n)),
                   by = .(Exporter, Taxon, Term)][order(-volumen)], 15))

cat("\n== México: top 15 taxones exportados silvestres ==\n")
print(head(detalle[Source == "W" & !reexportacion & Exporter == "MX",
                   .(volumen = sum(volumen), n = sum(n)),
                   by = .(Importer, Taxon, Term)][order(-volumen)], 15))
