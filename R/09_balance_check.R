# =============================================================================
# 09_balance_check.R
# -----------------------------------------------------------------------------
# Зорилго : Cohort distribution + composition check around reform cutoffs.
#           McCrary RD test нь birth-year manipulation боломжгүй учир invalid
#           — харин раш cohort uniformity-ийг визуал шалгана.
#           Pre-trend (gender, education, region) cohort_le1995 vs cohort_ge1998.
# Орц     : data/processed/analysis_sample.rds
# Гарц    : output/figures/F1_cohort_balance.png  (300 dpi double-panel)
#           output/logs/09_balance.log
#           output/logs/09_pretrend.csv
# =============================================================================

source(here::here("R", "paths.R"))
suppressPackageStartupMessages({
  library(dplyr); library(tidyr); library(readr); library(ggplot2)
  library(cli); library(tictoc)
})

cli::cli_h1("09_balance_check.R — cohort distribution + pre-trend")
tic("Total")

df <- readRDS(file.path(PATHS$data_proc, "analysis_sample.rds")) |> as_tibble()

main <- df |>
  filter(main_flag_25_60 == 1L, !is.na(q_school_access), is.finite(q_school_access),
         !is.na(birth_year))

cli::cli_alert_info("MAIN home_aimag, 25-60: {nrow(main)} rows")

# ---- 1. Cohort distribution (birth-year histogram) ---------------------------
cohort_dist <- main |>
  count(birth_year) |>
  arrange(birth_year)

cli::cli_h2("Cohort N by birth_year (MAIN, full range)")
print(cohort_dist, n = Inf)

# ---- 2. Pre-trend table: composition by 5-year cohort bins ------------------
pretrend <- main |>
  mutate(
    cohort_bin = case_when(
      birth_year >= 1990 & birth_year <= 1995 ~ "1990-1995 (control late)",
      birth_year %in% 1996:1997               ~ "1996-1997 (donut)",
      birth_year >= 1998 & birth_year <= 2003 ~ "1998-2003 (treated)",
      TRUE                                    ~ NA_character_
    )
  ) |>
  filter(!is.na(cohort_bin)) |>
  group_by(cohort_bin) |>
  summarise(
    n              = n(),
    pct_female     = round(100 * mean(is_female, na.rm = TRUE), 2),
    mean_age       = round(mean(age, na.rm = TRUE), 2),
    mean_educ      = round(mean(educ_years, na.rm = TRUE), 2),
    pct_married    = round(100 * mean(is_married, na.rm = TRUE), 2),
    mean_q_school_access    = round(mean(q_school_access, na.rm = TRUE), 3),
    .groups = "drop"
  )

cli::cli_h2("Pre-trend: covariate balance across cohort bins (MAIN home_aimag)")
print(pretrend)

# ---- 3. Wave × cohort × treatment cross-tab --------------------------------
wave_cohort <- main |>
  mutate(
    cohort_bin = case_when(
      birth_year <= 1995L       ~ "≤1995 control",
      birth_year %in% 1996:1997 ~ "1996-97 donut",
      birth_year >= 1998L       ~ "≥1998 treated"
    )
  ) |>
  count(wave, cohort_bin) |>
  pivot_wider(names_from = cohort_bin, values_from = n, values_fill = 0L)

cli::cli_h2("Wave × cohort cross-tab")
print(wave_cohort)

# ---- 4. F1 figure: double-panel cohort balance ------------------------------
# Panel A: cohort distribution histogram (birth_year)
# Panel B: weighted educ_years mean by birth_year (pre-trend visualisation)
g_panelA <- main |>
  count(birth_year) |>
  ggplot(aes(x = birth_year, y = n)) +
  geom_col(fill = "grey60", colour = "grey20") +
  geom_vline(xintercept = c(1995.5, 1997.5), linetype = "dashed", colour = "red", linewidth = 0.6) +
  annotate("text", x = 1996.5, y = max(main |> count(birth_year) |> pull(n), na.rm=T) * 0.95,
           label = "donut\n1996-97", size = 3, colour = "red") +
  scale_x_continuous(breaks = seq(min(main$birth_year, na.rm=T), max(main$birth_year, na.rm=T), by = 5)) +
  labs(
    title = "Panel A: Cohort distribution (birth-year histogram)",
    subtitle = "MAIN home_aimag sample (25-60); donut: 1996-97 dashed",
    x = "Төрсөн он", y = "N (ажиглалт)"
  ) +
  theme_minimal(base_size = 11)

g_panelB <- main |>
  group_by(birth_year) |>
  summarise(
    mean_educ = sum(educ_years * hhweight, na.rm = TRUE) / sum(hhweight[!is.na(educ_years)], na.rm = TRUE),
    n = n(),
    .groups = "drop"
  ) |>
  filter(n >= 30L) |>
  ggplot(aes(x = birth_year, y = mean_educ)) +
  geom_point(aes(size = n), colour = "steelblue", alpha = 0.7) +
  geom_smooth(method = "loess", se = TRUE, colour = "darkblue", linewidth = 0.6) +
  geom_vline(xintercept = c(1995.5, 1997.5), linetype = "dashed", colour = "red", linewidth = 0.6) +
  scale_size_continuous(range = c(1, 4), name = "N") +
  labs(
    title = "Panel B: Weighted mean educ_years by cohort",
    subtitle = "Pre-trend визуал шалгалт; LOESS curve. n≥30 cohort бүрд",
    x = "Төрсөн он", y = "Mean schooling years (hhweight)"
  ) +
  theme_minimal(base_size = 11)

# Combine into double-panel
combined <- patchwork::wrap_plots(g_panelA, g_panelB, ncol = 1) +
  patchwork::plot_annotation(
    title = "F1: Cohort distribution & pre-trend balance (MAIN home_aimag)",
    caption = "ҮСХ HSES 2020/21/22/24, n=9,077, hhweight-аар жинлэсэн"
  )

# ---- 5. Save figure ---------------------------------------------------------
fig_path <- file.path(PATHS$out_figures, "F1_cohort_balance.png")
have_patchwork <- requireNamespace("patchwork", quietly = TRUE)
if (have_patchwork) {
  ggsave(fig_path, combined, width = 8, height = 9, dpi = 300, bg = "white")
} else {
  cli::cli_alert_warning("patchwork байхгүй — Panel A зөвхөн save хийгдэнэ")
  ggsave(fig_path, g_panelA, width = 8, height = 5, dpi = 300, bg = "white")
}

# ---- 6. Save logs/tables ----------------------------------------------------
write_csv(pretrend,    file.path(PATHS$out_logs, "09_pretrend.csv"))
write_csv(wave_cohort, file.path(PATHS$out_logs, "09_wave_cohort.csv"))
write_csv(cohort_dist, file.path(PATHS$out_logs, "09_cohort_dist.csv"))

log_path <- file.path(PATHS$out_logs, "09_balance.log")
sink(log_path, append = FALSE)
cat("==========================================================\n")
cat("09_balance_check.R лог  ", as.character(Sys.time()), "\n")
cat("==========================================================\n")
cat(sprintf("MAIN sample (home_aimag, 25-60): %d rows\n", nrow(main)))
cat(sprintf("Birth year range: [%d, %d]\n", min(main$birth_year, na.rm=T), max(main$birth_year, na.rm=T)))
cat("\nPre-trend balance (5-year bins):\n"); print(pretrend)
cat("\nWave × cohort cross-tab:\n"); print(wave_cohort)
cat("\nCohort distribution (full range):\n"); print(cohort_dist, n=Inf)
cat(sprintf("\nF1 figure saved: %s\n", fig_path))
sink()

toc()
cli::cli_alert_success("Гарц: F1_cohort_balance.png + 09_pretrend.csv")
cli::cli_alert_info("Дараагийн алхам: R/10_ols_baseline.R")
