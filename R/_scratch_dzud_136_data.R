suppressPackageStartupMessages({
  library(dplyr); library(tidyr); library(readr); library(stringr); library(tibble)
  library(httr); library(jsonlite); library(here)
})
options(width = 140, pillar.print_max = Inf)

fetch_pxweb <- function(url, body) {
  br <- charToRaw(enc2utf8(body))
  res <- POST(url, add_headers("Content-Type"="application/json; charset=utf-8"),
              body = br, timeout(120))
  if (status_code(res) != 200) stop("fail")
  fromJSON(content(res, "text", encoding="UTF-8"), simplifyVector=FALSE)
}
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

# Fetch DT_NSO_1001_136V1 (aimag-level loss)
url_136 <- "https://data.1212.mn/api/v1/mn/NSO/Regional%20development/Livestock/DT_NSO_1001_136V1.px"
js <- fetch_pxweb(url_136, '{"query":[],"response":{"format":"json-stat2"}}')
loss_raw <- parse_jsonstat(js)
cat(sprintf("Total rows: %d\n", nrow(loss_raw)))

# Filter to "Бүгд" species
loss_t <- loss_raw |> filter(`Малын төрөл_label` == "Бүгд")
cat(sprintf("After species filter (Бүгд): %d rows\n\n", nrow(loss_t)))

# Show all Бүс codes/labels
cat("ALL Бүс codes & labels in 136V1:\n")
print(loss_t |> distinct(Бүс, Бүс_label) |> arrange(Бүс), n = 35)

# Map labels to HSES codes (using existing aimag_lookup)
aimag_lookup <- read_csv(here("data/auxiliary/aimag_lookup.csv"), show_col_types = FALSE)
match_aimag <- function(lbl) {
  trimmed <- str_trim(lbl)
  aimag_lookup$hses_code[match(trimmed, aimag_lookup$aimag_mn)]
}

loss_aimag <- loss_t |>
  mutate(year = suppressWarnings(as.integer(Он_label)),
         hses_code = match_aimag(Бүс_label)) |>
  filter(!is.na(hses_code), !is.na(year)) |>
  rename(loss = value) |>
  group_by(hses_code, year) |>
  summarise(loss = first(loss), .groups = "drop")

cat(sprintf("\nMatched aimag-year cells: %d (22 aimag × 34 years = expected 748)\n", nrow(loss_aimag)))
cat(sprintf("Year range: %d-%d, unique aimags: %d\n",
            min(loss_aimag$year), max(loss_aimag$year), length(unique(loss_aimag$hses_code))))

# Display 1999-2002 dzud years
loss_join <- loss_aimag |> left_join(aimag_lookup, by = "hses_code")
cat("\n================================================================\n")
cat("1999-2002 \"3 ӨВЛИЙН ЗУД\" (DT_NSO_1001_136V1 source)\n")
cat("================================================================\n\n")
print(loss_join |>
  filter(year %in% 1999:2002) |>
  arrange(year, desc(loss)) |>
  select(year, aimag = aimag_mn, loss),
  n = 90)

cat("\n================================================================\n")
cat("2009-2010 (хоёрдугаар их зуд)\n")
cat("================================================================\n\n")
print(loss_join |>
  filter(year %in% 2009:2010) |>
  arrange(year, desc(loss)) |>
  select(year, aimag = aimag_mn, loss),
  n = 50)

# Save
saveRDS(loss_aimag, here("data/auxiliary/livestock_loss_aimag_136.rds"))
write_csv(loss_aimag, here("data/auxiliary/livestock_loss_aimag_136.csv"))
cat(sprintf("\nSaved: data/auxiliary/livestock_loss_aimag_136.{rds,csv}\n"))


