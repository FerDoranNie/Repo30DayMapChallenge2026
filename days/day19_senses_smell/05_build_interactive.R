# ==============================================================================
# Día 19: Senses: Smell — Mapa Interactivo HTML (Leaflet + Filtros por Alcaldía)
# Script 05: Genera docs/day19/index.html autocontenido listo para GitHub Pages
# ==============================================================================

.libPaths(c("C:/Users/fernando.dorantes/AppData/Local/R/win-library/4.3", .libPaths()))

suppressPackageStartupMessages({
  library(sf)
  library(data.table)
  library(geojsonsf)
  library(jsonlite)
})

sf_use_s2(FALSE)

fix_utf8 <- function(x) {
  out <- as.character(x)
  bad <- !validUTF8(out)
  if (any(bad)) {
    out[bad] <- iconv(out[bad], from = "latin1", to = "UTF-8")
  }
  out
}

cat("1. Cargando datos espaciales del Día 19...\n")
sp <- readRDS("data/processed/day19_spatial.rds")
alc <- sp$alc
alc_dt <- copy(sp$alc_dt)
hex_final <- sp$hex_final
retc_pts <- sp$retc_pts

alc$NOMGEO <- fix_utf8(alc$NOMGEO)
alc_dt[, NOMGEO := fix_utf8(NOMGEO)]
retc_pts$NOMBRE <- fix_utf8(retc_pts$NOMBRE)
retc_pts$SECTOR <- fix_utf8(retc_pts$SECTOR)
retc_pts$MUNICIPIO <- fix_utf8(retc_pts$MUNICIPIO)
retc_pts$sustancia_principal <- fix_utf8(retc_pts$sustancia_principal)

# Unir métricas a polígonos de alcaldías
alc_sf <- merge(alc[, c("CVE_MUN", "NOMGEO")], alc_dt[, .(
  CVE_MUN,
  area_km2 = round(area_km2, 2),
  n_gastro = as.integer(n_gastro),
  n_floral = as.integer(n_floral),
  n_arom_tot = as.integer(n_arom_tot),
  n_solv_denue = as.integer(n_solv_denue),
  n_retc = as.integer(n_retc),
  ton_voc = round(ton_voc, 2),
  dens_arom_km2 = round(dens_arom_km2, 1),
  dens_solv_km2 = round(dens_solv_km2, 1),
  ratio_arom_solv = round(ratio_arom_solv, 1)
)], by = "CVE_MUN")

# Asignar cada hexágono a su alcaldía (por punto interior)
cat("2. Asignando alcaldía a cada hexágono y reproyectando a WGS84...\n")
hex_pts <- st_point_on_surface(hex_final[, "hex_id"])
j_hex_alc <- st_join(hex_pts, alc[, c("CVE_MUN", "NOMGEO")], join = st_within, left = TRUE)
# Si alguno cayó justo en borde, usar st_nearest_feature
na_idx <- which(is.na(j_hex_alc$NOMGEO))
if (length(na_idx) > 0) {
  nearest <- st_nearest_feature(hex_pts[na_idx, ], alc)
  j_hex_alc$CVE_MUN[na_idx] <- alc$CVE_MUN[nearest]
  j_hex_alc$NOMGEO[na_idx] <- alc$NOMGEO[nearest]
}

hex_final$alcaldia <- j_hex_alc$NOMGEO
hex_final$cve_mun <- j_hex_alc$CVE_MUN

# Asignar alcaldía validada a cada punto RETC
j_retc_alc <- st_join(retc_pts, alc[, c("CVE_MUN", "NOMGEO")], join = st_within, left = TRUE)
na_r <- which(is.na(j_retc_alc$NOMGEO))
if (length(na_r) > 0) {
  nearest_r <- st_nearest_feature(retc_pts[na_r, ], alc)
  j_retc_alc$NOMGEO[na_r] <- alc$NOMGEO[nearest_r]
}
retc_pts$alcaldia <- j_retc_alc$NOMGEO

# Filtrar geometrías degeneradas (p. ej. Point en bordes tras st_intersection)
hex_final <- hex_final[st_geometry_type(hex_final) %in% c("POLYGON", "MULTIPOLYGON"), ]

# Seleccionar columnas compactas y transformar a EPSG:4326
hex_wgs <- hex_final[, c(
  "hex_id", "alcaldia", "olfato_cat", "n_gastro", "n_floral",
  "n_arom_tot", "n_solv_denue", "n_retc", "ton_voc", "ico"
)] |> st_transform(4326)
hex_wgs$ico <- round(hex_wgs$ico, 2)
hex_wgs$ton_voc <- round(hex_wgs$ton_voc, 2)
hex_wgs$n_gastro <- as.integer(hex_wgs$n_gastro)
hex_wgs$n_floral <- as.integer(hex_wgs$n_floral)
hex_wgs$n_arom_tot <- as.integer(hex_wgs$n_arom_tot)
hex_wgs$n_solv_denue <- as.integer(hex_wgs$n_solv_denue)
hex_wgs$n_retc <- as.integer(hex_wgs$n_retc)

alc_wgs <- alc_sf |>
  st_simplify(dTolerance = 25, preserveTopology = TRUE) |>
  st_transform(4326)

retc_wgs <- retc_pts[, c(
  "NRA", "NOMBRE", "SECTOR", "alcaldia", "fuente_retc",
  "ton_voc", "n_sustancias", "sustancia_principal"
)] |> st_transform(4326)
retc_wgs$ton_voc <- round(retc_wgs$ton_voc, 2)

# Sustancias top 8
subs_dt <- fread("data/processed/day19_substances.csv", encoding = "UTF-8")[1:8]
subs_dt[, short_sub := fcase(
  grepl("Estireno", SUSTANCIA), "Estireno",
  grepl("Clorobenceno", SUSTANCIA), "Clorobenceno",
  grepl("Xileno", SUSTANCIA), "Xileno (isómeros)",
  grepl("Arsénico", SUSTANCIA), "Arsénico (humos)",
  default = NA_character_
)]
subs_dt[is.na(short_sub), short_sub := SUSTANCIA]
subs_dt[, emision_ton := round(emision_ton, 1)]

cat("3. Serializando GeoJSON compacto (5 decimales)...\n")
hex_json  <- sf_geojson(hex_wgs, digits = 5)
alc_json  <- sf_geojson(alc_wgs, digits = 5)
retc_json <- sf_geojson(retc_wgs, digits = 5)
subs_json <- toJSON(subs_dt[, .(nombre = short_sub, ton = emision_ton, nota = nota_olfativa, estab = establecimientos)], auto_unbox = TRUE)

dir.create("docs/day19", recursive = TRUE, showWarnings = FALSE)

html_template <- '<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <meta name="referrer" content="strict-origin-when-cross-origin" />
  <title>¿A qué huele la Ciudad de México? | #30DayMapChallenge 2026 - Día 19</title>
  <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" crossorigin="" />
  <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js" crossorigin=""></script>
  <style>
    :root {
      --bg-paper: #F7F4EB;
      --bg-card: #FFFDF8;
      --border: #D6CFC0;
      --ink: #0F172A;
      --ink-muted: #475569;
      --amber: #D97706;
      --amber-soft: #F4B96A;
      --floral: #2D6A4F;
      --mixed: #94A3B8;
      --solv: #881337;
      --conserv: #E8E3D8;
      --retc: #BE123C;
    }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      background: var(--bg-paper);
      color: var(--ink);
      height: 100vh;
      overflow: hidden;
      display: flex;
    }
    /* Sidebar */
    #sidebar {
      width: 390px;
      min-width: 340px;
      height: 100vh;
      background: var(--bg-paper);
      border-right: 1px solid var(--border);
      display: flex;
      flex-direction: column;
      overflow-y: auto;
      padding: 18px 18px 22px 18px;
      z-index: 1000;
    }
    .badge {
      display: inline-block;
      font-size: 11px;
      font-weight: 700;
      letter-spacing: 0.04em;
      text-transform: uppercase;
      color: var(--solv);
      background: #FDE8EC;
      border: 1px solid #F5C2CE;
      border-radius: 999px;
      padding: 3px 10px;
      margin-bottom: 8px;
      width: fit-content;
    }
    h1 {
      font-size: 20px;
      line-height: 1.2;
      font-weight: 800;
      color: var(--ink);
      margin-bottom: 6px;
    }
    .subtitle {
      font-size: 12.5px;
      line-height: 1.45;
      color: var(--ink-muted);
      margin-bottom: 14px;
    }
    .section {
      background: var(--bg-card);
      border: 1px solid var(--border);
      border-radius: 10px;
      padding: 12px 13px;
      margin-bottom: 12px;
    }
    .section-title {
      font-size: 11.5px;
      font-weight: 700;
      text-transform: uppercase;
      letter-spacing: 0.04em;
      color: var(--ink-muted);
      margin-bottom: 8px;
      display: flex;
      justify-content: space-between;
      align-items: center;
    }
    .filter-row {
      display: flex;
      gap: 8px;
      align-items: center;
    }
    select {
      flex: 1;
      padding: 8px 10px;
      border: 1px solid #B8B0A0;
      border-radius: 7px;
      background: #FFFFFF;
      color: var(--ink);
      font-size: 13px;
      font-weight: 600;
      cursor: pointer;
    }
    .btn {
      padding: 8px 10px;
      border: 1px solid #B8B0A0;
      border-radius: 7px;
      background: var(--bg-paper);
      color: var(--ink);
      font-size: 12px;
      font-weight: 600;
      cursor: pointer;
      white-space: nowrap;
      transition: background 0.15s;
    }
    .btn:hover { background: #EAE4D6; }
    .coord-input {
      flex: 1;
      padding: 7px 9px;
      border: 1px solid #B8B0A0;
      border-radius: 7px;
      background: #FFFFFF;
      color: var(--ink);
      font-size: 12.5px;
      font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
    }
    .coord-hint {
      font-size: 10.8px;
      color: var(--ink-muted);
      margin-top: 5px;
    }
    .coord-err {
      font-size: 11px;
      color: var(--solv);
      font-weight: 600;
      margin-top: 4px;
      display: none;
    }
    /* Methodology button & panel (top-right) */
    #meth-btn {
      position: absolute;
      top: 12px;
      right: 54px;
      z-index: 1100;
      background: var(--bg-card);
      border: 1px solid var(--border);
      border-radius: 8px;
      padding: 7px 12px;
      font-size: 12.5px;
      font-weight: 700;
      color: var(--ink);
      box-shadow: 0 2px 10px rgba(15,23,42,0.14);
      cursor: pointer;
      display: flex;
      align-items: center;
      gap: 6px;
      transition: background 0.15s;
    }
    #meth-btn:hover { background: #F2EEE4; }
    #meth-panel {
      position: absolute;
      top: 52px;
      right: 54px;
      width: 390px;
      max-width: calc(100vw - 70px);
      max-height: calc(100vh - 80px);
      overflow-y: auto;
      z-index: 1100;
      background: var(--bg-card);
      border: 1px solid var(--border);
      border-radius: 12px;
      padding: 16px 18px;
      box-shadow: 0 10px 30px rgba(15,23,42,0.18);
      display: none;
      font-size: 12.5px;
      line-height: 1.5;
      color: var(--ink);
    }
    #meth-panel.open { display: block; }
    .meth-head {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 10px;
      padding-bottom: 8px;
      border-bottom: 1px solid var(--border);
    }
    .meth-head h2 { font-size: 15px; font-weight: 800; color: var(--ink); }
    .meth-close {
      background: var(--bg-paper);
      border: 1px solid var(--border);
      border-radius: 6px;
      padding: 3px 8px;
      font-size: 12px;
      font-weight: 700;
      cursor: pointer;
      color: var(--ink);
    }
    .meth-close:hover { background: #EAE4D6; }
    #meth-panel h3 {
      font-size: 12px;
      font-weight: 800;
      text-transform: uppercase;
      letter-spacing: 0.03em;
      color: var(--solv);
      margin-top: 11px;
      margin-bottom: 4px;
    }
    #meth-panel ul { padding-left: 17px; margin-bottom: 6px; }
    #meth-panel li { margin-bottom: 4px; }
    .formula-box {
      background: var(--bg-paper);
      border: 1px solid #E2DCCE;
      border-radius: 7px;
      padding: 8px 10px;
      font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
      font-size: 11.5px;
      margin: 6px 0;
      color: var(--ink);
    }
    /* KPI Grid */
    .kpi-grid {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 8px;
    }
    .kpi {
      background: var(--bg-paper);
      border: 1px solid #E2DCCE;
      border-radius: 8px;
      padding: 8px 10px;
    }
    .kpi-label {
      font-size: 10.5px;
      color: var(--ink-muted);
      font-weight: 600;
      margin-bottom: 2px;
    }
    .kpi-val {
      font-size: 17px;
      font-weight: 800;
      color: var(--ink);
      line-height: 1.15;
    }
    .kpi-sub {
      font-size: 10.5px;
      color: var(--ink-muted);
      margin-top: 2px;
    }
    .kpi-amber .kpi-val { color: #B45309; }
    .kpi-solv .kpi-val { color: var(--solv); }
    .kpi-floral .kpi-val { color: var(--floral); }
    /* Category toggles */
    .cat-list {
      display: flex;
      flex-direction: column;
      gap: 5px;
    }
    .cat-item {
      display: flex;
      align-items: center;
      gap: 8px;
      font-size: 12px;
      cursor: pointer;
      padding: 4px 6px;
      border-radius: 6px;
      transition: background 0.12s;
      user-select: none;
    }
    .cat-item:hover { background: #F2EEE4; }
    .cat-item input { cursor: pointer; accent-color: var(--ink); }
    .swatch {
      width: 13px;
      height: 13px;
      border-radius: 3px;
      border: 1px solid rgba(15,23,42,0.22);
      flex-shrink: 0;
    }
    .cat-name { flex: 1; color: var(--ink); font-weight: 500; }
    .cat-count {
      font-size: 11px;
      font-weight: 700;
      color: var(--ink-muted);
      background: #EFECE3;
      padding: 1px 6px;
      border-radius: 999px;
    }
    /* Layer toggles */
    .layer-row {
      display: flex;
      flex-wrap: wrap;
      gap: 10px;
      font-size: 12px;
      margin-bottom: 8px;
    }
    .layer-row label {
      display: flex;
      align-items: center;
      gap: 5px;
      cursor: pointer;
      font-weight: 500;
    }
    .slider-row {
      display: flex;
      align-items: center;
      gap: 8px;
      font-size: 11.5px;
      color: var(--ink-muted);
    }
    .slider-row input[type="range"] { flex: 1; accent-color: var(--amber); }
    /* Substances mini bars */
    .sub-bar-row {
      margin-bottom: 6px;
    }
    .sub-bar-head {
      display: flex;
      justify-content: space-between;
      font-size: 11.5px;
      margin-bottom: 2px;
    }
    .sub-bar-name { font-weight: 700; color: var(--ink); }
    .sub-bar-meta { color: var(--ink-muted); font-size: 10.5px; }
    .sub-bar-track {
      height: 6px;
      background: #ECE7DC;
      border-radius: 999px;
      overflow: hidden;
    }
    .sub-bar-fill {
      height: 100%;
      background: var(--solv);
      border-radius: 999px;
    }
    .credits {
      margin-top: auto;
      padding-top: 8px;
      font-size: 11px;
      line-height: 1.45;
      color: var(--ink-muted);
      border-top: 1px solid var(--border);
    }
    .credits a { color: var(--solv); text-decoration: none; font-weight: 600; }
    .credits a:hover { text-decoration: underline; }
    /* Map container */
    #map-wrap {
      flex: 1;
      position: relative;
      height: 100vh;
    }
    #map {
      width: 100%;
      height: 100%;
      background: #E5E0D5;
    }
    #toggle-sidebar {
      display: none;
      position: absolute;
      top: 12px;
      left: 12px;
      z-index: 1100;
      background: var(--bg-card);
      border: 1px solid var(--border);
      border-radius: 8px;
      padding: 8px 12px;
      font-size: 12.5px;
      font-weight: 700;
      color: var(--ink);
      box-shadow: 0 2px 8px rgba(15,23,42,0.12);
      cursor: pointer;
    }
    /* Leaflet custom popup */
    .leaflet-popup-content-wrapper {
      background: var(--bg-card);
      color: var(--ink);
      border-radius: 10px;
      border: 1px solid var(--border);
      box-shadow: 0 6px 20px rgba(15,23,42,0.16);
    }
    .leaflet-popup-content {
      margin: 11px 13px;
      font-size: 12.5px;
      line-height: 1.45;
    }
    .pop-title {
      font-size: 13.5px;
      font-weight: 800;
      margin-bottom: 4px;
      color: var(--ink);
    }
    .pop-tag {
      display: inline-block;
      font-size: 10.5px;
      font-weight: 700;
      padding: 2px 7px;
      border-radius: 999px;
      color: #fff;
      margin-bottom: 6px;
    }
    .pop-table {
      width: 100%;
      border-collapse: collapse;
      margin-top: 4px;
    }
    .pop-table td {
      padding: 2px 0;
      font-size: 12px;
    }
    .pop-table td:last-child {
      text-align: right;
      font-weight: 700;
    }
    @media (max-width: 820px) {
      #sidebar {
        position: absolute;
        left: 0;
        top: 0;
        width: 88vw;
        max-width: 360px;
        transform: translateX(-100%);
        transition: transform 0.25s ease;
        box-shadow: 4px 0 20px rgba(15,23,42,0.2);
      }
      #sidebar.open { transform: translateX(0); }
      #toggle-sidebar { display: block; }
    }
  </style>
</head>
<body>
  <aside id="sidebar">
    <div class="badge">#30DayMapChallenge 2026 · Día 19: Senses: Smell</div>
    <h1>¿A qué huele la Ciudad de México?</h1>
    <p class="subtitle">
      Paisaje olfativo urbano en hexágonos de 750 m: 50,152 comercios del DENUE (INEGI) frente a 25 plantas con emisiones de COVs al aire en RETC 2024 (SEMARNAT).
    </p>

    <div class="section">
      <div class="section-title">
        <span>Filtrar por Alcaldía</span>
        <button id="btn-reset" class="btn" title="Ver toda la CDMX">Toda la CDMX</button>
      </div>
      <div class="filter-row">
        <select id="alc-select">
          <option value="ALL">Todas las alcaldías (16)</option>
        </select>
      </div>
    </div>

    <div class="section">
      <div class="section-title">
        <span>Buscar por Latitud, Longitud</span>
        <button id="btn-coord-clear" class="btn" style="padding:3px 8px;font-size:11px;">Limpiar</button>
      </div>
      <div class="filter-row">
        <input id="coord-input" class="coord-input" type="text" placeholder="Ej. 19.4326, -99.1332" />
        <button id="btn-coord-go" class="btn">Ir</button>
      </div>
      <div class="coord-hint">Pega coordenadas en formato <code>lat, lon</code>.</div>
      <div id="coord-err" class="coord-err"></div>
    </div>

    <div class="section">
      <div class="section-title">
        <span id="kpi-scope">Resumen · Ciudad de México</span>
      </div>
      <div class="kpi-grid">
        <div class="kpi kpi-amber">
          <div class="kpi-label">Aromas cotidianos</div>
          <div class="kpi-val" id="kpi-arom">—</div>
          <div class="kpi-sub" id="kpi-dens">— estab./km²</div>
        </div>
        <div class="kpi kpi-solv">
          <div class="kpi-label">Solventes y comb.</div>
          <div class="kpi-val" id="kpi-solv">—</div>
          <div class="kpi-sub" id="kpi-ratio">Relación — : 1</div>
        </div>
        <div class="kpi kpi-solv">
          <div class="kpi-label">Emisiones RETC 2024</div>
          <div class="kpi-val" id="kpi-ton">—</div>
          <div class="kpi-sub" id="kpi-retc">— plantas COVs</div>
        </div>
        <div class="kpi kpi-floral">
          <div class="kpi-label">Florerías y plantas</div>
          <div class="kpi-val" id="kpi-floral">—</div>
          <div class="kpi-sub" id="kpi-area">Área: — km²</div>
        </div>
      </div>
    </div>

    <div class="section">
      <div class="section-title">
        <span>Firma olfativa dominante</span>
        <button id="btn-all-cats" class="btn" style="padding:3px 8px;font-size:11px;">Todas</button>
      </div>
      <div class="cat-list" id="cat-list"></div>
    </div>

    <div class="section">
      <div class="section-title"><span>Capas y visualización</span></div>
      <div class="layer-row">
        <label><input type="checkbox" id="chk-hex" checked /> Hexágonos</label>
        <label><input type="checkbox" id="chk-retc" checked /> Plantas RETC</label>
        <label><input type="checkbox" id="chk-alc" checked /> Alcaldías</label>
        <label><input type="checkbox" id="chk-osm" checked /> OpenStreetMap</label>
      </div>
      <div class="slider-row">
        <span>Opacidad hex:</span>
        <input type="range" id="rng-opacity" min="0.2" max="0.95" step="0.05" value="0.78" />
        <span id="lbl-opacity">78%</span>
      </div>
    </div>

    <div class="section">
      <div class="section-title"><span>Top COVs olorosos al aire (RETC 2024 CDMX)</span></div>
      <div id="subs-container"></div>
    </div>

    <div class="credits">
      <strong>Metodología:</strong> Índice de Contraste Olfativo <code>ICO = log(1+aromas) − log(1+2.5×carga_solventes)</code> en grilla hexagonal (750 m, EPSG:32614).<br/>
      <strong>Fuentes:</strong> INEGI DENUE (CDMX) &amp; SEMARNAT RETC Verificado / Gasolineras 2024.<br/>
      <strong>Autor:</strong> Fernando Dorantes Nieto (<a href="https://github.com/FerDoranNie/Repo30DayMapChallenge2026" target="_blank">@FerDoranNie</a>)
    </div>
  </aside>

  <main id="map-wrap">
    <button id="toggle-sidebar">☰ Filtros y datos</button>
    <button id="meth-btn" aria-expanded="false" aria-controls="meth-panel">📖 Metodología</button>
    <div id="meth-panel" role="dialog" aria-label="Metodología del mapa">
      <div class="meth-head">
        <h2>Metodología del Paisaje Olfativo</h2>
        <button id="meth-close" class="meth-close">✕ Ocultar</button>
      </div>
      <p>
        Este mapa estima la huella olfativa de la Ciudad de México combinando dos fuentes oficiales públicas y agregándolas en una grilla hexagonal regular de <strong>750 m</strong> (proyección UTM 14N, <code>EPSG:32614</code>; 3,240 hexágonos).
      </p>
      <h3>1. Datos Oficiales Integrados</h3>
      <ul>
        <li><strong>DENUE (INEGI, CDMX — 50,152 establecimientos):</strong>
          <em>Aroma cotidiano</em> (39,718): tacos, tortas y antojitos (<code>722513–14</code>), panaderías y tortillerías (<code>311811–30</code>), cafeterías y tostadores (<code>722515</code>, <code>311921–22</code>).
          <em>Aroma floral</em> (4,945): florerías y plantas (<code>466312</code>).
          <em>Solventes y combustibles</em> (5,489): hojalatería, pintura y solventes (<code>811121</code>, <code>325510</code>, <code>467113</code>), plásticos/química/residuos (<code>3261*</code>, <code>5621*</code>) y gasolineras (<code>468411</code>).
        </li>
        <li><strong>RETC Verificado y Gasolineras 2024 (SEMARNAT):</strong> 25 establecimientos en CDMX con emisiones al aire de Compuestos Orgánicos Volátiles (COVs) y sustancias químicas olorosas (<strong>940.6 ton/año</strong>), excluyendo GEI inodoros (CO₂, CH₄, N₂O).</li>
      </ul>
      <h3>2. Índice de Contraste Olfativo (ICO)</h3>
      <div class="formula-box">
        carga_solventes = n_solv_denue + 8 × n_retc<br/>
        ICO = log(1 + n_aromas) − log(1 + 2.5 × carga_solventes)
      </div>
      <p>
        Cada planta industrial RETC pondera <strong>×8</strong> frente a talleres difusos. Con base en <code>ICO</code>, densidad total y proporción floral se clasifican 6 firmas olfativas dominantes.
      </p>
      <h3>3. Alcance y Lectura</h3>
      <p>
        Representa fuentes fijas y actividad económica registrada (proxy territorial del olfato urbano); no modela emisiones vehiculares móviles ni dispersión atmosférica horaria por viento.
      </p>
    </div>
    <div id="map"></div>
  </main>

  <script>
    const HEX_DATA  = __HEX_JSON__;
    const ALC_DATA  = __ALC_JSON__;
    const RETC_DATA = __RETC_JSON__;
    const SUBS_DATA = __SUBS_JSON__;

    const CATEGORIES = [
      { key: "Aroma gastronómico intenso (pan, café, tacos)", short: "Gastronómico intenso (pan, café, tacos)", color: "#D97706" },
      { key: "Aroma cotidiano moderado",                      short: "Aroma cotidiano moderado",               color: "#F4B96A" },
      { key: "Oasis floral (viveros y mercados)",             short: "Oasis floral (viveros y mercados)",      color: "#2D6A4F" },
      { key: "Paisaje mixto (transición)",                    short: "Paisaje mixto (transición)",             color: "#94A3B8" },
      { key: "Dominio de solventes, combustibles e industria",short: "Solventes, combustibles e industria",    color: "#881337" },
      { key: "Suelo de conservación / baja densidad",         short: "Suelo de conservación / baja densidad",  color: "#E8E3D8" }
    ];
    const CAT_COLOR = Object.fromEntries(CATEGORIES.map(c => [c.key, c.color]));

    const state = {
      alcaldia: "ALL",
      activeCats: new Set(CATEGORIES.map(c => c.key)),
      showHex: true,
      showRetc: true,
      showAlc: true,
      hexOpacity: 0.78
    };

    // Inicializar mapa Leaflet
    const map = L.map("map", {
      center: [19.32, -99.13],
      zoom: 11,
      minZoom: 9,
      maxZoom: 16,
      zoomControl: false
    });
    L.control.zoom({ position: "topright" }).addTo(map);
    L.control.scale({ imperial: false, position: "bottomright" }).addTo(map);

    const osmLayer = L.tileLayer("https://tile.openstreetmap.org/{z}/{x}/{y}.png", {
      attribution: `&copy; <a href="https://www.openstreetmap.org/copyright" target="_blank" rel="noopener">OpenStreetMap</a> contributors`,
      maxZoom: 19,
      crossOrigin: false
    }).addTo(map);

    // Poblar selector de alcaldías
    const alcSelect = document.getElementById("alc-select");
    const alcList = ALC_DATA.features
      .map(f => f.properties.NOMGEO)
      .sort((a, b) => a.localeCompare(b, "es"));
    alcList.forEach(name => {
      const opt = document.createElement("option");
      opt.value = name;
      opt.textContent = name;
      alcSelect.appendChild(opt);
    });

    // Poblar filtros de categoría
    const catListEl = document.getElementById("cat-list");
    CATEGORIES.forEach((c, idx) => {
      const lbl = document.createElement("label");
      lbl.className = "cat-item";
      lbl.innerHTML = `
        <input type="checkbox" data-cat="${c.key}" checked />
        <span class="swatch" style="background:${c.color}"></span>
        <span class="cat-name">${c.short}</span>
        <span class="cat-count" id="cnt-cat-${idx}">0</span>
      `;
      lbl.querySelector("input").addEventListener("change", (e) => {
        if (e.target.checked) state.activeCats.add(c.key);
        else state.activeCats.delete(c.key);
        renderLayers();
      });
      catListEl.appendChild(lbl);
    });

    // Poblar mini-gráfico de sustancias RETC
    const subsEl = document.getElementById("subs-container");
    const maxTon = Math.max(...SUBS_DATA.map(d => d.ton));
    SUBS_DATA.forEach(d => {
      const pct = Math.max(3, (d.ton / maxTon) * 100);
      const row = document.createElement("div");
      row.className = "sub-bar-row";
      row.innerHTML = `
        <div class="sub-bar-head">
          <span class="sub-bar-name">${d.nombre}</span>
          <span class="sub-bar-meta"><strong>${d.ton.toLocaleString("es-MX")} t</strong> · ${d.nota}</span>
        </div>
        <div class="sub-bar-track"><div class="sub-bar-fill" style="width:${pct}%"></div></div>
      `;
      subsEl.appendChild(row);
    });

    // Grupos de capas
    let hexLayer = null;
    let alcLayer = null;
    let retcLayer = null;

    function fmt(n) { return Number(n).toLocaleString("es-MX"); }

    function updateKPIs() {
      const scopeEl = document.getElementById("kpi-scope");
      let feats = ALC_DATA.features;
      if (state.alcaldia !== "ALL") {
        feats = feats.filter(f => f.properties.NOMGEO === state.alcaldia);
        scopeEl.textContent = "Resumen · " + state.alcaldia;
      } else {
        scopeEl.textContent = "Resumen · Ciudad de México (16 alcaldías)";
      }
      const sum = (k) => feats.reduce((acc, f) => acc + (Number(f.properties[k]) || 0), 0);
      const arom = sum("n_arom_tot");
      const floral = sum("n_floral");
      const solv = sum("n_solv_denue");
      const retc = sum("n_retc");
      const ton = sum("ton_voc");
      const area = sum("area_km2");
      const dens = area > 0 ? (arom / area) : 0;
      const ratio = solv > 0 ? (arom / solv) : arom;

      document.getElementById("kpi-arom").textContent = fmt(arom);
      document.getElementById("kpi-dens").textContent = dens.toFixed(1) + " estab./km²";
      document.getElementById("kpi-solv").textContent = fmt(solv);
      document.getElementById("kpi-ratio").textContent = "Relación " + ratio.toFixed(1) + " : 1";
      document.getElementById("kpi-ton").textContent = ton.toFixed(1) + " t/año";
      document.getElementById("kpi-retc").textContent = retc + (retc === 1 ? " planta COVs" : " plantas COVs");
      document.getElementById("kpi-floral").textContent = fmt(floral);
      document.getElementById("kpi-area").textContent = "Área: " + area.toFixed(1) + " km²";

      // Actualizar conteos de hexágonos por categoría en la alcaldía activa
      const hexInScope = HEX_DATA.features.filter(f =>
        state.alcaldia === "ALL" || f.properties.alcaldia === state.alcaldia
      );
      CATEGORIES.forEach((c, idx) => {
        const n = hexInScope.filter(f => f.properties.olfato_cat === c.key).length;
        document.getElementById("cnt-cat-" + idx).textContent = fmt(n);
      });
    }

    function renderLayers(flyTo = false) {
      if (hexLayer) { map.removeLayer(hexLayer); hexLayer = null; }
      if (alcLayer) { map.removeLayer(alcLayer); alcLayer = null; }
      if (retcLayer) { map.removeLayer(retcLayer); retcLayer = null; }

      // 1. Capa de hexágonos
      if (state.showHex) {
        const filteredHex = {
          type: "FeatureCollection",
          features: HEX_DATA.features.filter(f => {
            const p = f.properties;
            const okAlc = (state.alcaldia === "ALL" || p.alcaldia === state.alcaldia);
            const okCat = state.activeCats.has(p.olfato_cat);
            return okAlc && okCat;
          })
        };
        hexLayer = L.geoJSON(filteredHex, {
          style: (f) => ({
            fillColor: CAT_COLOR[f.properties.olfato_cat] || "#CBD5E1",
            fillOpacity: state.hexOpacity,
            color: "#F7F4EB",
            weight: 0.6
          }),
          onEachFeature: (f, layer) => {
            const p = f.properties;
            const col = CAT_COLOR[p.olfato_cat] || "#475569";
            const textCol = p.olfato_cat === "Suelo de conservación / baja densidad" ? "#0F172A" : "#FFFFFF";
            layer.on("mouseover", () => layer.setStyle({ weight: 1.8, color: "#0F172A" }));
            layer.on("mouseout", () => layer.setStyle({ weight: 0.6, color: "#F7F4EB" }));
            layer.bindPopup(`
              <div class="pop-title">${p.alcaldia} · Hexágono #${p.hex_id}</div>
              <span class="pop-tag" style="background:${col};color:${textCol}">${p.olfato_cat}</span>
              <table class="pop-table">
                <tr><td>Comercios gastronómicos</td><td>${fmt(p.n_gastro)}</td></tr>
                <tr><td>Florerías y plantas</td><td>${fmt(p.n_floral)}</td></tr>
                <tr><td>Solventes / combustibles (DENUE)</td><td>${fmt(p.n_solv_denue)}</td></tr>
                <tr><td>Plantas RETC 2024</td><td>${fmt(p.n_retc)} (${p.ton_voc} t/año)</td></tr>
                <tr><td>Índice de Contraste (ICO)</td><td>${p.ico}</td></tr>
              </table>
            `);
          }
        }).addTo(map);
      }

      // 2. Capa de límites de alcaldías
      if (state.showAlc) {
        alcLayer = L.geoJSON(ALC_DATA, {
          interactive: true,
          style: (f) => {
            const isSel = state.alcaldia !== "ALL" && f.properties.NOMGEO === state.alcaldia;
            return {
              fillColor: "transparent",
              fillOpacity: 0,
              color: isSel ? "#0F172A" : "#334155",
              weight: isSel ? 2.8 : 1.0,
              dashArray: isSel ? null : "2,2"
            };
          },
          onEachFeature: (f, layer) => {
            layer.bindTooltip(f.properties.NOMGEO, { sticky: true, direction: "top", opacity: 0.9 });
            layer.on("click", () => {
              if (state.alcaldia !== f.properties.NOMGEO) {
                state.alcaldia = f.properties.NOMGEO;
                alcSelect.value = state.alcaldia;
                updateKPIs();
                renderLayers(true);
              }
            });
          }
        }).addTo(map);
        // Mandar alcaldías debajo de hexágonos si hexágonos están activos para no bloquear clics en hexágonos
        if (hexLayer) alcLayer.bringToBack();
      }

      // 3. Capa de plantas RETC 2024
      if (state.showRetc) {
        const filteredRetc = {
          type: "FeatureCollection",
          features: RETC_DATA.features.filter(f =>
            state.alcaldia === "ALL" || f.properties.alcaldia === state.alcaldia
          )
        };
        retcLayer = L.geoJSON(filteredRetc, {
          pointToLayer: (f, latlng) => {
            const t = Number(f.properties.ton_voc) || 0;
            const r = Math.max(5, Math.min(20, 4.5 + Math.sqrt(t) * 0.65));
            return L.circleMarker(latlng, {
              radius: r,
              fillColor: "#BE123C",
              color: "#FFFBEB",
              weight: 1.6,
              fillOpacity: 0.88
            });
          },
          onEachFeature: (f, layer) => {
            const p = f.properties;
            layer.bindPopup(`
              <div class="pop-title">${p.NOMBRE}</div>
              <span class="pop-tag" style="background:#BE123C;">RETC 2024 · ${p.alcaldia}</span>
              <table class="pop-table">
                <tr><td>Sector</td><td>${p.SECTOR}</td></tr>
                <tr><td>Emisión COVs al aire</td><td>${fmt(p.ton_voc)} ton/año</td></tr>
                <tr><td>Sustancia principal</td><td>${p.sustancia_principal}</td></tr>
                <tr><td>Sustancias reportadas</td><td>${p.n_sustancias}</td></tr>
              </table>
            `);
          }
        }).addTo(map);
      }

      // Hacer zoom suave a la alcaldía seleccionada
      if (flyTo) {
        if (state.alcaldia === "ALL") {
          const b = L.geoJSON(ALC_DATA).getBounds();
          map.flyToBounds(b, { padding: [25, 25], duration: 0.7 });
        } else {
          const selFeat = ALC_DATA.features.find(f => f.properties.NOMGEO === state.alcaldia);
          if (selFeat) {
            const b = L.geoJSON(selFeat).getBounds();
            map.flyToBounds(b, { padding: [40, 40], duration: 0.7 });
          }
        }
      }
    }

    // Eventos de controles
    alcSelect.addEventListener("change", (e) => {
      state.alcaldia = e.target.value;
      updateKPIs();
      renderLayers(true);
    });
    document.getElementById("btn-reset").addEventListener("click", () => {
      state.alcaldia = "ALL";
      alcSelect.value = "ALL";
      updateKPIs();
      renderLayers(true);
    });
    document.getElementById("btn-all-cats").addEventListener("click", () => {
      state.activeCats = new Set(CATEGORIES.map(c => c.key));
      document.querySelectorAll("#cat-list input").forEach(inp => inp.checked = true);
      renderLayers(false);
    });
    document.getElementById("chk-hex").addEventListener("change", (e) => {
      state.showHex = e.target.checked;
      renderLayers(false);
    });
    document.getElementById("chk-retc").addEventListener("change", (e) => {
      state.showRetc = e.target.checked;
      renderLayers(false);
    });
    document.getElementById("chk-alc").addEventListener("change", (e) => {
      state.showAlc = e.target.checked;
      renderLayers(false);
    });
    document.getElementById("rng-opacity").addEventListener("input", (e) => {
      state.hexOpacity = parseFloat(e.target.value);
      document.getElementById("lbl-opacity").textContent = Math.round(state.hexOpacity * 100) + "%";
      if (hexLayer) hexLayer.setStyle({ fillOpacity: state.hexOpacity });
    });
    document.getElementById("chk-osm").addEventListener("change", (e) => {
      if (e.target.checked) osmLayer.addTo(map);
      else map.removeLayer(osmLayer);
    });
    document.getElementById("toggle-sidebar").addEventListener("click", () => {
      document.getElementById("sidebar").classList.toggle("open");
    });

    // Botón y panel de Metodología (arriba a la derecha)
    const methBtn = document.getElementById("meth-btn");
    const methPanel = document.getElementById("meth-panel");
    const methClose = document.getElementById("meth-close");
    function toggleMeth(forceState) {
      const open = typeof forceState === "boolean" ? forceState : !methPanel.classList.contains("open");
      methPanel.classList.toggle("open", open);
      methBtn.setAttribute("aria-expanded", String(open));
      methBtn.textContent = open ? "✕ Ocultar metodología" : "📖 Metodología";
    }
    methBtn.addEventListener("click", () => toggleMeth());
    methClose.addEventListener("click", () => toggleMeth(false));

    // Búsqueda por Latitud, Longitud (100% cliente, sin API key) + detección del hexágono
    let searchMarker = null;
    function pointInRing(pt, ring) {
      let inside = false;
      const x = pt[0], y = pt[1];
      for (let i = 0, j = ring.length - 1; i < ring.length; j = i++) {
        const xi = ring[i][0], yi = ring[i][1];
        const xj = ring[j][0], yj = ring[j][1];
        const intersect = ((yi > y) !== (yj > y)) && (x < (xj - xi) * (y - yi) / (yj - yi + 1e-12) + xi);
        if (intersect) inside = !inside;
      }
      return inside;
    }
    function pointInGeom(lon, lat, geom) {
      const pt = [lon, lat];
      if (geom.type === "Polygon") {
        if (!pointInRing(pt, geom.coordinates[0])) return false;
        for (let h = 1; h < geom.coordinates.length; h++) {
          if (pointInRing(pt, geom.coordinates[h])) return false;
        }
        return true;
      }
      if (geom.type === "MultiPolygon") {
        return geom.coordinates.some(poly => {
          if (!pointInRing(pt, poly[0])) return false;
          for (let h = 1; h < poly.length; h++) {
            if (pointInRing(pt, poly[h])) return false;
          }
          return true;
        });
      }
      return false;
    }
    function searchByCoords() {
      const raw = document.getElementById("coord-input").value.trim();
      const errEl = document.getElementById("coord-err");
      errEl.style.display = "none";
      const parts = raw.split(/[\\s,;]+/).filter(Boolean).map(Number);
      if (parts.length !== 2 || parts.some(isNaN)) {
        errEl.textContent = "Formato inválido. Usa: lat, lon (ej. 19.4326, -99.1332)";
        errEl.style.display = "block";
        return;
      }
      const [lat, lon] = parts;
      if (lat < -90 || lat > 90 || lon < -180 || lon > 180) {
        errEl.textContent = "Coordenadas fuera de rango geográfico.";
        errEl.style.display = "block";
        return;
      }
      if (searchMarker) { map.removeLayer(searchMarker); searchMarker = null; }
      const hit = HEX_DATA.features.find(f => pointInGeom(lon, lat, f.geometry));
      let popupHtml = `<div class="pop-title">📍 ${lat.toFixed(5)}, ${lon.toFixed(5)}</div>`;
      if (hit) {
        const p = hit.properties;
        const col = CAT_COLOR[p.olfato_cat] || "#475569";
        const textCol = p.olfato_cat === "Suelo de conservación / baja densidad" ? "#0F172A" : "#FFFFFF";
        popupHtml += `
          <div style="font-size:12px;color:#475569;margin-bottom:4px;"><strong>${p.alcaldia}</strong> · Hexágono #${p.hex_id}</div>
          <span class="pop-tag" style="background:${col};color:${textCol}">${p.olfato_cat}</span>
          <table class="pop-table">
            <tr><td>Comercios gastronómicos</td><td>${fmt(p.n_gastro)}</td></tr>
            <tr><td>Florerías y plantas</td><td>${fmt(p.n_floral)}</td></tr>
            <tr><td>Solventes / combustibles</td><td>${fmt(p.n_solv_denue)}</td></tr>
            <tr><td>Plantas RETC 2024</td><td>${fmt(p.n_retc)} (${p.ton_voc} t/año)</td></tr>
            <tr><td>Índice de Contraste (ICO)</td><td>${p.ico}</td></tr>
          </table>
        `;
      } else {
        popupHtml += `<div style="color:#475569;font-size:12px;">Este punto está fuera de los límites de la Ciudad de México.</div>`;
      }
      searchMarker = L.circleMarker([lat, lon], {
        radius: 8,
        fillColor: "#0F172A",
        color: "#FFFDF8",
        weight: 2.5,
        fillOpacity: 0.95
      }).addTo(map).bindPopup(popupHtml).openPopup();
      map.flyTo([lat, lon], 14, { duration: 0.8 });
    }
    document.getElementById("btn-coord-go").addEventListener("click", searchByCoords);
    document.getElementById("coord-input").addEventListener("keydown", (e) => {
      if (e.key === "Enter") searchByCoords();
    });
    document.getElementById("btn-coord-clear").addEventListener("click", () => {
      document.getElementById("coord-input").value = "";
      document.getElementById("coord-err").style.display = "none";
      if (searchMarker) { map.removeLayer(searchMarker); searchMarker = null; }
    });

    // Render inicial
    updateKPIs();
    renderLayers(true);
  </script>
</body>
</html>'

html_out <- sub("__HEX_JSON__", hex_json, html_template, fixed = TRUE)
html_out <- sub("__ALC_JSON__", alc_json, html_out, fixed = TRUE)
html_out <- sub("__RETC_JSON__", retc_json, html_out, fixed = TRUE)
html_out <- sub("__SUBS_JSON__", subs_json, html_out, fixed = TRUE)

out_path <- "docs/day19/index.html"
writeLines(html_out, out_path, useBytes = TRUE)
cat(sprintf("Listo! Archivo generado: %s (%.2f MB)\n", out_path, file.info(out_path)$size / 1e6))
