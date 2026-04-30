# Test newly discovered HSES IV candidates with corrected fixed effects.

options(warn = 1, encoding = "UTF-8")

required_pkgs <- c("dplyr", "stringr", "readr", "tibble", "purrr", "fixest")
missing_pkgs <- required_pkgs[!vapply(required_pkgs, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_pkgs) > 0) stop("Missing packages: ", paste(missing_pkgs, collapse = ", "))

suppressPackageStartupMessages({
  library(dplyr)
  library(stringr)
  library(readr)
  library(tibble)
  library(purrr)
  library(fixest)
})

dir.create("output/tables", recursive = TRUE, showWarnings = FALSE)
dir.create("output/reports", recursive = TRUE, showWarnings = FALSE)
dir.create("output/logs", recursive = TRUE, showWarnings = FALSE)

sink("output/logs/13e_new_iv_test.log", split = TRUE)
on.exit(sink(), add = TRUE)

cat("13e_new_iv_test.R\n")
cat("Started:", as.character(Sys.time()), "\n\n")

data_path <- "data/auxiliary/new_iv_candidate_data.rds"
list_path <- "data/auxiliary/new_iv_candidate_list.csv"
if (!file.exists(data_path)) stop("Missing ", data_path, ". Run R/13d_unexplored_variables.R first.")
if (!file.exists(list_path)) stop("Missing ", list_path, ". Run R/13d_unexplored_variables.R first.")

dat <- readRDS(data_path)
candidates <- read_csv(list_path, show_col_types = FALSE)

dat <- dat %>%
  mutate(
    birth_aimag = as.factor(birth_aimag),
    birth_cohort = as.factor(birth_cohort),
    wave = as.factor(wave),
    birth_year_fe = as.factor(birth_year),
    female = as.numeric(female),
    married = as.numeric(married),
    urban = as.numeric(urban),
    hhweight = suppressWarnings(as.numeric(hhweight))
  )

main_sample <- dat %>%
  filter(
    age >= 25, age <= 60,
    is.finite(lwage),
    !is.na(educ_years),
    !is.na(birth_year),
    !is.na(birth_aimag),
    !is.na(birth_cohort),
    !is.na(wave)
  )

cat("Main wage sample rows:", nrow(main_sample), "\n")
cat("Waves in sample:", paste(sort(unique(as.character(main_sample$wave))), collapse = ", "), "\n\n")

controls <- intersect(c("age", "age2", "female", "married", "urban"), names(main_sample))
rhs_controls <- if (length(controls) > 0) paste(controls, collapse = " + ") else "1"

sign_ok_fun <- function(pi_hat, expected_sign) {
  if (is.na(pi_hat) || is.na(expected_sign) || expected_sign == "unknown") return(NA)
  if (expected_sign == "positive") return(pi_hat > 0)
  if (expected_sign == "negative") return(pi_hat < 0)
  NA
}

run_one <- function(iv_var, iv_name, expected_sign, source, exclusion_warning) {
  if (!iv_var %in% names(main_sample)) {
    return(tibble(iv_name, iv_var, pi_hat = NA_real_, pi_p = NA_real_, F_first = NA_real_,
                  beta_2sls = NA_real_, se_2sls = NA_real_, N = 0L, expected_sign,
                  sign_ok = NA, cor_q_school_access = NA_real_, verdict = "COLLINEAR_USELESS",
                  notes = "variable not found"))
  }
  d <- main_sample %>%
    mutate(iv_value = suppressWarnings(as.numeric(.data[[iv_var]]))) %>%
    filter(!is.na(iv_value), is.finite(iv_value))
  n_nonmissing <- nrow(d)
  n_unique <- n_distinct(d$iv_value, na.rm = TRUE)
  if (n_nonmissing < 100 || n_unique < 2) {
    return(tibble(iv_name, iv_var, pi_hat = NA_real_, pi_p = NA_real_, F_first = NA_real_,
                  beta_2sls = NA_real_, se_2sls = NA_real_, N = n_nonmissing, expected_sign,
                  sign_ok = NA, cor_q_school_access = NA_real_, verdict = "COLLINEAR_USELESS",
                  notes = paste0("insufficient usable variation: N=", n_nonmissing, ", unique=", n_unique, "; ", exclusion_warning)))
  }
  d$iv_test_value <- d$iv_value
  wts <- if ("hhweight" %in% names(d) && any(is.finite(d$hhweight) & d$hhweight > 0, na.rm = TRUE)) ~hhweight else NULL
  vc <- if (n_distinct(d$birth_aimag) >= 2) ~birth_aimag else "hetero"
  fs_formula <- as.formula(paste0("educ_years ~ iv_test_value + ", rhs_controls, " | birth_aimag + birth_cohort + wave"))
  iv_formula <- as.formula(paste0("lwage ~ ", rhs_controls, " | birth_aimag + birth_cohort + wave | educ_years ~ iv_test_value"))
  warning_note <- exclusion_warning
  first <- tryCatch(
    feols(fs_formula, data = d, weights = wts, vcov = vc, notes = FALSE),
    error = function(e) e
  )
  if (inherits(first, "error")) {
    first <- tryCatch(
      feols(fs_formula, data = d, weights = wts, vcov = "hetero", notes = FALSE),
      error = function(e) e
    )
    warning_note <- paste(warning_note, "cluster failed; robust attempted", sep = " | ")
  }
  if (inherits(first, "error")) {
    return(tibble(iv_name, iv_var, pi_hat = NA_real_, pi_p = NA_real_, F_first = NA_real_,
                  beta_2sls = NA_real_, se_2sls = NA_real_, N = n_nonmissing, expected_sign,
                  sign_ok = NA, cor_q_school_access = NA_real_, verdict = "COLLINEAR_USELESS",
                  notes = paste("first-stage failed:", conditionMessage(first), warning_note)))
  }
  ct <- tryCatch(coeftable(first), error = function(e) NULL)
  if (is.null(ct) || !"iv_test_value" %in% rownames(ct)) {
    return(tibble(iv_name, iv_var, pi_hat = NA_real_, pi_p = NA_real_, F_first = NA_real_,
                  beta_2sls = NA_real_, se_2sls = NA_real_, N = nobs(first), expected_sign,
                  sign_ok = NA, cor_q_school_access = NA_real_, verdict = "COLLINEAR_USELESS",
                  notes = paste("absorbed by fixed effects or collinear", warning_note, sep = " | ")))
  }
  pi_hat <- unname(coef(first)["iv_test_value"])
  se_first <- unname(ct["iv_test_value", "Std. Error"])
  pi_p <- unname(ct["iv_test_value", "Pr(>|t|)"])
  F_first <- as.numeric((pi_hat / se_first)^2)
  sign_ok <- sign_ok_fun(pi_hat, expected_sign)
  cor_q_school_access <- if ("q_school_access" %in% names(d)) suppressWarnings(cor(d$iv_test_value, as.numeric(d$q_school_access), use = "pairwise.complete.obs")) else NA_real_
  second <- tryCatch(
    feols(iv_formula, data = d, weights = wts, vcov = vc, notes = FALSE),
    error = function(e) e
  )
  if (inherits(second, "error")) {
    second <- tryCatch(
      feols(iv_formula, data = d, weights = wts, vcov = "hetero", notes = FALSE),
      error = function(e) e
    )
    warning_note <- paste(warning_note, "2SLS cluster failed; robust attempted", sep = " | ")
  }
  beta_2sls <- NA_real_
  se_2sls <- NA_real_
  if (!inherits(second, "error")) {
    sc <- tryCatch(coeftable(second), error = function(e) NULL)
    if (!is.null(sc)) {
      rn <- rownames(sc)
      target <- rn[str_detect(rn, "educ_years")]
      if (length(target) > 0) {
        beta_2sls <- unname(sc[target[1], "Estimate"])
        se_2sls <- unname(sc[target[1], "Std. Error"])
      }
    }
  } else {
    warning_note <- paste(warning_note, "2SLS failed:", conditionMessage(second), sep = " | ")
  }
  verdict <- case_when(
    !is.na(sign_ok) & !sign_ok ~ "WRONG_SIGN",
    is.na(F_first) ~ "COLLINEAR_USELESS",
    F_first >= 10 ~ "STRONG",
    F_first >= 5 ~ "MARGINAL",
    F_first < 5 ~ "WEAK",
    TRUE ~ "COLLINEAR_USELESS"
  )
  tibble(
    iv_name, iv_var, pi_hat, pi_p, F_first, beta_2sls, se_2sls,
    N = nobs(first), expected_sign, sign_ok, cor_q_school_access, verdict,
    notes = paste(source, warning_note, sep = " | ")
  )
}

results <- pmap_dfr(
  candidates %>% select(iv_var, iv_name, expected_sign, source, exclusion_warning),
  run_one
) %>%
  arrange(desc(F_first), verdict, iv_var)

write_csv(results, "output/tables/T2c_new_iv_search.csv")

top10 <- results %>%
  arrange(desc(F_first)) %>%
  select(iv_var, iv_name, pi_hat, F_first, beta_2sls, se_2sls, N, expected_sign, sign_ok, cor_q_school_access, verdict, notes) %>%
  head(10)

strong <- results %>% filter(verdict == "STRONG")
marginal <- results %>% filter(verdict == "MARGINAL")
failed <- results %>% filter(verdict %in% c("WEAK", "WRONG_SIGN", "COLLINEAR_USELESS"))

hidden_results <- results %>%
  filter(iv_var %in% candidates$iv_var[candidates$hidden_gem %in% TRUE]) %>%
  arrange(desc(F_first))

clean_warning_pattern <- regex(
  "Post-treatment|Current|endogenous|exclusion risk|caveat|diagnostic|direct|invalid|not a valid|needs substantive|Household choice",
  ignore_case = TRUE
)
recommended <- strong %>% filter(!str_detect(notes, clean_warning_pattern))

summary_lines <- c(
  "# New HSES IV Search",
  "",
  paste0("Generated: ", Sys.time()),
  "",
  paste0("Main wage sample N before IV-specific missing filters: ", nrow(main_sample)),
  paste0("Candidate IVs tested: ", nrow(results)),
  "",
  "## Top 10 by Corrected-FE First Stage",
  "",
  paste0("- ", top10$iv_var, ": pi=", round(top10$pi_hat, 4),
         ", F=", round(top10$F_first, 2), ", N=", top10$N,
         ", verdict=", top10$verdict,
         ", q_school_access_cor=", round(top10$cor_q_school_access, 3)),
  "",
  "## Strong",
  if (nrow(strong) == 0) "none" else paste0("- ", strong$iv_var, ": F=", round(strong$F_first, 2), ", notes=", strong$notes),
  "",
  "## Marginal",
  if (nrow(marginal) == 0) "none" else paste0("- ", marginal$iv_var, ": F=", round(marginal$F_first, 2), ", notes=", marginal$notes),
  "",
  "## Hidden Gems Tested",
  if (nrow(hidden_results) == 0) "no relevant variable found" else paste0("- ", hidden_results$iv_var, ": F=", round(hidden_results$F_first, 2), ", verdict=", hidden_results$verdict),
  "",
  "## Recommended IV",
  if (nrow(recommended) == 0) {
    "No clean HSES-only IV is recommended. Strong first stages, where present, have exclusion restriction or post-treatment problems."
  } else {
    paste0("- ", recommended$iv_var[1])
  }
)
writeLines(summary_lines, "output/reports/new_iv_search_summary.md", useBytes = TRUE)

checkpoint <- c(
  "## CHECKPOINT 2.7 — HSES Deep Variable Exploration",
  "",
  "Discovered variables (newly explored):",
  paste0("- ", candidates$iv_var, " (", candidates$source, "; nonmissing=", candidates$n_nonmissing, ")"),
  "",
  "Tested as IV:",
  paste0("- ", top10$iv_var, ": F=", round(top10$F_first, 2), ", pi=", round(top10$pi_hat, 4),
         ", verdict=", top10$verdict, ", N=", top10$N),
  "",
  "New candidates (final):",
  paste0("- Strong (F >= 10): ", if (nrow(strong) == 0) "none" else paste(strong$iv_var, collapse = ", ")),
  paste0("- Marginal (5 <= F < 10): ", if (nrow(marginal) == 0) "none" else paste(marginal$iv_var, collapse = ", ")),
  paste0("- Failed (F < 5 / wrong sign / collinear): ", if (nrow(failed) == 0) "none" else paste(failed$iv_var, collapse = ", ")),
  "",
  "Conclusion:",
  "- No HSES-only candidate is accepted as a clean primary IV without an exclusion-restriction caveat.",
  ""
)

log_path <- "RESULTS_LOG.md"
old <- if (file.exists(log_path)) readLines(log_path, warn = FALSE, encoding = "UTF-8") else character()
idx <- grep("^## CHECKPOINT 2\\.7", old)
if (length(idx) > 0) old <- old[seq_len(idx[1] - 1)]
writeLines(c(old, "", checkpoint), log_path, useBytes = TRUE)

cat("Results rows:", nrow(results), "\n")
print(top10, n = Inf)
cat("\n13e complete.\n")


