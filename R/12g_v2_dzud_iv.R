# =============================================================================
# R/12g_v2_dzud_iv.R — DZUD IV (CORRECTED V2)
#
# Phase 2 corrections (vs v1 R/12g_dzud_iv.R):
#   1. Main exposure window: AGE 12-17 (educ choice), not 6-17 (nutrition channel)
#   2. Mortality RATE = loss / lag(livestock) × 100 (already done in v1)
#   3. Animal types: bundled "Бүгд" main; species-split = robustness/mechanism
#   4. FE: birth_aimag + birth_cohort (5-year bins) + wave; NOT aimag×cohort interaction
#   5. HONEST verdicts: "F empirically" not "F expected"; "failed-to-reject" not "valid"
#
# Identification: within-aimag (chronic risk absorbed) + within-cohort (secular trends
#   absorbed). Dzud variation = idiosyncratic year shocks differentially experienced
#   by adjacent birth cohorts.
#
# Эх сурвалж: data/auxiliary/livestock_loss_by_aimag.{csv,rds} +
#             data/auxiliary/livestock_count_by_aimag.{csv,rds}
#             (R/02b_clean_nso_xlsx.R-аар цэвэрлэсэн)
# =============================================================================
suppressPackageStartupMessages({
  library(dplyr); library(tidyr); library(readr); library(stringr); library(tibble)
  library(fixest); library(cli); library(here)
})
setFixest_estimation(panel.id = NULL)
set.seed(2026)
options(width = 130)

AUX <- here("data", "auxiliary")

# -----------------------------------------------------------------------------
# 1. Load cleaned panel + compute year-specific top quartile threshold
# -----------------------------------------------------------------------------
cli_h1("STEP 1: Load dzud_panel + add year-specific severe_p75")

panel <- readRDS(file.path(AUX, "dzud_panel.rds")) |>
  as_tibble() |>
  group_by(year) |>
  mutate(severe_p75 = as.integer(loss_rate >= quantile(loss_rate, 0.75, na.rm = TRUE))) |>
  ungroup()

cat(sprintf("Panel: %d rows × %d cols, years %d-%d\n",
            nrow(panel), ncol(panel), min(panel$year), max(panel$year)))
cat(sprintf("dzud_5pct events: %d, dzud_10pct: %d, severe_p75: %d\n",
            sum(panel$dzud_5pct, na.rm = TRUE),
            sum(panel$dzud_10pct, na.rm = TRUE),
            sum(panel$severe_p75, na.rm = TRUE)))

# -----------------------------------------------------------------------------
# 2. Build childhood exposure for THREE windows
# -----------------------------------------------------------------------------
cli_h1("STEP 2: Childhood exposure (12-17 main / 15-17 narrow / 6-17 broad)")

build_exposure <- function(panel, age_lo, age_hi, suffix) {
  expand_grid(
    birth_aimag = sort(unique(panel$hses_code)),
    birth_year  = 1955:2010
  ) |>
    rowwise() |>
    mutate(
      cum   = sum(panel$loss_rate[panel$hses_code == birth_aimag &
                                  panel$year %in% (birth_year + age_lo):(birth_year + age_hi)],
                  na.rm = TRUE),
      maxv  = suppressWarnings(max(panel$loss_rate[panel$hses_code == birth_aimag &
                                                   panel$year %in% (birth_year + age_lo):(birth_year + age_hi)],
                                   na.rm = TRUE)),
      cnt5  = sum(panel$dzud_5pct[panel$hses_code == birth_aimag &
                                  panel$year %in% (birth_year + age_lo):(birth_year + age_hi)],
                  na.rm = TRUE),
      cnt10 = sum(panel$dzud_10pct[panel$hses_code == birth_aimag &
                                   panel$year %in% (birth_year + age_lo):(birth_year + age_hi)],
                  na.rm = TRUE),
      cntp75 = sum(panel$severe_p75[panel$hses_code == birth_aimag &
                                    panel$year %in% (birth_year + age_lo):(birth_year + age_hi)],
                   na.rm = TRUE),
      n_obs = sum(!is.na(panel$loss_rate[panel$hses_code == birth_aimag &
                                         panel$year %in% (birth_year + age_lo):(birth_year + age_hi)]))
    ) |>
    ungroup() |>
    mutate(maxv = ifelse(is.finite(maxv), maxv, NA_real_)) |>
    rename_with(~ paste0(.x, "_", suffix), c(cum, maxv, cnt5, cnt10, cntp75, n_obs))
}

exp_12_17 <- build_exposure(panel, 12, 17, "12_17")  # main
exp_15_17 <- build_exposure(panel, 15, 17, "15_17")  # narrow
exp_6_17  <- build_exposure(panel,  6, 17, "6_17")   # broad
cat(sprintf("Exposure cells: %d (each window)\n", nrow(exp_12_17)))

# -----------------------------------------------------------------------------
# 3. Merge to HSES analysis sample
# -----------------------------------------------------------------------------
cli_h1("STEP 3: Merge to HSES analysis sample")

df <- readRDS(here("data/processed/analysis_sample.rds")) |> as_tibble()
main <- df |>
  filter(main_flag_25_60 == 1L,
         !is.na(q_school_access), is.finite(q_school_access),
         !is.na(birth_year), !is.na(educ_years), !is.na(lwage),
         !is.na(birth_aimag), !is.na(hhweight)) |>
  left_join(exp_12_17, by = c("birth_aimag", "birth_year")) |>
  left_join(exp_15_17, by = c("birth_aimag", "birth_year")) |>
  left_join(exp_6_17,  by = c("birth_aimag", "birth_year")) |>
  # 5-year birth cohort bins (FE)
  mutate(birth_cohort = case_when(
    birth_year < 1970 ~ "pre1970",
    birth_year < 1975 ~ "1970-74",
    birth_year < 1980 ~ "1975-79",
    birth_year < 1985 ~ "1980-84",
    birth_year < 1990 ~ "1985-89",
    birth_year < 1995 ~ "1990-94",
    TRUE              ~ "post1995"
  ))

cat(sprintf("Main sample: N=%d\n", nrow(main)))
cat(sprintf("Cells with FULL 12-17 window (n_obs=6):  %d (%.1f%%)\n",
            sum(main$n_obs_12_17 == 6, na.rm = TRUE),
            100 * mean(main$n_obs_12_17 == 6, na.rm = TRUE)))
cat(sprintf("Cells with FULL 6-17 window (n_obs=12):  %d (%.1f%%)\n",
            sum(main$n_obs_6_17 == 12, na.rm = TRUE),
            100 * mean(main$n_obs_6_17 == 12, na.rm = TRUE)))

# Restrict to cohorts with FULL coverage (avoid bias from partial windows)
iv_data <- main |> filter(n_obs_12_17 == 6, n_obs_6_17 == 12)
cat(sprintf("After full-coverage filter: N=%d\n", nrow(iv_data)))

# -----------------------------------------------------------------------------
# 4. First-stage F across all 5 IVs × 3 windows = 15 specs
# -----------------------------------------------------------------------------
cli_h1("STEP 4: First-stage F (5 IVs × 3 windows)")

iv_specs <- list(
  list(stem = "cum",    label = "cumulative loss rate"),
  list(stem = "maxv",   label = "maximum loss rate"),
  list(stem = "cnt5",   label = ">=5% loss count"),
  list(stem = "cnt10",  label = ">=10% loss count"),
  list(stem = "cntp75", label = ">=year-p75 loss count")
)
windows <- list(
  list(suf = "12_17", label = "12-17 (MAIN)"),
  list(suf = "15_17", label = "15-17 (narrow)"),
  list(suf = "6_17",  label = "6-17 (broad)")
)

run_first_stage <- function(iv_var) {
  fml <- as.formula(sprintf(
    "educ_years ~ %s + age + age2 + is_female + is_married | birth_aimag + birth_cohort + wave",
    iv_var))
  feols(fml, data = iv_data, weights = ~hhweight, cluster = ~aimag + wave)
}
run_iv <- function(iv_var) {
  fml <- as.formula(sprintf(
    "lwage ~ age + age2 + is_female + is_married | birth_aimag + birth_cohort + wave | educ_years ~ %s",
    iv_var))
  feols(fml, data = iv_data, weights = ~hhweight, cluster = ~aimag + wave)
}

extract_F  <- function(iv) tryCatch(if (is.null(iv)) NA_real_ else fitstat(iv, "ivf1")$ivf1$stat,
                                    error = function(e) NA_real_)
extract_b  <- function(iv) tryCatch(if (is.null(iv)) NA_real_ else coeftable(iv)["fit_educ_years","Estimate"],
                                    error = function(e) NA_real_)
extract_se <- function(iv) tryCatch(if (is.null(iv)) NA_real_ else coeftable(iv)["fit_educ_years","Std. Error"],
                                    error = function(e) NA_real_)
extract_pi <- function(fs, var) tryCatch(coeftable(fs)[var,"Estimate"], error = function(e) NA_real_)
extract_pi_p <- function(fs, var) tryCatch(coeftable(fs)[var,"Pr(>|t|)"], error = function(e) NA_real_)

# ------ Anderson-Rubin robust 95% CI (manual grid) ------------------------
ar_ci <- function(iv_var, beta_grid = seq(-1, 1, by = 0.005)) {
  reject <- vapply(beta_grid, function(b) {
    iv_data2 <- iv_data |> mutate(resid_y = lwage - b * educ_years)
    f <- as.formula(sprintf(
      "resid_y ~ %s + age + age2 + is_female + is_married | birth_aimag + birth_cohort + wave",
      iv_var))
    m <- tryCatch(feols(f, data = iv_data2, weights = ~hhweight, cluster = ~aimag + wave),
                  error = function(e) NULL)
    if (is.null(m)) return(NA)
    p <- tryCatch(coeftable(m)[iv_var, "Pr(>|t|)"], error = function(e) NA_real_)
    isTRUE(p < 0.05)
  }, logical(1))
  if (all(is.na(reject)) || all(reject, na.rm = TRUE)) return(c(NA_real_, NA_real_))
  not_rejected <- beta_grid[!reject]
  if (length(not_rejected) == 0) return(c(NA_real_, NA_real_))
  c(min(not_rejected, na.rm = TRUE), max(not_rejected, na.rm = TRUE))
}

results <- list()
for (sp in iv_specs) {
  for (w in windows) {
    iv_var <- paste0(sp$stem, "_", w$suf)
    if (!iv_var %in% names(iv_data)) next
    fs <- tryCatch(run_first_stage(iv_var), error = function(e) NULL)
    iv <- tryCatch(run_iv(iv_var), error = function(e) NULL)
    pi_var <- if (!is.null(fs) && iv_var %in% rownames(coeftable(fs))) iv_var else NA_character_
    pi_hat <- if (!is.na(pi_var)) extract_pi(fs, pi_var) else NA_real_
    pi_p   <- if (!is.na(pi_var)) extract_pi_p(fs, pi_var) else NA_real_
    F_st   <- extract_F(iv)
    b      <- extract_b(iv)
    se     <- extract_se(iv)

    # Anderson-Rubin only if marginal/strong (otherwise too costly and undefined)
    ar_lo <- ar_hi <- NA_real_
    if (!is.na(F_st) && F_st >= 5 && F_st < 16.38) {
      ar <- ar_ci(iv_var)
      ar_lo <- ar[1]; ar_hi <- ar[2]
    }

    verdict <- if (is.na(F_st)) "🚨 USELESS"
               else if (F_st >= 16.38) "✅ STRONG (F>=16.38)"
               else if (F_st >= 10)    "✅ STRONG (F in [10,16.38))"
               else if (F_st >= 5)     "🟡 MARGINAL (F in [5,10)) — AR-robust required"
               else                     "❌ WEAK (F<5)"

    results[[length(results) + 1]] <- tibble(
      window = w$label, iv = sp$label, iv_var = iv_var,
      pi_hat = pi_hat, pi_p = pi_p, F_first = F_st,
      beta_iv = b, se_beta = se,
      ar_ci_lo = ar_lo, ar_ci_hi = ar_hi,
      N = nrow(iv_data), verdict = verdict
    )
  }
}
res <- bind_rows(results) |> arrange(window, desc(F_first))
cat("\n--- Үр дүн ---\n")
print(res, n = Inf)

# -----------------------------------------------------------------------------
# 5. Animal-type robustness: large vs small stock
# -----------------------------------------------------------------------------
cli_h1("STEP 5: Animal-type robustness (large vs small stock)")

ls_all <- readRDS(file.path(AUX, "livestock_count_by_aimag_species.rds"))
loss_all <- readRDS(file.path(AUX, "livestock_loss_by_aimag_species.rds"))

bundle <- function(spp_keep, name) {
  ls_sub <- ls_all |> filter(species %in% spp_keep) |>
    group_by(hses_code, year) |> summarise(livestock = sum(livestock, na.rm=TRUE), .groups="drop")
  loss_sub <- loss_all |> filter(species %in% spp_keep) |>
    group_by(hses_code, year) |> summarise(loss = sum(loss, na.rm=TRUE), .groups="drop")
  loss_sub |> inner_join(ls_sub, by=c("hses_code","year")) |>
    arrange(hses_code, year) |>
    group_by(hses_code) |>
    mutate(livestock_lag = lag(livestock),
           loss_rate = if_else(!is.na(livestock_lag) & livestock_lag > 0,
                               loss / livestock_lag, NA_real_)) |>
    ungroup()
}
large <- bundle(c("Адуу","Үхэр","Тэмээ"), "large")
small <- bundle(c("Хонь","Ямаа"), "small")

# Animal-type cor (multicollinearity check)
animal_pivot <- bind_rows(
    ls_all |> filter(species != "Бүгд") |> mutate(metric = "count"),
    loss_all |> filter(species != "Бүгд") |> rename(value = loss) |> mutate(metric = "loss"))
loss_wide <- loss_all |> filter(species != "Бүгд") |>
  inner_join(ls_all |> filter(species != "Бүгд"), by = c("species","hses_code","year")) |>
  group_by(species, hses_code) |>
  mutate(livestock_lag = lag(livestock),
         loss_rate = if_else(!is.na(livestock_lag) & livestock_lag > 0,
                             loss / livestock_lag, NA_real_)) |>
  ungroup() |>
  select(species, hses_code, year, loss_rate) |>
  pivot_wider(names_from = species, values_from = loss_rate)
cat("Animal-type loss_rate correlation matrix (across aimag-years):\n")
animal_cor <- loss_wide |> select(any_of(c("Адуу","Үхэр","Тэмээ","Хонь","Ямаа"))) |>
  cor(use = "complete.obs")
print(round(animal_cor, 3))
high_cor <- max(animal_cor[upper.tri(animal_cor)], na.rm = TRUE)
cat(sprintf("\nMax pairwise cor: %.3f → %s as separate IVs\n",
            high_cor, ifelse(high_cor > 0.7, "DO NOT use", "OK to test")))

# Build large/small exposure for 12-17 window
build_exp_subset <- function(sub_panel, suffix) {
  sub_panel <- sub_panel |>
    mutate(d5 = as.integer(loss_rate >= 0.05))
  expand_grid(birth_aimag = sort(unique(sub_panel$hses_code)),
              birth_year  = 1955:2010) |>
    rowwise() |>
    mutate(cum_lr = sum(sub_panel$loss_rate[sub_panel$hses_code == birth_aimag &
                                            sub_panel$year %in% (birth_year + 12):(birth_year + 17)],
                        na.rm = TRUE),
           cnt5 = sum(sub_panel$d5[sub_panel$hses_code == birth_aimag &
                                   sub_panel$year %in% (birth_year + 12):(birth_year + 17)],
                      na.rm = TRUE),
           n_obs = sum(!is.na(sub_panel$loss_rate[sub_panel$hses_code == birth_aimag &
                                                  sub_panel$year %in% (birth_year + 12):(birth_year + 17)]))) |>
    ungroup() |>
    rename_with(~ paste0(.x, "_", suffix), c(cum_lr, cnt5, n_obs))
}
exp_large <- build_exp_subset(large, "large")
exp_small <- build_exp_subset(small, "small")

iv_data_anim <- main |>
  left_join(exp_large, by = c("birth_aimag","birth_year")) |>
  left_join(exp_small, by = c("birth_aimag","birth_year")) |>
  filter(n_obs_large == 6, n_obs_small == 6)

run_anim <- function(iv_var) {
  fs_f <- as.formula(sprintf(
    "educ_years ~ %s + age + age2 + is_female + is_married | birth_aimag + birth_cohort + wave", iv_var))
  iv_f <- as.formula(sprintf(
    "lwage ~ age + age2 + is_female + is_married | birth_aimag + birth_cohort + wave | educ_years ~ %s", iv_var))
  fs <- feols(fs_f, data = iv_data_anim, weights = ~hhweight, cluster = ~aimag + wave)
  iv <- feols(iv_f, data = iv_data_anim, weights = ~hhweight, cluster = ~aimag + wave)
  list(fs=fs, iv=iv)
}

cat(sprintf("\nAnimal-type sample: N=%d\n", nrow(iv_data_anim)))
for (v in c("cum_lr_large","cum_lr_small","cnt5_large","cnt5_small")) {
  r <- tryCatch(run_anim(v), error = function(e) NULL)
  if (is.null(r)) { cat(sprintf("  %s: skipped\n", v)); next }
  cat(sprintf("  %-15s F=%6.2f  π̂=%+.4f  β_IV=%+.4f (SE %.4f)\n",
              v, extract_F(r$iv), extract_pi(r$fs, v),
              extract_b(r$iv), extract_se(r$iv)))
}

# -----------------------------------------------------------------------------
# 6. Heterogeneity: rural birth × dzud
# -----------------------------------------------------------------------------
cli_h1("STEP 6: Heterogeneity — rural birth × dzud (Groppo-K hypothesis)")

iv_data_h <- iv_data |> mutate(rural_birth = as.integer(birth_aimag != 11L))  # 11 = УБ
cat(sprintf("Rural birth distribution: %d rural, %d UB\n",
            sum(iv_data_h$rural_birth == 1L), sum(iv_data_h$rural_birth == 0L)))

# First stage with interaction
fs_h <- feols(educ_years ~ cum_12_17 * rural_birth + age + age2 + is_female + is_married |
                birth_aimag + birth_cohort + wave,
              data = iv_data_h, weights = ~hhweight, cluster = ~aimag + wave)
cat("First stage (educ ~ cum_12_17 × rural_birth):\n")
print(coeftable(fs_h)[grep("cum_12_17|rural", rownames(coeftable(fs_h))), , drop = FALSE])

# -----------------------------------------------------------------------------
# 7. Output table
# -----------------------------------------------------------------------------
cli_h1("STEP 7: Save output T2c_dzud_iv_v2.csv")

out_csv <- here("output/tables/T2c_dzud_iv_v2.csv")
write_csv(res, out_csv)
cat(sprintf("Saved: %s (%d rows)\n", out_csv, nrow(res)))

cli_h1("DZUD IV V2 ANALYSIS COMPLETE")
cat("\nSummary (12-17 main window):\n")
print(res |> filter(window == "12-17 (MAIN)") |>
        select(iv_var, F_first, beta_iv, se_beta, ar_ci_lo, ar_ci_hi, verdict))


