# Audit dzud exposure as an IV for education in returns-to-education models.

options(warn = 1)

get_script_path <- function() {
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", args, value = TRUE)
  if (length(file_arg) == 0) return(file.path("codex", "R", "02_dzud_iv_audit.R"))
  sub("^--file=", "", file_arg[[1]])
}

script_dir <- dirname(normalizePath(get_script_path(), winslash = "/", mustWork = FALSE))
project_root <- normalizePath(file.path(script_dir, "..", ".."), winslash = "/", mustWork = TRUE)
codex_root <- file.path(project_root, "codex")

dirs <- file.path(codex_root, c("output/tables", "output/logs", "output/reports", "data/cleaned"))
invisible(lapply(dirs, dir.create, recursive = TRUE, showWarnings = FALSE))

log_file <- file.path(codex_root, "output/logs/02_dzud_iv_audit.log")
sink(log_file, split = TRUE)
on.exit(sink(), add = TRUE)

cat("02_dzud_iv_audit.R\n")
cat("Project root:", project_root, "\n")
cat("Output root:", codex_root, "\n\n")

required_pkgs <- c("dplyr", "tidyr", "stringr", "readr", "tibble", "purrr", "fixest")
missing_pkgs <- required_pkgs[!vapply(required_pkgs, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_pkgs) > 0) {
  stop("Missing required R packages: ", paste(missing_pkgs, collapse = ", "))
}

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(stringr)
  library(readr)
  library(tibble)
  library(purrr)
  library(fixest)
})

fmt <- function(x, digits = 3) {
  ifelse(is.na(x), "NA", formatC(x, digits = digits, format = "f"))
}

hses_path <- file.path(codex_root, "data/cleaned/hses_clean.rds")
dzud_path <- file.path(codex_root, "data/cleaned/dzud_panel.rds")
if (!file.exists(hses_path)) stop("Missing cleaned HSES file: ", hses_path)
if (!file.exists(dzud_path)) stop("Missing dzud panel file: ", dzud_path)

hses <- readRDS(hses_path)
dzud_panel <- readRDS(dzud_path)

cat("Loaded HSES clean rows:", nrow(hses), "\n")
cat("Loaded dzud panel rows:", nrow(dzud_panel), "\n\n")

hses <- hses %>%
  mutate(
    row_id = row_number(),
    birth_cohort = case_when(
      birth_year < 1970 ~ "pre1970",
      birth_year >= 1970 & birth_year <= 1974 ~ "1970-74",
      birth_year >= 1975 & birth_year <= 1979 ~ "1975-79",
      birth_year >= 1980 & birth_year <= 1984 ~ "1980-84",
      birth_year >= 1985 & birth_year <= 1989 ~ "1985-89",
      birth_year >= 1990 & birth_year <= 1994 ~ "1990-94",
      birth_year >= 1995 ~ "post1995",
      TRUE ~ NA_character_
    ),
    birth_cohort = factor(
      birth_cohort,
      levels = c("pre1970", "1970-74", "1975-79", "1980-84", "1985-89", "1990-94", "post1995")
    ),
    birth_aimag = as.integer(birth_aimag),
    wave = as.integer(wave),
    birth_year = as.integer(birth_year),
    region_fe = if ("birth_region" %in% names(.)) as.character(birth_region) else as.character(region),
    rural_birth = as.integer(birth_aimag != 11)
  )

make_exposure <- function(people, panel, start_age, end_age, suffix, prefix = "dzud") {
  expected_n <- end_age - start_age + 1
  panel_use <- panel %>%
    select(aimag_code, year, loss_rate, dzud5, dzud10, dzud_p75)

  grid <- people %>%
    select(row_id, birth_aimag, birth_year) %>%
    tidyr::crossing(age_at_exposure = start_age:end_age) %>%
    mutate(year = birth_year + age_at_exposure) %>%
    left_join(panel_use, by = c("birth_aimag" = "aimag_code", "year" = "year"))

  grid %>%
    group_by(row_id) %>%
    summarise(
      n_window_years = expected_n,
      n_loss_rate_nonmissing = sum(!is.na(loss_rate)),
      cum = ifelse(n_loss_rate_nonmissing == expected_n, sum(loss_rate), NA_real_),
      max = ifelse(n_loss_rate_nonmissing == expected_n, max(loss_rate), NA_real_),
      count5 = ifelse(n_loss_rate_nonmissing == expected_n, sum(dzud5 == 1, na.rm = TRUE), NA_real_),
      count10 = ifelse(n_loss_rate_nonmissing == expected_n, sum(dzud10 == 1, na.rm = TRUE), NA_real_),
      p75_count = ifelse(n_loss_rate_nonmissing == expected_n, sum(dzud_p75 == 1, na.rm = TRUE), NA_real_),
      any_dzud5 = ifelse(n_loss_rate_nonmissing == expected_n, as.integer(sum(dzud5 == 1, na.rm = TRUE) > 0), NA_real_),
      .groups = "drop"
    ) %>%
    transmute(
      row_id,
      !!paste0(prefix, "_cum_", suffix) := cum,
      !!paste0(prefix, "_max_", suffix) := max,
      !!paste0(prefix, "_count5_", suffix) := count5,
      !!paste0(prefix, "_count10_", suffix) := count10,
      !!paste0(prefix, "_p75_count_", suffix) := p75_count,
      !!paste0(prefix, "_any_dzud5_", suffix) := any_dzud5,
      !!paste0(prefix, "_n_complete_", suffix) := n_loss_rate_nonmissing
    )
}

windows <- tibble::tribble(
  ~window, ~suffix, ~start_age, ~end_age,
  "12-17", "12_17", 12L, 17L,
  "15-17", "15_17", 15L, 17L,
  "6-17", "6_17", 6L, 17L
)

exposure_list <- purrr::pmap(
  windows,
  function(window, suffix, start_age, end_age) make_exposure(hses, dzud_panel, start_age, end_age, suffix)
)
exposures <- purrr::reduce(exposure_list, left_join, by = "row_id")
analysis <- hses %>% left_join(exposures, by = "row_id")
saveRDS(analysis, file.path(codex_root, "data/cleaned/hses_dzud_exposure.rds"))

cat("Exposure completion by window:\n")
for (i in seq_len(nrow(windows))) {
  suffix <- windows$suffix[[i]]
  nvar <- paste0("dzud_n_complete_", suffix)
  expected <- windows$end_age[[i]] - windows$start_age[[i]] + 1
  cat(" ", windows$window[[i]], ": complete rows =",
      sum(analysis[[nvar]] == expected, na.rm = TRUE), "of", nrow(analysis), "\n")
}
cat("\n")

available_controls <- c("age", "age2", "female", "married", "urban")
controls <- available_controls[
  available_controls %in% names(analysis) &
    vapply(available_controls, function(v) sum(!is.na(analysis[[v]])) > 0 && dplyr::n_distinct(stats::na.omit(analysis[[v]])) > 1, logical(1))
]
cat("Controls used:", ifelse(length(controls) == 0, "none", paste(controls, collapse = ", ")), "\n")
cat("Weights used:", ifelse("hhweight" %in% names(analysis), "hhweight", "none"), "\n\n")

fe_designs <- tibble::tribble(
  ~fe_design, ~fe_formula, ~identification_source, ~is_main,
  "region + wave", "region_fe + wave", "between-aimag/chronic", FALSE,
  "birth_aimag + wave", "birth_aimag + wave", "within-aimag", FALSE,
  "birth_aimag + birth_cohort + wave", "birth_aimag + birth_cohort + wave", "within-aimag + cohort-controlled", TRUE,
  "birth_aimag + birth_year + wave", "birth_aimag + birth_year + wave", "within-aimag + birth-year-controlled", FALSE
)

if (!"region_fe" %in% names(analysis) || dplyr::n_distinct(stats::na.omit(analysis$region_fe)) < 2) {
  fe_designs <- fe_designs %>% filter(fe_design != "region + wave")
  cat("Skipped region + wave: region variable not available with usable variation.\n")
}
if (dplyr::n_distinct(stats::na.omit(analysis$birth_year)) < 2) {
  fe_designs <- fe_designs %>% filter(fe_design != "birth_aimag + birth_year + wave")
  cat("Skipped birth-year FE: birth_year lacks usable variation.\n")
}

iv_specs <- tidyr::crossing(
  windows %>% select(window, suffix),
  tibble::tribble(
    ~iv_name, ~iv_prefix,
    "cumulative loss rate", "dzud_cum",
    "maximum loss rate", "dzud_max",
    "count loss_rate >= 5", "dzud_count5",
    "count loss_rate >= 10", "dzud_count10",
    "count loss_rate >= year p75", "dzud_p75_count",
    "any loss_rate >= 5", "dzud_any_dzud5"
  )
) %>%
  mutate(iv_var = paste0(iv_prefix, "_", suffix))

coef_row <- function(fit, term) {
  ct <- as.data.frame(fixest::coeftable(fit))
  ct$term <- rownames(ct)
  hit <- ct[ct$term == term, , drop = FALSE]
  if (nrow(hit) == 0) return(NULL)
  p_col <- grep("^Pr\\(", names(hit), value = TRUE)
  if (length(p_col) == 0) p_col <- grep("p", names(hit), ignore.case = TRUE, value = TRUE)
  list(
    estimate = unname(hit$Estimate[[1]]),
    se = unname(hit[["Std. Error"]][[1]]),
    p = if (length(p_col) > 0) unname(hit[[p_col[[1]]]][[1]]) else NA_real_
  )
}

fit_feols_safe <- function(fml, data, cluster_var = "birth_aimag") {
  args <- list(fml = fml, data = data, notes = FALSE)
  if ("hhweight" %in% names(data)) args$weights <- stats::as.formula("~hhweight")
  if (cluster_var %in% names(data) && dplyr::n_distinct(stats::na.omit(data[[cluster_var]])) > 1) {
    args$vcov <- stats::as.formula(paste0("~", cluster_var))
    fit <- tryCatch(do.call(fixest::feols, args), error = function(e) e)
    if (!inherits(fit, "error")) return(list(fit = fit, vcov = "cluster"))
  }
  args$vcov <- "hetero"
  fit <- tryCatch(do.call(fixest::feols, args), error = function(e) e)
  if (inherits(fit, "error")) return(list(fit = NULL, vcov = "failed", error = conditionMessage(fit)))
  list(fit = fit, vcov = "hetero")
}

model_vars_from_fe <- function(fe_formula) {
  str_squish(unlist(strsplit(fe_formula, "\\+")))
}

make_verdict <- function(fe_design, pi_hat, F_first, is_main, usable = TRUE) {
  if (!usable || is.na(pi_hat) || is.na(F_first)) {
    return(ifelse(is_main, "COLLINEAR_USELESS", "DIAGNOSTIC_ONLY"))
  }
  if (!is_main) return("DIAGNOSTIC_ONLY")
  if (pi_hat >= 0) return("WRONG_SIGN")
  if (F_first >= 10) return("STRONG")
  if (F_first >= 5) return("MARGINAL")
  "WEAK"
}

run_audit_model <- function(data, window, iv_name, iv_var, fe_design, fe_formula, identification_source, is_main) {
  fe_vars <- model_vars_from_fe(fe_formula)
  needed <- unique(c("educ_years", "ln_wage", iv_var, controls, fe_vars, "birth_aimag", "hhweight"))
  needed <- needed[needed %in% names(data)]
  df <- data %>%
    filter(if_all(all_of(needed), ~ !is.na(.x))) %>%
    filter(is.finite(educ_years), is.finite(ln_wage), is.finite(.data[[iv_var]]))

  base_row <- tibble(
    window = window,
    iv_name = iv_name,
    iv_var = iv_var,
    fe_design = fe_design,
    pi_hat = NA_real_,
    pi_p = NA_real_,
    F_first = NA_real_,
    beta_2sls = NA_real_,
    se_2sls = NA_real_,
    N = nrow(df),
    expected_sign_ok = NA,
    sign_comment = "not estimated",
    verdict = make_verdict(fe_design, NA_real_, NA_real_, is_main, usable = FALSE),
    identification_source = identification_source
  )

  if (nrow(df) < 50 || dplyr::n_distinct(df[[iv_var]]) < 2) return(base_row)

  rhs_fs <- paste(c(iv_var, controls), collapse = " + ")
  fs_formula <- stats::as.formula(paste0("educ_years ~ ", rhs_fs, " | ", fe_formula))
  fs_fit <- fit_feols_safe(fs_formula, df)
  if (is.null(fs_fit$fit)) return(base_row)

  cr <- coef_row(fs_fit$fit, iv_var)
  if (is.null(cr) || is.na(cr$se) || cr$se == 0) return(base_row)

  pi_hat <- cr$estimate
  F_first <- (pi_hat / cr$se)^2
  expected_sign_ok <- !is.na(pi_hat) && pi_hat < 0
  sign_comment <- ifelse(expected_sign_ok, "negative as expected", "positive or zero; wrong expected sign")

  rhs_2sls <- if (length(controls) == 0) "1" else paste(controls, collapse = " + ")
  iv_formula <- stats::as.formula(paste0("ln_wage ~ ", rhs_2sls, " | ", fe_formula, " | educ_years ~ ", iv_var))
  iv_fit <- fit_feols_safe(iv_formula, df)
  beta_2sls <- NA_real_
  se_2sls <- NA_real_
  if (!is.null(iv_fit$fit)) {
    coef_names <- names(stats::coef(iv_fit$fit))
    endog_name <- coef_names[grepl("educ_years", coef_names)]
    if (length(endog_name) > 0) {
      iv_cr <- coef_row(iv_fit$fit, endog_name[[1]])
      if (!is.null(iv_cr)) {
        beta_2sls <- iv_cr$estimate
        se_2sls <- iv_cr$se
      }
    }
  }

  tibble(
    window = window,
    iv_name = iv_name,
    iv_var = iv_var,
    fe_design = fe_design,
    pi_hat = pi_hat,
    pi_p = cr$p,
    F_first = F_first,
    beta_2sls = beta_2sls,
    se_2sls = se_2sls,
    N = stats::nobs(fs_fit$fit),
    expected_sign_ok = expected_sign_ok,
    sign_comment = sign_comment,
    verdict = make_verdict(fe_design, pi_hat, F_first, is_main, usable = TRUE),
    identification_source = identification_source
  )
}

cat("Running first-stage and 2SLS audit models...\n")
audit_grid <- tidyr::crossing(iv_specs, fe_designs)
audit <- purrr::pmap_dfr(
  audit_grid,
  function(window, suffix, iv_name, iv_prefix, iv_var, fe_design, fe_formula, identification_source, is_main) {
    run_audit_model(analysis, window, iv_name, iv_var, fe_design, fe_formula, identification_source, is_main)
  }
)

audit_path <- file.path(codex_root, "output/tables/T2c_dzud_iv_audit.csv")
readr::write_csv(audit, audit_path)
cat("Saved audit table:", audit_path, "rows:", nrow(audit), "\n\n")

variance_absorbed <- function(data, iv_var, fe_formula) {
  fe_vars <- model_vars_from_fe(fe_formula)
  needed <- c(iv_var, fe_vars, "hhweight")
  needed <- needed[needed %in% names(data)]
  df <- data %>%
    filter(if_all(all_of(needed), ~ !is.na(.x))) %>%
    filter(is.finite(.data[[iv_var]]))
  if (nrow(df) < 20 || dplyr::n_distinct(df[[iv_var]]) < 2) {
    return(tibble(N = nrow(df), r2_absorbed = NA_real_))
  }
  fml <- stats::as.formula(paste0(iv_var, " ~ 1 | ", fe_formula))
  args <- list(fml = fml, data = df, notes = FALSE)
  if ("hhweight" %in% names(df)) args$weights <- stats::as.formula("~hhweight")
  fit <- tryCatch(do.call(fixest::feols, args), error = function(e) NULL)
  if (is.null(fit)) return(tibble(N = nrow(df), r2_absorbed = NA_real_))
  y <- df[[iv_var]]
  w <- if ("hhweight" %in% names(df)) df$hhweight else rep(1, nrow(df))
  ybar <- stats::weighted.mean(y, w, na.rm = TRUE)
  tss <- sum(w * (y - ybar)^2, na.rm = TRUE)
  rss <- sum(w * stats::residuals(fit)^2, na.rm = TRUE)
  tibble(N = stats::nobs(fit), r2_absorbed = ifelse(tss > 0, 1 - rss / tss, NA_real_))
}

key_ivs <- c("dzud_count5_6_17", "dzud_count5_12_17", "dzud_cum_12_17")
decomp_fe <- tibble::tribble(
  ~absorbed_by, ~fe_formula,
  "birth_aimag FE", "birth_aimag",
  "birth_aimag + birth_cohort FE", "birth_aimag + birth_cohort",
  "region + wave FE", "region_fe + wave"
)
if (!"region_fe" %in% names(analysis) || dplyr::n_distinct(stats::na.omit(analysis$region_fe)) < 2) {
  decomp_fe <- decomp_fe %>% filter(absorbed_by != "region + wave FE")
}

variance_decomp <- tidyr::crossing(iv_var = key_ivs, decomp_fe) %>%
  filter(iv_var %in% names(analysis)) %>%
  pmap_dfr(function(iv_var, absorbed_by, fe_formula) {
    variance_absorbed(analysis, iv_var, fe_formula) %>%
      mutate(iv_var = iv_var, absorbed_by = absorbed_by, .before = 1)
  })
variance_path <- file.path(codex_root, "output/tables/T2c_dzud_variance_decomposition.csv")
readr::write_csv(variance_decomp, variance_path)
cat("Saved variance decomposition:", variance_path, "rows:", nrow(variance_decomp), "\n")

sign_flip <- audit %>%
  filter(iv_var %in% key_ivs, fe_design %in% c("region + wave", "birth_aimag + wave", "birth_aimag + birth_cohort + wave")) %>%
  mutate(sign = case_when(is.na(pi_hat) ~ NA_character_, pi_hat < 0 ~ "negative", pi_hat > 0 ~ "positive", TRUE ~ "zero")) %>%
  group_by(iv_var) %>%
  mutate(sign_flip_across_designs = n_distinct(sign[!is.na(sign)]) > 1) %>%
  ungroup() %>%
  select(iv_var, fe_design, pi_hat, F_first, sign, sign_flip_across_designs)
sign_flip_path <- file.path(codex_root, "output/tables/T2c_dzud_sign_flip.csv")
readr::write_csv(sign_flip, sign_flip_path)
cat("Saved sign flip diagnostic:", sign_flip_path, "rows:", nrow(sign_flip), "\n")

make_bundle_exposure <- function(people, panel, bundle_name) {
  panel_use <- panel %>%
    filter(bundle == bundle_name) %>%
    select(aimag_code, year, loss_rate) %>%
    mutate(
      dzud5 = ifelse(is.na(loss_rate), NA_integer_, as.integer(loss_rate >= 5)),
      dzud10 = ifelse(is.na(loss_rate), NA_integer_, as.integer(loss_rate >= 10)),
      dzud_p75 = NA_integer_
    )
  make_exposure(people, panel_use, 12, 17, "12_17", prefix = bundle_name)
}

animal_cor_max <- NA_real_
animal_cor_path <- file.path(codex_root, "output/tables/T2c_dzud_animal_cor.csv")
animal_robust_path <- file.path(codex_root, "output/tables/T2c_dzud_animal_robustness.csv")
animal_robust <- tibble()

livestock_animal_path <- file.path(codex_root, "data/cleaned/livestock_by_animal.rds")
loss_animal_path <- file.path(codex_root, "data/cleaned/loss_by_animal.rds")
if (file.exists(livestock_animal_path) && file.exists(loss_animal_path)) {
  livestock_by_animal <- readRDS(livestock_animal_path)
  loss_by_animal <- readRDS(loss_animal_path)
  animal_panel <- full_join(
    livestock_by_animal,
    loss_by_animal,
    by = c("aimag_code", "aimag_name", "animal_type", "year")
  ) %>%
    filter(animal_type %in% c("Адуу", "Үхэр", "Тэмээ", "Хонь", "Ямаа")) %>%
    arrange(aimag_code, animal_type, year) %>%
    group_by(aimag_code, animal_type) %>%
    mutate(livestock_lag = lag(livestock_count)) %>%
    ungroup() %>%
    mutate(loss_rate = ifelse(is.finite(loss_count) & is.finite(livestock_lag) & livestock_lag > 0,
                              loss_count / livestock_lag * 100, NA_real_))

  animal_wide <- animal_panel %>%
    select(aimag_code, year, animal_type, loss_rate) %>%
    tidyr::pivot_wider(names_from = animal_type, values_from = loss_rate)
  cor_mat <- stats::cor(animal_wide %>% select(-aimag_code, -year), use = "pairwise.complete.obs")
  cor_df <- as.data.frame(cor_mat)
  cor_df <- tibble::rownames_to_column(cor_df, "animal_type")
  readr::write_csv(cor_df, animal_cor_path)
  upper_vals <- abs(cor_mat[upper.tri(cor_mat)])
  animal_cor_max <- max(upper_vals, na.rm = TRUE)
  cat("Saved animal correlation matrix:", animal_cor_path, "\n")
  cat("Max pairwise animal loss-rate correlation:", fmt(animal_cor_max, 3), "\n")
  if (is.finite(animal_cor_max) && animal_cor_max > 0.7) {
    cat("Animal-specific IVs are not suitable as separate IVs due to multicollinearity.\n")
  }

  bundle_map <- tibble::tribble(
    ~animal_type, ~bundle,
    "Адуу", "large_stock",
    "Үхэр", "large_stock",
    "Тэмээ", "large_stock",
    "Хонь", "small_stock",
    "Ямаа", "small_stock"
  )
  count_bundle <- livestock_by_animal %>%
    inner_join(bundle_map, by = "animal_type") %>%
    group_by(aimag_code, aimag_name, bundle, year) %>%
    summarise(livestock_count = sum(livestock_count, na.rm = TRUE), .groups = "drop")
  loss_bundle <- loss_by_animal %>%
    inner_join(bundle_map, by = "animal_type") %>%
    group_by(aimag_code, aimag_name, bundle, year) %>%
    summarise(loss_count = sum(loss_count, na.rm = TRUE), .groups = "drop")
  bundle_panel <- full_join(
    count_bundle,
    loss_bundle,
    by = c("aimag_code", "aimag_name", "bundle", "year")
  ) %>%
    arrange(aimag_code, bundle, year) %>%
    group_by(aimag_code, bundle) %>%
    mutate(livestock_lag = lag(livestock_count)) %>%
    ungroup() %>%
    mutate(loss_rate = ifelse(is.finite(loss_count) & is.finite(livestock_lag) & livestock_lag > 0,
                              loss_count / livestock_lag * 100, NA_real_))

  bundle_exposures <- purrr::map(
    c("large_stock", "small_stock"),
    ~ make_bundle_exposure(analysis, bundle_panel, .x)
  ) %>%
    purrr::reduce(left_join, by = "row_id")
  analysis_animal <- analysis %>% left_join(bundle_exposures, by = "row_id")

  animal_iv_vars <- tibble::tribble(
    ~bundle, ~iv_name, ~iv_var,
    "large_stock", "large cumulative loss rate", "large_stock_cum_12_17",
    "large_stock", "large maximum loss rate", "large_stock_max_12_17",
    "large_stock", "large count loss_rate >= 5", "large_stock_count5_12_17",
    "small_stock", "small cumulative loss rate", "small_stock_cum_12_17",
    "small_stock", "small maximum loss rate", "small_stock_max_12_17",
    "small_stock", "small count loss_rate >= 5", "small_stock_count5_12_17"
  )
  animal_robust <- animal_iv_vars %>%
    pmap_dfr(function(bundle, iv_name, iv_var) {
      run_audit_model(
        analysis_animal, "12-17", iv_name, iv_var,
        "birth_aimag + birth_cohort + wave",
        "birth_aimag + birth_cohort + wave",
        "within-aimag + cohort-controlled",
        TRUE
      ) %>% mutate(bundle = bundle, .before = 1)
    })
  readr::write_csv(animal_robust, animal_robust_path)
  cat("Saved animal robustness:", animal_robust_path, "rows:", nrow(animal_robust), "\n")
} else {
  readr::write_csv(tibble(), animal_cor_path)
  readr::write_csv(tibble(), animal_robust_path)
  cat("Animal-type data not found; wrote empty animal diagnostics.\n")
}

run_heterogeneity <- function(data, iv_var) {
  fe_formula <- "birth_aimag + birth_cohort + wave"
  fe_vars <- model_vars_from_fe(fe_formula)
  needed <- unique(c("educ_years", iv_var, "rural_birth", controls, fe_vars, "birth_aimag", "hhweight"))
  needed <- needed[needed %in% names(data)]
  df <- data %>%
    filter(if_all(all_of(needed), ~ !is.na(.x))) %>%
    filter(is.finite(educ_years), is.finite(.data[[iv_var]]))
  if (nrow(df) < 50 || dplyr::n_distinct(df[[iv_var]]) < 2) {
    return(tibble(iv_var = iv_var, proxy = "rural_birth", term = NA_character_,
                  estimate = NA_real_, std_error = NA_real_, p = NA_real_, N = nrow(df)))
  }
  rhs <- paste(c(paste0(iv_var, " * rural_birth"), controls), collapse = " + ")
  fml <- stats::as.formula(paste0("educ_years ~ ", rhs, " | ", fe_formula))
  fit <- fit_feols_safe(fml, df)
  if (is.null(fit$fit)) {
    return(tibble(iv_var = iv_var, proxy = "rural_birth", term = NA_character_,
                  estimate = NA_real_, std_error = NA_real_, p = NA_real_, N = nrow(df)))
  }
  ct <- as.data.frame(fixest::coeftable(fit$fit))
  ct$term <- rownames(ct)
  p_col <- grep("^Pr\\(", names(ct), value = TRUE)
  wanted <- c(iv_var, paste0(iv_var, ":rural_birth"), paste0("rural_birth:", iv_var))
  ct %>%
    filter(term %in% wanted) %>%
    transmute(
      iv_var = iv_var,
      proxy = "rural_birth",
      term,
      estimate = Estimate,
      std_error = `Std. Error`,
      p = if (length(p_col) > 0) .data[[p_col[[1]]]] else NA_real_,
      N = stats::nobs(fit$fit)
    )
}

heterogeneity <- purrr::map_dfr(c("dzud_count5_12_17", "dzud_cum_12_17"), ~ run_heterogeneity(analysis, .x))
heterogeneity_path <- file.path(codex_root, "output/tables/T2c_dzud_heterogeneity.csv")
readr::write_csv(heterogeneity, heterogeneity_path)
cat("Saved heterogeneity:", heterogeneity_path, "rows:", nrow(heterogeneity), "\n\n")

main_corrected <- audit %>%
  filter(window == "12-17", fe_design == "birth_aimag + birth_cohort + wave") %>%
  arrange(desc(F_first))

main_negative <- main_corrected %>% filter(!is.na(pi_hat), pi_hat < 0)
all_main_F_lt5 <- nrow(main_corrected) > 0 && all(main_corrected$F_first < 5 | is.na(main_corrected$F_first))
has_strong <- any(main_corrected$verdict == "STRONG", na.rm = TRUE)
has_marginal <- any(main_corrected$verdict == "MARGINAL", na.rm = TRUE)

final_verdict <- if (all_main_F_lt5 || (!has_strong && !has_marginal)) {
  "Reject as IV"
} else if (has_strong) {
  "Use as primary IV"
} else {
  "Use only as descriptive mechanism"
}

region_high <- audit %>%
  filter(window == "12-17", fe_design == "region + wave", F_first >= 10) %>%
  nrow() > 0
corrected_weak <- all_main_F_lt5
chronic_statement <- if (region_high && corrected_weak) {
  "High F is driven by chronic between-aimag differences, not clean shock variation."
} else if (region_high) {
  "Region + wave produces high diagnostic F for at least one IV."
} else {
  "Region + wave does not produce high diagnostic F in the main window."
}

any_sign_flip <- any(sign_flip$sign_flip_across_designs, na.rm = TRUE)
sign_flip_statement <- if (any_sign_flip) {
  "Sign flip indicates unstable mechanism and weak identification."
} else {
  "No sign flip detected across the recorded key diagnostic designs."
}

animal_statement <- if (is.finite(animal_cor_max) && animal_cor_max > 0.7) {
  paste0("Animal-specific IVs are not suitable as separate IVs due to multicollinearity; max pairwise correlation = ", fmt(animal_cor_max, 3), ".")
} else if (is.finite(animal_cor_max)) {
  paste0("Animal-specific max pairwise correlation = ", fmt(animal_cor_max, 3), ".")
} else {
  "Animal-type correlation diagnostic not available."
}

data_files_used <- file.path(codex_root, "output/logs/01_data_files_used.csv")
used_lines <- if (file.exists(data_files_used)) {
  used <- readr::read_csv(data_files_used, show_col_types = FALSE)
  paste0("- ", used$role, ": `", used$path, "`")
} else {
  c("- Cleaned HSES and dzud files from `codex/data/cleaned/`")
}

main_md <- c(
  "| IV | pi_hat | p | F_first | beta_2SLS | se_2SLS | N | verdict |",
  "|---|---:|---:|---:|---:|---:|---:|---|",
  paste0(
    "| ", main_corrected$iv_var,
    " | ", fmt(main_corrected$pi_hat, 4),
    " | ", fmt(main_corrected$pi_p, 4),
    " | ", fmt(main_corrected$F_first, 3),
    " | ", fmt(main_corrected$beta_2sls, 4),
    " | ", fmt(main_corrected$se_2sls, 4),
    " | ", main_corrected$N,
    " | ", main_corrected$verdict,
    " |"
  )
)

report <- c(
  "# Dzud IV Audit Summary",
  "",
  "## Data Files Used",
  used_lines,
  "",
  "## Sample Size",
  paste0("- Clean HSES wage-earner sample with matched birth aimag: ", nrow(hses)),
  paste0("- Main age 12-17 complete-exposure rows: ", sum(!is.na(analysis$dzud_count5_12_17))),
  "",
  "## Main Corrected FE Results",
  "- FE: birth_aimag + birth_cohort + wave",
  main_md,
  "",
  "## Diagnostics",
  paste0("- ", chronic_statement),
  paste0("- ", sign_flip_statement),
  paste0("- ", animal_statement),
  "",
  "## Final Verdict",
  paste0("- ", final_verdict),
  if (final_verdict == "Reject as IV") "- Reject dzud as primary IV." else character(0),
  if (final_verdict != "Use as primary IV") "- Do not make causal IV claims from the dzud first stage." else character(0)
)

report_path <- file.path(codex_root, "output/reports/dzud_iv_audit_summary.md")
writeLines(report, report_path, useBytes = TRUE)
cat("Saved markdown summary:", report_path, "\n")

cat("\nMain corrected FE rows:\n")
print(main_corrected, n = nrow(main_corrected))
cat("\nFinal verdict:", final_verdict, "\n")
cat("02_dzud_iv_audit.R complete.\n")
