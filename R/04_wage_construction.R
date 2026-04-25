# =============================================================================
# 04_wage_construction.R
# -----------------------------------------------------------------------------
# Зорилго : HSES 2020-2024 harmonized panel-аас NOMINAL hourly wage үүсгэх.
#           HSES Q4.36 нь sub-part: a = "сүүлийн сард" (monthly), b = "сүүлийн
#           12 сард" (annual). Hourly = q0436b / annual_hours (Tier 1) эсвэл
#           q0436a / monthly_hours (Tier 2 fallback).
#           Sample: 22-60 нас (alt_sample-ыг ч хамруулна; main_flag = 1 if 25-60).
#           Real wage-ийг 04b_cpi_deflator.R дотор үүсгэнэ.
# Орц     : data/processed/hses_harmonized.rds  (R/03_harmonize.R-ийн гарц)
# Гарц    : data/processed/wage_nominal.rds
# =============================================================================
#
# Hourly wage 2-tier formula:
#   Tier 1 (full annual decomposition):
#       annual_hours   = q0437 (months/yr) × q0438 (days/mo) × q0439 (hrs/day)
#       hourly_nominal = q0436b (annual) / annual_hours
#   Tier 2 (fallback if q0437/q0438/q0439-ийн аль нэг NA):
#       monthly_hours_approx = q0427 (hrs/week) × 4.33      (4.33 = 52/12)
#       hourly_nominal       = q0436a (monthly) / (q0427 × 4.33)
# =============================================================================

source(here::here("R", "paths.R"))
suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(readr)
  library(cli)
})

cli::cli_h1("04_wage_construction.R — nominal hourly wage")

# ---- 1. Орц уншиx -----------------------------------------------------------
in_path <- file.path(PATHS$data_proc, "hses_harmonized.rds")
if (!file.exists(in_path)) {
  cli::cli_abort("Орц олдсонгүй: {in_path}. Эхлээд R/03_harmonize.R-г ажиллуул.")
}
df <- readRDS(in_path) |> as_tibble()
cli::cli_alert_info("Harmonized panel: {nrow(df)} мөр × {ncol(df)} багана")

# ---- 2. Шаардлагатай хувьсагч шалгах -----------------------------------------
required <- c("id", "wave", "month_interview", "aimag", "age", "sex",
              "working_for_wage", "q0436a", "q0436b",
              "q0437", "q0438", "q0439", "q0427")
missing_vars <- setdiff(required, names(df))
if (length(missing_vars)) {
  cli::cli_abort("Дутуу хувьсагч: {paste(missing_vars, collapse = ', ')}")
}

# ---- 3. Sample filter (22-60 alt; 25-60 main_flag) --------------------------
df_emp <- df |>
  filter(
    working_for_wage == 1L,
    age >= 22L, age <= 60L
  ) |>
  mutate(main_flag = age >= 25L & age <= 60L)

cli::cli_alert_info(
  "Filter (working_for_wage=1, 22-60 нас): {nrow(df)} → {nrow(df_emp)} мөр; ",
  "main_flag (25-60): {sum(df_emp$main_flag)} мөр"
)

# ---- 4. Nominal hourly wage (2-tier) ----------------------------------------
# Tier 1 (тэргүүн): q0436b (annual) / (q0437 × q0438 × q0439)
df_emp <- df_emp |>
  mutate(
    annual_hours_t1 = q0437 * q0438 * q0439,
    hourly_t1 = if_else(
      !is.na(q0436b) & !is.na(annual_hours_t1) &
        q0436b > 0 & annual_hours_t1 > 0 & annual_hours_t1 <= 4992,
      # 4992 = 24 × 31 × 12 — implausibility upper bound
      q0436b / annual_hours_t1,
      NA_real_
    )
  )

# Tier 2 (fallback): q0436a (monthly) / (q0427 × 4.33)
WEEKS_PER_MONTH <- 4.33   # 52 / 12
df_emp <- df_emp |>
  mutate(
    hourly_t2 = if_else(
      !is.na(q0436a) & !is.na(q0427) &
        q0436a > 0 & q0427 > 0 & q0427 <= 80,
      q0436a / (q0427 * WEEKS_PER_MONTH),
      NA_real_
    )
  )

# Coalesce: tier1 → tier2
df_emp <- df_emp |>
  mutate(
    nominal_hourly = coalesce(hourly_t1, hourly_t2),
    wage_method = case_when(
      !is.na(hourly_t1) ~ "tier1",
      !is.na(hourly_t2) ~ "tier2",
      TRUE              ~ NA_character_
    )
  ) |>
  filter(!is.na(nominal_hourly), nominal_hourly > 0)

# ---- 5. Outlier trim (top/bottom 1% per wave) -------------------------------
df_emp <- df_emp |>
  group_by(wave) |>
  mutate(
    p01 = quantile(nominal_hourly, 0.01, na.rm = TRUE),
    p99 = quantile(nominal_hourly, 0.99, na.rm = TRUE),
    wage_trim_flag = nominal_hourly < p01 | nominal_hourly > p99
  ) |>
  ungroup()

n_trim <- sum(df_emp$wage_trim_flag)
df_clean <- df_emp |>
  filter(!wage_trim_flag) |>
  select(-p01, -p99, -wage_trim_flag) |>
  mutate(ln_nominal_hourly = log(nominal_hourly))

cli::cli_alert_info("Outlier trim (top/bottom 1% wave-аар): {n_trim} мөр устсан.")
cli::cli_alert_info("Эцсийн nominal wage panel: {nrow(df_clean)} мөр.")

# ---- 6. Method-аар хуваарилалт ----------------------------------------------
method_tbl <- df_clean |>
  count(wave, wage_method) |>
  pivot_wider(names_from = wage_method, values_from = n, values_fill = 0L)
cli::cli_h2("Wage method хуваарилалт (wave × tier)")
print(method_tbl)

# ---- 7. year_month түлхүүр баталгаажуулах -----------------------------------
if (!"year_month" %in% names(df_clean)) {
  df_clean <- df_clean |>
    mutate(year_month = sprintf("%d-%02d", wave, month_interview))
}

# ---- 8. Сводка --------------------------------------------------------------
summary_tbl <- df_clean |>
  group_by(wave) |>
  summarise(
    n             = n(),
    n_main        = sum(main_flag),
    mean_nominal  = mean(nominal_hourly, na.rm = TRUE),
    median_nominal = median(nominal_hourly, na.rm = TRUE),
    sd_nominal    = sd(nominal_hourly, na.rm = TRUE),
    mean_lnominal = mean(ln_nominal_hourly, na.rm = TRUE),
    .groups = "drop"
  )

cli::cli_h2("Wave-аар nominal hourly wage товчлол (MNT)")
print(summary_tbl)

# ---- 9. Хадгалах ------------------------------------------------------------
out_path  <- file.path(PATHS$data_proc, "wage_nominal.rds")
saveRDS(df_clean, out_path)
write_csv(summary_tbl, file.path(PATHS$out_logs, "04_wage_summary_by_wave.csv"))
write_csv(method_tbl,  file.path(PATHS$out_logs, "04_wage_method.csv"))

# Лог
log_path <- file.path(PATHS$out_logs, "04_wage_construction.log")
sink(log_path, append = FALSE)
cat("==========================================================\n")
cat("04_wage_construction.R лог  ", as.character(Sys.time()), "\n")
cat("==========================================================\n")
cat(sprintf("Орц: %s (%d мөр)\n", in_path, nrow(df)))
cat(sprintf("Filter (working_for_wage=1, 22-60 нас): %d мөр\n", nrow(df_emp)))
cat(sprintf("Outlier trim (top/bottom 1%% wave-аар): %d мөр устсан\n", n_trim))
cat(sprintf("Эцсийн nominal wage panel: %d мөр\n", nrow(df_clean)))
cat(sprintf("  main_flag (25-60): %d мөр\n", sum(df_clean$main_flag)))
cat("\nWave-аар:\n"); print(summary_tbl)
cat("\nWave × tier:\n"); print(method_tbl)
sink()

cli::cli_alert_success("Гарц: {out_path}  ({nrow(df_clean)} мөр)")
cli::cli_alert_info("Дараагийн алхам: R/04b_cpi_deflator.R")
