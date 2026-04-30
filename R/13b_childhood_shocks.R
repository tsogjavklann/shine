# HSES 2020-2024 childhood shock variable scan.

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

dir.create("data/auxiliary", recursive = TRUE, showWarnings = FALSE)
dir.create("output/tables", recursive = TRUE, showWarnings = FALSE)
dir.create("output/reports", recursive = TRUE, showWarnings = FALSE)
dir.create("output/logs", recursive = TRUE, showWarnings = FALSE)

sink("output/logs/13b_childhood_shocks.log", split = TRUE)
on.exit(sink(), add = TRUE)

cat("13b_childhood_shocks.R\n")
cat("Started:", as.character(Sys.time()), "\n\n")

inventory_path <- "data/auxiliary/hses_variable_inventory.csv"
preview_path <- "data/auxiliary/hses_variable_preview.csv"
if (!file.exists(inventory_path)) stop("Missing ", inventory_path, ". Run R/13a_hses_variable_inventory.R first.")
if (!file.exists(preview_path)) stop("Missing ", preview_path, ". Run R/13a_hses_variable_inventory.R first.")

inv <- read_csv(inventory_path, show_col_types = FALSE)
preview <- read_csv(preview_path, show_col_types = FALSE)

normalize_inventory <- function(x) {
  if (!"label_mn" %in% names(x) && "label" %in% names(x)) x <- mutate(x, label_mn = label)
  if (!"label_en" %in% names(x)) x <- mutate(x, label_en = label_mn)
  if (!"waves_present" %in% names(x)) x <- mutate(x, waves_present = NA_character_)
  if (!"category" %in% names(x)) x <- mutate(x, category = NA_character_)
  if (!"n_obs" %in% names(x) && "total_obs" %in% names(x)) x <- mutate(x, n_obs = total_obs)
  if (!"n_missing" %in% names(x)) x <- mutate(x, n_missing = NA_real_)
  if (!"n_unique" %in% names(x) && "avg_unique" %in% names(x)) x <- mutate(x, n_unique = avg_unique)
  if (!"n_unique" %in% names(x)) x <- mutate(x, n_unique = NA_real_)
  x %>%
    mutate(
      label_mn = coalesce(as.character(label_mn), ""),
      label_en = coalesce(as.character(label_en), ""),
      search_text = str_to_lower(paste(var_name, label_mn, label_en, category, sep = " | "))
    )
}

inv <- normalize_inventory(inv)

preview_compact <- preview %>%
  mutate(label_mn = coalesce(as.character(label_mn), ""),
         label_en = coalesce(as.character(label_en), ""),
         value_labels = coalesce(as.character(value_labels), ""),
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
  ~section, ~pattern, ~english_description,
  "A_migration_history", "нүү|шилж|суурьш|оршин|5-н жилийн өмнө|5 жилийн өмнө|migration|moved|resid|lived", "Migration, years lived, previous residence",
  "B_ethnicity_religion", "үндэс|угсаа|яс|шашин|казах|буриад|дөрвөд|халх|ethnic|religion|nationality|mother tongue|төрөлх хэл", "Ethnicity, religion, language",
  "C_parental_occupation", "эцэг|эх|аав|ээж|малчин|мал аж ахуй|ажил мэргэжил|occupation|profession|herder|parent", "Parents, herder, occupation",
  "D_early_health_disability", "хүүхэд нас|эрүүл|өвчин|эмнэл|хөгжлийн бэрхшээл|хүндрэл|disability|illness|chronic|health", "Health, disability, illness",
  "E_household_young_age", "ах|эгч|дүү|төрсөн дараалал|siblings|birth order|өрхийн ам бүл|өрхийн гишүүд", "Siblings and household composition",
  "F_family_disruption", "өнчин|нас бар|салсан|бэлэвсэн|өрх толгойл|single|orphan|widow|deceased|divorce", "Family disruption"
)

manual_gems <- tribble(
  ~var_name, ~hidden_gem_note,
  "q0114a", "HIDDEN_GEM: birthplace aimag, useful for validating birth_aimag mapping",
  "q0114b", "HIDDEN_GEM: birthplace soum/district, finer geography exists for 2020-2022",
  "q0118a", "HIDDEN_GEM: in 2024 birthplace aimag; in older waves last migration origin aimag",
  "q0118b", "HIDDEN_GEM: in 2024 birthplace soum; in older waves last migration origin soum",
  "q0116",  "HIDDEN_GEM: ever migrated in 2020-2022; different meaning in 2024",
  "q0119",  "HIDDEN_GEM: last migration year / years living here",
  "q0120",  "HIDDEN_GEM: migration reason in 2020-2022; ever migrated in 2024",
  "q0121a", "HIDDEN_GEM: 5-years-ago aimag in 2020-2022",
  "q0121b", "HIDDEN_GEM: 5-years-ago soum in 2020-2022",
  "q0123",  "HIDDEN_GEM: last migration year in 2024",
  "q0124",  "HIDDEN_GEM: migration reason in 2024, includes education and natural disaster",
  "q0125a", "HIDDEN_GEM: 5-years-ago aimag in 2024",
  "q0125b", "HIDDEN_GEM: 5-years-ago soum in 2024",
  "q0215",  "HIDDEN_GEM: school dropout indicator; outcome-proximate, not clean IV",
  "q0217",  "HIDDEN_GEM: dropout reason, includes finance, distance, migration, health; not clean IV",
  "q0218",  "HIDDEN_GEM: never-attended-school reason, includes distance and dormitory shortage; not clean IV",
  "q0328_6","HIDDEN_GEM: native-language communication difficulty proxy; no clean ethnicity variable found"
)

hits <- map_dfr(seq_len(nrow(sections)), function(i) {
  s <- sections[i, ]
  inv %>%
    filter(str_detect(search_text, regex(s$pattern, ignore_case = TRUE))) %>%
    mutate(section = s$section, english_description = s$english_description, pattern = s$pattern)
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
    n_obs, n_missing, n_unique, preview_waves, missing_rate_min, missing_rate_max,
    top_10_values, value_labels, english_description, finding, hidden_gem
  ) %>%
  arrange(section, desc(hidden_gem), var_name)

empty_sections <- sections$section[!sections$section %in% unique(hits$section)]

write_csv(hits, "output/tables/T2e_childhood_shock_variable_hits.csv")
write_csv(hits %>% filter(hidden_gem | section %in% c("A_migration_history", "B_ethnicity_religion", "C_parental_occupation", "D_early_health_disability")),
          "data/auxiliary/hses_childhood_shock_candidates.csv")

section_counts <- hits %>% count(section, name = "n_hits")
write_csv(section_counts, "output/tables/T2e_childhood_shock_section_counts.csv")

report_lines <- c(
  "# Childhood Shock Variable Detection",
  "",
  paste0("Generated: ", Sys.time()),
  "",
  "## Search Results",
  ""
)

for (s in sections$section) {
  n <- sum(hits$section == s)
  report_lines <- c(report_lines, paste0("### ", s), "")
  if (n == 0) {
    report_lines <- c(report_lines, "no relevant variable found", "")
  } else {
    top <- hits %>% filter(section == s) %>% arrange(desc(hidden_gem), var_name) %>% head(20)
    report_lines <- c(
      report_lines,
      paste0("Hits: ", n),
      "",
      paste0("- ", top$var_name, ": ", top$label_mn, " / ", top$label_en,
             ifelse(top$hidden_gem, " [HIDDEN_GEM]", "")),
      ""
    )
  }
}

report_lines <- c(
  report_lines,
  "## Empty Sections",
  if (length(empty_sections) == 0) "none" else paste("- no relevant variable found:", empty_sections),
  "",
  "## Key Empirical Notes",
  "- Migration variables exist, but wording changes in 2024; q0116/q0120 must be wave-specific.",
  "- Birthplace aimag/soum variables exist and should be used to validate existing birth_aimag/birth_soum.",
  "- Dropout and reason variables exist, but are education-outcome-proximate and should not be treated as clean excluded IVs.",
  "- No direct clean ethnicity/religion variable was identified in this scan; q0328_6 is language-communication difficulty, not ethnicity."
)

writeLines(report_lines, "output/reports/childhood_shocks_detection.md", useBytes = TRUE)

cat("Hits:", nrow(hits), "\n")
print(section_counts, n = Inf)
cat("\n13b complete.\n")


