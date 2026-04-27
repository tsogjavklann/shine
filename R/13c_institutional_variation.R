# HSES 2020-2024 institutional variation scan.

options(warn = 1, encoding = "UTF-8")

required_pkgs <- c("dplyr", "stringr", "readr", "tibble", "purrr")
missing_pkgs <- required_pkgs[!vapply(required_pkgs, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_pkgs) > 0) stop("Missing packages: ", paste(missing_pkgs, collapse = ", "))

suppressPackageStartupMessages({
  library(dplyr)
  library(stringr)
  library(readr)
  library(tibble)
  library(purrr)
})

dir.create("output/tables", recursive = TRUE, showWarnings = FALSE)
dir.create("output/reports", recursive = TRUE, showWarnings = FALSE)
dir.create("output/logs", recursive = TRUE, showWarnings = FALSE)

sink("output/logs/13c_institutional_variation.log", split = TRUE)
on.exit(sink(), add = TRUE)

cat("13c_institutional_variation.R\n")
cat("Started:", as.character(Sys.time()), "\n\n")

inventory_path <- "data/aux/hses_variable_inventory.csv"
preview_path <- "data/aux/hses_variable_preview.csv"
if (!file.exists(inventory_path)) stop("Missing ", inventory_path, ". Run R/13a_hses_variable_inventory.R first.")
if (!file.exists(preview_path)) stop("Missing ", preview_path, ". Run R/13a_hses_variable_inventory.R first.")

inv <- read_csv(inventory_path, show_col_types = FALSE)
preview <- read_csv(preview_path, show_col_types = FALSE)

if (!"label_mn" %in% names(inv) && "label" %in% names(inv)) inv <- mutate(inv, label_mn = label)
if (!"label_en" %in% names(inv)) inv <- mutate(inv, label_en = label_mn)
if (!"waves_present" %in% names(inv)) inv <- mutate(inv, waves_present = NA_character_)
if (!"category" %in% names(inv)) inv <- mutate(inv, category = NA_character_)
if (!"n_obs" %in% names(inv) && "total_obs" %in% names(inv)) inv <- mutate(inv, n_obs = total_obs)
if (!"n_unique" %in% names(inv) && "avg_unique" %in% names(inv)) inv <- mutate(inv, n_unique = avg_unique)
if (!"n_unique" %in% names(inv)) inv <- mutate(inv, n_unique = NA_real_)

inv <- inv %>%
  mutate(
    label_mn = coalesce(as.character(label_mn), ""),
    label_en = coalesce(as.character(label_en), ""),
    category = coalesce(as.character(category), ""),
    search_text = str_to_lower(paste(var_name, label_mn, label_en, category, sep = " | "))
  )

preview_compact <- preview %>%
  mutate(value_labels = coalesce(as.character(value_labels), ""),
         top_10_values = coalesce(as.character(top_10_values), "")) %>%
  group_by(var_name) %>%
  summarise(
    preview_waves = paste(sort(unique(wave)), collapse = ","),
    preview_files = paste(sort(unique(source_type)), collapse = ","),
    missing_rate_min = suppressWarnings(min(missing_rate, na.rm = TRUE)),
    missing_rate_max = suppressWarnings(max(missing_rate, na.rm = TRUE)),
    top_10_values = paste(unique(na.omit(top_10_values))[1:min(3, length(unique(na.omit(top_10_values))))], collapse = " || "),
    value_labels = paste(unique(na.omit(value_labels))[1:min(3, length(unique(na.omit(value_labels))))], collapse = " || "),
    .groups = "drop"
  )

sections <- tribble(
  ~section, ~pattern, ~description,
  "A_dormitory_access", "дотуур байр|boarding|dormitory|суралцах хугацаандаа хаана амьдар", "Dormitory and boarding access",
  "B_school_type", "өмчийн хэлбэр|улсын|хувийн|private school|public school|vocational|мэргэжлийн сургууль|МСҮТ|шашны сургууль", "School ownership/type",
  "C_soum_level_geography", "сум|дүүрэг|soum|district|q0114b|q0118b|q0121b|q0125b|aimagsoum", "Soum-level geography",
  "D_birthplace_type", "хаана төрсөн|төрсөн бэ|born|аймгийн төв|сумын төв|хөдөө|нийслэл", "Birthplace and place type",
  "E_schooling_shocks", "завсард|сургуулиас гарсан|сургуульд суралцаагүй|dropout|left school|тасал|хэтэрхий хол|дотуур байр хүрэлцээгүй", "Dropout, nonattendance, distance, dorm shortage"
)

manual_gems <- tribble(
  ~var_name, ~hidden_gem_note,
  "q0222", "HIDDEN_GEM: current student's living arrangement includes dormitory",
  "q0223", "HIDDEN_GEM: school transport includes walking/bus/dormitory living",
  "q0221", "HIDDEN_GEM: current school location, capital/aimag center/soum center",
  "q0220", "HIDDEN_GEM: current school ownership, public/private",
  "q0215", "HIDDEN_GEM: dropout indicator; post-treatment for completed education",
  "q0216", "HIDDEN_GEM: grade at dropout; post-treatment for completed education",
  "q0217", "HIDDEN_GEM: dropout reason includes finance, work, health, distance, migration",
  "q0218", "HIDDEN_GEM: never-attended reason includes distance and dormitory shortage",
  "q0114b", "HIDDEN_GEM: birthplace soum/district for 2020-2022",
  "q0118b", "HIDDEN_GEM: birthplace soum/district for 2024; older waves last migration origin soum",
  "birth_soum", "HIDDEN_GEM: processed birth soum already exists in analysis sample"
)

hits <- map_dfr(seq_len(nrow(sections)), function(i) {
  s <- sections[i, ]
  inv %>%
    filter(str_detect(search_text, regex(s$pattern, ignore_case = TRUE)) | var_name %in% c("birth_soum", "q0114b", "q0118b", "q0121b", "q0125b")) %>%
    mutate(section = s$section, institutional_description = s$description, pattern = s$pattern)
}) %>%
  distinct(section, var_name, .keep_all = TRUE) %>%
  left_join(preview_compact, by = "var_name") %>%
  left_join(manual_gems, by = "var_name") %>%
  mutate(
    hidden_gem = !is.na(hidden_gem_note),
    finding = if_else(hidden_gem, hidden_gem_note, "candidate_or_context_variable")
  ) %>%
  select(
    section, var_name, label_mn, label_en, category, waves_present,
    n_obs, n_unique, preview_waves, missing_rate_min, missing_rate_max,
    top_10_values, value_labels, institutional_description, finding, hidden_gem
  ) %>%
  arrange(section, desc(hidden_gem), var_name)

write_csv(hits, "output/tables/T2e_institutional_variation_hits.csv")
write_csv(hits %>% count(section, name = "n_hits"), "output/tables/T2e_institutional_variation_section_counts.csv")

report_lines <- c(
  "# Institutional Variation Scan",
  "",
  paste0("Generated: ", Sys.time()),
  "",
  "## Findings",
  ""
)

for (s in sections$section) {
  tmp <- hits %>% filter(section == s) %>% arrange(desc(hidden_gem), var_name)
  report_lines <- c(report_lines, paste0("### ", s), "")
  if (nrow(tmp) == 0) {
    report_lines <- c(report_lines, "no relevant variable found", "")
  } else {
    report_lines <- c(
      report_lines,
      paste0("Hits: ", nrow(tmp)),
      "",
      paste0("- ", head(tmp$var_name, 25), ": ", head(tmp$label_mn, 25), " / ", head(tmp$label_en, 25),
             ifelse(head(tmp$hidden_gem, 25), " [HIDDEN_GEM]", "")),
      ""
    )
  }
}

report_lines <- c(
  report_lines,
  "## Empirical Use Warning",
  "- q0220-q0223 are observed only for current students, so adult wage-sample coverage is expected to be low.",
  "- q0215-q0218 are education-outcome-proximate. They are useful for mechanisms, not clean excluded IVs.",
  "- Soum identifiers create finer geography, but require external soum-level historical shocks to become plausible IVs."
)

writeLines(report_lines, "output/reports/institutional_variation_scan.md", useBytes = TRUE)

cat("Hits:", nrow(hits), "\n")
print(hits %>% count(section, name = "n_hits"), n = Inf)
cat("\n13c complete.\n")
