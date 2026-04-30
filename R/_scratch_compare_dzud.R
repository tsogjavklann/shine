suppressPackageStartupMessages({library(dplyr); library(readr); library(here); library(httr); library(jsonlite); library(stringr); library(tibble)})
options(width = 130)

# Load XLSX-derived
xlsx_panel <- readRDS(here("data/auxiliary/dzud_panel.rds"))

# Re-fetch API live for comparison
fetch_pxweb <- function(url, body) {
  br <- charToRaw(enc2utf8(body))
  res <- POST(url, add_headers("Content-Type"="application/json; charset=utf-8"),
              body = br, timeout(60))
  if (status_code(res) != 200) stop("fail")
  fromJSON(content(res, "text", encoding="UTF-8"), simplifyVector=FALSE)
}
parse_jsonstat <- function(js) {
  dim_ids <- unlist(js$id)
  dim_info <- lapply(dim_ids, function(d) {
    cat <- js$dimension[[d]]$category
    idx <- unlist(cat$index); lab <- unlist(cat$label)
    ord <- order(idx)
    list(codes=names(idx)[ord], labels=lab[names(idx)[ord]])
  })
  names(dim_info) <- dim_ids
  grid_lst_rev <- rev(setNames(lapply(dim_info, function(di) di$codes), dim_ids))
  grid_df <- expand.grid(grid_lst_rev, stringsAsFactors = FALSE, KEEP.OUT.ATTRS = FALSE)
  grid_df <- grid_df[, rev(seq_along(grid_df)), drop = FALSE]
  names(grid_df) <- dim_ids
  vals <- unlist(js$value, use.names=FALSE)
  n <- min(nrow(grid_df), length(vals))
  grid_df <- grid_df[seq_len(n),,drop=FALSE]
  grid_df$value <- as.numeric(vals[seq_len(n)])
  for (d in dim_ids) {
    grid_df[[paste0(d, "_label")]] <- dim_info[[d]]$labels[match(grid_df[[d]], dim_info[[d]]$codes)]
  }
  as_tibble(grid_df)
}
lookup <- read_csv(here("data/auxiliary/aimag_lookup.csv"), show_col_types = FALSE)

# Loss
js_loss <- fetch_pxweb(
  "https://data.1212.mn/api/v1/mn/NSO/Regional%20development/Livestock/DT_NSO_1001_136V1.px",
  '{"query":[],"response":{"format":"json-stat2"}}')
api_loss <- parse_jsonstat(js_loss) |>
  filter(`Малын төрөл_label` == "Бүгд") |>
  mutate(year = suppressWarnings(as.integer(Он_label)),
         hses_code = lookup$hses_code[match(str_trim(Бүс_label), lookup$aimag_mn)]) |>
  filter(!is.na(hses_code), !is.na(year)) |>
  rename(loss_api = value) |>
  group_by(hses_code, year) |>
  summarise(loss_api = first(loss_api), .groups = "drop")

# Count
js_cnt <- fetch_pxweb(
  "https://data.1212.mn/api/v1/mn/NSO/Regional%20development/Livestock/DT_NSO_1001_109V1.px",
  '{"query":[],"response":{"format":"json-stat2"}}')
api_cnt <- parse_jsonstat(js_cnt) |>
  filter(`Малын төрөл_label` == "Бүгд") |>
  mutate(year = suppressWarnings(as.integer(Он_label)),
         hses_code = lookup$hses_code[match(str_trim(Бүс_label), lookup$aimag_mn)]) |>
  filter(!is.na(hses_code), !is.na(year)) |>
  rename(livestock_api = value) |>
  group_by(hses_code, year) |>
  summarise(livestock_api = first(livestock_api), .groups = "drop")

cat("=== LOSS comparison (API vs XLSX) ===\n")
cmp_loss <- xlsx_panel |>
  select(hses_code, year, loss_xlsx = loss) |>
  full_join(api_loss, by = c("hses_code", "year"))
cat(sprintf("Both present: %d\n", sum(!is.na(cmp_loss$loss_xlsx) & !is.na(cmp_loss$loss_api))))
cat(sprintf("Only XLSX: %d, Only API: %d\n",
            sum(!is.na(cmp_loss$loss_xlsx) & is.na(cmp_loss$loss_api)),
            sum(is.na(cmp_loss$loss_xlsx) & !is.na(cmp_loss$loss_api))))
cmp_loss <- cmp_loss |> mutate(diff = loss_xlsx - loss_api)
cat(sprintf("Mean |diff|: %.4f, max |diff|: %.4f\n",
            mean(abs(cmp_loss$diff), na.rm=TRUE), max(abs(cmp_loss$diff), na.rm=TRUE)))

cat("\n=== COUNT comparison (API vs XLSX) ===\n")
cmp_cnt <- xlsx_panel |>
  select(hses_code, year, livestock_xlsx = livestock) |>
  full_join(api_cnt, by = c("hses_code", "year"))
cat(sprintf("Both present: %d\n", sum(!is.na(cmp_cnt$livestock_xlsx) & !is.na(cmp_cnt$livestock_api))))
cmp_cnt <- cmp_cnt |> mutate(diff = livestock_xlsx - livestock_api)
cat(sprintf("Mean |diff|: %.4f, max |diff|: %.4f\n",
            mean(abs(cmp_cnt$diff), na.rm=TRUE), max(abs(cmp_cnt$diff), na.rm=TRUE)))

# loss_rate comparison
cat("\n=== LOSS_RATE distribution (XLSX panel) ===\n")
cat(sprintf("dzud_5pct: %d, dzud_10pct: %d, dzud_top10: %d\n",
            sum(xlsx_panel$dzud_5pct, na.rm=TRUE),
            sum(xlsx_panel$dzud_10pct, na.rm=TRUE),
            sum(xlsx_panel$dzud_top10, na.rm=TRUE)))

cat("\n=== Top 5 dzud_5pct events ===\n")
print(xlsx_panel |> filter(dzud_5pct == 1L) |>
        left_join(lookup, by = "hses_code") |>
        arrange(desc(loss_rate)) |>
        select(year, aimag_mn, loss, livestock_lag, loss_rate) |>
        head(15))

# Check Завхан 2001 specifically
cat("\n=== Завхан (81) loss_rate timeline ===\n")
print(xlsx_panel |> filter(hses_code == 81) |> arrange(year) |>
        select(year, loss, livestock_lag, loss_rate, dzud_5pct))


