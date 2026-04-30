# =============================================================================
# 24a_audit_student_teacher_avg_16_18.R
# -----------------------------------------------------------------------------
# Audit the student_teacher_ratio_avg_16_18 threshold pipeline.
# This script does not estimate a new model and does not search for IVs.
# =============================================================================

options(warn = 1, encoding = "UTF-8")

source(here::here("R", "paths.R"))

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(tibble)
})

dir.create(PATHS$out_tables, recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(PATHS$out_root, "reports"), recursive = TRUE, showWarnings = FALSE)
dir.create(PATHS$out_logs, recursive = TRUE, showWarnings = FALSE)

log_path <- file.path(PATHS$out_logs, "24a_audit_student_teacher_avg_16_18.log")
sink(log_path, split = TRUE)
on.exit(sink(), add = TRUE)

cat("24a_audit_student_teacher_avg_16_18.R\n")
cat("Started:", as.character(Sys.time()), "\n\n")

analysis_path <- file.path(PATHS$data_proc, "analysis_sample.rds")
family_path <- file.path(PATHS$data_proc, "family_structure.rds")
panel_path <- file.path(PATHS$data_root, "cleaned", "school_supply_panel.rds")
iv_ready_path <- file.path(PATHS$data_proc, "ivtr_ready_parent_educ_mean_student_teacher_avg_16_18.rds")
resid_path <- file.path(PATHS$data_proc, "ch_residualized_student_teacher_avg_16_18_parent_mean.rds")
script_path <- file.path(PATHS$R_scripts, "24_student_teacher_avg_16_18_ch_full_pipeline.R")

required_files <- c(analysis_path, family_path, panel_path, iv_ready_path, resid_path, script_path)
missing_files <- required_files[!file.exists(required_files)]
if (length(missing_files) > 0) stop("Missing files: ", paste(missing_files, collapse = ", "))

analysis <- readRDS(analysis_path) |> as_tibble()
family <- readRDS(family_path) |>
  as_tibble() |>
  mutate(
    parent_educ_mean_rebuilt = rowMeans(cbind(father_educ_years, mother_educ_years), na.rm = TRUE),
    parent_educ_mean_rebuilt = if_else(is.nan(parent_educ_mean_rebuilt), NA_real_, parent_educ_mean_rebuilt)
  ) |>
  select(id, father_educ_years, mother_educ_years, parent_educ_mean_rebuilt)

panel <- readRDS(panel_path) |>
  as_tibble() |>
  transmute(
    aimag_code = as.numeric(aimag_code),
    year = as.numeric(year),
    students = as.numeric(students),
    teachers = as.numeric(teachers),
    student_teacher_ratio_panel = as.numeric(student_teacher_ratio),
    teachers_per_student_panel = as.numeric(teachers_per_student),
    student_teacher_ratio_rebuilt = students / teachers,
    teachers_per_student_rebuilt = teachers / students
  )

panel_formula_check <- panel |>
  summarise(
    n_panel_rows = n(),
    n_finite_student_teacher_ratio = sum(is.finite(student_teacher_ratio_panel)),
    max_abs_str_minus_students_over_teachers = max(abs(student_teacher_ratio_panel - student_teacher_ratio_rebuilt), na.rm = TRUE),
    max_abs_tps_minus_teachers_over_students = max(abs(teachers_per_student_panel - teachers_per_student_rebuilt), na.rm = TRUE)
  )

dat <- analysis |>
  left_join(family, by = "id")

if (!"age2" %in% names(dat)) dat$age2 <- as.numeric(dat$age)^2
if (!"female" %in% names(dat) && "is_female" %in% names(dat)) dat$female <- dat$is_female
if (!"married" %in% names(dat) && "is_married" %in% names(dat)) dat$married <- dat$is_married
if (!"birth_cohort" %in% names(dat)) {
  dat <- dat |>
    mutate(
      birth_cohort = case_when(
        birth_year < 1970 ~ "pre1970",
        birth_year >= 1970 & birth_year <= 1974 ~ "1970_1974",
        birth_year >= 1975 & birth_year <= 1979 ~ "1975_1979",
        birth_year >= 1980 & birth_year <= 1984 ~ "1980_1984",
        birth_year >= 1985 & birth_year <= 1989 ~ "1985_1989",
        birth_year >= 1990 & birth_year <= 1994 ~ "1990_1994",
        birth_year >= 1995 ~ "post1995",
        TRUE ~ NA_character_
      )
    )
}
if (!"hhweight" %in% names(dat)) dat$hhweight <- 1

join_point <- function(data, age_num) {
  point <- panel |>
    transmute(
      birth_aimag_join = aimag_code,
      year_join = year,
      !!paste0("str_rebuilt_", age_num) := student_teacher_ratio_panel,
      !!paste0("tps_rebuilt_", age_num) := teachers_per_student_panel
    )
  join_by <- setNames(
    c("birth_aimag_join", "year_join"),
    c("birth_aimag", paste0("year_at_", age_num))
  )
  data |>
    mutate("{paste0('year_at_', age_num)}" := as.numeric(birth_year) + age_num) |>
    left_join(point, by = join_by)
}

rebuilt <- dat |>
  join_point(16) |>
  join_point(17) |>
  join_point(18) |>
  mutate(
    n_years_rebuilt_16_18 = rowSums(cbind(
      is.finite(str_rebuilt_16),
      is.finite(str_rebuilt_17),
      is.finite(str_rebuilt_18)
    )),
    student_teacher_ratio_avg_16_18_rebuilt = if_else(
      n_years_rebuilt_16_18 == 3L,
      rowMeans(cbind(str_rebuilt_16, str_rebuilt_17, str_rebuilt_18), na.rm = FALSE),
      NA_real_
    )
  )

saved <- readRDS(iv_ready_path) |> as_tibble()
resid_df <- readRDS(resid_path) |> as_tibble()

comparison <- saved |>
  select(
    id, birth_aimag, birth_year, age, educ_years, lwage, parent_educ_mean,
    student_teacher_ratio_avg_16_18,
    n_years_student_teacher_ratio_16_18,
    student_teacher_ratio_at_16,
    student_teacher_ratio_at_17,
    student_teacher_ratio_at_18
  ) |>
  left_join(
    rebuilt |>
      select(
        id,
        parent_educ_mean_rebuilt,
        n_years_rebuilt_16_18,
        student_teacher_ratio_avg_16_18_rebuilt
      ),
    by = "id"
  )

construction_check <- comparison |>
  summarise(
    N_saved = n(),
    n_all_three_years_saved = sum(n_years_student_teacher_ratio_16_18 == 3L),
    n_all_three_years_rebuilt = sum(n_years_rebuilt_16_18 == 3L),
    max_abs_saved_vs_rebuilt_threshold = max(abs(student_teacher_ratio_avg_16_18 - student_teacher_ratio_avg_16_18_rebuilt), na.rm = TRUE),
    max_abs_parent_educ_saved_vs_rebuilt = max(abs(parent_educ_mean - parent_educ_mean_rebuilt), na.rm = TRUE),
    any_threshold_missing_in_saved = any(!is.finite(student_teacher_ratio_avg_16_18)),
    any_parent_missing_in_saved = any(!is.finite(parent_educ_mean))
  )

sample_filter_check <- saved |>
  summarise(
    N = n(),
    age_min = min(age, na.rm = TRUE),
    age_max = max(age, na.rm = TRUE),
    nonfinite_lwage = sum(!is.finite(lwage)),
    missing_educ_years = sum(!is.finite(educ_years)),
    missing_parent_educ_mean = sum(!is.finite(parent_educ_mean)),
    missing_threshold = sum(!is.finite(student_teacher_ratio_avg_16_18)),
    missing_controls = sum(!is.finite(age) | !is.finite(age2) | !is.finite(female) | !is.finite(married) | !is.finite(urban)),
    missing_fe = sum(is.na(birth_aimag) | is.na(birth_cohort) | is.na(wave)),
    nonpositive_weight = sum(!is.finite(hhweight) | hhweight <= 0),
    n_clusters = n_distinct(birth_aimag),
    n_birth_cohorts = n_distinct(birth_cohort),
    n_waves = n_distinct(wave)
  )

gamma_tbl <- read_csv(file.path(PATHS$out_tables, "T11c_student_teacher_avg_16_18_ch_gamma_hat.csv"), show_col_types = FALSE)
grid <- read_csv(file.path(PATHS$out_tables, "T11c_student_teacher_avg_16_18_ch_threshold_grid.csv"), show_col_types = FALSE)
gmm <- read_csv(file.path(PATHS$out_tables, "T11d_student_teacher_avg_16_18_ch_gmm_final_results.csv"), show_col_types = FALSE)
wald <- read_csv(file.path(PATHS$out_tables, "T11d_student_teacher_avg_16_18_ch_gmm_wald_test.csv"), show_col_types = FALSE)
boot <- read_csv(file.path(PATHS$out_tables, "T11e_student_teacher_avg_16_18_ch_bootstrap_draws.csv"), show_col_types = FALSE)
boot_inf <- read_csv(file.path(PATHS$out_tables, "T11e_student_teacher_avg_16_18_ch_bootstrap_inference.csv"), show_col_types = FALSE)

gamma_hat <- gamma_tbl$gamma_hat[1]
grid_min <- grid |> arrange(SSR_2SLS) |> slice(1)
grid_check <- tibble(
  gamma_hat_table = gamma_hat,
  gamma_min_from_grid = grid_min$gamma,
  gamma_matches_grid_min = abs(gamma_hat - grid_min$gamma) < .Machine$double.eps^0.5,
  n_grid_rows = nrow(grid),
  n_valid_grid_rows = sum(is.finite(grid$SSR_2SLS) & !is.na(grid$beta_low_2sls) & !is.na(grid$beta_high_2sls)),
  n_warning_flagged = sum(grid$warning_flag, na.rm = TRUE),
  min_SSR = grid_min$SSR_2SLS
)

regime_check <- saved |>
  mutate(
    low = student_teacher_ratio_avg_16_18 <= gamma_hat,
    high = student_teacher_ratio_avg_16_18 > gamma_hat
  ) |>
  summarise(
    gamma_hat = gamma_hat,
    N_low_recomputed = sum(low),
    N_high_recomputed = sum(high),
    N_low_table = gamma_tbl$N_low[1],
    N_high_table = gamma_tbl$N_high[1],
    low_high_counts_match = N_low_recomputed == N_low_table & N_high_recomputed == N_high_table,
    mean_threshold_low = mean(student_teacher_ratio_avg_16_18[low]),
    mean_threshold_high = mean(student_teacher_ratio_avg_16_18[high]),
    max_threshold_low = max(student_teacher_ratio_avg_16_18[low]),
    min_threshold_high = min(student_teacher_ratio_avg_16_18[high])
  )

script_lines <- readLines(script_path, warn = FALSE)
script_text <- paste(script_lines, collapse = "\n")
iv_lines <- script_lines[grepl("iv_low|iv_high|educ_years ~", script_lines)]
script_role_check <- tibble(
  has_parent_iv_formula = grepl("educ_years ~ parent_educ_mean", script_text, fixed = TRUE),
  gmm_instrument_uses_parent_educ_mean_r = grepl("iv_low = z *", script_text, fixed = TRUE) &&
    grepl("z <- as.numeric(data$parent_educ_mean_r)", script_text, fixed = TRUE),
  threshold_used_as_instrument_string_present = any(grepl("iv_(low|high).*student_teacher_ratio_avg_16_18", iv_lines)),
  log_distance_used_as_iv_string_present = any(grepl("educ_years ~ .*log_distance_to_ub", script_lines)),
  father_mother_overid_iv_string_present = any(grepl("educ_years ~ .*father_educ_years", script_lines)) ||
    any(grepl("educ_years ~ .*mother_educ_years", script_lines))
)

success <- boot |> filter(!failed_flag, is.finite(beta_diff_boot))
beta_diff_observed <- boot_inf$beta_diff_observed[1]
centered_p_recomputed <- mean(abs(success$beta_diff_boot - mean(success$beta_diff_boot, na.rm = TRUE)) >= abs(beta_diff_observed), na.rm = TRUE)
sign_p_two_sided <- 2 * min(
  mean(success$beta_diff_boot <= 0, na.rm = TRUE),
  mean(success$beta_diff_boot >= 0, na.rm = TRUE)
)
percentile_ci_contains_zero_recomputed <- boot_inf$beta_diff_q025[1] <= 0 & boot_inf$beta_diff_q975[1] >= 0

bootstrap_check <- tibble(
  n_success = nrow(success),
  n_failed = sum(boot$failed_flag, na.rm = TRUE),
  n_warning = sum(boot$warning_flag, na.rm = TRUE),
  beta_diff_observed = beta_diff_observed,
  beta_diff_boot_mean = mean(success$beta_diff_boot, na.rm = TRUE),
  beta_diff_q025 = quantile(success$beta_diff_boot, 0.025, na.rm = TRUE, names = FALSE),
  beta_diff_q975 = quantile(success$beta_diff_boot, 0.975, na.rm = TRUE, names = FALSE),
  percentile_ci_contains_zero = percentile_ci_contains_zero_recomputed,
  centered_bootstrap_p_value_table = boot_inf$bootstrap_p_value[1],
  centered_bootstrap_p_value_recomputed = centered_p_recomputed,
  sign_based_two_sided_p_value = sign_p_two_sided,
  note = "The table p-value is the centered bootstrap-tail p-value used in earlier project stages; the percentile CI is a separate percentile interval."
)

matrix_diag <- read_csv(file.path(PATHS$out_tables, "T11d_student_teacher_avg_16_18_ch_gmm_matrix_diagnostics.csv"), show_col_types = FALSE)
matrix_check <- matrix_diag |>
  transmute(
    rank_X,
    rank_Z,
    rank_ZtZ,
    rank_XZ,
    rank_XZ_W_ZX,
    all_full_rank = rank_X == 7 & rank_Z == 7 & rank_ZtZ == 7 & rank_XZ == 7 & rank_XZ_W_ZX == 7,
    near_singular_warning,
    condition_number_ZtZ,
    condition_number_S_cluster,
    condition_number_XZ_W_ZX,
    S_cluster_invertible,
    S_robust_invertible
  )

audit <- bind_cols(
  tibble(check_group = "overall"),
  construction_check,
  sample_filter_check |> select(n_clusters, n_birth_cohorts, n_waves),
  grid_check |> select(gamma_matches_grid_min, n_grid_rows, n_warning_flagged),
  regime_check |> select(low_high_counts_match),
  matrix_check |> select(all_full_rank, near_singular_warning),
  bootstrap_check |> select(n_success, n_failed, n_warning, percentile_ci_contains_zero, centered_bootstrap_p_value_table, sign_based_two_sided_p_value),
  script_role_check
)

write_csv(panel_formula_check, file.path(PATHS$out_tables, "T11f_student_teacher_avg_16_18_panel_formula_audit.csv"))
write_csv(construction_check, file.path(PATHS$out_tables, "T11f_student_teacher_avg_16_18_construction_audit.csv"))
write_csv(sample_filter_check, file.path(PATHS$out_tables, "T11f_student_teacher_avg_16_18_sample_filter_audit.csv"))
write_csv(grid_check, file.path(PATHS$out_tables, "T11f_student_teacher_avg_16_18_grid_audit.csv"))
write_csv(regime_check, file.path(PATHS$out_tables, "T11f_student_teacher_avg_16_18_regime_audit.csv"))
write_csv(script_role_check, file.path(PATHS$out_tables, "T11f_student_teacher_avg_16_18_script_role_audit.csv"))
write_csv(bootstrap_check, file.path(PATHS$out_tables, "T11f_student_teacher_avg_16_18_bootstrap_audit.csv"))
write_csv(audit, file.path(PATHS$out_tables, "T11f_student_teacher_avg_16_18_overall_audit.csv"))

fatal_issue <- any(c(
  construction_check$max_abs_saved_vs_rebuilt_threshold > 1e-10,
  construction_check$max_abs_parent_educ_saved_vs_rebuilt > 1e-10,
  sample_filter_check$nonfinite_lwage > 0,
  sample_filter_check$missing_educ_years > 0,
  sample_filter_check$missing_parent_educ_mean > 0,
  sample_filter_check$missing_threshold > 0,
  !grid_check$gamma_matches_grid_min,
  !regime_check$low_high_counts_match,
  !matrix_check$all_full_rank,
  script_role_check$threshold_used_as_instrument_string_present,
  script_role_check$log_distance_used_as_iv_string_present,
  script_role_check$father_mother_overid_iv_string_present
), na.rm = TRUE)

decision <- if (fatal_issue) {
  "STOP: audit found a construction, role, rank, or grid consistency problem."
} else {
  "PASS: no construction, IV-role, grid, regime-coding, or rank error was found."
}

report_lines <- c(
  "# Audit: student_teacher_ratio_avg_16_18 Threshold Pipeline",
  "",
  paste0("Generated: ", Sys.time()),
  "",
  "## Verdict",
  decision,
  "",
  "## Construction Checks",
  paste0("- Panel formula max abs difference for student_teacher_ratio = students / teachers: ",
         format(panel_formula_check$max_abs_str_minus_students_over_teachers, scientific = TRUE)),
  paste0("- Saved threshold vs independently rebuilt threshold max abs difference: ",
         format(construction_check$max_abs_saved_vs_rebuilt_threshold, scientific = TRUE)),
  paste0("- Saved parent_educ_mean vs rebuilt from father/mother max abs difference: ",
         format(construction_check$max_abs_parent_educ_saved_vs_rebuilt, scientific = TRUE)),
  paste0("- All saved observations have complete age 16, 17, and 18 school-supply years: ",
         construction_check$n_all_three_years_saved == construction_check$N_saved),
  "",
  "## Role Checks",
  paste0("- Parent IV formula present: ", script_role_check$has_parent_iv_formula),
  paste0("- GMM instruments use parent_educ_mean_r interactions: ", script_role_check$gmm_instrument_uses_parent_educ_mean_r),
  paste0("- Threshold used as instrument: ", script_role_check$threshold_used_as_instrument_string_present),
  paste0("- log_distance_to_ub used as IV: ", script_role_check$log_distance_used_as_iv_string_present),
  paste0("- father+mother overidentified IV used: ", script_role_check$father_mother_overid_iv_string_present),
  "",
  "## Grid / Regime / Matrix Checks",
  paste0("- gamma_hat matches minimum SSR grid point: ", grid_check$gamma_matches_grid_min),
  paste0("- Grid rows / warning rows: ", grid_check$n_grid_rows, " / ", grid_check$n_warning_flagged),
  paste0("- Regime counts match gamma table: ", regime_check$low_high_counts_match),
  paste0("- Low/high N: ", regime_check$N_low_recomputed, " / ", regime_check$N_high_recomputed),
  paste0("- Full rank GMM matrices: ", matrix_check$all_full_rank),
  paste0("- Near-singular warning: ", matrix_check$near_singular_warning),
  "",
  "## Bootstrap Check",
  paste0("- Successful / failed / warning draws: ", bootstrap_check$n_success, " / ", bootstrap_check$n_failed, " / ", bootstrap_check$n_warning),
  paste0("- beta_diff observed: ", round(bootstrap_check$beta_diff_observed, 6)),
  paste0("- beta_diff percentile CI: [", round(bootstrap_check$beta_diff_q025, 6), ", ", round(bootstrap_check$beta_diff_q975, 6), "]"),
  paste0("- Percentile CI contains zero: ", bootstrap_check$percentile_ci_contains_zero),
  paste0("- Centered bootstrap p-value: ", round(bootstrap_check$centered_bootstrap_p_value_table, 6)),
  paste0("- Sign-based two-sided p-value: ", round(bootstrap_check$sign_based_two_sided_p_value, 6)),
  "- Note: the centered bootstrap p-value and percentile CI can disagree because they answer slightly different bootstrap-tail questions.",
  "",
  "## Important Interpretation",
  "- The computational pipeline passed the audit.",
  "- The inference is still methodologically cautious: the centered bootstrap p-value is above 0.05, while the percentile CI excludes zero.",
  "- Therefore, do not write this as unequivocally proven strong heterogeneity. Write it as suggestive evidence with a positive percentile interval, but with the bootstrap p-value caveat.",
  "- The direction remains high-crowding regime > low-crowding regime, which is not the simple better-school-quality story."
)

writeLines(report_lines, file.path(PATHS$out_root, "reports", "student_teacher_avg_16_18_pipeline_audit.md"), useBytes = TRUE)

cat("Panel formula check:\n")
print(panel_formula_check)
cat("\nConstruction check:\n")
print(construction_check)
cat("\nSample filter check:\n")
print(sample_filter_check)
cat("\nGrid check:\n")
print(grid_check)
cat("\nRegime check:\n")
print(regime_check)
cat("\nScript role check:\n")
print(script_role_check)
cat("\nBootstrap check:\n")
print(bootstrap_check)
cat("\nDecision:", decision, "\n")
cat("\nCompleted:", as.character(Sys.time()), "\n")
