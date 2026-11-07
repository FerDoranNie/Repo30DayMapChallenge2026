# ==============================================================================
# Día 06 — Vintage: descarga de registros de Helia Bravo Hollis desde GBIF
# Autor: Fernando Dorantes Nieto (@FerDoranNie) — #30DayMapChallenge 2026
# Salida: data/raw/day06/bravo_gbif.csv y data/processed/day06_bravo.rds
# ==============================================================================

.libPaths(c("C:/Users/fernando.dorantes/AppData/Local/R/win-library/4.3", .libPaths()))
suppressPackageStartupMessages({
  library(httr)
  library(jsonlite)
  library(dplyr)
})

dir.create("data/raw/day06", recursive = TRUE, showWarnings = FALSE)
dir.create("data/processed", recursive = TRUE, showWarnings = FALSE)

base_url <- "https://api.gbif.org/v1/occurrence/search"
limit <- 300

fetch_page <- function(offset) {
  res <- GET(
    base_url,
    query = list(
      recordedBy = "Helia Bravo Hollis",
      hasCoordinate = "true",
      occurrenceStatus = "PRESENT",
      limit = limit,
      offset = offset
    ),
    user_agent("Repo30DayMapChallenge2026/1.0 (fernando.dorantes)")
  )
  stop_for_status(res)
  fromJSON(content(res, as = "text", encoding = "UTF-8"), flatten = TRUE)
}

first <- fetch_page(0)
total <- first$count
message("Registros disponibles: ", total)

pages <- ceiling(total / limit)
all_res <- vector("list", pages)
all_res[[1]] <- first$results
if (pages > 1) {
  for (i in 2:pages) {
    Sys.sleep(0.4)
    all_res[[i]] <- fetch_page((i - 1) * limit)$results
    message("Página ", i, "/", pages)
  }
}

raw <- bind_rows(all_res)

keep <- c(
  "key", "scientificName", "acceptedScientificName", "taxonRank",
  "eventDate", "year", "month", "day",
  "decimalLatitude", "decimalLongitude", "coordinateUncertaintyInMeters",
  "country", "countryCode", "stateProvince", "locality",
  "recordedBy", "basisOfRecord", "institutionCode", "collectionCode",
  "catalogNumber", "datasetKey", "occurrenceID"
)
keep <- intersect(keep, names(raw))
bravo <- raw[, keep]

write.csv(bravo, "data/raw/day06/bravo_gbif.csv", row.names = FALSE, fileEncoding = "UTF-8")
saveRDS(bravo, "data/processed/day06_bravo.rds")

message("Guardados ", nrow(bravo), " registros.")
print(table(bravo$year, useNA = "ifany"))
