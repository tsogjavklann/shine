suppressPackageStartupMessages({
  library(dplyr); library(httr); library(jsonlite); library(stringr); library(tibble)
})

fetch_pxweb <- function(url, body_str) {
  body_raw <- charToRaw(enc2utf8(body_str))
  res <- POST(url, add_headers("Content-Type"="application/json; charset=utf-8"),
              body = body_raw, timeout(60))
  if (status_code(res) == 200) jsonlite::fromJSON(content(res, "text", encoding="UTF-8"), simplifyVector=FALSE) else NULL
}
parse_jsonstat <- function(js) {
  dim_ids <- unlist(js$id)
  dim_info <- lapply(dim_ids, function(d) {
    cat <- js$dimension[[d]]$category
    idx <- unlist(cat$index); lab <- unlist(cat$label)
    ord <- order(idx); list(codes=names(idx)[ord], labels=lab[names(idx)[ord]])
  })
  grid_lst_rev <- rev(setNames(lapply(dim_info, function(di) di$labels), dim_ids))
  grid_df <- expand.grid(grid_lst_rev, stringsAsFactors=FALSE, KEEP.OUT.ATTRS=FALSE)
  grid_df <- grid_df[, rev(seq_along(grid_df)), drop=FALSE]
  names(grid_df) <- dim_ids
  vals <- unlist(js$value, use.names=FALSE)
  n <- min(nrow(grid_df), length(vals))
  grid_df <- grid_df[seq_len(n),,drop=FALSE]
  grid_df$value <- as.numeric(vals[seq_len(n)])
  as_tibble(grid_df)
}

js <- fetch_pxweb(
  "https://data.1212.mn/api/v1/mn/NSO/Education,%20health/General%20educational%20schools/DT_NSO_2001_001V1.px",
  '{"query":[],"response":{"format":"json-stat2"}}'
)

t <- parse_jsonstat(js) |>
  rename(aimag_mn=1, year_chr=2, teachers=value) |>
  mutate(year = suppressWarnings(as.integer(str_trim(year_chr))))

cat("=== ӨГӨГДЛИЙН ЕРӨНХИЙ МЭДЭЭЛЭЛ ===\n")
cat(sprintf("Жилийн хүрээ: %d - %d\n", min(t$year, na.rm=T), max(t$year, na.rm=T)))
cat(sprintf("Нийт мөр: %d\n", nrow(t)))
cat(sprintf("Нийт аймаг (NSO нэрээр): %d\n\n", length(unique(t$aimag_mn))))

cat("=== БАГШИЙН ТОО АЙМГУУДААР — 2010 ОН ===\n")
print(t |> filter(year == 2010) |> arrange(desc(teachers)) |> select(aimag_mn, teachers),
      n = 30)

cat("\n=== БАГШИЙН ТОО АЙМГУУДААР — 2002 ОН (1985 онд төрсөн нь 17 настай байсан жил) ===\n")
print(t |> filter(year == 2002) |> arrange(desc(teachers)) |> select(aimag_mn, teachers),
      n = 30)

cat("\n=== БАГШИЙН ТОО АЙМГУУДААР — 1990 ОН ===\n")
print(t |> filter(year == 1990) |> arrange(desc(teachers)) |> select(aimag_mn, teachers),
      n = 30)
