# Dedicated dzud exposure audit for age 6-12.

options(warn = 1)

get_script_path <- function() {
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", args, value = TRUE)
  if (length(file_arg) == 0) return(file.path("codex", "R", "04_dzud_6_12_checks.R"))
  sub("^--file=", "", file_arg[[1]])
}

script_dir <- dirname(normalizePath(get_script_path(), winslash = "/", mustWork = FALSE))
project_root <- normalizePath(file.path(script_dir, "..", ".."), winslash = "/", mustWork = TRUE)
codex_root <- file.path(project_root, "codex")
invisible(lapply(file.path(codex_root, c("output/tables", "output/logs", "data/cleaned")), dir.create, recursive = TRUE, showWarnings = FALSE))

sink(file.path(codex_root, "output/logs/04_dzud_6_12_checks.log"), split = TRUE)
on.exit(sink(), add = TRUE)

required_pkgs <- c("dplyr", "tidyr", "readr", "fixest", "tibble", "purrr")
missing_pkgs <- required_pkgs[!vapply(required_pkgs, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_pkgs) > 0) stop("Missing required R packages: ", paste(missing_pkgs, collapse = ", "))

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(readr)
  library(fixest)
  library(tibble)
  library(purrr)
})

aimag_codes <- c(11, 21, 22, 23, 41, 42, 43, 44, 45, 46, 48, 61, 62, 63, 64, 65, 67, 81, 82, 83, 84, 85)

cohort_bin <- function(birth_year) {
  factor(case_when(
    birth_year < 1970 ~ "pre1970",
    birth_year >= 1970 & birth_year <= 1974 ~ "1970-74",
    birth_year >= 1975 & birth_year <= 1979 ~ "1975-79",
    birth_year >= 1980 & birth_year <= 1984 ~ "1980-84",
    birth_year >= 1985 & birth_year <= 1989 ~ "1985-89",
    birth_year >= 1990 & birth_year <= 1994 ~ "1990-94",
    birth_year >= 1995 ~ "post1995",
    TRUE ~ NA_character_
  ), levels = c("pre1970", "1970-74", "1975-79", "1980-84", "1985-89", "1990-94", "post1995"))
}

make_exposure_6_12 <- function(people, panel) {
  start_age <- 6L
  end_age <- 12L
  expected_n <- end_age - start_age + 1
  panel_use <- panel %>% select(aimag_code, year, loss_rate, dzud5, dzud10, dzud_p75)
  people %>%
    select(row_id, birth_aimag, birth_year) %>%
    crossing(age_at_exposure = start_age:end_age) %>%
    mutate(year = birth_year + age_at_exposure) %>%
    left_join(panel_use, by = c("birth_aimag" = "aimag_code", "year" = "year")) %>%
    group_by(row_id) %>%
    summarise(
      n_complete_6_12 = sum(!is.na(loss_rate)),
      dzud_cum_6_12 = ifelse(n_complete_6_12 == expected_n, sum(loss_rate), NA_real_),
      dzud_max_6_12 = ifelse(n_complete_6_12 == expected_n, max(loss_rate), NA_real_),
      dzud_count5_6_12 = ifelse(n_complete_6_12 == expected_n, sum(dzud5 == 1, na.rm = TRUE), NA_real_),
      dzud_count10_6_12 = ifelse(n_complete_6_12 == expected_n, sum(dzud10 == 1, na.rm = TRUE), NA_real_),
      dzud_p75_count_6_12 = ifelse(n_complete_6_12 == expected_n, sum(dzud_p75 == 1, na.rm = TRUE), NA_real_),
      dzud_any_dzud5_6_12 = ifelse(n_complete_6_12 == expected_n, as.integer(sum(dzud5 == 1, na.rm = TRUE) > 0), NA_real_),
      .groups = "drop"
    )
}

coef_row <- function(fit, term) {
  ct <- as.data.frame(coeftable(fit))
  ct$term <- rownames(ct)
  hit <- ct[ct$term == term, , drop = FALSE]
  if (nrow(hit) == 0) return(NULL)
  p_col <- grep("^Pr\\(", names(hit), value = TRUE)
  list(
    estimate = hit$Estimate[[1]],
    se = hit[["Std. Error"]][[1]],
    p = if (length(p_col) > 0) hit[[p_col[[1]]]][[1]] else NA_real_
  )
}

fit_feols_safe <- function(fml, data) {
  args <- list(fml = fml, data = data, notes = FALSE)
  if ("hhweight" %in% names(data)) args$weights <- ~hhweight
  if ("birth_aimag" %in% names(data) && n_distinct(na.omit(data$birth_aimag)) > 1) {
    args$vcov <- ~birth_aimag
    fit <- tryCatch(do.call(feols, args), error = function(e) e)
    if (!inherits(fit, "error")) return(fit)
  }
  args$vcov <- "hetero"
  fit <- tryCatch(do.call(feols, args), error = function(e) e)
  if (inherits(fit, "error")) return(NULL)
  fit
}

verdict_main <- function(pi_hat, F_first, main = TRUE) {
  if (!main) return("DIAGNOSTIC_ONLY")
  if (is.na(pi_hat) || is.na(F_first)) return("COLLINEAR_USELESS")
  if (pi_hat >= 0) return("WRONG_SIGN")
  if (F_first >= 10) return("STRONG")
  if (F_first >= 5) return("MARGINAL")
  "WEAK"
}

run_model <- function(data, sample, iv_var, fe_design, fe_formula, main = FALSE) {
  controls <- c("age", "age2", "female", "married", "urban")
  controls <- controls[controls %in% names(data)]
  fe_vars <- trimws(unlist(strsplit(fe_formula, "\\+")))
  needed <- unique(c("educ_years", "ln_wage", iv_var, controls, fe_vars, "birth_aimag", "hhweight"))
  needed <- needed[needed %in% names(data)]
  df <- data %>%
    filter(if_all(all_of(needed), ~ !is.na(.x))) %>%
    filter(is.finite(educ_years), is.finite(.data[[iv_var]]))

  empty <- tibble(
    sample = sample, iv_var = iv_var, fe_design = fe_design,
    pi_hat = NA_real_, pi_p = NA_real_, F_first = NA_real_,
    beta_2sls = NA_real_, se_2sls = NA_real_, N = nrow(df),
    verdict = verdict_main(NA_real_, NA_real_, main)
  )
  if (nrow(df) < 100 || n_distinct(df[[iv_var]]) < 2) return(empty)

  rhs <- paste(c(iv_var, controls), collapse = " + ")
  fs <- fit_feols_safe(as.formula(paste0("educ_years ~ ", rhs, " | ", fe_formula)), df)
  if (is.null(fs)) return(empty)
  cr <- coef_row(fs, iv_var)
  if (is.null(cr) || is.na(cr$se) || cr$se == 0) return(empty)
  pi_hat <- cr$estimate
  F_first <- (pi_hat / cr$se)^2

  beta_2sls <- NA_real_
  se_2sls <- NA_real_
  if ("ln_wage" %in% names(df) && sum(!is.na(df$ln_wage)) > 100) {
    rhs_iv <- if (length(controls) == 0) "1" else paste(controls, collapse = " + ")
    ivfit <- fit_feols_safe(as.formula(paste0("ln_wage ~ ", rhs_iv, " | ", fe_formula, " | educ_years ~ ", iv_var)), df)
    if (!is.null(ivfit)) {
      endog_name <- names(coef(ivfit))[grepl("educ_years", names(coef(ivfit)))][1]
      if (!is.na(endog_name)) {
        ivcr <- coef_row(ivfit, endog_name)
        if (!is.null(ivcr)) {
          beta_2sls <- ivcr$estimate
          se_2sls <- ivcr$se
        }
      }
    }
  }

  tibble(
    sample = sample,
    iv_var = iv_var,
    fe_design = fe_design,
    pi_hat = pi_hat,
    pi_p = cr$p,
    F_first = F_first,
    beta_2sls = beta_2sls,
    se_2sls = se_2sls,
    N = nobs(fs),
    verdict = verdict_main(pi_hat, F_first, main)
  )
}

run_first_stage_only <- function(data, sample, iv_var) {
  controls <- c("age", "age2", "female", "married", "urban")
  controls <- controls[controls %in% names(data)]
  needed <- unique(c("educ_years", iv_var, controls, "birth_aimag", "birth_cohort", "wave", "hhweight"))
  df <- data %>%
    filter(if_all(all_of(needed), ~ !is.na(.x))) %>%
    filter(is.finite(educ_years), is.finite(.data[[iv_var]]))
  empty <- tibble(sample = sample, iv_var = iv_var, pi_hat = NA_real_, pi_p = NA_real_, F_first = NA_real_, N = nrow(df), verdict = "NOT_ESTIMATED")
  if (nrow(df) < 100 || n_distinct(df[[iv_var]]) < 2) return(empty)
  rhs <- paste(c(iv_var, controls), collapse = " + ")
  fs <- fit_feols_safe(as.formula(paste0("educ_years ~ ", rhs, " | birth_aimag + birth_cohort + wave")), df)
  if (is.null(fs)) return(empty)
  cr <- coef_row(fs, iv_var)
  if (is.null(cr) || is.na(cr$se) || cr$se == 0) return(empty)
  pi_hat <- cr$estimate
  F_first <- (pi_hat / cr$se)^2
  tibble(
    sample = sample, iv_var = iv_var, pi_hat = pi_hat, pi_p = cr$p,
    F_first = F_first, N = nobs(fs),
    verdict = case_when(
      pi_hat >= 0 ~ "WRONG_SIGN",
      F_first >= 10 ~ "STRONG",
      F_first >= 5 ~ "MARGINAL",
      TRUE ~ "WEAK"
    )
  )
}

cat("04_dzud_6_12_checks.R\n")

dzud_panel <- readRDS(file.path(codex_root, "data/cleaned/dzud_panel.rds"))
hses <- readRDS(file.path(codex_root, "data/cleaned/hses_clean.rds")) %>%
  mutate(
    row_id = row_number(),
    birth_cohort = cohort_bin(birth_year),
    rural_birth = as.integer(birth_aimag != 11),
    region_fe = if ("birth_region" %in% names(.)) as.character(birth_region) else as.character(region)
  )
hses <- hses %>% left_join(make_exposure_6_12(hses, dzud_panel), by = "row_id")
saveRDS(hses, file.path(codex_root, "data/cleaned/hses_dzud_exposure_6_12.rds"))

fe_designs <- tibble::tribble(
  ~fe_design, ~fe_formula, ~main,
  "region + wave", "region_fe + wave", FALSE,
  "birth_aimag + wave", "birth_aimag + wave", FALSE,
  "birth_aimag + birth_cohort + wave", "birth_aimag + birth_cohort + wave", TRUE,
  "birth_aimag + birth_year + wave", "birth_aimag + birth_year + wave", FALSE
)

iv_vars <- c(
  "dzud_cum_6_12",
  "dzud_max_6_12",
  "dzud_count5_6_12",
  "dzud_count10_6_12",
  "dzud_p75_count_6_12",
  "dzud_any_dzud5_6_12"
)

audit_6_12 <- tidyr::crossing(iv_var = iv_vars, fe_designs) %>%
  pmap_dfr(function(iv_var, fe_design, fe_formula, main) {
    run_model(hses, "wage_sample", iv_var, fe_design, fe_formula, main)
  })

write_csv(audit_6_12, file.path(codex_root, "output/tables/T2c_dzud_6_12_audit.csv"))

harm <- readRDS(file.path(project_root, "data/processed/hses_harmonized.rds"))
all_adults <- harm %>%
  transmute(
    id = as.character(id),
    educ_years = as.numeric(educ_years),
    birth_year = as.integer(birth_year),
    birth_aimag = as.integer(birth_aimag),
    age = as.numeric(age),
    age2 = age^2,
    female = as.integer(as.numeric(sex) == 2),
    married = as.integer(as.numeric(marital) == 2),
    urban = as.integer(as.numeric(urban) == 1),
    hhweight = ifelse(is.finite(as.numeric(hhweight)) & as.numeric(hhweight) > 0, as.numeric(hhweight), 1),
    wave = as.integer(wave),
    row_id = row_number()
  ) %>%
  filter(age >= 25, age <= 60, birth_aimag %in% aimag_codes, !is.na(birth_year), !is.na(educ_years)) %>%
  mutate(
    birth_cohort = cohort_bin(birth_year),
    rural_birth = as.integer(birth_aimag != 11)
  )
all_adults <- all_adults %>% left_join(make_exposure_6_12(all_adults, dzud_panel), by = "row_id")

make_samples <- function(df, prefix) {
  list(
    all = df,
    rural_birth = df %>% filter(rural_birth == 1),
    current_rural = df %>% filter(urban == 0),
    birth_1980_1999 = df %>% filter(birth_year >= 1980, birth_year <= 1999),
    rural_birth_1980_1999 = df %>% filter(rural_birth == 1, birth_year >= 1980, birth_year <= 1999)
  ) %>%
    imap(~ mutate(.x, sample_label = paste(prefix, .y, sep = "_")))
}

sample_list <- c(make_samples(hses, "wage"), make_samples(all_adults, "all_adults"))
logic_6_12 <- imap_dfr(sample_list, function(df, nm) {
  map_dfr(c("dzud_cum_6_12", "dzud_count5_6_12", "dzud_p75_count_6_12"), ~ run_first_stage_only(df, unique(df$sample_label)[1], .x))
})

coverage_6_12 <- bind_rows(
  hses %>% mutate(sample = "wage"),
  all_adults %>% mutate(sample = "all_adults")
) %>%
  mutate(complete_6_12 = !is.na(dzud_cum_6_12)) %>%
  group_by(sample, birth_cohort) %>%
  summarise(
    N = n(),
    complete_6_12_N = sum(complete_6_12),
    complete_6_12_share = mean(complete_6_12),
    .groups = "drop"
  )

write_csv(logic_6_12, file.path(codex_root, "output/tables/T2c_dzud_6_12_logic_checks.csv"))
write_csv(coverage_6_12, file.path(codex_root, "output/tables/T2c_dzud_6_12_coverage_by_cohort.csv"))

cat("Saved T2c_dzud_6_12_audit.csv rows:", nrow(audit_6_12), "\n")
cat("Saved T2c_dzud_6_12_logic_checks.csv rows:", nrow(logic_6_12), "\n")
cat("Saved T2c_dzud_6_12_coverage_by_cohort.csv rows:", nrow(coverage_6_12), "\n\n")
cat("Corrected main FE, wage sample:\n")
print(audit_6_12 %>% filter(fe_design == "birth_aimag + birth_cohort + wave") %>% arrange(desc(F_first)), n = 20)
cat("\nLogic checks:\n")
print(logic_6_12, n = nrow(logic_6_12))
