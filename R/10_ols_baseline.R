# =============================================================================
# 10_ols_baseline.R
# -----------------------------------------------------------------------------
# Зорилго : Mincer OLS baseline — Main A (no location FE) + Main B (with
#           location FE), weights = ~hhweight, cluster = ~aimag + wave.
#           +Sensitivity: one-way cluster ~aimag, HC3 robust (3 SE columns).
#           +Subsample sensitivity: drop UB, drop urban-only.
# Орц     : data/processed/analysis_sample.rds
# Гарц    : output/tables/T2_ols_baseline.csv
#           output/logs/10_ols_baseline.log
# =============================================================================

source(here::here("R", "paths.R"))
suppressPackageStartupMessages({
  library(dplyr); library(tidyr); library(readr)
  library(fixest); library(broom); library(cli); library(tictoc)
})
setFixest_estimation(panel.id = NULL)

cli::cli_h1("10_ols_baseline.R — Mincer OLS (Main A + Main B + sensitivity)")
tic("Total")

# ---- 1. Load + restrict to MAIN home_aimag sample --------------------------
df <- readRDS(file.path(PATHS$data_proc, "analysis_sample.rds")) |> as_tibble()
main <- df |>
  filter(main_flag_25_60 == 1L,
         !is.na(q_home), is.finite(q_home),
         !is.na(educ_years), !is.na(lwage),
         !is.na(age), !is.na(is_female), !is.na(is_married),
         !is.na(region), !is.na(wave), !is.na(aimag), !is.na(hhweight))
cli::cli_alert_info("MAIN home_aimag sample (complete cases): {nrow(main)} rows")

# ---- 2. Build SE variants for one regression -------------------------------
fit_with_se <- function(formula_str, data, label) {
  f <- as.formula(formula_str)
  m_main  <- feols(f, data = data, weights = ~hhweight,
                   cluster = ~aimag + wave)
  m_a1    <- feols(f, data = data, weights = ~hhweight,
                   cluster = ~aimag)
  m_hc3   <- feols(f, data = data, weights = ~hhweight,
                   se = "hetero")     # HC1; we'll request HC3 via vcov below

  # Get educ_years coefficient + 3 SE versions
  b_main  <- coef(m_main)["educ_years"]
  se_2way <- se(m_main, cluster = ~aimag + wave)["educ_years"]
  se_1way <- se(m_a1,    cluster = ~aimag)["educ_years"]
  se_hc3  <- se(m_hc3,   se = "hetero")["educ_years"]
  fst     <- fitstat(m_main, "wf")$wf
  N       <- nobs(m_main)
  R2adj   <- fitstat(m_main, "ar2")$ar2

  tibble(
    spec        = label,
    N           = N,
    beta_educ   = unname(b_main),
    se_2way     = unname(se_2way),
    se_1way     = unname(se_1way),
    se_HC1      = unname(se_hc3),
    F_test      = if (is.null(fst)) NA_real_ else as.numeric(fst$stat),
    R2_adj      = unname(R2adj)
  )
}

# ---- 3. Specifications -----------------------------------------------------
# Main A: no location FE; controls = age, age2, female, married + region FE + wave FE
# Main B: + location_f (4-cat) FE
# Sensitivity_a: drop urban (urban==1) — keep rural/UB only
# Sensitivity_b: drop UB-only (aimag != 11)

CTRLS <- "educ_years + age + age2 + is_female + is_married"
FE_A  <- "| region + wave"
FE_B  <- "| region + wave + location_f"

specs <- list(
  list("Main A (no location FE)",
       paste("lwage ~", CTRLS, FE_A),
       main),
  list("Main B (+ location FE)",
       paste("lwage ~", CTRLS, FE_B),
       main),
  list("Sens. drop urban (rural+UB)",
       paste("lwage ~", CTRLS, FE_A),
       main |> filter(urban != 1L | is.na(urban))),  # keep non-urban
  list("Sens. drop UB (non-UB only)",
       paste("lwage ~", CTRLS, FE_A),
       main |> filter(aimag != 11L | is.na(aimag)))
)

# ---- 4. Run all specs -------------------------------------------------------
T2 <- bind_rows(lapply(specs, function(s) fit_with_se(s[[2]], s[[3]], s[[1]])))
T2 <- T2 |>
  mutate(across(c(beta_educ, se_2way, se_1way, se_HC1, F_test, R2_adj),
                ~ round(.x, 5)))
cli::cli_h2("T2 OLS baseline + sensitivity")
print(T2)

# Coverage diagnostic: SE гурвын зөрөө >2× уу?
T2_se_check <- T2 |>
  mutate(
    ratio_2way_1way = se_2way / se_1way,
    ratio_2way_HC1  = se_2way / se_HC1
  )
cli::cli_h2("SE comparison (ratio 2way / one-way / HC1)")
print(T2_se_check |> select(spec, ratio_2way_1way, ratio_2way_HC1))

# ---- 5. Хадгалах ------------------------------------------------------------
write_csv(T2,           file.path(PATHS$out_tables, "T2_ols_baseline.csv"))
write_csv(T2_se_check,  file.path(PATHS$out_logs,   "10_se_comparison.csv"))

log_path <- file.path(PATHS$out_logs, "10_ols_baseline.log")
sink(log_path, append = FALSE)
cat("==========================================================\n")
cat("10_ols_baseline.R лог  ", as.character(Sys.time()), "\n")
cat("==========================================================\n")
cat(sprintf("MAIN sample (complete cases, home_aimag, 25-60): %d rows\n", nrow(main)))
cat("\nT2 OLS baseline + sensitivity:\n"); print(T2)
cat("\nSE ratios (2way vs 1way vs HC1):\n"); print(T2_se_check)
cat("\nNote: SE ratio > 2 → few-cluster bias caveat нэмж бичих\n")
sink()

toc()
cli::cli_alert_success("Гарц: T2_ols_baseline.csv + 10_se_comparison.csv")
cli::cli_alert_info("Дараагийн алхам: R/11_iv_2sls.R")
