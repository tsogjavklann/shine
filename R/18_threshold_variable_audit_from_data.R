# Threshold-variable audit for IV threshold returns-to-education design.
# This script audits candidate threshold variables only; it does not run IVTR.

options(warn = 1, encoding = "UTF-8")

source(here::here("R", "paths.R"))
suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(tibble)
  library(stringr)
})

dir.create(PATHS$out_tables, recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(PATHS$out_root, "reports"), recursive = TRUE, showWarnings = FALSE)
dir.create(PATHS$out_logs, recursive = TRUE, showWarnings = FALSE)

log_path <- file.path(PATHS$out_logs, "18_threshold_variable_audit_from_data.log")
sink(log_path, split = TRUE)
on.exit(sink(), add = TRUE)

cat("18_threshold_variable_audit_from_data.R\n")
cat("Started:", as.character(Sys.time()), "\n\n")

analysis_path <- file.path(PATHS$data_proc, "analysis_sample.rds")
family_path <- file.path(PATHS$data_proc, "family_structure.rds")
school_exposure_path <- file.path(PATHS$data_root, "cleaned", "hses_school_supply_exposure_manual.rds")
distance_path <- file.path(PATHS$data_aux, "aimag_distance_to_ub.csv")
inventory_path <- file.path(PATHS$data_aux, "hses_variable_inventory.csv")
preview_path <- file.path(PATHS$data_aux, "hses_variable_preview.csv")

if (!file.exists(analysis_path)) stop("Missing ", analysis_path)
if (!file.exists(family_path)) stop("Missing ", family_path)

analysis <- readRDS(analysis_path) |> as_tibble()
family <- readRDS(family_path) |>
  as_tibble() |>
  select(id, father_educ_years, mother_educ_years, father_educ_level, mother_educ_level, n_siblings, birth_order) |>
  distinct(id, .keep_all = TRUE)

dat <- analysis |>
  left_join(family, by = "id")

if (!"female" %in% names(dat)) dat$female <- as.numeric(dat$is_female)
if (!"married" %in% names(dat)) dat$married <- as.numeric(dat$is_married)

dat <- dat |>
  mutate(
    female = as.numeric(female),
    married = as.numeric(married),
    parent_educ_mean = rowMeans(cbind(as.numeric(father_educ_years), as.numeric(mother_educ_years)), na.rm = TRUE),
    parent_educ_mean = if_else(is.nan(parent_educ_mean), NA_real_, parent_educ_mean),
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

if (file.exists(school_exposure_path)) {
  school_exposure <- readRDS(school_exposure_path) |>
    as_tibble() |>
    select(id, contains("_at_12"), contains("_at_15"), contains("_at_17"), starts_with("mean_"), starts_with("cumulative_")) |>
    distinct(id, .keep_all = TRUE)
  dat <- dat |> left_join(school_exposure, by = "id")
}

if (file.exists(distance_path)) {
  dist <- read_csv(distance_path, show_col_types = FALSE) |>
    transmute(
      birth_aimag = as.numeric(aimag),
      distance_to_ub = as.numeric(distance_to_ub),
      log_distance_to_ub = as.numeric(log_distance_to_ub),
      born_ub = if_else(str_detect(str_to_lower(aimag_name), "ulaan|улаан|ub"), 1, 0, missing = 0)
    )
  dat <- dat |> left_join(dist, by = "birth_aimag")
}

main <- dat |>
  filter(
    age >= 25, age <= 60,
    is.finite(lwage),
    !is.na(educ_years), is.finite(educ_years),
    !is.na(parent_educ_mean), is.finite(parent_educ_mean),
    !is.na(age), !is.na(age2), !is.na(female), !is.na(married), !is.na(urban),
    !is.na(birth_aimag), !is.na(birth_cohort), !is.na(wave)
  )

if ("hhweight" %in% names(main)) {
  main <- main |> filter(!is.na(hhweight), is.finite(hhweight), hhweight > 0)
}

if (nrow(main) == 0) stop("Main wage sample is empty.")

inventory <- if (file.exists(inventory_path)) read_csv(inventory_path, show_col_types = FALSE) else tibble()
preview <- if (file.exists(preview_path)) read_csv(preview_path, show_col_types = FALSE) else tibble()

candidate_names <- c(
  "q_school_access", "q_new", "n_years_school_access", "n_years_new",
  "distance_to_ub", "log_distance_to_ub", "born_ub",
  "urban", "location", "region", "hhsize",
  "father_educ_years", "mother_educ_years", "parent_educ_mean",
  "father_educ_level", "mother_educ_level", "n_siblings", "birth_order",
  "educ_level", "educ_years",
  "lwage", "real_hourly", "nominal_hourly", "q0436a", "q0436b", "q0436c",
  "school_density_student_at_12", "students_per_school_at_12", "teachers_per_student_at_12",
  "student_teacher_ratio_at_12", "school_closure_rate_at_12", "school_growth_rate_at_12",
  "school_density_pop_at_12", "teachers_per_1000_children_at_12", "students_per_1000_children_at_12",
  "school_density_student_at_15", "students_per_school_at_15", "teachers_per_student_at_15",
  "student_teacher_ratio_at_15", "school_closure_rate_at_15", "school_growth_rate_at_15",
  "school_density_pop_at_15", "teachers_per_1000_children_at_15", "students_per_1000_children_at_15",
  "school_density_student_at_17", "students_per_school_at_17", "teachers_per_student_at_17",
  "student_teacher_ratio_at_17", "school_closure_rate_at_17", "school_growth_rate_at_17",
  "school_density_pop_at_17", "teachers_per_1000_children_at_17", "students_per_1000_children_at_17",
  "cumulative_school_closure_age7_15", "cumulative_school_growth_age7_15",
  "mean_school_density_student_age7_15", "mean_teachers_per_student_age7_15",
  "mean_students_per_school_age7_15", "mean_student_teacher_ratio_age7_15",
  "mean_school_density_pop_age7_15", "mean_teachers_per_1000_children_age7_15"
)
candidate_names <- unique(candidate_names[candidate_names %in% names(main)])

source_file_for <- function(v) {
  if (v %in% c("father_educ_years", "mother_educ_years", "father_educ_level", "mother_educ_level", "parent_educ_mean", "n_siblings", "birth_order")) {
    family_path
  } else if (str_detect(v, "school|teacher|student|closure|growth")) {
    school_exposure_path
  } else if (v %in% c("distance_to_ub", "log_distance_to_ub", "born_ub")) {
    distance_path
  } else {
    analysis_path
  }
}

family_for <- function(v) {
  case_when(
    v %in% c("father_educ_years", "mother_educ_years", "parent_educ_mean", "father_educ_level", "mother_educ_level", "n_siblings", "birth_order", "hhsize") ~ "Credit constraints / family background",
    v %in% c("urban", "location", "region", "distance_to_ub", "log_distance_to_ub", "born_ub") ~ "Local labor market conditions / geographic access",
    str_detect(v, "q_school_access|q_new|school|teacher|student|closure|growth|n_years") ~ "School quality / education access",
    v %in% c("educ_level", "educ_years") ~ "Cognitive ability",
    str_detect(v, "lwage|wage|hourly|q0436") ~ "Credit constraints / family background",
    TRUE ~ "Other"
  )
}

mechanism_for <- function(v, fam) {
  case_when(
    fam == "School quality / education access" ~ "Education returns may differ by childhood school access or school quality environment.",
    fam == "Local labor market conditions / geographic access" ~ "Education returns may differ by remoteness, urban access, or local labor-market opportunity.",
    v %in% c("n_siblings", "birth_order") ~ "Family resource dilution may affect returns to schooling.",
    str_detect(v, "parent|father|mother") ~ "Family background may shift education returns, but overlaps with the IV.",
    str_detect(v, "wage|hourly|q0436|lwage") ~ "Current earnings are mechanically related to the outcome and are not valid thresholds.",
    v %in% c("urban", "location", "region", "hhsize") ~ "Current household/location status may proxy market access but is post-treatment risk.",
    TRUE ~ "Potential heterogeneity mechanism is weak or indirect."
  )
}

classify_type <- function(x) {
  x <- x[is.finite(x)]
  ux <- sort(unique(x))
  if (length(ux) <= 2) return("binary")
  if (length(ux) <= 20 && all(abs(ux - round(ux)) < 1e-8)) return("ordered")
  "continuous"
}

predetermined_score_for <- function(v, fam) {
  case_when(
    fam == "School quality / education access" ~ 5,
    v %in% c("distance_to_ub", "log_distance_to_ub", "born_ub", "n_siblings", "birth_order") ~ 5,
    str_detect(v, "parent|father|mother") ~ 5,
    v %in% c("urban", "location", "region", "hhsize") ~ 1,
    str_detect(v, "wage|hourly|q0436|lwage") ~ 0,
    v %in% c("educ_level", "educ_years") ~ 0,
    TRUE ~ 2
  )
}

theory_score_for <- function(v, fam) {
  case_when(
    v == "q_school_access" ~ 5,
    fam == "School quality / education access" & str_detect(v, "teacher|student_teacher|school_density|q_new|mean_") ~ 5,
    fam == "Local labor market conditions / geographic access" & v %in% c("distance_to_ub", "log_distance_to_ub") ~ 4,
    v == "born_ub" ~ 3,
    v %in% c("n_siblings", "birth_order") ~ 3,
    str_detect(v, "parent|father|mother") ~ 4,
    v %in% c("urban", "location", "region", "hhsize") ~ 2,
    str_detect(v, "wage|hourly|q0436|lwage") ~ 0,
    v %in% c("educ_level", "educ_years") ~ 0,
    TRUE ~ 2
  )
}

post_treatment_penalty_for <- function(v) {
  case_when(
    str_detect(v, "wage|hourly|q0436|lwage") ~ 5,
    v %in% c("urban", "location", "region", "hhsize") ~ 4,
    v %in% c("educ_level", "educ_years") ~ 5,
    TRUE ~ 0
  )
}

iv_overlap_penalty_for <- function(v) {
  case_when(
    v == "parent_educ_mean" ~ 5,
    v %in% c("father_educ_years", "mother_educ_years", "father_educ_level", "mother_educ_level") ~ 4,
    TRUE ~ 0
  )
}

reject_reason_for <- function(v, fam, type, caner, binary_split, post_pen, iv_pen, miss_rate) {
  reasons <- character()
  if (v == "parent_educ_mean") reasons <- c(reasons, "same variable as the IV")
  if (v %in% c("father_educ_years", "mother_educ_years", "father_educ_level", "mother_educ_level")) reasons <- c(reasons, "too close to the IV")
  if (v %in% c("educ_years", "educ_level", "degree", "dropout_grade")) reasons <- c(reasons, "education outcome, not a threshold")
  if (str_detect(v, "lwage|wage|hourly|q0436")) reasons <- c(reasons, "mechanically current wage/outcome-related")
  if (v %in% c("urban", "location", "region", "hhsize")) reasons <- c(reasons, "current status with post-treatment risk")
  if (!caner && !binary_split && is.finite(miss_rate) && miss_rate > 0.5) {
    reasons <- c(reasons, "weak coverage in main wage sample")
  } else if (!caner && !binary_split) {
    reasons <- c(reasons, "insufficient continuous/ordered variation")
  }
  if (length(reasons) == 0) NA_character_ else paste(unique(reasons), collapse = "; ")
}

diagnose_candidate <- function(v) {
  x <- suppressWarnings(as.numeric(main[[v]]))
  n <- length(x)
  ok <- !is.na(x) & is.finite(x)
  n_non <- sum(ok)
  miss_rate <- 1 - n_non / n
  ux <- unique(x[ok])
  type <- if (n_non > 0) classify_type(x) else "unavailable"
  fam <- family_for(v)
  caner <- type %in% c("continuous", "ordered") && length(ux) >= 20 && miss_rate <= 0.5
  binary_split <- type == "binary" && length(ux) == 2 && miss_rate <= 0.5
  if (v %in% c("parent_educ_mean", "father_educ_years", "mother_educ_years", "father_educ_level", "mother_educ_level", "educ_years", "educ_level") ||
      str_detect(v, "lwage|wage|hourly|q0436")) {
    caner <- FALSE
    binary_split <- FALSE
  }
  theory <- theory_score_for(v, fam)
  pred <- predetermined_score_for(v, fam)
  dataq <- case_when(
    miss_rate <= 0.10 ~ 5,
    miss_rate <= 0.25 ~ 4,
    miss_rate <= 0.50 ~ 3,
    miss_rate <= 0.75 ~ 1,
    TRUE ~ 0
  )
  variation <- case_when(
    type == "continuous" && length(ux) >= 100 ~ 5,
    type == "continuous" && length(ux) >= 30 ~ 4,
    type %in% c("continuous", "ordered") && length(ux) >= 20 ~ 3,
    type == "binary" && length(ux) == 2 ~ 1,
    TRUE ~ 0
  )
  post_pen <- post_treatment_penalty_for(v)
  iv_pen <- iv_overlap_penalty_for(v)
  reject_reason <- reject_reason_for(v, fam, type, caner, binary_split, post_pen, iv_pen, miss_rate)
  tibble(
    variable_name = v,
    family = fam,
    source_file = source_file_for(v),
    type = type,
    N_nonmissing = n_non,
    missing_rate = miss_rate,
    unique_values = length(ux),
    min = if (n_non > 0) min(x[ok]) else NA_real_,
    p10 = if (n_non > 0) as.numeric(quantile(x[ok], 0.10, names = FALSE)) else NA_real_,
    p25 = if (n_non > 0) as.numeric(quantile(x[ok], 0.25, names = FALSE)) else NA_real_,
    p50 = if (n_non > 0) as.numeric(quantile(x[ok], 0.50, names = FALSE)) else NA_real_,
    p75 = if (n_non > 0) as.numeric(quantile(x[ok], 0.75, names = FALSE)) else NA_real_,
    p90 = if (n_non > 0) as.numeric(quantile(x[ok], 0.90, names = FALSE)) else NA_real_,
    max = if (n_non > 0) max(x[ok]) else NA_real_,
    correlation_with_lwage = suppressWarnings(cor(x, main$lwage, use = "pairwise.complete.obs")),
    correlation_with_educ_years = suppressWarnings(cor(x, main$educ_years, use = "pairwise.complete.obs")),
    correlation_with_parent_educ_mean = suppressWarnings(cor(x, main$parent_educ_mean, use = "pairwise.complete.obs")),
    likely_pre_determined_yes_no = ifelse(pred >= 4, "yes", "no"),
    post_treatment_risk_yes_no = ifelse(post_pen > 0, "yes", "no"),
    same_as_or_too_close_to_IV_yes_no = ifelse(iv_pen > 0, "yes", "no"),
    usable_for_Caner_Hansen_continuous_threshold_yes_no = ifelse(caner, "yes", "no"),
    usable_as_binary_split_yes_no = ifelse(binary_split, "yes", "no"),
    expected_mechanism = mechanism_for(v, fam),
    caveat = case_when(
      !is.na(reject_reason) ~ reject_reason,
      fam == "School quality / education access" ~ "birth-aimag exposure is a proxy and may share regional confounding",
      fam == "Local labor market conditions / geographic access" ~ "geographic thresholds may capture broad regional differences",
      fam == "Credit constraints / family background" ~ "family-background proxy, not direct childhood credit constraint",
      TRUE ~ "interpret cautiously"
    ),
    theory_score = theory,
    predetermined_score = pred,
    data_quality_score = dataq,
    variation_score = variation,
    post_treatment_penalty = post_pen,
    IV_overlap_penalty = iv_pen,
    overall_score = theory + pred + dataq + variation - post_pen - iv_pen,
    rejected = !is.na(reject_reason),
    rejection_reason = reject_reason
  )
}

audit <- bind_rows(lapply(candidate_names, diagnose_candidate)) |>
  arrange(desc(overall_score), variable_name)

inventory_rejections <- tibble()
if (nrow(inventory) > 0) {
  unavailable_vars <- tibble(
    variable_name = c("q0211", "q0212", "exam_score", "math_score", "language_score", "childhood_parental_income", "childhood_parental_assets", "current_household_consumption")
  ) |>
    mutate(
      family = case_when(
        variable_name %in% c("q0211", "q0212", "exam_score", "math_score", "language_score") ~ "Cognitive ability",
        TRUE ~ "Credit constraints / family background"
      ),
      source_file = if_else(variable_name %in% inventory$var_name, inventory_path, "not found in processed/cleaned audit sources"),
      type = if_else(variable_name %in% c("q0211", "q0212"), "binary", "unavailable"),
      N_nonmissing = NA_integer_,
      missing_rate = NA_real_,
      unique_values = NA_integer_,
      min = NA_real_, p10 = NA_real_, p25 = NA_real_, p50 = NA_real_, p75 = NA_real_, p90 = NA_real_, max = NA_real_,
      correlation_with_lwage = NA_real_,
      correlation_with_educ_years = NA_real_,
      correlation_with_parent_educ_mean = NA_real_,
      likely_pre_determined_yes_no = "unclear",
      post_treatment_risk_yes_no = "no",
      same_as_or_too_close_to_IV_yes_no = "no",
      usable_for_Caner_Hansen_continuous_threshold_yes_no = "no",
      usable_as_binary_split_yes_no = if_else(variable_name %in% c("q0211", "q0212"), "potentially, if merged", "no"),
      expected_mechanism = case_when(
        variable_name == "q0211" ~ "Basic literacy proxy, not an exam score.",
        variable_name == "q0212" ~ "Basic numeracy proxy, not a math score.",
        str_detect(variable_name, "score") ~ "Direct ability score would be relevant, but no such processed variable is available.",
        TRUE ~ "Credit-constraint background would be relevant, but no childhood measure is available."
      ),
      caveat = case_when(
        variable_name %in% c("q0211", "q0212") ~ "found in inventory, not merged into current processed analysis sample; binary proxy, not score",
        TRUE ~ "not found as usable variable in processed/cleaned audit data"
      ),
      theory_score = if_else(family == "Cognitive ability", 4, 5),
      predetermined_score = 3,
      data_quality_score = 0,
      variation_score = if_else(variable_name %in% c("q0211", "q0212"), 1, 0),
      post_treatment_penalty = 0,
      IV_overlap_penalty = 0,
      overall_score = theory_score + predetermined_score + data_quality_score + variation_score,
      rejected = TRUE,
      rejection_reason = caveat
    )
  inventory_rejections <- unavailable_vars
}

full_audit <- bind_rows(audit, inventory_rejections) |>
  arrange(desc(overall_score), variable_name)

shortlist <- full_audit |>
  filter(!rejected, usable_for_Caner_Hansen_continuous_threshold_yes_no == "yes" | usable_as_binary_split_yes_no == "yes") |>
  arrange(desc(overall_score), family, variable_name)

rejected <- full_audit |>
  filter(rejected) |>
  arrange(desc(overall_score), variable_name)

write_csv(full_audit, file.path(PATHS$out_tables, "T7_threshold_variable_audit_full.csv"))
write_csv(shortlist, file.path(PATHS$out_tables, "T7_threshold_variable_shortlist.csv"))
write_csv(rejected, file.path(PATHS$out_tables, "T7_threshold_variable_rejected.csv"))

best_cont <- shortlist |>
  filter(usable_for_Caner_Hansen_continuous_threshold_yes_no == "yes") |>
  arrange(desc(overall_score), desc(theory_score), desc(predetermined_score), desc(data_quality_score), desc(variation_score)) |>
  slice(1)
best_binary <- shortlist |>
  filter(usable_as_binary_split_yes_no == "yes") |>
  arrange(desc(overall_score), desc(theory_score), desc(predetermined_score), desc(data_quality_score), desc(variation_score)) |>
  slice(1)

family_available <- full_audit |>
  group_by(family) |>
  summarise(
    n_candidates = n(),
    n_usable_continuous = sum(usable_for_Caner_Hansen_continuous_threshold_yes_no == "yes", na.rm = TRUE),
    n_usable_binary = sum(usable_as_binary_split_yes_no == "yes", na.rm = TRUE),
    top_candidate = variable_name[which.max(overall_score)],
    .groups = "drop"
  )

q_school_access_row <- full_audit |> filter(variable_name == "q_school_access") |> slice(1)
log_dist_row <- full_audit |> filter(variable_name == "log_distance_to_ub") |> slice(1)

report_lines <- c(
  "# Threshold Variable Audit From Available Data",
  "",
  paste0("Generated: ", Sys.time()),
  paste0("Main wage sample with parent_educ_mean N: ", nrow(main)),
  "",
  "## 1. Threshold Families Available",
  paste0("- ", family_available$family, ": candidates=", family_available$n_candidates,
         ", usable continuous=", family_available$n_usable_continuous,
         ", usable binary=", family_available$n_usable_binary,
         ", top=", family_available$top_candidate),
  "",
  "## 2. Families Unavailable or Weak",
  "- Direct cognitive test/exam/AFQT/math/language scores are unavailable in the processed analysis data.",
  "- Basic literacy/numeracy indicators (`q0211`, `q0212`) exist in the inventory, but are binary proxies and are not currently merged into the processed analysis sample.",
  "- True childhood parental income, parental assets, and parental wealth measures were not found as usable processed variables.",
  "- Current household income/consumption/assets/dwelling variables are post-treatment risk and/or not available in the processed analysis sample.",
  "",
  "## 3. Top Recommended Continuous Threshold",
  if (nrow(best_cont) == 0) {
    "No continuous threshold candidate is recommended."
  } else {
    paste0("- ", best_cont$variable_name, " (family: ", best_cont$family,
           ", score: ", best_cont$overall_score, "). Mechanism: ", best_cont$expected_mechanism)
  },
  "",
  "## 4. Top Recommended Binary Heterogeneity Split",
  if (nrow(best_binary) == 0) {
    "No binary split candidate is recommended."
  } else {
    paste0("- ", best_binary$variable_name, " (family: ", best_binary$family,
           ", score: ", best_binary$overall_score, "). Use as heterogeneity split, not continuous Caner-Hansen threshold.")
  },
  "",
  "## 5. Rejected Variables",
  paste0("- ", head(rejected$variable_name, 20), ": ", head(rejected$rejection_reason, 20)),
  "",
  "## 6. Should q_school_access Remain Main Threshold?",
  paste0("- q_school_access score: ", q_school_access_row$overall_score,
         "; usable continuous: ", q_school_access_row$usable_for_Caner_Hansen_continuous_threshold_yes_no,
         "; N_nonmissing: ", q_school_access_row$N_nonmissing,
         "; unique values: ", q_school_access_row$unique_values, "."),
  "- Recommendation: q_school_access should remain the main threshold unless you want a narrower school-quality interpretation using a specific normalized school-supply exposure.",
  "",
  "## 7. Is log_distance_to_ub Better?",
  paste0("- log_distance_to_ub score: ", log_dist_row$overall_score,
         "; usable continuous: ", log_dist_row$usable_for_Caner_Hansen_continuous_threshold_yes_no,
         "; unique values: ", log_dist_row$unique_values, "."),
  "- It is a plausible geographic-access threshold and may be useful as an alternative threshold, but it is coarser than q_school_access and captures broad regional/remoteness differences.",
  "- It must not be used as an IV.",
  "",
  "## 8. Truly Predetermined Credit-Constraint Variables",
  "- No true childhood parental income, childhood parental wealth, or childhood asset variable was found in the processed/cleaned audit data.",
  "- `n_siblings` and `birth_order` are predetermined family-background proxies, but they are not direct credit-constraint measures.",
  "- `parent_educ_mean` and father/mother education variables are rejected as thresholds because they overlap with the IV.",
  "",
  "## 9. Final Recommendation For Next IVTR Test",
  if (nrow(best_cont) > 0) {
    paste0("- Main recommendation: use `", best_cont$variable_name, "` as the next continuous threshold variable.")
  } else {
    "- Main recommendation: do not run another continuous-threshold IVTR until a better q variable is constructed."
  },
  if (nrow(best_binary) > 0) {
    paste0("- Binary split option: `", best_binary$variable_name, "` only as a heterogeneity split.")
  } else {
    "- No binary split is strong enough to prioritize."
  },
  "",
  "## Warnings",
  "- Scores are theory/data-quality scores, not p-values.",
  "- This audit did not run IVTR models.",
  "- Current household/location variables carry post-treatment risk.",
  "- Many household asset/consumption variables are visible in inventories but not merged into processed analysis data."
)

writeLines(report_lines, file.path(PATHS$out_root, "reports", "threshold_variable_audit_from_data_summary.md"), useBytes = TRUE)

cat("Full audit rows:", nrow(full_audit), "\n")
cat("Shortlist rows:", nrow(shortlist), "\n")
cat("Rejected rows:", nrow(rejected), "\n")
cat("\nBest continuous:\n")
print(best_cont)
cat("\nBest binary:\n")
print(best_binary)
cat("\nFamily availability:\n")
print(family_available, n = Inf)
cat("\nCompleted:", as.character(Sys.time()), "\n")
