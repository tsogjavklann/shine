# =============================================================================
# 25_mics_nuts_inventory_for_hses_project.R
# -----------------------------------------------------------------------------
# Inventory local NUTS/MICS files for possible use in the Mongolia HSES
# returns-to-education project.
# This script does not merge MICS into HSES and does not run IV/IVTR.
# =============================================================================

options(warn = 1, encoding = "UTF-8")

source(here::here("R", "paths.R"))

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(tibble)
  library(haven)
  library(stringr)
  library(purrr)
})

dir.create(PATHS$out_tables, recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(PATHS$out_root, "reports"), recursive = TRUE, showWarnings = FALSE)
dir.create(PATHS$out_logs, recursive = TRUE, showWarnings = FALSE)

log_path <- file.path(PATHS$out_logs, "25_mics_nuts_inventory_for_hses_project.log")
sink(log_path, split = TRUE)
on.exit(sink(), add = TRUE)

cat("25_mics_nuts_inventory_for_hses_project.R\n")
cat("Started:", as.character(Sys.time()), "\n\n")

mics_files <- list.files(PATHS$data_root, pattern = "\\.sav$", recursive = TRUE, full.names = TRUE)
mics_files <- mics_files[grepl("НҮТС|MICS|SISS", mics_files, ignore.case = TRUE)]
if (length(mics_files) == 0) stop("No local NUTS/MICS .sav files found.")

classify_var <- function(name, label) {
  txt <- str_to_lower(paste(name, label, sep = " "))
  case_when(
    str_detect(txt, "wealth|asset|possess|ownership|dwelling|floor|roof|wall|water|sanitation|toilet|electric|internet|computer|car|livestock|housing|household characteristics|өрх|орон сууц|хөрөнгө|мал|ус|цахилгаан|жорлон") ~ "wealth_assets_housing",
    str_detect(txt, "school|education|attendance|attend|grade|class|drop|repeat|reading|numeracy|literacy|сургууль|боловсрол|анги|унших|тоолох") ~ "education_schooling",
    str_detect(txt, "mother|father|parent|эх|эцэг|аав|ээж") ~ "parents_family",
    str_detect(txt, "birth|age|sex|gender|urban|rural|region|aimag|province|location|cluster|sample|weight|төрсөн|нас|хүйс|хот|хөдөө|бүс|аймаг|түүвэр|жин") ~ "demographics_geo_weights",
    str_detect(txt, "work|labour|labor|occupation|employment|paid|unpaid|child labour|ажил|хөдөлмөр") ~ "work_child_labour",
    str_detect(txt, "health|nutrition|height|weight|vaccin|disease|disability|functional|хөгжлийн бэрх|эрүүл|хоол|жин|өндөр") ~ "health_disability_nutrition",
    str_detect(txt, "income|consumption|expenditure|transfer|орлого|зарлага|хэрэглээ") ~ "income_consumption",
    TRUE ~ "other"
  )
}

read_meta <- function(path) {
  dat <- read_sav(path, n_max = 0)
  nms <- names(dat)
  labels <- vapply(dat, function(x) {
    lab <- attr(x, "label", exact = TRUE)
    if (is.null(lab)) "" else as.character(lab)
  }, character(1))
  tibble(
    source_file = normalizePath(path, winslash = "/", mustWork = FALSE),
    survey_folder = basename(dirname(path)),
    file_name = basename(path),
    variable_name = nms,
    variable_label = labels,
    family = classify_var(nms, labels)
  )
}

inventory <- map_dfr(mics_files, read_meta)

file_summary <- inventory |>
  count(survey_folder, file_name, name = "n_variables") |>
  arrange(survey_folder, file_name)

family_summary <- inventory |>
  count(survey_folder, family, name = "n_variables") |>
  arrange(survey_folder, desc(n_variables))

candidate_patterns <- c(
  "wealth|asset|dwelling|floor|roof|wall|water|toilet|sanitation|electric|internet|computer|livestock",
  "school|education|attendance|grade|reading|numeracy|literacy|child labour|work",
  "mother.*education|father.*education|parent.*education|orphan|living with mother|living with father",
  "region|urban|rural|aimag|cluster|weight"
)

candidate_vars <- inventory |>
  filter(str_detect(str_to_lower(paste(variable_name, variable_label)), paste(candidate_patterns, collapse = "|"))) |>
  mutate(
    possible_use = case_when(
      family == "wealth_assets_housing" ~ "Build region/urban-year childhood household-environment or wealth-context proxy; cannot individual-link to HSES.",
      family == "education_schooling" ~ "External validation / descriptive context for schooling access or youth school outcomes.",
      family == "parents_family" ~ "Check whether parental education/family background patterns can validate HSES parent_educ_mean story.",
      family == "demographics_geo_weights" ~ "Needed for aggregation: region, urban/rural, cluster, weights.",
      family == "work_child_labour" ~ "Possible child-labour context proxy, but not directly linkable to adult HSES outcomes.",
      TRUE ~ "Potential supporting context only."
    ),
    recommended_role = case_when(
      family %in% c("wealth_assets_housing", "education_schooling") ~ "auxiliary contextual variable / robustness threshold candidate after aggregation",
      family == "demographics_geo_weights" ~ "merge/aggregation key or survey design variable",
      TRUE ~ "descriptive validation only"
    )
  ) |>
  arrange(survey_folder, family, variable_name)

write_csv(inventory, file.path(PATHS$out_tables, "T12_mics_nuts_variable_inventory.csv"))
write_csv(file_summary, file.path(PATHS$out_tables, "T12_mics_nuts_file_summary.csv"))
write_csv(family_summary, file.path(PATHS$out_tables, "T12_mics_nuts_family_summary.csv"))
write_csv(candidate_vars, file.path(PATHS$out_tables, "T12_mics_nuts_candidate_variables.csv"))

report_lines <- c(
  "# NUTS/MICS Inventory for HSES Returns-to-Education Project",
  "",
  paste0("Generated: ", Sys.time()),
  "",
  "## Local Data Found",
  paste0("- Local MICS/NUTS .sav files found: ", length(mics_files)),
  paste0("- Survey folders: ", paste(unique(inventory$survey_folder), collapse = ", ")),
  "",
  "## Main Relevant Families",
  "- wealth_assets_housing: useful for household-environment/wealth-context proxies, but not directly linkable to adult HSES individuals.",
  "- education_schooling: useful for validating school-access and youth schooling environment measures.",
  "- parents_family: useful for validating family-background patterns, not for replacing the parent_educ_mean IV.",
  "- demographics_geo_weights: needed to aggregate by region/urban/year and apply MICS weights.",
  "",
  "## Econometric Recommendation",
  "- Do not merge MICS microdata to HSES at the individual level; the samples contain different people.",
  "- Use MICS as auxiliary/contextual data aggregated by region x urban/rural x survey year, or at broader region/year level if aimag is unavailable.",
  "- Candidate contextual thresholds could include regional child household wealth index, housing deprivation, internet/computer access, school attendance, or child labour rates.",
  "- These are contextual proxies, not individual childhood measures for HSES adults.",
  "- Because HSES adults in the wage sample are mostly born before the MICS child cohorts, MICS is better for external validation and current/period context than exact childhood exposure.",
  "",
  "## Output Tables",
  "- output/tables/T12_mics_nuts_variable_inventory.csv",
  "- output/tables/T12_mics_nuts_file_summary.csv",
  "- output/tables/T12_mics_nuts_family_summary.csv",
  "- output/tables/T12_mics_nuts_candidate_variables.csv"
)

writeLines(report_lines, file.path(PATHS$out_root, "reports", "mics_nuts_inventory_for_hses_project.md"), useBytes = TRUE)

cat("File summary:\n")
print(file_summary, n = Inf)
cat("\nFamily summary:\n")
print(family_summary, n = Inf)
cat("\nCandidate variables sample:\n")
print(head(candidate_vars, 50), n = 50)
cat("\nCompleted:", as.character(Sys.time()), "\n")
