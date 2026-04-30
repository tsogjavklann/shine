# =============================================================================
# 08_descriptive.R
# -----------------------------------------------------------------------------
# Зорилго : T1 descriptive — main_sample (home_aimag, n=9,849) дотор гол
#           хувьсагчдын mean/sd/median by reform cohort. Alt-sample (newaimag
#           full, n=23,331) тусдаа column-аар харьцуулна.
# Орц     : data/processed/analysis_sample.rds
# Гарц    : output/tables/T1_descriptive.csv
#           output/logs/08_descriptive.log
# =============================================================================
# CHECKPOINT 1 шийдвэр: MAIN = home_aimag (Card/Duflo cleanest)
# =============================================================================

source(here::here("R", "paths.R"))
suppressPackageStartupMessages({
  library(dplyr); library(tidyr); library(readr); library(cli); library(tictoc)
})

cli::cli_h1("08_descriptive.R — T1 descriptive table")
tic("Total")

# ---- 1. Орц + sample restriction --------------------------------------------
df <- readRDS(file.path(PATHS$data_proc, "analysis_sample.rds")) |> as_tibble()
cli::cli_alert_info("analysis_sample: {nrow(df)} rows × {ncol(df)} cols")

# MAIN: 25-60 нас + home_aimag (q_school_access valid)
main <- df |>
  filter(main_flag_25_60 == 1L, !is.na(q_school_access), is.finite(q_school_access))

# ALT (robustness ref): 25-60 + newaimag valid (q_new valid; broader)
alt  <- df |>
  filter(main_flag_25_60 == 1L, !is.na(q_new), is.finite(q_new))

cli::cli_alert_info("MAIN (home_aimag): {nrow(main)} rows; ALT (newaimag): {nrow(alt)} rows")

# ---- 2. Cohort tagging (PLAN §1.2 reform_main donut) ------------------------
tag_cohort <- function(d) {
  d |>
    mutate(
      cohort = case_when(
        is.na(birth_year)         ~ NA_character_,
        birth_year <= 1995L       ~ "control_le1995",
        birth_year %in% 1996:1997 ~ "donut_1996_97",
        birth_year >= 1998L       ~ "treated_ge1998",
        TRUE                      ~ NA_character_
      )
    )
}

main <- tag_cohort(main)
alt  <- tag_cohort(alt)

# ---- 3. T1 descriptive helpers ----------------------------------------------
# Numeric summary: n, mean, sd, p25, p50, p75
num_summary <- function(x, w = NULL) {
  ok <- !is.na(x) & is.finite(x)
  x  <- x[ok]
  if (!is.null(w)) w <- w[ok]
  if (length(x) == 0L) return(c(n=0L, mean=NA, sd=NA, p25=NA, p50=NA, p75=NA))
  if (is.null(w)) {
    c(n = length(x),
      mean = mean(x), sd = sd(x),
      p25 = unname(quantile(x, .25)),
      p50 = unname(quantile(x, .50)),
      p75 = unname(quantile(x, .75)))
  } else {
    # Weighted mean + sd; quantiles унbiased weighted (use Hmisc-style approx)
    sw <- sum(w)
    m <- sum(x * w) / sw
    v <- sum(w * (x - m)^2) / sw
    c(n = length(x),
      mean = m, sd = sqrt(v),
      p25 = unname(quantile(x, .25)),
      p50 = unname(quantile(x, .50)),
      p75 = unname(quantile(x, .75)))
  }
}

# Build T1 row for one variable in one cohort group
build_row <- function(d, var, label, cohort_filter = NULL, weighted = TRUE) {
  if (!is.null(cohort_filter)) d <- d |> filter(cohort == cohort_filter)
  w <- if (weighted) d$hhweight else NULL
  s <- num_summary(d[[var]], w)
  tibble(variable = label,
         n = as.integer(s["n"]),
         mean = unname(s["mean"]),
         sd   = unname(s["sd"]),
         p25  = unname(s["p25"]),
         p50  = unname(s["p50"]),
         p75  = unname(s["p75"]))
}

# ---- 4. Build T1 by sample × cohort ----------------------------------------
VARS <- list(
  list("educ_years",     "Schooling years (q0213)"),
  list("lwage",          "ln(real hourly wage)"),
  list("real_hourly",    "Real hourly wage (MNT, 2020 base)"),
  list("nominal_hourly", "Nominal hourly wage (MNT)"),
  list("age",            "Age"),
  list("q_school_access",         "school_access (q_school_access, MAIN)"),
  list("q_new",          "school_access (q_new, robustness)"),
  list("is_female",      "Female (1=Эм)"),
  list("is_married",     "Married (q0106 ∈ 2:3)"),
  list("hhsize",         "Household size"),
  list("hhweight",       "Sampling weight")
)

build_t1_section <- function(d, sample_label) {
  cohorts <- list(
    list("ALL",            NULL),
    list("control_le1995", "control_le1995"),
    list("donut_1996_97",  "donut_1996_97"),
    list("treated_ge1998", "treated_ge1998")
  )
  rows <- list()
  for (v in VARS) {
    for (c in cohorts) {
      r <- build_row(d, v[[1]], v[[2]], c[[2]], weighted = TRUE) |>
        mutate(sample = sample_label, cohort = c[[1]], .before = 1)
      rows[[length(rows) + 1L]] <- r
    }
  }
  bind_rows(rows)
}

t1_main <- build_t1_section(main, "MAIN_home_aimag")
t1_alt  <- build_t1_section(alt,  "ALT_newaimag")

T1 <- bind_rows(t1_main, t1_alt) |>
  mutate(across(c(mean, sd, p25, p50, p75), ~ round(.x, 3)))

cli::cli_h2("T1 descriptive (head; ALL rows = both samples × all cohorts × all vars)")
print(T1 |> filter(cohort == "ALL"), n = Inf)

# ---- 5. Cohort N counts ----------------------------------------------------
cohort_N <- bind_rows(
  main |> count(cohort) |> mutate(sample = "MAIN_home_aimag"),
  alt  |> count(cohort) |> mutate(sample = "ALT_newaimag")
) |>
  pivot_wider(names_from = cohort, values_from = n, values_fill = 0L) |>
  select(sample, everything())
cli::cli_h2("Cohort N by sample")
print(cohort_N)

# ---- 6. Wave breakdown (treated cohort distribution) -----------------------
wave_treated <- main |>
  group_by(wave) |>
  summarise(
    n            = n(),
    n_treated    = sum(cohort == "treated_ge1998", na.rm = TRUE),
    pct_treated  = round(100 * n_treated / n, 2),
    n_donut      = sum(cohort == "donut_1996_97", na.rm = TRUE),
    n_control    = sum(cohort == "control_le1995", na.rm = TRUE),
    .groups = "drop"
  )
cli::cli_h2("MAIN sample wave breakdown (treated cohort distribution)")
print(wave_treated)

# ---- 7. Хадгалах ------------------------------------------------------------
write_csv(T1,           file.path(PATHS$out_tables, "T1_descriptive.csv"))
write_csv(cohort_N,     file.path(PATHS$out_logs,   "08_cohort_N_by_sample.csv"))
write_csv(wave_treated, file.path(PATHS$out_logs,   "08_wave_treated.csv"))

log_path <- file.path(PATHS$out_logs, "08_descriptive.log")
sink(log_path, append = FALSE)
cat("==========================================================\n")
cat("08_descriptive.R лог  ", as.character(Sys.time()), "\n")
cat("==========================================================\n")
cat(sprintf("MAIN (home_aimag, 25-60): %d rows\n", nrow(main)))
cat(sprintf("ALT  (newaimag,  25-60): %d rows\n", nrow(alt)))
cat("\nCohort N by sample:\n"); print(cohort_N)
cat("\nMAIN wave × cohort:\n"); print(wave_treated)
cat("\nT1 descriptive (ALL cohort, both samples):\n")
print(T1 |> filter(cohort == "ALL"), n = Inf)
sink()

toc()
cli::cli_alert_success("Гарц: {file.path(PATHS$out_tables, 'T1_descriptive.csv')}")
cli::cli_alert_info("Дараагийн алхам: R/09_balance_check.R")
