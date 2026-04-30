suppressPackageStartupMessages({
  library(dplyr); library(tidyr); library(readr); library(here); library(stringr)
  library(httr); library(jsonlite); library(tibble)
})
options(width = 140, pillar.print_max = Inf)

cat("================================================================\n")
cat("ӨГӨГДЛИЙН БАЙРШИЛ\n")
cat("================================================================\n\n")
cat("Локал хадгалсан файлууд:\n")
cat(sprintf("  %s\n", here("data/auxiliary/dzud_panel.rds")))
cat(sprintf("  %s\n", here("data/auxiliary/dzud_panel.csv")))
cat("\nNSO эх үүсвэр (1212.mn):\n")
cat("  https://data.1212.mn/api/v1/mn/NSO/Industry,%20service/Livestock/DT_NSO_1001_029V1.px\n")
cat("  (Том малын зүй бус хорогдол, малын төрөл, баг/хороо, жилээр, 1971-2025)\n\n")

panel <- readRDS(here("data/auxiliary/dzud_panel.rds"))
aimag_names <- read_csv(here("data/auxiliary/aimag_lookup.csv"), show_col_types = FALSE)
panel <- panel |> left_join(aimag_names, by = "hses_code")

cat("================================================================\n")
cat("dzud_panel.rds бүтэц\n")
cat("================================================================\n\n")
cat(sprintf("Хэмжээ: %d мөр × %d багана\n", nrow(panel), ncol(panel)))
cat("Багана:\n")
print(names(panel))

cat("\n================================================================\n")
cat("1999-2002 (\"3 өвлийн зуд\") — ялсан loss_rate (descending)\n")
cat("================================================================\n\n")
print(panel |>
  filter(year %in% 1999:2002) |>
  select(year, aimag = aimag_mn, loss, livestock_lag, loss_rate) |>
  arrange(year, desc(loss_rate)) |>
  mutate(loss_rate = round(loss_rate * 100, 3),
         loss = round(loss, 1),
         livestock_lag = round(livestock_lag, 1)) |>
  rename(`loss_%` = loss_rate))

cat("\n================================================================\n")
cat("2009-2010 (хоёрдугаар их зуд) loss_rate\n")
cat("================================================================\n\n")
print(panel |>
  filter(year %in% 2009:2010) |>
  select(year, aimag = aimag_mn, loss, livestock_lag, loss_rate) |>
  arrange(year, desc(loss_rate)) |>
  mutate(loss_rate = round(loss_rate * 100, 3),
         loss = round(loss, 1),
         livestock_lag = round(livestock_lag, 1)) |>
  rename(`loss_%` = loss_rate))

cat("\n================================================================\n")
cat("CROSS-CHECK: NSO-аас өөр хүснэгт DT_NSO_1001_011V1 (улирлаар)\n")
cat("Зуны 2000-2001 онуудаар улирал тус бүрд харьцуулна\n")
cat("================================================================\n\n")

fetch_pxweb <- function(url, body_str) {
  body_raw <- charToRaw(enc2utf8(body_str))
  res <- POST(url, add_headers("Content-Type"="application/json; charset=utf-8"),
              body = body_raw, timeout(60))
  if (status_code(res) == 200) fromJSON(content(res, "text", encoding="UTF-8"), simplifyVector=FALSE) else NULL
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

# Try alternative table 011V1 (quarterly aimag-level) — only goes back to 2011 sadly
url_011 <- "https://data.1212.mn/api/v1/mn/NSO/Industry,%20service/Livestock/DT_NSO_1001_011V1.px"
cat("URL: https://data.1212.mn/api/v1/mn/NSO/Industry,%20service/Livestock/DT_NSO_1001_011V1.px\n")
cat("Note: Энэ хүснэгт нь 2011 оноос л эхэлдэг тул 1999-2002 зудыг харуулахгүй.\n\n")

# Bag-level raw — show how many SUB-aimag rows we lost when aggregating
url_029 <- "https://data.1212.mn/api/v1/mn/NSO/Industry,%20service/Livestock/DT_NSO_1001_029V1.px"
cat("Жишээ — DT_NSO_1001_029V1-ээс ЗАВХАН (181) АЙМГИЙН 2000 оны мэдээ\n")
cat("(Бүх дэд код = баг/хороо түвшний)\n\n")

js029 <- fetch_pxweb(url_029, '{"query":[],"response":{"format":"json-stat2"}}')
raw <- parse_jsonstat(js029)
zavkhan_2000 <- raw |>
  filter(`Малын төрөл_label` == "Бүгд",
         Он_label == "2000",
         startsWith(Бүс, "181")) |>
  select(code = Бүс, name = Бүс_label, loss = value) |>
  arrange(nchar(code), code)
cat(sprintf("Завхан-аас 2000 онд бүртгэгдсэн нийт мөр: %d\n", nrow(zavkhan_2000)))
print(zavkhan_2000, n = 50)

cat("\n--- Ховд (184) ОНЦ DZUD ЖИЛ (2000) ---\n")
khovd_2000 <- raw |>
  filter(`Малын төрөл_label` == "Бүгд",
         Он_label == "2000",
         startsWith(Бүс, "184")) |>
  select(code = Бүс, name = Бүс_label, loss = value) |>
  arrange(nchar(code), code)
cat(sprintf("Ховд-оос 2000 онд бүртгэгдсэн нийт мөр: %d\n", nrow(khovd_2000)))
print(khovd_2000, n = 30)


