# Main q_school_access IV threshold estimation with parent_educ_mean IV.
# Method: Caner-Hansen-inspired IV threshold approximation.

options(warn = 1, encoding = "UTF-8")

source(here::here("R", "paths.R"))
suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(tibble)
  library(fixest)
  library(ggplot2)
})

setFixest_estimation(panel.id = NULL)

dir.create(PATHS$out_tables, recursive = TRUE, showWarnings = FALSE)
dir.create(PATHS$out_figures, recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(PATHS$out_root, "reports"), recursive = TRUE, showWarnings = FALSE)
dir.create(PATHS$out_logs, recursive = TRUE, showWarnings = FALSE)

log_path <- file.path(PATHS$out_logs, "15_main_ivtr_qschool_access_parent_mean.log")
sink(log_path, split = TRUE)
on.exit(sink(), add = TRUE)

cat("15_main_ivtr_qschool_access_parent_mean.R\n")
cat("Started:", as.character(Sys.time()), "\n\n")

input_path <- file.path(PATHS$data_proc, "ivtr_ready_parent_educ_mean_qschool_access.rds")
if (!file.exists(input_path)) stop("Missing ", input_path)

search_files <- list.files(
  PATHS$R_scripts,
  pattern = "\\.R$",
  recursive = TRUE,
  full.names = TRUE
)
search_hits <- tibble(file = character(), line = integer(), text = character())
for (f in search_files) {
  txt <- readLines(f, warn = FALSE, encoding = "UTF-8")
  hit <- grep("Caner|Hansen|IVTR|threshold|gamma|grid|GMM", txt, ignore.case = FALSE)
  if (length(hit) > 0) {
    search_hits <- bind_rows(
      search_hits,
      tibble(file = f, line = hit, text = txt[hit])
    )
  }
}
exact_ch_found <- any(grepl("Caner.*Hansen|GMM", search_hits$text, ignore.case = TRUE)) &&
  any(grepl("feols\\(|ivreg\\(|gmm\\(", search_hits$text, ignore.case = TRUE)) &&
  any(grepl("gamma|threshold", search_hits$text, ignore.case = TRUE)) &&
  any(grepl("objective|Q\\(|GMM", search_hits$text, ignore.case = TRUE))

# The project contains design notes and planned filenames, but no completed
# exact Caner-Hansen GMM estimator to reuse.
exact_ch_found <- FALSE
method_note <- "Caner-Hansen-inspired IV threshold approximation"
objective_note <- "Weighted second-stage residual sum of squares; not full Caner-Hansen GMM inference."

cat("Exact Caner-Hansen implementation found:", exact_ch_found, "\n")
cat("Method:", method_note, "\n\n")

raw <- readRDS(input_path) |> as_tibble()
has_weight <- "hhweight" %in% names(raw)

required <- c(
  "lwage", "educ_years", "parent_educ_mean", "q_school_access",
  "age", "age2", "female", "married", "urban",
  "birth_aimag", "birth_cohort", "wave"
)
missing_required <- setdiff(required, names(raw))
if (length(missing_required) > 0) {
  stop("Missing required variable(s): ", paste(missing_required, collapse = ", "))
}

df <- raw |>
  mutate(
    lwage = as.numeric(lwage),
    educ_years = as.numeric(educ_years),
    parent_educ_mean = as.numeric(parent_educ_mean),
    q_school_access = as.numeric(q_school_access),
    age = as.numeric(age),
    age2 = as.numeric(age2),
    female = as.numeric(female),
    married = as.numeric(married),
    urban = as.numeric(urban),
    birth_aimag = as.factor(birth_aimag),
    birth_cohort = as.factor(birth_cohort),
    wave = as.factor(wave),
    hhweight = if (has_weight) as.numeric(hhweight) else 1
  ) |>
  filter(
    age >= 25, age <= 60,
    is.finite(lwage),
    !is.na(educ_years), is.finite(educ_years),
    !is.na(parent_educ_mean), is.finite(parent_educ_mean),
    !is.na(q_school_access), is.finite(q_school_access),
    !is.na(age), !is.na(age2),
    !is.na(female), !is.na(married), !is.na(urban),
    !is.na(birth_aimag),
    !is.na(birth_cohort),
    !is.na(wave)
  )

if (has_weight) {
  df <- df |> filter(!is.na(hhweight), is.finite(hhweight), hhweight > 0)
}

if (nrow(df) == 0) stop("No observations remain after IVTR sample cleaning.")

wts <- if (has_weight) ~hhweight else NULL
cluster_vcov <- ~birth_aimag

fmt <- function(x, digits = 4) ifelse(is.na(x), "NA", formatC(x, format = "f", digits = digits))
corr_pair <- function(x, y) suppressWarnings(cor(x, y, use = "pairwise.complete.obs"))

sample_diag <- tibble(
  N = nrow(df),
  q_school_access_min = min(df$q_school_access, na.rm = TRUE),
  q_school_access_p10 = as.numeric(quantile(df$q_school_access, 0.10, na.rm = TRUE, names = FALSE)),
  q_school_access_p25 = as.numeric(quantile(df$q_school_access, 0.25, na.rm = TRUE, names = FALSE)),
  q_school_access_p50 = as.numeric(quantile(df$q_school_access, 0.50, na.rm = TRUE, names = FALSE)),
  q_school_access_p75 = as.numeric(quantile(df$q_school_access, 0.75, na.rm = TRUE, names = FALSE)),
  q_school_access_p90 = as.numeric(quantile(df$q_school_access, 0.90, na.rm = TRUE, names = FALSE)),
  q_school_access_max = max(df$q_school_access, na.rm = TRUE),
  q_school_access_unique_values = n_distinct(df$q_school_access),
  corr_q_school_access_educ_years = corr_pair(df$q_school_access, df$educ_years),
  corr_q_school_access_parent_educ_mean = corr_pair(df$q_school_access, df$parent_educ_mean),
  n_birth_aimag_clusters = n_distinct(df$birth_aimag),
  n_birth_cohort_groups = n_distinct(df$birth_cohort),
  n_waves = n_distinct(df$wave)
)
write_csv(sample_diag, file.path(PATHS$out_tables, "T4_ivtr_qschool_access_sample_diagnostics.csv"))

capture_warnings <- function(expr) {
  notes <- character()
  value <- withCallingHandlers(
    expr,
    warning = function(w) {
      notes <<- c(notes, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )
  list(value = value, warnings = notes)
}

fit_feols <- function(fml, data) {
  args <- list(fml = fml, data = data, weights = wts, vcov = cluster_vcov, notes = FALSE)
  capture_warnings(do.call(feols, args))
}

extract_coef <- function(fit, pattern) {
  ct <- coeftable(fit)
  rn <- rownames(ct)
  term <- rn[grepl(pattern, rn, fixed = TRUE)][1]
  if (is.na(term) || length(term) == 0) {
    return(tibble(term = NA_character_, estimate = NA_real_, se = NA_real_, p_value = NA_real_))
  }
  tibble(
    term = term,
    estimate = unname(ct[term, "Estimate"]),
    se = unname(ct[term, "Std. Error"]),
    p_value = unname(ct[term, "Pr(>|t|)"])
  )
}

ols_fml <- lwage ~ educ_years + age + age2 + female + married + urban |
  birth_aimag + birth_cohort + wave
iv_fml <- lwage ~ age + age2 + female + married + urban |
  birth_aimag + birth_cohort + wave |
  educ_years ~ parent_educ_mean

ols_fit <- fit_feols(ols_fml, df)
iv_fit <- fit_feols(iv_fml, df)
ols_row <- extract_coef(ols_fit$value, "educ_years")
iv_row <- extract_coef(iv_fit$value, "fit_educ_years")

baseline_table <- tibble(
  model = c("OLS", "2SLS_parent_educ_mean"),
  N = c(nobs(ols_fit$value), nobs(iv_fit$value)),
  beta_educ_years = c(ols_row$estimate, iv_row$estimate),
  se = c(ols_row$se, iv_row$se),
  p_value = c(ols_row$p_value, iv_row$p_value),
  accepted_first_stage_clustered_wald_F = c(NA_real_, 558.45),
  weak_iv_flag = c(NA, FALSE),
  cluster = "birth_aimag",
  weights = ifelse(has_weight, "hhweight", "none")
)
write_csv(baseline_table, file.path(PATHS$out_tables, "T4_ivtr_qschool_access_baseline_ols_2sls.csv"))

q10 <- sample_diag$q_school_access_p10
q90 <- sample_diag$q_school_access_p90
candidates <- sort(unique(df$q_school_access[df$q_school_access >= q10 & df$q_school_access <= q90]))
if (length(candidates) > 200) {
  candidates <- seq(q10, q90, length.out = 200)
}

cat("Threshold candidates:", length(candidates), "\n")

get_regime_terms <- function(fit) {
  rn <- rownames(coeftable(fit))
  low <- rn[grepl("educ_low", rn, fixed = TRUE)][1]
  high <- rn[grepl("educ_high", rn, fixed = TRUE)][1]
  c(low = low, high = high)
}

objective_value <- function(fit, data) {
  r <- resid(fit)
  if (has_weight) {
    sum(data$hhweight * r^2, na.rm = TRUE)
  } else {
    sum(r^2, na.rm = TRUE)
  }
}

run_gamma <- function(gamma) {
  d <- df |>
    mutate(
      low = as.integer(q_school_access <= gamma),
      high = as.integer(q_school_access > gamma),
      educ_low = educ_years * low,
      educ_high = educ_years * high,
      iv_low = parent_educ_mean * low,
      iv_high = parent_educ_mean * high
    )

  warning_note <- character()
  fml <- lwage ~ age + age2 + female + married + urban |
    birth_aimag + birth_cohort + wave |
    educ_low + educ_high ~ iv_low + iv_high

  fit <- tryCatch(
    fit_feols(fml, d),
    error = function(e) e
  )

  if (inherits(fit, "error")) {
    return(tibble(
      gamma = gamma, N = nrow(d), N_low = sum(d$low), N_high = sum(d$high),
      beta_low = NA_real_, se_low = NA_real_, p_low = NA_real_,
      beta_high = NA_real_, se_high = NA_real_, p_high = NA_real_,
      objective_value = Inf,
      warning_flag = TRUE,
      warning_note = paste("estimation error:", conditionMessage(fit))
    ))
  }

  warning_note <- fit$warnings
  ct <- coeftable(fit$value)
  terms <- get_regime_terms(fit$value)
  missing_terms <- any(is.na(terms))
  if (missing_terms) {
    return(tibble(
      gamma = gamma, N = nrow(d), N_low = sum(d$low), N_high = sum(d$high),
      beta_low = NA_real_, se_low = NA_real_, p_low = NA_real_,
      beta_high = NA_real_, se_high = NA_real_, p_high = NA_real_,
      objective_value = Inf,
      warning_flag = TRUE,
      warning_note = paste(c(warning_note, "educ_low or educ_high coefficient missing"), collapse = " | ")
    ))
  }

  tibble(
    gamma = gamma,
    N = nrow(d),
    N_low = sum(d$low),
    N_high = sum(d$high),
    beta_low = unname(ct[terms["low"], "Estimate"]),
    se_low = unname(ct[terms["low"], "Std. Error"]),
    p_low = unname(ct[terms["low"], "Pr(>|t|)"]),
    beta_high = unname(ct[terms["high"], "Estimate"]),
    se_high = unname(ct[terms["high"], "Std. Error"]),
    p_high = unname(ct[terms["high"], "Pr(>|t|)"]),
    objective_value = objective_value(fit$value, d),
    warning_flag = length(warning_note) > 0,
    warning_note = ifelse(length(warning_note) > 0, paste(unique(warning_note), collapse = " | "), "")
  )
}

grid_table <- bind_rows(lapply(candidates, run_gamma)) |>
  arrange(objective_value)

write_csv(grid_table, file.path(PATHS$out_tables, "T4_ivtr_qschool_access_grid_search.csv"))

if (!any(is.finite(grid_table$objective_value))) stop("No valid threshold-grid estimates.")
gamma_hat <- grid_table$gamma[which.min(grid_table$objective_value)]

fit_final_ivtr <- function(gamma) {
  d <- df |>
    mutate(
      low = as.integer(q_school_access <= gamma),
      high = as.integer(q_school_access > gamma),
      educ_low = educ_years * low,
      educ_high = educ_years * high,
      iv_low = parent_educ_mean * low,
      iv_high = parent_educ_mean * high
    )
  fml <- lwage ~ age + age2 + female + married + urban |
    birth_aimag + birth_cohort + wave |
    educ_low + educ_high ~ iv_low + iv_high
  fit <- fit_feols(fml, d)
  list(data = d, fit = fit)
}

final_obj <- fit_final_ivtr(gamma_hat)
final_fit <- final_obj$fit$value
final_data <- final_obj$data
final_warnings <- final_obj$fit$warnings
final_ct <- coeftable(final_fit)
final_terms <- get_regime_terms(final_fit)

beta_low <- unname(final_ct[final_terms["low"], "Estimate"])
se_low <- unname(final_ct[final_terms["low"], "Std. Error"])
p_low <- unname(final_ct[final_terms["low"], "Pr(>|t|)"])
beta_high <- unname(final_ct[final_terms["high"], "Estimate"])
se_high <- unname(final_ct[final_terms["high"], "Std. Error"])
p_high <- unname(final_ct[final_terms["high"], "Pr(>|t|)"])
beta_diff <- beta_high - beta_low

final_results <- tibble(
  threshold_variable = "q_school_access",
  gamma_hat = gamma_hat,
  N = nrow(final_data),
  N_low = sum(final_data$low),
  N_high = sum(final_data$high),
  beta_low = beta_low,
  se_low = se_low,
  p_low = p_low,
  beta_high = beta_high,
  se_high = se_high,
  p_high = p_high,
  beta_difference_high_minus_low = beta_diff,
  method_note = method_note,
  warning_note = ifelse(length(final_warnings) > 0, paste(unique(final_warnings), collapse = " | "), "")
)
write_csv(final_results, file.path(PATHS$out_tables, "T4_ivtr_qschool_access_final_results.csv"))

wald_test <- function(fit, low_term, high_term, n_clusters) {
  b <- coef(fit)
  V <- vcov(fit)
  if (!all(c(low_term, high_term) %in% names(b))) {
    return(tibble(
      test = "beta_low = beta_high",
      beta_difference_high_minus_low = NA_real_,
      se_difference = NA_real_,
      t_stat = NA_real_,
      wald_F = NA_real_,
      df1 = 1,
      df2 = n_clusters - 1,
      p_value = NA_real_,
      method = "manual Wald test from clustered VCOV"
    ))
  }
  diff <- unname(b[high_term] - b[low_term])
  var_diff <- unname(V[high_term, high_term] + V[low_term, low_term] - 2 * V[high_term, low_term])
  se_diff <- sqrt(max(var_diff, 0))
  t_stat <- diff / se_diff
  F_stat <- t_stat^2
  df2 <- n_clusters - 1
  p <- pf(F_stat, df1 = 1, df2 = df2, lower.tail = FALSE)
  tibble(
    test = "beta_low = beta_high",
    beta_difference_high_minus_low = diff,
    se_difference = se_diff,
    t_stat = t_stat,
    wald_F = F_stat,
    df1 = 1,
    df2 = df2,
    p_value = p,
    method = "manual Wald test from clustered VCOV"
  )
}

threshold_test <- wald_test(
  final_fit,
  final_terms["low"],
  final_terms["high"],
  n_distinct(final_data$birth_aimag)
)
write_csv(threshold_test, file.path(PATHS$out_tables, "T4_ivtr_qschool_access_threshold_effect_test.csv"))

objective_plot <- grid_table |>
  filter(is.finite(objective_value)) |>
  ggplot(aes(x = gamma, y = objective_value)) +
  geom_line(color = "#2f5d62", linewidth = 0.7) +
  geom_vline(xintercept = gamma_hat, color = "#b33939", linewidth = 0.7) +
  labs(
    x = "q_school_access threshold candidate",
    y = "Weighted second-stage residual sum of squares",
    title = "q_school_access IV threshold objective grid"
  ) +
  theme_minimal(base_size = 11)

ggsave(
  filename = file.path(PATHS$out_figures, "ivtr_qschool_access_objective_grid.png"),
  plot = objective_plot,
  width = 7,
  height = 4.5,
  dpi = 300
)

regime_plot_data <- tibble(
  regime = c("Low q_school_access", "High q_school_access"),
  beta = c(beta_low, beta_high),
  se = c(se_low, se_high),
  N = c(sum(final_data$low), sum(final_data$high))
) |>
  mutate(
    ci_low = beta - 1.96 * se,
    ci_high = beta + 1.96 * se,
    regime = factor(regime, levels = c("Low q_school_access", "High q_school_access"))
  )

regime_plot <- regime_plot_data |>
  ggplot(aes(x = regime, y = beta)) +
  geom_hline(yintercept = 0, color = "grey70", linewidth = 0.4) +
  geom_pointrange(aes(ymin = ci_low, ymax = ci_high), color = "#2f5d62", linewidth = 0.8) +
  labs(
    x = NULL,
    y = "2SLS return to education",
    title = "Regime-specific education returns by q_school_access threshold"
  ) +
  theme_minimal(base_size = 11)

ggsave(
  filename = file.path(PATHS$out_figures, "ivtr_qschool_access_regime_returns.png"),
  plot = regime_plot,
  width = 6,
  height = 4.5,
  dpi = 300
)

threshold_interpretation <- if (!is.na(threshold_test$p_value) && threshold_test$p_value < 0.05) {
  "Education returns differ across q_school_access regimes in this approximation."
} else {
  "The regime point estimates differ numerically, but there is no strong evidence of threshold heterogeneity in education returns across q_school_access regimes."
}

report_lines <- c(
  "# Main IVTR: q_school_access Threshold with parent_educ_mean IV",
  "",
  paste0("Generated: ", Sys.time()),
  "",
  "## 1. Empirical Design",
  "- Outcome: `lwage`.",
  "- Endogenous regressor: `educ_years`.",
  "- Main IV: `parent_educ_mean`.",
  "- Threshold variable: `q_school_access`.",
  "- Controls: age, age2, female, married, urban.",
  "- Fixed effects: birth_aimag, birth_cohort, wave.",
  paste0("- Weights: ", ifelse(has_weight, "`hhweight`.", "none.")),
  "- Cluster: birth_aimag.",
  "",
  "## 2. Existing Caner-Hansen Implementation",
  paste0("- Exact implementation found: ", exact_ch_found),
  "",
  "## 3. Method Note",
  paste0("- Method: ", method_note, "."),
  paste0("- Objective: ", objective_note),
  "",
  "## 4. Accepted IV Diagnostics",
  "- `parent_educ_mean` is constructed from `father_educ_years` and `mother_educ_years` only.",
  "- It does not use `educ_years`.",
  "- Audited IVTR-ready sample first-stage clustered Wald F = 558.45.",
  "- Weak-IV flag = FALSE.",
  "",
  "## 5. q_school_access Diagnostics",
  paste0("- N: ", sample_diag$N),
  paste0("- min: ", fmt(sample_diag$q_school_access_min), ", p10: ", fmt(sample_diag$q_school_access_p10), ", p25: ", fmt(sample_diag$q_school_access_p25), ", p50: ", fmt(sample_diag$q_school_access_p50), ", p75: ", fmt(sample_diag$q_school_access_p75), ", p90: ", fmt(sample_diag$q_school_access_p90), ", max: ", fmt(sample_diag$q_school_access_max)),
  paste0("- unique values: ", sample_diag$q_school_access_unique_values),
  paste0("- corr(q_school_access, educ_years): ", fmt(sample_diag$corr_q_school_access_educ_years)),
  paste0("- corr(q_school_access, parent_educ_mean): ", fmt(sample_diag$corr_q_school_access_parent_educ_mean)),
  paste0("- birth_aimag clusters: ", sample_diag$n_birth_aimag_clusters, ", birth_cohort groups: ", sample_diag$n_birth_cohort_groups, ", waves: ", sample_diag$n_waves),
  "",
  "## 6. Baseline OLS and 2SLS",
  paste0("- OLS beta: ", fmt(ols_row$estimate), ", SE: ", fmt(ols_row$se), ", p-value: ", fmt(ols_row$p_value)),
  paste0("- 2SLS beta: ", fmt(iv_row$estimate), ", SE: ", fmt(iv_row$se), ", p-value: ", fmt(iv_row$p_value)),
  "",
  "## 7. gamma_hat",
  paste0("- gamma_hat: ", fmt(gamma_hat)),
  "",
  "## 8. Regime Sizes",
  paste0("- Low regime N: ", final_results$N_low),
  paste0("- High regime N: ", final_results$N_high),
  "",
  "## 9. Regime Returns",
  paste0("- beta_low: ", fmt(beta_low), ", SE: ", fmt(se_low), ", p-value: ", fmt(p_low)),
  paste0("- beta_high: ", fmt(beta_high), ", SE: ", fmt(se_high), ", p-value: ", fmt(p_high)),
  paste0("- beta_high - beta_low: ", fmt(beta_diff)),
  "",
  "## 10. Threshold Effect Test",
  paste0("- Wald F: ", fmt(threshold_test$wald_F), ", p-value: ", fmt(threshold_test$p_value), ", df: ", threshold_test$df1, ", ", threshold_test$df2),
  "",
  "## 11. Interpretation",
  threshold_interpretation,
  "This should not be read as q_school_access causing wage returns.",
  "",
  "## 12. Caveats",
  "- This is not a full Caner-Hansen GMM implementation or nonstandard threshold inference.",
  "- Parental education may affect wages through family background, networks, and unobserved ability channels.",
  "- q_school_access is treated as a threshold proxy; if it reflects current household conditions, interpretation should be cautious.",
  "- The threshold search uses an in-sample weighted RSS objective, so threshold-effect inference is approximate."
)

writeLines(report_lines, file.path(PATHS$out_root, "reports", "main_ivtr_qschool_access_parent_mean_summary.md"), useBytes = TRUE)

cat("Sample diagnostics:\n")
print(sample_diag)
cat("\nBaseline:\n")
print(baseline_table)
cat("\nGamma hat:", gamma_hat, "\n")
cat("\nFinal IVTR:\n")
print(final_results)
cat("\nThreshold effect test:\n")
print(threshold_test)
cat("\nCompleted:", as.character(Sys.time()), "\n")
