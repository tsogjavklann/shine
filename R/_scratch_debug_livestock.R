suppressPackageStartupMessages({library(dplyr); library(readr); library(here); library(httr); library(jsonlite); library(stringr); library(tibble)})
options(width = 130)

xlsx_panel <- readRDS(here("data/auxiliary/dzud_panel.rds"))
lookup <- read_csv(here("data/auxiliary/aimag_lookup.csv"), show_col_types = FALSE)

# Re-fetch API
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

cmp <- xlsx_panel |>
  select(hses_code, year, livestock_xlsx = livestock) |>
  inner_join(api_cnt, by = c("hses_code", "year")) |>
  mutate(diff = livestock_xlsx - livestock_api) |>
  left_join(lookup, by = "hses_code")

cat("=== Largest |diff| in livestock ===\n")
print(cmp |> arrange(desc(abs(diff))) |> select(year, aimag_mn, livestock_xlsx, livestock_api, diff) |> head(20))

cat("\n=== Diff distribution by аймаг ===\n")
print(cmp |> group_by(aimag_mn) |>
        summarise(mean_diff = mean(diff, na.rm=TRUE),
                  n_nonzero = sum(abs(diff) > 0.01, na.rm=TRUE),
                  .groups = "drop") |>
        arrange(desc(abs(mean_diff))))

# Specific check: Завхан 2010 (which we verified earlier)
cat("\n=== Завхан 2009-2010 (lag verify) ===\n")
print(cmp |> filter(aimag_mn == "Завхан", year %in% c(2009, 2010)))

# Check XLSX file directly — DT_NSO_1001_008V1 is sheet name; what is it?
cat("\n=== NOTE: XLSX sheet says DT_NSO_1001_008V1 ===\n")
cat("API DT_NSO_1001_109V1: МАЛЫН ТОО, аймаг, нийслэл, жилээр\n")
cat("DT_NSO_1001_008V1 in original metadata: БОЙЖУУЛСАН ТӨЛ (raised young livestock!)\n")
cat("If XLSX is actually 008V1, that explains the diff — different table altogether.\n")


