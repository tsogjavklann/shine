# =============================================================================
# 11_iv_2sls.R
# -----------------------------------------------------------------------------
# Зорилго : 2SLS — Mincer + IV (reform_main donut design, q0114a/q0118a-аас
#           үүсгэгдсэн). Гол inference: Anderson-Rubin (AR) weak-IV-robust CI.
#           Stock-Yogo critical нь cluster-robust setting-д INVALID — report
#           хийхгүй. KP rk Wald F-statistic (cluster-robust) тайлагнагдана.
#           3 SE: two-way ~aimag+wave, one-way ~aimag, HC1 robust.
#           DWH endogeneity test тайлагнагдана.
# Орц     : data/processed/analysis_sample.rds
# Гарц    : output/tables/T2_iv_2sls.csv          (point + 3 SE + F + AR CI)
#           output/logs/iv_diagnostics.log         (full diagnostics dump)
# =============================================================================

source(here::here("R", "paths.R"))
suppressPackageStartupMessages({
  library(dplyr); library(tidyr); library(readr)
  library(fixest); library(broom); library(cli); library(tictoc)
})
setFixest_estimation(panel.id = NULL)
set.seed(2026)

cli::cli_h1("11_iv_2sls.R — 2SLS + KP-F + AR-robust CI")
tic("Total")

# ---- 1. Load + restrict + drop donut (reform_main NA) ----------------------
df <- readRDS(file.path(PATHS$data_proc, "analysis_sample.rds")) |> as_tibble()
main <- df |>
  filter(main_flag_25_60 == 1L,
         !is.na(q_school_access), is.finite(q_school_access),
         !is.na(educ_years), !is.na(lwage),
         !is.na(age), !is.na(is_female), !is.na(is_married),
         !is.na(region), !is.na(wave), !is.na(aimag), !is.na(hhweight),
         !is.na(reform_main))   # donut filter: drops 1996-97 cohort
cli::cli_alert_info("MAIN sample (post-donut): {nrow(main)} rows")
cli::cli_alert_info("  treated (reform_main=1): {sum(main$reform_main == 1L)}")
cli::cli_alert_info("  control (reform_main=0): {sum(main$reform_main == 0L)}")

# ---- 2. fit_iv_with_se: 2SLS + 3 SE versions -------------------------------
fit_iv <- function(formula_main_str, data, label) {
  f <- as.formula(formula_main_str)
  # 2-way cluster (main)
  m_2way <- feols(f, data = data, weights = ~hhweight,
                  cluster = ~aimag + wave)
  # 1-way cluster
  m_1way <- feols(f, data = data, weights = ~hhweight,
                  cluster = ~aimag)
  # HC1 robust
  m_hc1  <- feols(f, data = data, weights = ~hhweight,
                  se = "hetero")

  # Endog coef = "fit_educ_years" (fixest naming for fitted endog var)
  endog_name <- grep("^fit_", names(coef(m_2way)), value = TRUE)
  if (length(endog_name) == 0L) endog_name <- "educ_years"

  b      <- coef(m_2way)[endog_name]
  se2    <- se(m_2way, cluster = ~aimag + wave)[endog_name]
  se1    <- se(m_1way, cluster = ~aimag)[endog_name]
  sehc1  <- se(m_hc1,  se = "hetero")[endog_name]

  # First-stage F (cluster-robust). fitstat "ivf1" returns the partial F for
  # the single endog. For cluster-robust use fitstat(., "ivf1.kpr").
  fst_kpr <- tryCatch(
    fitstat(m_2way, "ivf1.kpr")[[1]]$stat,
    error = function(e) NA_real_
  )
  fst_ivf <- tryCatch(
    fitstat(m_2way, "ivf1")[[1]]$stat,
    error = function(e) NA_real_
  )

  # DWH endogeneity test
  wh <- tryCatch(
    fitstat(m_2way, "wh")[[1]]$p,
    error = function(e) NA_real_
  )

  # Wald 1st-stage from fixest (returns F)
  wald_first <- tryCatch(
    summary(m_2way, stage = 1)$coeftable["reform_main", "t value"]^2,
    error = function(e) NA_real_
  )

  tibble(
    spec = label,
    N = nobs(m_2way),
    beta_iv  = unname(b),
    se_2way  = unname(se2),
    se_1way  = unname(se1),
    se_HC1   = unname(sehc1),
    KP_F     = unname(fst_kpr),
    ivf1_F   = unname(fst_ivf),
    wald_1st_F = unname(wald_first),
    DWH_p    = unname(wh)
  )
}

# ---- 3. Anderson-Rubin CI by grid (single endog, single IV) ----------------
# AR test: regress (lwage - β*educ_years) ~ reform_main + controls | FE
# At true β, coef on reform_main should be 0. CI is set of β where Wald p ≥ α.
ar_ci <- function(data, beta_hat, ctrls_str, fe_str,
                  alpha = 0.05, grid_n = 401L, half_width = 2.0) {
  # Grid centred on beta_hat with HALF_WIDTH on each side (wide grid for weak IV)
  beta_grid <- seq(beta_hat - half_width, beta_hat + half_width,
                   length.out = grid_n)

  # For each β in grid: residual_β = lwage - β * educ_years
  # Then regress residual_β ~ reform_main + ctrls | FE, weights, cluster
  test_one <- function(b) {
    d2 <- data |> mutate(resid_b = lwage - b * educ_years)
    f <- as.formula(paste("resid_b ~ reform_main +", ctrls_str, "|", fe_str))
    m <- tryCatch(
      feols(f, data = d2, weights = ~hhweight, cluster = ~aimag + wave),
      error = function(e) NULL
    )
    if (is.null(m)) return(NA_real_)
    # Wald test of reform_main coefficient = 0
    p <- tryCatch(coeftable(m)["reform_main", "Pr(>|t|)"], error = function(e) NA_real_)
    p
  }

  pvals <- vapply(beta_grid, test_one, numeric(1))
  in_ci <- pvals >= alpha
  if (!any(in_ci, na.rm = TRUE)) {
    return(c(low = NA_real_, high = NA_real_))
  }
  c(low = min(beta_grid[in_ci], na.rm = TRUE),
    high = max(beta_grid[in_ci], na.rm = TRUE))
}

# ---- 4. Specifications -----------------------------------------------------
CTRLS <- "age + age2 + is_female + is_married"
FE_A  <- "region + wave"
FE_B  <- "region + wave + location_f"

# 2SLS formula in fixest: outcome ~ ctrls | FE | endog ~ instrument
spec_main_a <- paste("lwage ~", CTRLS, "|", FE_A, "| educ_years ~ reform_main")
spec_main_b <- paste("lwage ~", CTRLS, "|", FE_B, "| educ_years ~ reform_main")

cli::cli_alert("Fitting Main A (no location FE)...")
res_a <- fit_iv(spec_main_a, main, "Main A 2SLS (reform_main, no loc FE)")

cli::cli_alert("Fitting Main B (+ location FE)...")
res_b <- fit_iv(spec_main_b, main, "Main B 2SLS (reform_main, + loc FE)")

T2_iv <- bind_rows(res_a, res_b)

# ---- 5. AR CI for Main A and Main B ----------------------------------------
cli::cli_alert("Computing AR CI for Main A (grid search ±2.0 around β̂; wide for weak-IV)...")
ar_a <- ar_ci(main, res_a$beta_iv, CTRLS, FE_A, half_width = 2.0)
cli::cli_alert("Computing AR CI for Main B...")
ar_b <- ar_ci(main, res_b$beta_iv, CTRLS, FE_B, half_width = 2.0)
# AR CI 'unbounded' indicator: if low/high hits grid edge, CI is essentially open
ar_open_a <- (!is.na(ar_a["low"])  && abs(ar_a["low"]  - (res_a$beta_iv - 2.0)) < 0.01) ||
             (!is.na(ar_a["high"]) && abs(ar_a["high"] - (res_a$beta_iv + 2.0)) < 0.01)
ar_open_b <- (!is.na(ar_b["low"])  && abs(ar_b["low"]  - (res_b$beta_iv - 2.0)) < 0.01) ||
             (!is.na(ar_b["high"]) && abs(ar_b["high"] - (res_b$beta_iv + 2.0)) < 0.01)
if (ar_open_a) cli::cli_alert_warning("Main A: AR CI grid edge hit → CI essentially unbounded")
if (ar_open_b) cli::cli_alert_warning("Main B: AR CI grid edge hit → CI essentially unbounded")

T2_iv <- T2_iv |>
  mutate(
    AR_CI_low  = c(ar_a["low"],  ar_b["low"]),
    AR_CI_high = c(ar_a["high"], ar_b["high"])
  ) |>
  mutate(across(c(beta_iv, se_2way, se_1way, se_HC1, KP_F, ivf1_F, wald_1st_F,
                  DWH_p, AR_CI_low, AR_CI_high), ~ round(.x, 5)))

cli::cli_h2("T2 IV 2SLS results (β_educ + 3 SE + KP-F + AR CI)")
print(T2_iv)

# ---- 6. Strength assessment (use wald_1st_F if KP not computed) ------------
F_main <- if (!is.na(res_a$KP_F)) res_a$KP_F else res_a$wald_1st_F
strength_label <- case_when(
  is.na(F_main)   ~ "F NA — couldn't compute",
  F_main >= 10    ~ "STRONG (F ≥ 10)",
  F_main >= 5     ~ "WEAK (F ∈ [5, 10)) — AR CI чухал",
  TRUE            ~ "VERY WEAK (F < 5) — exploratory; OLS/OLS-Quantile-руу шилжих санал"
)
cli::cli_alert_info("First-stage strength (Main A F = {round(F_main,3)}): {strength_label}")

# ---- 7. Хадгалах + лог ------------------------------------------------------
write_csv(T2_iv, file.path(PATHS$out_tables, "T2_iv_2sls.csv"))

log_path <- file.path(PATHS$out_logs, "iv_diagnostics.log")
sink(log_path, append = FALSE)
cat("==========================================================\n")
cat("11_iv_2sls.R — IV diagnostics  ", as.character(Sys.time()), "\n")
cat("==========================================================\n")
cat(sprintf("MAIN sample (post-donut, complete cases): %d rows\n", nrow(main)))
cat(sprintf("  reform_main treated: %d\n", sum(main$reform_main == 1L)))
cat(sprintf("  reform_main control: %d\n", sum(main$reform_main == 0L)))
cat("\nT2 IV 2SLS results:\n"); print(T2_iv)
cat(sprintf("\nFirst-stage strength: %s\n", strength_label))
cat("\n--- Methodology notes ---\n")
cat("- Main inference: Anderson-Rubin (AR) weak-IV-robust CI (gird search, α=0.05)\n")
cat("- KP rk Wald F (cluster-robust two-way, ~aimag+wave) reported as first-stage strength\n")
cat("- Stock-Yogo critical values NOT reported (invalid for cluster-robust SE)\n")
cat("- DWH endogeneity test: H0 = OLS consistent (educ exogenous)\n")
cat("- 3 SE columns: 2-way cluster (main), 1-way ~aimag, HC1 robust\n")
sink()

toc()
cli::cli_alert_success("Гарц: T2_iv_2sls.csv + iv_diagnostics.log")
cli::cli_alert_info("Дараагийн алхам: R/12_iv_robustness.R")
