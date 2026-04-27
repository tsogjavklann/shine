# Stage 16C: Caner-Hansen-style two-step GMM slope estimation at gamma_hat.

options(warn = 1, encoding = "UTF-8")

source(here::here("R", "paths.R"))
suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(tibble)
  library(ggplot2)
})

dir.create(PATHS$out_tables, recursive = TRUE, showWarnings = FALSE)
dir.create(PATHS$out_figures, recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(PATHS$out_root, "reports"), recursive = TRUE, showWarnings = FALSE)
dir.create(PATHS$out_logs, recursive = TRUE, showWarnings = FALSE)

log_path <- file.path(PATHS$out_logs, "16c_ch_gmm_slope_qschool_access.log")
sink(log_path, split = TRUE)
on.exit(sink(), add = TRUE)

cat("16c_ch_gmm_slope_qschool_access.R\n")
cat("Started:", as.character(Sys.time()), "\n\n")

data_path <- file.path(PATHS$data_proc, "ch_residualized_qschool_access_parent_mean.rds")
gamma_path <- file.path(PATHS$out_tables, "T5b_ch_gamma_hat.csv")
if (!file.exists(data_path)) stop("Missing ", data_path, ". Run Stage 16A first.")
if (!file.exists(gamma_path)) stop("Missing ", gamma_path, ". Run Stage 16B first.")

df <- readRDS(data_path) |> as_tibble()
gamma_tbl <- read_csv(gamma_path, show_col_types = FALSE)
gamma_hat <- as.numeric(gamma_tbl$gamma_hat[1])
if (!is.finite(gamma_hat)) stop("Invalid gamma_hat in ", gamma_path)

has_weight <- "hhweight" %in% names(df)
required <- c(
  "lwage_r", "educ_years_r", "parent_educ_mean_r", "q_school_access",
  "age_r", "age2_r", "female_r", "married_r", "urban_r",
  "birth_aimag"
)
missing_required <- setdiff(required, names(df))
if (length(missing_required) > 0) {
  stop("Missing required variable(s): ", paste(missing_required, collapse = ", "))
}

df <- df |>
  mutate(
    lwage_r = as.numeric(lwage_r),
    educ_years_r = as.numeric(educ_years_r),
    parent_educ_mean_r = as.numeric(parent_educ_mean_r),
    q_school_access = as.numeric(q_school_access),
    age_r = as.numeric(age_r),
    age2_r = as.numeric(age2_r),
    female_r = as.numeric(female_r),
    married_r = as.numeric(married_r),
    urban_r = as.numeric(urban_r),
    birth_aimag = as.factor(birth_aimag),
    hhweight = if (has_weight) as.numeric(hhweight) else 1
  ) |>
  filter(
    is.finite(lwage_r),
    is.finite(educ_years_r),
    is.finite(parent_educ_mean_r),
    is.finite(q_school_access),
    is.finite(age_r),
    is.finite(age2_r),
    is.finite(female_r),
    is.finite(married_r),
    is.finite(urban_r),
    !is.na(birth_aimag)
  )

if (has_weight) {
  df <- df |> filter(is.finite(hhweight), hhweight > 0)
}

if (nrow(df) == 0) stop("No observations remain after loading residualized data.")

df <- df |>
  mutate(
    low = as.integer(q_school_access <= gamma_hat),
    high = as.integer(q_school_access > gamma_hat)
  )

y <- as.numeric(df$lwage_r)
x <- as.numeric(df$educ_years_r)
z <- as.numeric(df$parent_educ_mean_r)
controls <- as.matrix(df |> select(age_r, age2_r, female_r, married_r, urban_r))
X <- cbind(
  educ_low = x * df$low,
  educ_high = x * df$high,
  controls
)
Z <- cbind(
  iv_low = z * df$low,
  iv_high = z * df$high,
  controls
)

n <- nrow(df)
k <- ncol(X)
clusters <- df$birth_aimag
n_clusters <- n_distinct(clusters)
w <- if (has_weight) as.numeric(df$hhweight) else rep(1, n)
sqrt_w <- sqrt(w)

# Weighted GMM is implemented by transforming y, X, and Z by sqrt(hhweight).
yw <- y * sqrt_w
Xw <- X * sqrt_w
Zw <- Z * sqrt_w

safe_solve <- function(M) {
  tryCatch(solve(M), error = function(e) NULL)
}

rank_X <- qr(Xw)$rank
rank_Z <- qr(Zw)$rank
ZtZ <- crossprod(Zw)
rank_ZtZ <- qr(ZtZ)$rank
rank_XZ <- qr(crossprod(Xw, Zw))$rank
condition_ZtZ <- tryCatch(kappa(ZtZ, exact = TRUE), error = function(e) NA_real_)

W0 <- safe_solve(ZtZ / n)
if (is.null(W0)) stop("Initial W0 = solve((Z'Z)/n) failed.")

gmm_estimate <- function(W) {
  A_left <- crossprod(Xw, Zw) %*% W %*% crossprod(Zw, Xw)
  A_right <- crossprod(Xw, Zw) %*% W %*% crossprod(Zw, yw)
  beta <- safe_solve(A_left)
  if (is.null(beta)) return(NULL)
  as.numeric(beta %*% A_right)
}

beta_gmm1 <- gmm_estimate(W0)
if (is.null(beta_gmm1)) stop("Initial GMM estimate failed.")
u1 <- as.numeric(yw - Xw %*% beta_gmm1)

moment_i <- Zw * as.numeric(u1)
S_robust <- crossprod(moment_i) / n

cluster_levels <- levels(droplevels(clusters))
cluster_moments <- matrix(0, nrow = length(cluster_levels), ncol = ncol(Zw))
for (j in seq_along(cluster_levels)) {
  idx <- clusters == cluster_levels[j]
  cluster_moments[j, ] <- colSums(moment_i[idx, , drop = FALSE])
}
S_cluster <- crossprod(cluster_moments) / n

S_robust_inv <- safe_solve(S_robust)
S_cluster_inv <- safe_solve(S_cluster)
condition_S_robust <- tryCatch(kappa(S_robust, exact = TRUE), error = function(e) NA_real_)
condition_S_cluster <- tryCatch(kappa(S_cluster, exact = TRUE), error = function(e) NA_real_)

warning_notes <- character()
if (is.null(S_cluster_inv)) {
  warning_notes <- c(warning_notes, "S_cluster singular; using heteroskedastic-robust S")
}
if (!is.null(S_cluster_inv) && is.finite(condition_S_cluster) && condition_S_cluster > 1e10) {
  warning_notes <- c(warning_notes, "S_cluster high condition number > 1e10; using heteroskedastic-robust S")
  S_cluster_inv <- NULL
}
if (is.null(S_robust_inv)) {
  warning_notes <- c(warning_notes, "S_robust singular")
}

if (!is.null(S_cluster_inv)) {
  S_main <- S_cluster
  W1 <- S_cluster_inv
  weighting_matrix_used <- "cluster-robust S by birth_aimag"
  inference_reference <- paste0("t distribution with df=", n_clusters - 1)
  p_fun <- function(t) 2 * pt(abs(t), df = n_clusters - 1, lower.tail = FALSE)
} else if (!is.null(S_robust_inv)) {
  S_main <- S_robust
  W1 <- S_robust_inv
  weighting_matrix_used <- "heteroskedastic-robust S"
  inference_reference <- "normal approximation"
  p_fun <- function(t) 2 * pnorm(abs(t), lower.tail = FALSE)
} else {
  stop("Both cluster and robust moment covariance matrices are singular.")
}

beta_gmm2 <- gmm_estimate(W1)
if (is.null(beta_gmm2)) stop("Two-step GMM estimate failed.")
u2 <- as.numeric(yw - Xw %*% beta_gmm2)

A <- crossprod(Zw, Xw) / n
B <- t(A) %*% W1 %*% A
condition_XZWZX <- tryCatch(kappa(B, exact = TRUE), error = function(e) NA_real_)
B_inv <- safe_solve(B)
if (is.null(B_inv)) stop("GMM bread matrix is singular.")

V <- B_inv %*% t(A) %*% W1 %*% S_main %*% W1 %*% A %*% B_inv / n
se <- sqrt(pmax(diag(V), 0))
t_stats <- beta_gmm2 / se
p_values <- p_fun(t_stats)

coef_names <- colnames(X)
coef_table <- tibble(
  term = coef_names,
  estimate = beta_gmm2,
  se = se,
  t_stat = t_stats,
  p_value = p_values,
  inference_reference = inference_reference,
  weighting_matrix_used = weighting_matrix_used
)

beta_low <- coef_table$estimate[coef_table$term == "educ_low"]
beta_high <- coef_table$estimate[coef_table$term == "educ_high"]
beta_diff <- beta_high - beta_low

R <- matrix(0, nrow = 1, ncol = k)
colnames(R) <- coef_names
R[1, "educ_high"] <- 1
R[1, "educ_low"] <- -1
var_diff <- as.numeric(R %*% V %*% t(R))
se_diff <- sqrt(max(var_diff, 0))
t_diff <- beta_diff / se_diff
wald_stat <- t_diff^2
wald_p <- if (weighting_matrix_used == "cluster-robust S by birth_aimag") {
  pf(wald_stat, df1 = 1, df2 = n_clusters - 1, lower.tail = FALSE)
} else {
  pchisq(wald_stat, df = 1, lower.tail = FALSE)
}

rank_XZWZX <- qr(B)$rank
near_singular_warning <- any(c(
  rank_X < k,
  rank_Z < ncol(Z),
  rank_ZtZ < ncol(Z),
  rank_XZ < k,
  rank_XZWZX < k,
  is.finite(condition_ZtZ) && condition_ZtZ > 1e8,
  is.finite(condition_XZWZX) && condition_XZWZX > 1e8
))
if (near_singular_warning) {
  warning_notes <- c(warning_notes, "high condition number or rank warning in GMM matrices")
}

matrix_diag <- tibble(
  gamma_hat = gamma_hat,
  N = n,
  N_low = sum(df$low),
  N_high = sum(df$high),
  rank_X = rank_X,
  rank_Z = rank_Z,
  rank_ZtZ = rank_ZtZ,
  rank_XZ = rank_XZ,
  rank_XZWZX = rank_XZWZX,
  condition_number_ZtZ = condition_ZtZ,
  condition_number_S_robust = condition_S_robust,
  condition_number_S_cluster = condition_S_cluster,
  condition_number_XZ_W_ZX = condition_XZWZX,
  S_cluster_invertible = !is.null(safe_solve(S_cluster)),
  S_robust_invertible = !is.null(safe_solve(S_robust)),
  near_singular_warning = near_singular_warning,
  warning_note = paste(unique(warning_notes), collapse = " | ")
)

final_results <- coef_table |>
  filter(term %in% c("educ_low", "educ_high")) |>
  transmute(
    gamma_hat = gamma_hat,
    term,
    estimate,
    se,
    t_stat,
    p_value,
    N = n,
    N_low = sum(df$low),
    N_high = sum(df$high),
    weighting_matrix_used,
    inference_reference,
    beta_difference_high_minus_low = beta_diff,
    warning_note = paste(unique(warning_notes), collapse = " | ")
  )

wald_test <- tibble(
  gamma_hat = gamma_hat,
  test = "beta_low_GMM = beta_high_GMM",
  beta_difference_high_minus_low = beta_diff,
  se_difference = se_diff,
  t_stat = t_diff,
  wald_statistic = wald_stat,
  p_value = wald_p,
  df1 = 1,
  df2 = ifelse(weighting_matrix_used == "cluster-robust S by birth_aimag", n_clusters - 1, NA_real_),
  inference_reference = ifelse(weighting_matrix_used == "cluster-robust S by birth_aimag", "F(1, G-1)", "chi-square(1)"),
  weighting_matrix_used = weighting_matrix_used
)

comparison <- gamma_tbl |>
  transmute(
    gamma_hat,
    beta_low_2sls,
    beta_high_2sls
  ) |>
  mutate(
    beta_low_GMM = beta_low,
    beta_high_GMM = beta_high,
    beta_diff_GMM_high_minus_low = beta_diff,
    inference_method = paste0("two-step GMM, ", weighting_matrix_used, ", ", inference_reference)
  )

write_csv(matrix_diag, file.path(PATHS$out_tables, "T5c_ch_gmm_matrix_diagnostics.csv"))
write_csv(final_results, file.path(PATHS$out_tables, "T5c_ch_gmm_final_results.csv"))
write_csv(wald_test, file.path(PATHS$out_tables, "T5c_ch_gmm_wald_test.csv"))
write_csv(comparison, file.path(PATHS$out_tables, "T5c_ch_2sls_vs_gmm_comparison.csv"))

plot_data <- final_results |>
  mutate(
    regime = recode(term, educ_low = "Low q_school_access", educ_high = "High q_school_access"),
    ci_low = estimate - 1.96 * se,
    ci_high = estimate + 1.96 * se,
    regime = factor(regime, levels = c("Low q_school_access", "High q_school_access"))
  )

g <- ggplot(plot_data, aes(x = regime, y = estimate)) +
  geom_hline(yintercept = 0, color = "grey70", linewidth = 0.4) +
  geom_pointrange(aes(ymin = ci_low, ymax = ci_high), color = "#2f5d62", linewidth = 0.8) +
  labs(
    x = NULL,
    y = "Two-step GMM return to education",
    title = "Stage 16C GMM regime-specific education returns"
  ) +
  theme_minimal(base_size = 11)

ggsave(
  filename = file.path(PATHS$out_figures, "full_ch_stage16c_gmm_regime_returns.png"),
  plot = g,
  width = 6,
  height = 4.5,
  dpi = 300
)

safe_stage16d <- !near_singular_warning &&
  all(is.finite(final_results$estimate)) &&
  all(is.finite(final_results$se)) &&
  is.finite(wald_test$p_value)

decision <- if (safe_stage16d) {
  "Proceed to Stage 16D bootstrap inference."
} else {
  "Proceed to Stage 16D only with numerical caution; review matrix warnings first."
}

fmt <- function(x, digits = 4) ifelse(is.na(x), "NA", formatC(x, format = "f", digits = digits))

report_lines <- c(
  "# Stage 16C: GMM Slope Estimation at q_school_access gamma_hat",
  "",
  paste0("Generated: ", Sys.time()),
  "",
  "## 1. gamma_hat Used",
  paste0("- gamma_hat: ", fmt(gamma_hat)),
  "",
  "## 2. GMM Method",
  "- Residualized variables from Stage 16A are used.",
  "- Regime interactions are formed at the Stage 16B threshold.",
  "- First-step GMM uses W0 = solve((Z'Z)/n).",
  "- Second-step GMM uses the inverse moment covariance matrix.",
  paste0("- Main weighting matrix: ", weighting_matrix_used),
  "",
  "## 3. Matrix Diagnostics",
  paste0("- N: ", n),
  paste0("- N_low: ", sum(df$low)),
  paste0("- N_high: ", sum(df$high)),
  paste0("- rank(X): ", rank_X),
  paste0("- rank(Z): ", rank_Z),
  paste0("- rank(Z'Z): ", rank_ZtZ),
  paste0("- rank(X'Z): ", rank_XZ),
  paste0("- condition number Z'Z: ", fmt(condition_ZtZ)),
  paste0("- condition number X'Z W Z'X: ", fmt(condition_XZWZX)),
  paste0("- near-singular warning: ", near_singular_warning),
  "",
  "## 4. GMM Regime Slopes",
  paste0("- beta_low_GMM: ", fmt(beta_low), ", SE: ", fmt(final_results$se[final_results$term == "educ_low"]), ", p-value: ", fmt(final_results$p_value[final_results$term == "educ_low"])),
  paste0("- beta_high_GMM: ", fmt(beta_high), ", SE: ", fmt(final_results$se[final_results$term == "educ_high"]), ", p-value: ", fmt(final_results$p_value[final_results$term == "educ_high"])),
  paste0("- beta_high - beta_low: ", fmt(beta_diff)),
  "",
  "## 5. Wald Test",
  paste0("- Wald statistic: ", fmt(wald_stat)),
  paste0("- p-value: ", fmt(wald_p)),
  paste0("- inference reference: ", wald_test$inference_reference),
  "",
  "## 6. Comparison with Stage 16B 2SLS Slopes",
  paste0("- beta_low_2SLS: ", fmt(comparison$beta_low_2sls), " vs beta_low_GMM: ", fmt(comparison$beta_low_GMM)),
  paste0("- beta_high_2SLS: ", fmt(comparison$beta_high_2sls), " vs beta_high_GMM: ", fmt(comparison$beta_high_GMM)),
  "",
  "## 7. Numerical Warnings",
  if (length(warning_notes) == 0) "- No numerical warnings recorded." else paste0("- ", unique(warning_notes)),
  "",
  "## 8. Decision",
  decision,
  "",
  "## 9. Caveats",
  "- Do not call this the final full result until Stage 16D bootstrap/inference is complete.",
  "- Parental education may affect wages through family background, networks, and unobserved ability channels.",
  "- q_school_access threshold exogeneity remains an identifying assumption.",
  "- Stage 16C did not run bootstrap inference."
)

writeLines(report_lines, file.path(PATHS$out_root, "reports", "ch_stage16c_gmm_slope_estimation.md"), useBytes = TRUE)

cat("Matrix diagnostics:\n")
print(matrix_diag)
cat("\nFinal GMM results:\n")
print(final_results)
cat("\nWald test:\n")
print(wald_test)
cat("\nComparison:\n")
print(comparison)
cat("\nDecision:", decision, "\n")
cat("\nCompleted:", as.character(Sys.time()), "\n")
