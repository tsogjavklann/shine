# =============================================================================
# 12b_iv_search.R
# -----------------------------------------------------------------------------
# Зорилго : Comprehensive IV survey — empirical first-stage F + 2SLS β + Sargan
#           (overid spec-уудад) for ~14 candidate IVs.
#           Гарц: T2b_iv_search.csv ranked by F descending; verdict per spec.
# Орц     : data/processed/analysis_sample.rds
#           data/processed/family_structure.rds (R/03b)
#           data/auxiliary/aimag_distance_to_ub.csv (R/05c)
# Гарц    : output/tables/T2b_iv_search.csv
#           output/logs/12b_iv_search.log
# =============================================================================
# Sample (default): MAIN home_aimag (n=9,077)
# Controls: age + age² + is_female + is_married
# FE: region + wave (canonical Spec 2 structure)
# Cluster: ~aimag + wave (two-way)
# Weights: ~hhweight
# =============================================================================

source(here::here("R", "paths.R"))
suppressPackageStartupMessages({
  library(dplyr); library(tidyr); library(readr); library(stringr)
  library(fixest); library(cli); library(tictoc)
})
setFixest_estimation(panel.id = NULL)
set.seed(2026)

cli::cli_h1("12b_iv_search.R — comprehensive IV survey")
tic("Total")

# ---- 1. Load all inputs ----------------------------------------------------
df  <- readRDS(file.path(PATHS$data_proc, "analysis_sample.rds")) |> as_tibble()
fam <- readRDS(file.path(PATHS$data_proc, "family_structure.rds")) |> as_tibble()
dist_lk <- read_csv(file.path(PATHS$data_aux, "aimag_distance_to_ub.csv"),
                    show_col_types = FALSE) |>
  select(aimag, distance_to_ub)

# ---- 2. Build MAIN sample with all candidate IVs in one wide table ---------
main <- df |>
  filter(main_flag_25_60 == 1L,
         !is.na(q_school_access), is.finite(q_school_access),
         !is.na(educ_years), !is.na(lwage),
         !is.na(age), !is.na(is_female), !is.na(is_married),
         !is.na(region), !is.na(wave), !is.na(aimag), !is.na(hhweight)) |>
  # Distance IV
  left_join(dist_lk, by = c("birth_aimag" = "aimag")) |>
  # Family IVs (parental + siblings)
  left_join(fam |> select(id, father_educ_level, mother_educ_level,
                          father_educ_years, mother_educ_years,
                          n_siblings, birth_order, age_m),
            by = "id") |>
  # Quarter of birth (если age_m valid)
  mutate(
    # Note: q0105m gives "age in months" not month-of-birth. We'll treat
    # negative interpretation: assume q0105m provides additional months
    # to the year. So birth_month_proxy = (12 - q0105m) mod 12 + 1.
    # If q0105m is rare/invalid, this spec will simply have small N.
    quarter_birth = case_when(
      is.na(age_m) | age_m == 0 ~ NA_integer_,
      TRUE ~ as.integer(((12L - as.integer(age_m) %% 12L) %% 12L) %/% 3L + 1L)
    )
  )

cli::cli_alert_info("MAIN sample (with all IVs joined): {nrow(main)} rows")

# ---- 3. Helper: run 2SLS + collect diagnostics -----------------------------
CTRLS <- "age + age2 + is_female + is_married"
FE    <- "region + wave"

run_iv <- function(data, iv_expr, label, family,
                   require_n = 1000L, sargan = FALSE) {
  # iv_expr can be string of IV variable(s), e.g. "reform_main" or
  # "father_educ_level + mother_educ_level"
  # Filter to non-missing IV (and for factor IVs, ensure variation)
  iv_vars <- str_split(iv_expr, "\\s*\\+\\s*")[[1]]
  iv_vars <- iv_vars[!str_detect(iv_vars, "as\\.factor|interact|:")]
  for (v in iv_vars) {
    base_v <- str_remove_all(v, "as\\.factor\\(|\\)")
    if (base_v %in% names(data)) {
      data <- data[!is.na(data[[base_v]]), , drop = FALSE]
    }
  }
  N <- nrow(data)
  if (N < require_n) {
    return(tibble(
      spec = label, family = family, N = N, iv = iv_expr,
      pi_hat = NA, se_pi = NA, t_pi = NA, F_first = NA,
      beta_iv = NA, se_beta = NA,
      sargan_p = NA_real_,
      verdict = sprintf("⏭ N=%d < %d (skipped)", N, require_n)
    ))
  }

  # First stage: educ_years ~ iv_expr + ctrls | FE
  fs_str <- paste("educ_years ~", iv_expr, "+", CTRLS, "|", FE)
  m_fs <- tryCatch(
    feols(as.formula(fs_str), data = data, weights = ~hhweight,
          cluster = ~aimag + wave),
    error = function(e) NULL
  )

  # 2SLS: lwage ~ ctrls | FE | educ ~ iv
  iv_str <- paste("lwage ~", CTRLS, "|", FE, "| educ_years ~", iv_expr)
  m_iv <- tryCatch(
    feols(as.formula(iv_str), data = data, weights = ~hhweight,
          cluster = ~aimag + wave),
    error = function(e) NULL
  )

  if (is.null(m_fs) || is.null(m_iv)) {
    return(tibble(
      spec = label, family = family, N = N, iv = iv_expr,
      pi_hat = NA, se_pi = NA, t_pi = NA, F_first = NA,
      beta_iv = NA, se_beta = NA, sargan_p = NA_real_,
      verdict = "❌ FIT FAILED"
    ))
  }

  # First-stage F (from fs model: ivf1 not available since not iv-spec, use
  # waldtest of all IV vars or just the main one if single)
  fs_F <- tryCatch({
    iv_main_var <- iv_vars[1]
    if (iv_main_var %in% names(coef(m_fs))) {
      tval <- coef(m_fs)[iv_main_var] / se(m_fs, cluster = ~aimag + wave)[iv_main_var]
      tval^2
    } else {
      # Multi-IV or factor — use overall wald via fitstat from m_iv
      fitstat(m_iv, "ivf1")[[1]]$stat
    }
  }, error = function(e) NA_real_)
  pi_hat <- if (length(iv_vars) == 1L && iv_vars[1] %in% names(coef(m_fs)))
    unname(coef(m_fs)[iv_vars[1]]) else NA_real_
  se_pi  <- if (length(iv_vars) == 1L && iv_vars[1] %in% names(coef(m_fs)))
    unname(se(m_fs, cluster = ~aimag + wave)[iv_vars[1]]) else NA_real_

  # Try Kleibergen-Paap directly from m_iv
  kp_F <- tryCatch(fitstat(m_iv, "ivf1.kpr")[[1]]$stat, error = function(e) NA_real_)
  if (!is.na(kp_F)) fs_F <- kp_F   # prefer KP if computed

  # 2SLS β
  endog_name <- grep("^fit_", names(coef(m_iv)), value = TRUE)
  if (length(endog_name) == 0L) endog_name <- "educ_years"
  beta <- coef(m_iv)[endog_name]
  se_b <- se(m_iv, cluster = ~aimag + wave)[endog_name]

  # Sargan/Hansen J test (overid)
  sargan_p <- if (sargan) {
    tryCatch(fitstat(m_iv, "sargan")[[1]]$p, error = function(e) NA_real_)
  } else NA_real_

  # Verdict
  verdict <- case_when(
    is.na(fs_F)       ~ "F NA",
    fs_F >= 10        ~ "✅ STRONG (F≥10)",
    fs_F >= 5         ~ "🟡 MARGINAL (F∈[5,10))",
    fs_F >= 1         ~ "❌ WEAK (F<5)",
    TRUE              ~ "🚨 USELESS (F<1)"
  )

  tibble(
    spec = label, family = family, N = N, iv = iv_expr,
    pi_hat = pi_hat, se_pi = se_pi,
    t_pi = if (!is.na(pi_hat) && !is.na(se_pi)) pi_hat / se_pi else NA_real_,
    F_first = unname(fs_F),
    beta_iv = unname(beta), se_beta = unname(se_b),
    sargan_p = sargan_p, verdict = verdict
  )
}

# ---- 4. Specifications -----------------------------------------------------
specs <- list(
  list("01 reform_main",          "reform_main",                          "Cohort"),
  list("02 reform_alt_1997",      "reform_alt_1997",                      "Cohort"),
  list("03 reform_alt_1999",      "reform_alt_1999",                      "Cohort"),
  list("04 distance_to_ub",       "distance_to_ub",                       "Geography"),
  list("05 father_educ_level",    "father_educ_level",                    "Family"),
  list("06 mother_educ_level",    "mother_educ_level",                    "Family"),
  list("07 parents_combined",     "father_educ_level + mother_educ_level", "Family"),
  list("08 n_siblings",           "n_siblings",                           "Family"),
  list("09 birth_order",          "birth_order",                          "Family"),
  list("10 quarter_of_birth",     "as.factor(quarter_birth)",             "Time"),
  list("11 birth_aimag_factor",   "as.factor(birth_aimag)",               "Geography"),
  list("12 distance + reform",    "distance_to_ub + reform_main",          "Combo")
)

# Determine which specs have overidentification (more IVs than endog regressors)
overid <- sapply(specs, function(s) {
  iv_count <- length(str_split(s[[2]], "\\s*\\+\\s*")[[1]])
  iv_count > 1 || str_detect(s[[2]], "as\\.factor")
})

# ---- 5. Run all specs -------------------------------------------------------
results <- bind_rows(lapply(seq_along(specs), function(i) {
  s <- specs[[i]]
  cli::cli_alert("Running spec {i}: {s[[1]]} ({s[[3]]}) — IV: {s[[2]]}")
  # Lower require_n for family specs to attempt them; flag in verdict
  req_n <- if (s[[3]] == "Family") 500L else 1000L
  run_iv(main, s[[2]], s[[1]], s[[3]], require_n = req_n, sargan = overid[i])
}))

# Round + sort
results <- results |>
  mutate(across(c(pi_hat, se_pi, t_pi, F_first, beta_iv, se_beta, sargan_p),
                ~ if (is.numeric(.x)) round(.x, 5) else .x))

results_sorted <- results |> arrange(desc(F_first))

cli::cli_h2("T2b — IV search ranked by F descending")
print(results_sorted, n = Inf)

# ---- 6. Хадгалах + лог ------------------------------------------------------
write_csv(results_sorted, file.path(PATHS$out_tables, "T2b_iv_search.csv"))

log_path <- file.path(PATHS$out_logs, "12b_iv_search.log")
sink(log_path, append = FALSE)
cat("==========================================================\n")
cat("12b_iv_search.R — Comprehensive IV survey  ", as.character(Sys.time()), "\n")
cat("==========================================================\n")
cat(sprintf("MAIN sample (home_aimag, 25-60, complete cases): %d rows\n", nrow(main)))
cat("\nT2b — IV search results (ranked by first-stage F descending):\n")
print(results_sorted, n = Inf)

# Verdict summary
cat("\n--- VERDICT SUMMARY ---\n")
verdict_counts <- table(results$verdict)
print(verdict_counts)
cat("\nStrongest IV:\n")
print(results_sorted |> filter(!is.na(F_first)) |> head(3))
sink()

toc()
cli::cli_alert_success("Гарц: T2b_iv_search.csv")


