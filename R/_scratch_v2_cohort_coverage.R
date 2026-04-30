suppressPackageStartupMessages({library(dplyr); library(here); library(readr); library(tibble); library(tidyr)})
options(width = 130)

panel <- readRDS(here("data/auxiliary/dzud_panel.rds"))
df    <- readRDS(here("data/processed/analysis_sample.rds")) |> as_tibble()

cat("=================================================================\n")
cat("DZUD V2 — өгөгдлийн cohort болон жилийн хамрах хүрээ\n")
cat("=================================================================\n\n")

cat("NSO loss data: 1991-2024 (34 жил)\n")
cat("NSO count data: 1970-2024 (55 жил)\n\n")

# Build minimal exposure for both windows
build_n_obs <- function(panel, age_lo, age_hi) {
  expand_grid(birth_aimag = sort(unique(panel$hses_code)),
              birth_year  = 1955:2010) |>
    rowwise() |>
    mutate(n_obs = sum(!is.na(panel$loss_rate[panel$hses_code == birth_aimag &
                                              panel$year %in% (birth_year + age_lo):(birth_year + age_hi)]))) |>
    ungroup() |>
    mutate(window = sprintf("%d-%d", age_lo, age_hi),
           n_max = age_hi - age_lo + 1L)
}
exp_12_17 <- build_n_obs(panel, 12, 17)
exp_6_17  <- build_n_obs(panel, 6, 17)

cat("=== Cohort coverage by window (per birth_year) ===\n\n")
cat("12-17 window (loss data needed: birth+12 to birth+17):\n")
cat("  Earliest fully covered cohort: birth_year >= 1991-12 = 1979\n")
cat("  Latest fully covered cohort:   birth_year <= 2024-17 = 2007\n\n")

cat("6-17 window (loss data needed: birth+6 to birth+17):\n")
cat("  Earliest fully covered cohort: birth_year >= 1991-6 = 1985\n")
cat("  Latest fully covered cohort:   birth_year <= 2024-17 = 2007\n\n")

# Apply same filters as v2 script
main <- df |>
  filter(main_flag_25_60 == 1L,
         !is.na(q_school_access), is.finite(q_school_access),
         !is.na(birth_year), !is.na(educ_years), !is.na(lwage),
         !is.na(birth_aimag), !is.na(hhweight)) |>
  left_join(exp_12_17 |> select(-window, -n_max) |> rename(n_12_17 = n_obs),
            by = c("birth_aimag", "birth_year")) |>
  left_join(exp_6_17 |> select(-window, -n_max) |> rename(n_6_17 = n_obs),
            by = c("birth_aimag", "birth_year"))

cat("=== HSES sample (main_flag_25_60) cohort distribution ===\n")
print(main |> count(birth_year) |> arrange(birth_year), n = Inf)

cat("\n=== Coverage by birth_year (12-17 window) ===\n")
print(main |> group_by(birth_year) |>
        summarise(n = n(), n_full_12_17 = sum(n_12_17 == 6),
                  pct_full = round(100*mean(n_12_17 == 6), 1), .groups = "drop"),
      n = Inf)

cat("\n=== Coverage by birth_year (6-17 window) ===\n")
print(main |> group_by(birth_year) |>
        summarise(n = n(), n_full_6_17 = sum(n_6_17 == 12),
                  pct_full = round(100*mean(n_6_17 == 12), 1), .groups = "drop"),
      n = Inf)

# Final v2 sample
v2_sample <- main |> filter(n_12_17 == 6, n_6_17 == 12)
cat(sprintf("\n=== V2 final analysis sample ===\n"))
cat(sprintf("N = %d (after both window full-coverage filters)\n", nrow(v2_sample)))
cat(sprintf("Birth years: %d - %d (%d cohorts)\n",
            min(v2_sample$birth_year), max(v2_sample$birth_year),
            length(unique(v2_sample$birth_year))))
cat(sprintf("Age at survey: %d - %d\n",
            min(v2_sample$age, na.rm=TRUE), max(v2_sample$age, na.rm=TRUE)))

cat("\nN by wave:\n")
print(v2_sample |> count(wave))


