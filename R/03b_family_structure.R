# =============================================================================
# 03b_family_structure.R
# -----------------------------------------------------------------------------
# Зорилго : HSES household roster-аас family-IV candidates extract хийх:
#             - father_educ, mother_educ (parents living in same household)
#             - n_siblings, birth_order
#             - q0105m extraction (birth month if available, для quarter-of-birth)
# Орц     : data/raw/hses_raw.rds (R/02 гарц)
# Гарц    : data/processed/family_structure.rds
#           output/logs/03b_family_coverage.log
# =============================================================================
# Variable usage:
#   q0102 = relation to head; 1=head, 2=spouse, 3=child, 4=parent, ...
#   q0103 = sex; 1=male, 2=female
#   q0210 = education level (1-10 scale; 1=Боловсролгүй ... 10=Доктор)
#   q0213 = total schooling years
#   q0107 = spouse's ind_id (для head ↔ spouse pairing)
# Identifiers: identif (household), ind_id (person within household)
# =============================================================================

source(here::here("R", "paths.R"))
suppressPackageStartupMessages({
  library(dplyr); library(tidyr); library(purrr); library(readr)
  library(haven); library(labelled); library(cli); library(tictoc)
})

cli::cli_h1("03b_family_structure.R — parental educ + siblings + birth month")
tic("Total")

raw <- readRDS(file.path(PATHS$data_raw, "hses_raw.rds"))
get_df <- function(w, t) {
  d <- raw |> dplyr::filter(wave == w, type == t) |> dplyr::pull(data)
  if (length(d) == 0L || is.null(d[[1L]])) NULL else d[[1L]]
}

KEEP_WAVES <- c(2020L, 2021L, 2022L, 2024L)

zap <- function(x) {
  if (inherits(x, "haven_labelled")) labelled::remove_labels(x) |> as.numeric()
  else if (is.factor(x)) as.numeric(as.character(x))
  else as.numeric(x)
}

grab <- function(df, col) {
  if (col %in% names(df)) zap(df[[col]]) else rep(NA_real_, nrow(df))
}

# ---- Per-wave processor ------------------------------------------------------
process_wave <- function(w) {
  cli::cli_alert("[{w}] processing roster...")
  ind <- get_df(w, "indiv")
  if (is.null(ind)) return(NULL)

  ind_full <- tibble(
    identif       = as.numeric(ind$identif),
    ind_id        = as.numeric(ind$ind_id),
    relation_head = grab(ind, "q0102"),
    sex           = grab(ind, "q0103"),
    age           = grab(ind, "q0105y"),
    age_m         = grab(ind, "q0105m"),     # might be NA
    educ_level    = grab(ind, "q0210"),
    educ_years    = grab(ind, "q0213"),
    spouse_id     = grab(ind, "q0107")
  ) |>
    mutate(wave = w)

  # ---- 1. Identify head + spouse per household ----
  head_df <- ind_full |> filter(relation_head == 1L) |>
    transmute(identif, head_ind_id = ind_id,
              head_sex = sex, head_educ_level = educ_level, head_educ_years = educ_years,
              head_age = age, head_spouse_id = spouse_id)

  spouse_df <- ind_full |> filter(relation_head == 2L) |>
    transmute(identif, spouse_ind_id = ind_id,
              sp_sex = sex, sp_educ_level = educ_level, sp_educ_years = educ_years,
              sp_age = age)

  hh <- head_df |>
    left_join(spouse_df, by = "identif") |>
    distinct(identif, .keep_all = TRUE)

  # ---- 2. For each respondent: derive parental educ if relation_head == 3 ----
  # Children get head's + spouse's education as proxies for father/mother
  # (head can be male or female; pick by sex)
  ind_with_parents <- ind_full |>
    left_join(hh, by = "identif") |>
    mutate(
      is_child_of_head = relation_head == 3L,
      father_educ_level = case_when(
        !is_child_of_head           ~ NA_real_,
        head_sex == 1 & !is.na(head_educ_level) ~ head_educ_level,
        sp_sex   == 1 & !is.na(sp_educ_level)   ~ sp_educ_level,
        TRUE                                    ~ NA_real_
      ),
      mother_educ_level = case_when(
        !is_child_of_head           ~ NA_real_,
        head_sex == 2 & !is.na(head_educ_level) ~ head_educ_level,
        sp_sex   == 2 & !is.na(sp_educ_level)   ~ sp_educ_level,
        TRUE                                    ~ NA_real_
      ),
      father_educ_years = case_when(
        !is_child_of_head           ~ NA_real_,
        head_sex == 1 & !is.na(head_educ_years) ~ head_educ_years,
        sp_sex   == 1 & !is.na(sp_educ_years)   ~ sp_educ_years,
        TRUE                                    ~ NA_real_
      ),
      mother_educ_years = case_when(
        !is_child_of_head           ~ NA_real_,
        head_sex == 2 & !is.na(head_educ_years) ~ head_educ_years,
        sp_sex   == 2 & !is.na(sp_educ_years)   ~ sp_educ_years,
        TRUE                                    ~ NA_real_
      )
    )

  # ---- 3. Siblings: count of fellow "children of head" within household + birth order
  child_in_hh <- ind_full |>
    filter(relation_head == 3L) |>
    group_by(identif) |>
    arrange(desc(age), .by_group = TRUE) |>
    mutate(
      n_children_in_hh  = n(),
      birth_order_hh    = row_number()   # 1 = oldest
    ) |>
    ungroup() |>
    select(identif, ind_id, n_children_in_hh, birth_order_hh)

  ind_with_parents <- ind_with_parents |>
    left_join(child_in_hh, by = c("identif", "ind_id")) |>
    mutate(
      n_siblings = if_else(is_child_of_head, n_children_in_hh - 1L, NA_integer_),
      birth_order = if_else(is_child_of_head, birth_order_hh, NA_integer_)
    ) |>
    select(-n_children_in_hh, -birth_order_hh)

  # Build id column to match analysis_sample
  ind_with_parents |>
    mutate(id = sprintf("%d-%.0f-%.0f", wave, identif, ind_id)) |>
    select(id, wave, identif, ind_id, is_child_of_head,
           father_educ_level, mother_educ_level,
           father_educ_years, mother_educ_years,
           n_siblings, birth_order, age_m)
}

panels <- purrr::map(KEEP_WAVES, process_wave)
fam <- bind_rows(panels)
cli::cli_alert_success("Family panel: {nrow(fam)} rows × {ncol(fam)} cols")

# ---- 4. Coverage report ------------------------------------------------------
coverage <- fam |>
  group_by(wave) |>
  summarise(
    n_total          = n(),
    n_child_of_head  = sum(is_child_of_head, na.rm = TRUE),
    pct_father_educ  = round(100 * mean(!is.na(father_educ_level)), 2),
    pct_mother_educ  = round(100 * mean(!is.na(mother_educ_level)), 2),
    pct_n_siblings   = round(100 * mean(!is.na(n_siblings)), 2),
    pct_age_m        = round(100 * mean(!is.na(age_m) & age_m > 0), 2),
    .groups = "drop"
  )
cli::cli_h2("Coverage by wave")
print(coverage)

# ---- 5. Cross with analysis_sample to get effective wage-panel coverage ----
analysis <- readRDS(file.path(PATHS$data_proc, "analysis_sample.rds")) |> as_tibble()
joined <- analysis |>
  filter(main_flag_25_60 == 1L, !is.na(q_home), is.finite(q_home)) |>
  select(id, age, lwage, educ_years, hhweight) |>
  left_join(fam |> select(id, father_educ_level, mother_educ_level,
                          father_educ_years, mother_educ_years,
                          n_siblings, birth_order, age_m,
                          is_child_of_head),
            by = "id")

eff_coverage <- joined |>
  summarise(
    n_main_home          = n(),
    n_father_educ        = sum(!is.na(father_educ_level)),
    n_mother_educ        = sum(!is.na(mother_educ_level)),
    n_either_parent      = sum(!is.na(father_educ_level) | !is.na(mother_educ_level)),
    n_siblings_obs       = sum(!is.na(n_siblings)),
    pct_father_educ      = round(100 * n_father_educ / n_main_home, 2),
    pct_mother_educ      = round(100 * n_mother_educ / n_main_home, 2),
    pct_either_parent    = round(100 * n_either_parent / n_main_home, 2),
    pct_siblings         = round(100 * n_siblings_obs / n_main_home, 2)
  )
cli::cli_h2("EFFECTIVE coverage in MAIN home_aimag wage-panel sample")
print(eff_coverage)

# ---- 6. Хадгалах + лог ------------------------------------------------------
out_path <- file.path(PATHS$data_proc, "family_structure.rds")
saveRDS(fam, out_path)
write_csv(coverage,     file.path(PATHS$out_logs, "03b_family_coverage_by_wave.csv"))
write_csv(eff_coverage, file.path(PATHS$out_logs, "03b_family_eff_coverage_main.csv"))

log_path <- file.path(PATHS$out_logs, "03b_family_coverage.log")
sink(log_path, append = FALSE)
cat("==========================================================\n")
cat("03b_family_structure.R лог  ", as.character(Sys.time()), "\n")
cat("==========================================================\n")
cat(sprintf("Total roster rows extracted: %d\n", nrow(fam)))
cat("\nCoverage by wave (in full indiv panel):\n"); print(coverage)
cat("\nEffective coverage in MAIN home_aimag wage panel (n=9,077):\n")
print(eff_coverage)
cat("\nDecision rule:\n")
cat("  - n_either_parent ≥ 3,000: parental IV viable\n")
cat("  - n_siblings_obs ≥ 3,000: siblings IV viable\n")
sink()

toc()
cli::cli_alert_success("Гарц: {out_path}")
