# =============================================================================
# 22_find_better_threshold_candidates.R
# -----------------------------------------------------------------------------
# Purpose:
#   Search existing local project data for threshold-variable candidates that may
#   be more defensible than q_school_access or log_distance_to_ub.
#
# Important:
#   - Does not search for new IVs.
#   - Does not change the IV.
#   - Does not estimate IVTR.
#   - Does not choose by p-value.
# =============================================================================

source(here::here("R", "paths.R"))

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(tibble)
  library(stringr)
})

log_path <- file.path(PATHS$out_logs, "22_find_better_threshold_candidates.log")
dir.create(dirname(log_path), recursive = TRUE, showWarnings = FALSE)
sink(log_path, append = FALSE, split = TRUE)

cat("22_find_better_threshold_candidates.R\n")
cat("Started:", as.character(Sys.time()), "\n\n")

safe_read_rds <- function(path) {
  if (file.exists(path)) readRDS(path) |> as_tibble() else NULL
}

qnum <- function(x, p) {
  x <- suppressWarnings(as.numeric(x))
  x <- x[is.finite(x)]
  if (!length(x)) return(NA_real_)
  as.numeric(quantile(x, p, na.rm = TRUE, names = FALSE))
}

corr_pair <- function(x, y) {
  x <- suppressWarnings(as.numeric(x))
  y <- suppressWarnings(as.numeric(y))
  ok <- is.finite(x) & is.finite(y)
  if (sum(ok) < 10) return(NA_real_)
  suppressWarnings(cor(x[ok], y[ok]))
}

var_type <- function(x) {
  x <- suppressWarnings(as.numeric(x))
  ux <- sort(unique(x[is.finite(x)]))
  if (length(ux) <= 1) return("unavailable")
  if (length(ux) == 2 && all(ux %in% c(0, 1))) return("binary")
  if (length(ux) <= 15 && all(abs(ux - round(ux)) < 1e-8)) return("ordered")
  "continuous"
}

cohort_from_birth_year <- function(birth_year) {
  case_when(
    birth_year < 1970 ~ "pre1970",
    birth_year >= 1970 & birth_year <= 1974 ~ "1970_1974",
    birth_year >= 1975 & birth_year <= 1979 ~ "1975_1979",
    birth_year >= 1980 & birth_year <= 1984 ~ "1980_1984",
    birth_year >= 1985 & birth_year <= 1989 ~ "1985_1989",
    birth_year >= 1990 & birth_year <= 1994 ~ "1990_1994",
    birth_year >= 1995 ~ "post1995",
    TRUE ~ NA_character_
  )
}

analysis <- safe_read_rds(file.path(PATHS$data_proc, "analysis_sample.rds"))
if (is.null(analysis)) stop("Missing analysis_sample.rds")

fam <- safe_read_rds(file.path(PATHS$data_proc, "family_structure.rds"))
if (!is.null(fam)) {
  fam <- fam |>
    mutate(
      parent_educ_mean = rowMeans(cbind(father_educ_years, mother_educ_years), na.rm = TRUE),
      parent_educ_mean = if_else(is.nan(parent_educ_mean), NA_real_, parent_educ_mean)
    ) |>
    select(id, parent_educ_mean, father_educ_years, mother_educ_years,
           n_siblings, birth_order)
}

school_exp <- safe_read_rds(file.path(PATHS$data_root, "cleaned", "hses_school_supply_exposure_manual.rds"))
if (!is.null(school_exp)) {
  school_exp <- school_exp |>
    select(
      id,
      any_of(c(
        "school_density_student_at_12",
        "students_per_school_at_12",
        "teachers_per_student_at_12",
        "student_teacher_ratio_at_12",
        "school_density_pop_at_12",
        "teachers_per_1000_children_at_12",
        "school_density_student_at_15",
        "students_per_school_at_15",
        "teachers_per_student_at_15",
        "student_teacher_ratio_at_15",
        "school_density_pop_at_15",
        "teachers_per_1000_children_at_15",
        "school_density_student_at_17",
        "students_per_school_at_17",
        "teachers_per_student_at_17",
        "student_teacher_ratio_at_17",
        "school_density_pop_at_17",
        "teachers_per_1000_children_at_17",
        "mean_school_density_student_age7_15",
        "mean_teachers_per_student_age7_15",
        "mean_students_per_school_age7_15",
        "mean_student_teacher_ratio_age7_15",
        "mean_school_density_pop_age7_15",
        "mean_teachers_per_1000_children_age7_15"
      ))
    )
}

dist <- NULL
dist_path <- file.path(PATHS$data_aux, "aimag_distance_to_ub.csv")
if (file.exists(dist_path)) {
  dist <- read_csv(dist_path, show_col_types = FALSE) |>
    transmute(
      birth_aimag = as.numeric(aimag),
      distance_to_ub = as.numeric(distance_to_ub),
      log_distance_to_ub = as.numeric(log_distance_to_ub)
    )
}

dat <- analysis
if (!is.null(fam)) dat <- dat |> left_join(fam, by = "id")
if (!is.null(school_exp)) dat <- dat |> left_join(school_exp, by = "id")
if (!is.null(dist)) dat <- dat |> left_join(dist, by = "birth_aimag")

if (!"female" %in% names(dat) && "is_female" %in% names(dat)) dat$female <- dat$is_female
if (!"married" %in% names(dat) && "is_married" %in% names(dat)) dat$married <- dat$is_married
if (!"birth_cohort" %in% names(dat)) dat$birth_cohort <- cohort_from_birth_year(dat$birth_year)

dat <- dat |>
  mutate(
    born_ub = as.integer(birth_aimag == 11),
    rural_birth = as.integer(!is.na(birth_aimag) & birth_aimag != 11),
    q_age = as.numeric(age),
    q_birth_year = as.numeric(birth_year),
    q_current_hhsize = as.numeric(hhsize)
  )

base <- dat |>
  filter(
    age >= 25, age <= 60,
    is.finite(lwage),
    !is.na(educ_years),
    !is.na(parent_educ_mean),
    !is.na(age), !is.na(age2),
    !is.na(female), !is.na(married), !is.na(urban),
    !is.na(birth_aimag), !is.na(birth_cohort), !is.na(wave)
  )

cat("Parent-IV base sample N:", nrow(base), "\n")

candidate_meta <- tribble(
  ~variable_name, ~family, ~expected_mechanism, ~theory_score, ~predetermined_score, ~post_treatment_penalty, ~iv_overlap_penalty, ~level_fe_penalty, ~caveat,
  "student_teacher_ratio_at_17", "School quality", "Education returns may differ by class-size/school-quality exposure at late school age.", 5, 5, 0, 0, 0, "Strong theory, but coverage may be limited to cohorts with 2000+ school data.",
  "teachers_per_student_at_17", "School quality", "Education returns may differ by teacher availability during late school age.", 5, 5, 0, 0, 0, "Inverse of student-teacher ratio; interpretation is cleaner if higher means better supply.",
  "teachers_per_1000_children_at_17", "School quality", "Education returns may differ by teacher supply relative to child population.", 5, 5, 0, 0, 0, "Coverage may be weaker because population denominator is not always available.",
  "school_density_student_at_17", "School access", "Education returns may differ by school availability at late school age.", 4, 5, 0, 0, 0, "Age-17 exposure avoids partial 6-17 averaging.",
  "students_per_school_at_17", "School crowding", "Education returns may differ by school crowding during late school age.", 4, 5, 0, 0, 0, "Higher values mean more crowded schools.",
  "mean_student_teacher_ratio_age7_15", "School quality", "Average class-size/school-quality exposure across school ages.", 5, 5, 0, 0, 1, "Conceptually good, but can inherit partial-coverage problems.",
  "mean_teachers_per_student_age7_15", "School quality", "Average teacher availability across school ages.", 5, 5, 0, 0, 1, "Conceptually good, but can inherit partial-coverage problems.",
  "mean_school_density_student_age7_15", "School access", "Average school access across childhood school years.", 4, 5, 0, 0, 1, "Close to q_school_access but narrower construction.",
  "q_school_access", "School access", "Education returns may differ by childhood birth-aimag school access.", 4, 5, 0, 0, 1, "Previously used; partial exposure for older cohorts.",
  "q_new", "School access/current residence", "Current-residence school access proxy.", 2, 2, 2, 0, 1, "Current residence may reflect migration; weaker than birth-aimag exposure.",
  "log_distance_to_ub", "Geographic/labor-market access", "Returns may differ by remoteness from the capital/labor market access.", 3, 5, 0, 0, 2, "Only 22 birth-aimag-level values and collinear with birth-aimag level.",
  "distance_to_ub", "Geographic/labor-market access", "Returns may differ by remoteness from the capital/labor market access.", 3, 5, 0, 0, 2, "Only 22 birth-aimag-level values; use log form if used.",
  "born_ub", "Geographic/labor-market access", "UB-born vs non-UB-born heterogeneity split.", 3, 5, 0, 0, 2, "Binary split, not continuous Caner-Hansen threshold.",
  "rural_birth", "Geographic/labor-market access", "Non-UB-born vs UB-born heterogeneity split.", 3, 5, 0, 0, 2, "Binary split, not continuous Caner-Hansen threshold.",
  "birth_order", "Family background", "Resource dilution or sibling-rank heterogeneity in returns to schooling.", 3, 4, 0, 0, 0, "Observed from current household roster; not a clean childhood household history.",
  "n_siblings", "Family background", "Family size/resource dilution heterogeneity.", 3, 4, 0, 0, 0, "Observed only when siblings are in the current roster; incomplete childhood family size.",
  "q_age", "Life-cycle", "Returns to schooling may differ across labor-market life-cycle stages.", 4, 5, 0, 0, 0, "Not family/home background; age is already a control.",
  "q_birth_year", "Cohort", "Returns may differ across cohorts exposed to different macro/education environments.", 3, 5, 0, 0, 1, "Closely related to birth_cohort FE and wave-age structure.",
  "q_current_hhsize", "Current household condition", "Returns may differ by current household burden/resources.", 2, 1, 4, 0, 0, "Post-treatment risk; current household size may be affected by education/wage.",
  "urban", "Current location", "Urban/rural heterogeneity split.", 2, 1, 4, 0, 0, "Already a control and may reflect migration/labor outcomes."
)

score_data_quality <- function(n_nonmissing, n_base) {
  share <- if (n_base > 0) n_nonmissing / n_base else 0
  case_when(
    n_nonmissing >= 3000 & share >= 0.75 ~ 5,
    n_nonmissing >= 2000 & share >= 0.50 ~ 4,
    n_nonmissing >= 1000 & share >= 0.25 ~ 3,
    n_nonmissing >= 500 ~ 2,
    n_nonmissing > 0 ~ 1,
    TRUE ~ 0
  )
}

score_variation <- function(type, unique_values) {
  case_when(
    type == "continuous" & unique_values >= 100 ~ 5,
    type == "continuous" & unique_values >= 30 ~ 4,
    type == "continuous" & unique_values >= 10 ~ 3,
    type == "ordered" & unique_values >= 8 ~ 3,
    type == "ordered" & unique_values >= 4 ~ 2,
    type == "binary" ~ 1,
    TRUE ~ 0
  )
}

evaluate_candidate <- function(v) {
  if (!v %in% names(base)) {
    return(tibble(
      variable_name = v, type = "missing", N_nonmissing = 0L,
      missing_rate = 1, unique_values = 0L,
      min = NA_real_, p10 = NA_real_, p25 = NA_real_, p50 = NA_real_,
      p75 = NA_real_, p90 = NA_real_, max = NA_real_,
      corr_lwage = NA_real_, corr_educ_years = NA_real_,
      corr_parent_educ_mean = NA_real_
    ))
  }
  x <- suppressWarnings(as.numeric(base[[v]]))
  ok <- is.finite(x)
  ux <- unique(x[ok])
  tibble(
    variable_name = v,
    type = var_type(x),
    N_nonmissing = sum(ok),
    missing_rate = 1 - mean(ok),
    unique_values = length(ux),
    min = if (sum(ok)) min(x[ok]) else NA_real_,
    p10 = qnum(x, .10),
    p25 = qnum(x, .25),
    p50 = qnum(x, .50),
    p75 = qnum(x, .75),
    p90 = qnum(x, .90),
    max = if (sum(ok)) max(x[ok]) else NA_real_,
    corr_lwage = corr_pair(x, base$lwage),
    corr_educ_years = corr_pair(x, base$educ_years),
    corr_parent_educ_mean = corr_pair(x, base$parent_educ_mean)
  )
}

audit <- bind_rows(lapply(candidate_meta$variable_name, evaluate_candidate)) |>
  left_join(candidate_meta, by = "variable_name") |>
  rowwise() |>
  mutate(
    data_quality_score = score_data_quality(N_nonmissing, nrow(base)),
    variation_score = score_variation(type, unique_values),
    usable_continuous_threshold = type == "continuous" && unique_values >= 10 && N_nonmissing >= 500,
    usable_binary_split = type == "binary" && N_nonmissing >= 500,
    reject_reason = case_when(
      type %in% c("missing", "unavailable") ~ "missing or no variation",
      variable_name %in% c("father_educ_years", "mother_educ_years", "parent_educ_mean") ~ "same as or too close to IV",
      post_treatment_penalty >= 4 ~ "post-treatment/current-outcome risk",
      type == "binary" ~ "binary split only, not continuous threshold",
      N_nonmissing < 500 ~ "too little coverage",
      unique_values < 10 ~ "too little variation for continuous threshold",
      TRUE ~ NA_character_
    ),
    overall_score = theory_score + predetermined_score + data_quality_score + variation_score -
      post_treatment_penalty - iv_overlap_penalty - level_fe_penalty
  ) |>
  ungroup() |>
  arrange(desc(overall_score), desc(N_nonmissing), desc(unique_values))

shortlist <- audit |>
  filter(is.na(reject_reason), usable_continuous_threshold) |>
  arrange(desc(overall_score), desc(theory_score), desc(data_quality_score))

binary_splits <- audit |>
  filter(usable_binary_split) |>
  arrange(desc(overall_score))

rejected <- audit |>
  filter(!is.na(reject_reason)) |>
  arrange(desc(overall_score))

write_csv(audit, file.path(PATHS$out_tables, "T10_threshold_candidate_search_full.csv"))
write_csv(shortlist, file.path(PATHS$out_tables, "T10_threshold_candidate_search_shortlist.csv"))
write_csv(binary_splits, file.path(PATHS$out_tables, "T10_threshold_candidate_binary_splits.csv"))
write_csv(rejected, file.path(PATHS$out_tables, "T10_threshold_candidate_search_rejected.csv"))

best <- shortlist |> slice(1)
best_binary <- binary_splits |> slice(1)

fmt <- function(x, digits = 4) {
  ifelse(is.na(x), "NA", formatC(as.numeric(x), digits = digits, format = "f"))
}

report <- c(
  "# Threshold Candidate Search After q_school_access Rename",
  "",
  paste0("Generated: ", Sys.time()),
  paste0("Parent-IV base sample N: ", nrow(base)),
  "",
  "## Method",
  "- This audit does not estimate IVTR.",
  "- This audit does not search for or change IVs.",
  "- Candidates are scored by theory, predetermined status, data quality, variation, and penalties for post-treatment risk and FE-level limitations.",
  "",
  "## Main Finding",
  if (nrow(best) > 0) {
    paste0("- Best continuous candidate found: `", best$variable_name, "` (score ",
           best$overall_score, ", N=", best$N_nonmissing,
           ", unique=", best$unique_values, ").")
  } else {
    "- No usable continuous candidate passed the audit filters."
  },
  if (nrow(best_binary) > 0) {
    paste0("- Best binary split candidate: `", best_binary$variable_name, "` (score ",
           best_binary$overall_score, ", N=", best_binary$N_nonmissing, ").")
  } else {
    "- No usable binary split candidate passed the audit filters."
  },
  "",
  "## Top Continuous Shortlist",
  if (nrow(shortlist) > 0) {
    apply(shortlist |> slice_head(n = min(10, nrow(shortlist))), 1, function(r) {
      paste0("- `", r[["variable_name"]], "`: score=", r[["overall_score"]],
             ", family=", r[["family"]],
             ", N=", r[["N_nonmissing"]],
             ", unique=", r[["unique_values"]],
             ", caveat=", r[["caveat"]])
    })
  } else {
    "- None."
  },
  "",
  "## Variables Not Recommended As Main Continuous TR",
  apply(rejected |> slice_head(n = min(10, nrow(rejected))), 1, function(r) {
    paste0("- `", r[["variable_name"]], "`: ", r[["reject_reason"]],
           " (score=", r[["overall_score"]], ", N=", r[["N_nonmissing"]], ").")
  }),
  "",
  "## Recommendation",
  "- If you want a threshold more theoretically precise than `q_school_access`, the best available next candidate is a late-school-age school-quality measure, especially `student_teacher_ratio_at_17` or `teachers_per_student_at_17`.",
  "- These are preferable to the old `q_school_access` because they avoid averaging over partially observed childhood years.",
  "- They are preferable to `log_distance_to_ub` because they capture school-quality/access more directly and have more continuous variation.",
  "- Their weakness is smaller sample coverage, so the next step should be matrix/sample preparation only, not immediate bootstrap claims.",
  "",
  "## Important Warnings",
  "- HSES does not contain a clean retrospective childhood household income/wealth variable for adult respondents.",
  "- Current household-condition variables are not recommended as main TR because education and wages may affect them.",
  "- `parent_educ_mean`, `father_educ_years`, and `mother_educ_years` should not be thresholds because they overlap with the IV.",
  "- Binary variables such as `born_ub` are heterogeneity splits, not continuous Caner-Hansen threshold variables."
)

writeLines(report, file.path(PATHS$out_root, "reports", "threshold_candidate_recommendation_after_qrename.md"),
           useBytes = TRUE)

cat("\nTop shortlist:\n")
print(shortlist |> select(variable_name, family, N_nonmissing, unique_values, overall_score, caveat) |> head(10))

cat("\nOutputs written.\n")
cat("Finished:", as.character(Sys.time()), "\n")

sink()
