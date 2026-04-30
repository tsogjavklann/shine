suppressPackageStartupMessages({
  library(httr); library(jsonlite); library(dplyr); library(readr); library(stringr); library(tibble); library(here)
})
options(width = 130)

cat("=================================================================\n")
cat("CSV-ийн эх үүсвэрийг баталгаажуулах\n")
cat("=================================================================\n\n")

# 1. Бид хадгалсан CSV-ийг унших
local <- read_csv(here("data/auxiliary/dzud_panel.csv"), show_col_types = FALSE)
cat(sprintf("Локал CSV: %d мөр × %d багана\n", nrow(local), ncol(local)))
cat(sprintf("Жилийн хүрээ: %d-%d\n", min(local$year), max(local$year)))
cat(sprintf("Аймаг (hses_code): %d\n\n", length(unique(local$hses_code))))

# 2. NSO URL-ээс шууд татах
url_loss <- "https://data.1212.mn/api/v1/mn/NSO/Regional%20development/Livestock/DT_NSO_1001_136V1.px"
cat(sprintf("Татах URL: %s\n\n", url_loss))

body <- '{"query":[],"response":{"format":"json-stat2"}}'
res <- POST(url_loss,
            add_headers("Content-Type"="application/json; charset=utf-8"),
            body = charToRaw(enc2utf8(body)), timeout(60))
cat(sprintf("HTTP status: %d\n", status_code(res)))
js <- fromJSON(content(res, "text", encoding="UTF-8"), simplifyVector=FALSE)
cat(sprintf("Хүснэгтийн нэр (NSO API-аас): %s\n\n", js$label))

# Parse
parse_jsonstat <- function(js) {
  dim_ids <- unlist(js$id)
  dim_info <- lapply(dim_ids, function(d) {
    cat <- js$dimension[[d]]$category
    idx <- unlist(cat$index); lab <- unlist(cat$label)
    ord <- order(idx)
    list(codes = names(idx)[ord], labels = lab[names(idx)[ord]])
  })
  names(dim_info) <- dim_ids
  grid_lst_rev <- rev(setNames(lapply(dim_info, function(di) di$codes), dim_ids))
  grid_df <- expand.grid(grid_lst_rev, stringsAsFactors = FALSE, KEEP.OUT.ATTRS = FALSE)
  grid_df <- grid_df[, rev(seq_along(grid_df)), drop = FALSE]
  names(grid_df) <- dim_ids
  vals <- unlist(js$value, use.names = FALSE)
  n <- min(nrow(grid_df), length(vals))
  grid_df <- grid_df[seq_len(n), , drop = FALSE]
  grid_df$value <- as.numeric(vals[seq_len(n)])
  for (d in dim_ids) {
    grid_df[[paste0(d, "_label")]] <- dim_info[[d]]$labels[match(grid_df[[d]], dim_info[[d]]$codes)]
  }
  as_tibble(grid_df)
}

raw <- parse_jsonstat(js)
aimag_lookup <- read_csv(here("data/auxiliary/aimag_lookup.csv"), show_col_types = FALSE)
nso_panel <- raw |>
  filter(`Малын төрөл_label` == "Бүгд") |>
  mutate(year = suppressWarnings(as.integer(Он_label)),
         hses_code = aimag_lookup$hses_code[match(str_trim(Бүс_label), aimag_lookup$aimag_mn)]) |>
  filter(!is.na(hses_code), !is.na(year)) |>
  rename(loss_nso = value) |>
  group_by(hses_code, year) |>
  summarise(loss_nso = first(loss_nso), .groups = "drop")

cat(sprintf("NSO API хариу: %d (aimag, year) cell\n\n", nrow(nso_panel)))

# 3. Локал vs NSO API харьцуулалт
cmp <- local |>
  select(hses_code, year, loss_local = loss) |>
  inner_join(nso_panel, by = c("hses_code", "year")) |>
  mutate(diff = loss_local - loss_nso)

cat("=================================================================\n")
cat("ХАРЬЦУУЛАЛТ: Локал CSV vs NSO API ШУУД татсан\n")
cat("=================================================================\n\n")

cat(sprintf("Нийт харьцуулсан cell: %d\n", nrow(cmp)))
cat(sprintf("Утга яг ИЖИЛ (diff = 0): %d\n", sum(cmp$diff == 0, na.rm = TRUE)))
cat(sprintf("Утга ӨӨР: %d\n", sum(cmp$diff != 0, na.rm = TRUE)))
cat(sprintf("Хамгийн их diff: %.6f\n\n", max(abs(cmp$diff), na.rm = TRUE)))

cat("Random sample of 10 cells (харьцуулалт):\n")
print(cmp |> sample_n(10) |> arrange(year, hses_code))

cat("\n2010 он (зууны зуд) — БҮХ 22 АЙМАГ:\n")
cmp_2010 <- cmp |> filter(year == 2010) |> arrange(desc(loss_local))
aimag_names <- aimag_lookup |> rename(name = aimag_mn)
cmp_2010 <- cmp_2010 |> left_join(aimag_names, by = "hses_code")
print(cmp_2010 |> select(year, name, loss_local, loss_nso, diff))


