# =============================================================================
# 04b_cpi_deflator.R
# -----------------------------------------------------------------------------
# Зорилго : NSO PXWeb API (data.1212.mn) -аас Хэрэглээний үнийн улсын суурь
#           индекс (DT_NSO_0600_001V3, 2020=100 base) -ийг татаж 2 series үүсгэх:
#             cpi_annual  — year тус бүрд (Tier 1, q0436b annual deflation)
#             cpi_monthly — year-month тус бүрд (Tier 2, q0436a prev-month)
#           Wage panel-той tier-аас хамаарч merge → real_hourly + lwage.
# Орц     : data/processed/wage_nominal.rds
# Гарц    : data/aux/cpi_annual_2020base.rds
#           data/aux/cpi_monthly_2020base.rds
#           data/processed/wage_real.rds
# -----------------------------------------------------------------------------
# CPI source-ийн дараалал:
#   1) NSO PXWeb API (national, monthly, 2020=100)              ← primary
#   2) data/aux/cpi_manual.csv                                  ← fallback
# =============================================================================

source(here::here("R", "paths.R"))
suppressPackageStartupMessages({
  library(dplyr); library(tidyr); library(readr); library(stringr)
  library(jsonlite); library(httr); library(cli); library(tictoc)
})

cli::cli_h1("04b_cpi_deflator.R — two CPI series + real hourly wage")
tic("Total")

BASE_YEAR <- 2020L

# ---- 1. Wage panel ачаалах --------------------------------------------------
in_path <- file.path(PATHS$data_proc, "wage_nominal.rds")
if (!file.exists(in_path)) {
  cli::cli_abort("Орц олдсонгүй: {in_path}. Эхлээд R/04_wage_construction.R-г ажиллуул.")
}
wage <- readRDS(in_path) |> as_tibble()
cli::cli_alert_info("Nominal wage panel: {nrow(wage)} мөр")

# CPI matching keys:
#   Tier 1: aimag × year                  (use cpi_annual)
#   Tier 2: aimag × (year, month-1)       (use cpi_monthly)
wage <- wage |>
  mutate(
    cpi_year_t1 = as.integer(wave),
    cpi_year_t2  = if_else(month_interview == 1L, wave - 1L, wave),
    cpi_month_t2 = if_else(month_interview == 1L, 12L, as.integer(month_interview) - 1L),
    cpi_ym_t2    = sprintf("%d-%02d", cpi_year_t2, cpi_month_t2)
  )

# ---- 2. NSO PXWeb API fetcher -----------------------------------------------
NSO_API <- "https://data.1212.mn/api/v1/mn/NSO/Economy,%20environment/Consumer%20Price%20Index/DT_NSO_0600_001V3.px"

# Query body: Суурь он=2020=100 (index "1"), Бүлэг=Ерөнхий индекс ("0")
# UTF-8 raw bytes-аар POST хийнэ — R-ийн default encoding нь Cyrillic
# JSON key-уудыг буруу serialize хийдэг тул charToRaw(enc2utf8()) шаардлагатай
NSO_QUERY_STR <- '{"query":[{"code":"Суурь он","selection":{"filter":"item","values":["1"]}},{"code":"Бүлэг","selection":{"filter":"item","values":["0"]}}],"response":{"format":"json-stat2"}}'

fetch_nso_cpi_pxweb <- function(retries = 3L) {
  body_raw <- charToRaw(enc2utf8(NSO_QUERY_STR))
  for (i in seq_len(retries)) {
    cli::cli_alert("NSO PXWeb fetch attempt {i}/{retries}...")
    res <- tryCatch(
      httr::POST(NSO_API,
                 httr::add_headers(
                   "Content-Type" = "application/json; charset=utf-8",
                   "Accept" = "application/json"),
                 body = body_raw,
                 httr::timeout(60)),
      error = function(e) { cli::cli_alert_warning("HTTP error: {conditionMessage(e)}"); NULL }
    )
    if (!is.null(res) && httr::status_code(res) == 200L) {
      txt <- httr::content(res, "text", encoding = "UTF-8")
      js  <- jsonlite::fromJSON(txt, simplifyVector = FALSE)
      return(js)
    }
    if (!is.null(res)) cli::cli_alert_warning("HTTP {httr::status_code(res)}")
  }
  NULL
}

# ---- 3. Try API; fall back to manual CSV ------------------------------------
cpi_source <- NA_character_
cpi_monthly <- NULL

js <- fetch_nso_cpi_pxweb()
if (!is.null(js)) {
  cpi_source <- "nso_pxweb_api"
  # Parse json-stat2: dimension Сар.category.label maps "idx" → "YYYY-MM"
  month_labels <- js$dimension$`Сар`$category$label
  values <- unlist(js$value)
  if (length(month_labels) != length(values)) {
    cli::cli_alert_warning("Month label count ({length(month_labels)}) != value count ({length(values)}); using min")
  }
  n <- min(length(month_labels), length(values))
  ym <- unname(unlist(month_labels))[1:n]
  vv <- values[1:n]
  cpi_monthly <- tibble(
    year_month = ym,
    cpi_raw    = suppressWarnings(as.numeric(vv))
  ) |>
    filter(!is.na(cpi_raw)) |>
    mutate(
      year  = as.integer(substr(year_month, 1, 4)),
      month = as.integer(substr(year_month, 6, 7))
    ) |>
    filter(year >= 2018L, year <= 2026L)
  cli::cli_alert_success("NSO PXWeb fetched: {nrow(cpi_monthly)} monthly CPI rows (2018-2026 window)")
} else {
  cli::cli_alert_warning("NSO API failed — falling back to manual CSV")
  fp <- file.path(PATHS$data_aux, "cpi_manual.csv")
  if (!file.exists(fp)) {
    cli::cli_abort("Manual CSV олдсонгүй: {fp}")
  }
  manual <- read_csv(fp, show_col_types = FALSE)
  cpi_monthly <- manual |>
    transmute(
      year       = as.integer(year),
      month      = as.integer(month),
      cpi_raw    = as.numeric(cpi),
      year_month = sprintf("%d-%02d", year, month)
    )
  cpi_source <- "manual_csv"
  cli::cli_alert_success("Manual CSV: {nrow(cpi_monthly)} rows")
}

# ---- 4. Rebase to BASE_YEAR average = 100 -----------------------------------
base_avg <- mean(cpi_monthly$cpi_raw[cpi_monthly$year == BASE_YEAR], na.rm = TRUE)
if (is.na(base_avg) || base_avg <= 0) {
  cli::cli_abort("Base year ({BASE_YEAR}) CPI average олдсонгүй эсвэл <=0")
}

cpi_monthly <- cpi_monthly |>
  mutate(cpi = 100 * cpi_raw / base_avg) |>
  arrange(year, month) |>
  select(year, month, year_month, cpi)

cpi_annual <- cpi_monthly |>
  group_by(year) |>
  summarise(cpi = mean(cpi, na.rm = TRUE), .groups = "drop")

cli::cli_alert_success(
  "Rebased to {BASE_YEAR}=100 (base avg raw={round(base_avg,1)}); ",
  "cpi_annual {nrow(cpi_annual)} rows; cpi_monthly {nrow(cpi_monthly)} rows"
)
cli::cli_alert_info(
  "Annual range: [{round(min(cpi_annual$cpi),1)}, {round(max(cpi_annual$cpi),1)}]; ",
  "Monthly range: [{round(min(cpi_monthly$cpi),1)}, {round(max(cpi_monthly$cpi),1)}]"
)

saveRDS(cpi_annual,  file.path(PATHS$data_aux, "cpi_annual_2020base.rds"))
saveRDS(cpi_monthly, file.path(PATHS$data_aux, "cpi_monthly_2020base.rds"))
write_csv(cpi_annual,  file.path(PATHS$data_aux, "cpi_annual_2020base.csv"))
write_csv(cpi_monthly, file.path(PATHS$data_aux, "cpi_monthly_2020base.csv"))

# ---- 5. Merge to wage panel by tier -----------------------------------------
# National-level CPI (no aimag dimension) → join on year / year_month only
wage_real <- wage |>
  left_join(cpi_annual  |> rename(cpi_t1 = cpi),
            by = c("cpi_year_t1" = "year")) |>
  left_join(cpi_monthly |> rename(cpi_t2 = cpi) |> select(year_month, cpi_t2),
            by = c("cpi_ym_t2" = "year_month"))

# ---- 6. Tier-aware real wage ------------------------------------------------
wage_real <- wage_real |>
  mutate(
    cpi_used = case_when(
      wage_method == "tier1" ~ cpi_t1,
      wage_method == "tier2" ~ cpi_t2,
      TRUE                   ~ NA_real_
    ),
    real_hourly = nominal_hourly / (cpi_used / 100),
    lwage       = log(real_hourly),
    cpi_source  = cpi_source
  )

# ---- 7. Diagnostics ---------------------------------------------------------
n_missing <- sum(is.na(wage_real$cpi_used))
chk <- wage_real |>
  group_by(wave, wage_method) |>
  summarise(
    n         = n(),
    mean_cpi  = mean(cpi_used, na.rm = TRUE),
    mean_nom  = mean(nominal_hourly, na.rm = TRUE),
    mean_real = mean(real_hourly, na.rm = TRUE),
    .groups = "drop"
  )

cli::cli_h2("Wave × tier: nominal vs real hourly wage")
print(chk)
cli::cli_alert_info("Missing cpi_used rows: {n_missing}")

# ---- 8. Хадгалах + лог ------------------------------------------------------
out_path <- file.path(PATHS$data_proc, "wage_real.rds")
saveRDS(wage_real, out_path)
write_csv(chk, file.path(PATHS$out_logs, "04b_cpi_summary.csv"))

log_path <- file.path(PATHS$out_logs, "04b_cpi_deflator.log")
sink(log_path, append = FALSE)
cat("==========================================================\n")
cat("04b_cpi_deflator.R лог  ", as.character(Sys.time()), "\n")
cat("==========================================================\n")
cat(sprintf("CPI source: %s\n", cpi_source))
cat(sprintf("BASE_YEAR: %d\n", BASE_YEAR))
cat(sprintf("Base year raw average: %.2f\n", base_avg))
cat(sprintf("cpi_annual rows: %d\n", nrow(cpi_annual)))
cat(sprintf("cpi_monthly rows: %d\n", nrow(cpi_monthly)))
cat(sprintf("Wage panel: %d rows\n", nrow(wage)))
cat(sprintf("Missing cpi_used: %d (%.2f%%)\n", n_missing, 100*n_missing/nrow(wage_real)))
cat("\nWave × tier × CPI:\n"); print(chk)
cat("\ncpi_annual sample (2019-2024):\n")
print(cpi_annual |> filter(year >= 2019, year <= 2024))
sink()

toc()
cli::cli_alert_success("Гарц: {out_path}  ({nrow(wage_real)} мөр)")
cli::cli_alert_info("Дараагийн алхам: R/05_education_supply.R")
