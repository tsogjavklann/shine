# Audit HSES birth_aimag construction from raw HSES files.

options(warn = 1, encoding = "UTF-8")

source(here::here("R", "paths.R"))
suppressPackageStartupMessages({
  library(dplyr)
  library(haven)
  library(labelled)
  library(readr)
  library(tibble)
})

dir.create(PATHS$out_tables, recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(PATHS$out_root, "reports"), recursive = TRUE, showWarnings = FALSE)
dir.create(PATHS$out_logs, recursive = TRUE, showWarnings = FALSE)

log_path <- file.path(PATHS$out_logs, "20_audit_hses_birth_aimag.log")
sink(log_path, split = TRUE)
on.exit(sink(), add = TRUE)

cat("20_audit_hses_birth_aimag.R\n")
cat("Started:", as.character(Sys.time()), "\n\n")

raw_path <- file.path(PATHS$data_raw, "hses_raw.rds")
harm_path <- file.path(PATHS$data_proc, "hses_harmonized.rds")
analysis_path <- file.path(PATHS$data_proc, "analysis_sample.rds")

if (!file.exists(raw_path)) stop("Missing ", raw_path)
if (!file.exists(harm_path)) stop("Missing ", harm_path)
if (!file.exists(analysis_path)) stop("Missing ", analysis_path)

raw <- readRDS(raw_path)
harm <- readRDS(harm_path) |> as_tibble()
analysis <- readRDS(analysis_path) |> as_tibble()

zap <- function(x) {
  if (inherits(x, "haven_labelled")) {
    labelled::remove_labels(x) |> as.numeric()
  } else if (is.factor(x)) {
    as.numeric(as.character(x))
  } else {
    suppressWarnings(as.numeric(x))
  }
}

pick_df <- function(w, t) {
  d <- raw |> filter(wave == w, type == t) |> pull(data)
  if (length(d) == 0L || is.null(d[[1L]])) NULL else d[[1L]]
}

grab <- function(df, col) {
  if (col %in% names(df)) zap(df[[col]]) else rep(NA_real_, nrow(df))
}

label_of <- function(df, col) {
  if (col %in% names(df)) as.character(labelled::var_label(df[[col]])) else NA_character_
}

source_spec <- tibble(
  wave = c(2020L, 2021L, 2022L, 2024L),
  born_current_col = c("q0113", "q0113", "q0113", "q0117"),
  birth_aimag_raw_col = c("q0114a", "q0114a", "q0114a", "q0118a"),
  birth_soum_raw_col = c("q0114b", "q0114b", "q0114b", "q0118b")
)

label_rows <- list()
audit_rows <- list()
mismatch_rows <- list()

for (i in seq_len(nrow(source_spec))) {
  w <- source_spec$wave[i]
  born_col <- source_spec$born_current_col[i]
  bcol_a <- source_spec$birth_aimag_raw_col[i]
  bcol_b <- source_spec$birth_soum_raw_col[i]

  ind <- pick_df(w, "indiv")
  bv <- pick_df(w, "basicvars")
  if (is.null(ind) || is.null(bv)) next

  label_rows[[as.character(w)]] <- tibble(
    wave = w,
    born_current_col = born_col,
    born_current_label = label_of(ind, born_col),
    birth_aimag_raw_col = bcol_a,
    birth_aimag_raw_label = label_of(ind, bcol_a),
    birth_soum_raw_col = bcol_b,
    birth_soum_raw_label = label_of(ind, bcol_b),
    current_aimag_col = "newaimag",
    current_aimag_label = label_of(bv, "newaimag")
  )

  raw_wave <- tibble(
    wave = w,
    identif = as.numeric(ind$identif),
    ind_id = as.numeric(ind$ind_id),
    born_in_current = grab(ind, born_col),
    birth_aimag_raw = grab(ind, bcol_a),
    birth_soum_raw = grab(ind, bcol_b)
  ) |>
    left_join(
      tibble(
        identif = as.numeric(bv$identif),
        newaimag_proxy_raw = grab(bv, "newaimag")
      ) |> distinct(identif, .keep_all = TRUE),
      by = "identif"
    ) |>
    mutate(
      expected_birth_aimag = case_when(
        born_in_current == 1 ~ newaimag_proxy_raw,
        born_in_current == 2 ~ birth_aimag_raw,
        TRUE ~ birth_aimag_raw
      ),
      id = sprintf("%d-%.0f-%.0f", wave, identif, ind_id)
    )

  h <- harm |>
    filter(wave == w) |>
    select(id, birth_aimag, birth_aimag_from_current, aimag, newaimag_proxy)

  joined <- raw_wave |> left_join(h, by = "id")

  audit_rows[[as.character(w)]] <- joined |>
    summarise(
      wave = first(wave),
      raw_N = n(),
      birth_aimag_nonmissing = sum(!is.na(birth_aimag)),
      birth_aimag_missing = sum(is.na(birth_aimag)),
      born_current_yes = sum(born_in_current == 1, na.rm = TRUE),
      born_current_no = sum(born_in_current == 2, na.rm = TRUE),
      born_current_missing = sum(is.na(born_in_current)),
      raw_birth_aimag_nonmissing = sum(!is.na(birth_aimag_raw)),
      raw_birth_aimag_missing = sum(is.na(birth_aimag_raw)),
      filled_from_current = sum(birth_aimag_from_current == 1, na.rm = TRUE),
      filled_from_raw = sum(!is.na(birth_aimag) & (is.na(birth_aimag_from_current) | birth_aimag_from_current != 1)),
      processed_equals_expected = sum(!is.na(birth_aimag) & !is.na(expected_birth_aimag) & birth_aimag == expected_birth_aimag),
      processed_differs_expected = sum(!is.na(birth_aimag) & !is.na(expected_birth_aimag) & birth_aimag != expected_birth_aimag),
      birth_equals_current = sum(!is.na(birth_aimag) & !is.na(newaimag_proxy) & birth_aimag == newaimag_proxy),
      birth_differs_current = sum(!is.na(birth_aimag) & !is.na(newaimag_proxy) & birth_aimag != newaimag_proxy),
      unique_birth_aimag = n_distinct(birth_aimag[!is.na(birth_aimag)]),
      .groups = "drop"
    )

  mismatch_rows[[as.character(w)]] <- joined |>
    filter(!is.na(birth_aimag), !is.na(expected_birth_aimag), birth_aimag != expected_birth_aimag) |>
    select(
      wave, id, born_in_current, birth_aimag_raw, newaimag_proxy_raw,
      birth_aimag_processed = birth_aimag
    ) |>
    head(20)
}

label_tbl <- bind_rows(label_rows)
audit_tbl <- bind_rows(audit_rows)
mismatch_tbl <- bind_rows(mismatch_rows)

analysis_tbl <- analysis |>
  group_by(wave) |>
  summarise(
    N = n(),
    birth_aimag_nonmissing = sum(!is.na(birth_aimag)),
    birth_aimag_from_current = sum(birth_aimag_from_current == 1, na.rm = TRUE),
    birth_equals_current = sum(!is.na(birth_aimag) & !is.na(newaimag_proxy) & birth_aimag == newaimag_proxy),
    birth_differs_current = sum(!is.na(birth_aimag) & !is.na(newaimag_proxy) & birth_aimag != newaimag_proxy),
    .groups = "drop"
  ) |>
  mutate(
    birth_aimag_from_current_share = birth_aimag_from_current / N,
    .after = birth_aimag_from_current
  )

ivtr_tbl <- if (file.exists(file.path(PATHS$data_proc, "ivtr_ready_parent_educ_mean_logdist.rds"))) {
  readRDS(file.path(PATHS$data_proc, "ivtr_ready_parent_educ_mean_logdist.rds")) |>
    as_tibble() |>
    group_by(wave) |>
    summarise(
      N = n(),
      birth_aimag_nonmissing = sum(!is.na(birth_aimag)),
      unique_birth_aimag = n_distinct(birth_aimag[!is.na(birth_aimag)]),
      .groups = "drop"
    )
} else {
  tibble()
}

write_csv(label_tbl, file.path(PATHS$out_tables, "T9_hses_birth_aimag_source_labels.csv"))
write_csv(audit_tbl, file.path(PATHS$out_tables, "T9_hses_birth_aimag_raw_harmonized_audit.csv"))
write_csv(analysis_tbl, file.path(PATHS$out_tables, "T9_hses_birth_aimag_analysis_sample_audit.csv"))
write_csv(ivtr_tbl, file.path(PATHS$out_tables, "T9_hses_birth_aimag_ivtr_sample_audit.csv"))
write_csv(mismatch_tbl, file.path(PATHS$out_tables, "T9_hses_birth_aimag_mismatches.csv"))

report_lines <- c(
  "# HSES birth_aimag Audit",
  "",
  paste0("Generated: ", Sys.time()),
  "",
  "## Construction Source",
  "- 2020, 2021, 2022: birth-place raw aimag source is `q0114a`; birth-place raw soum source is `q0114b`.",
  "- 2024: birth-place raw aimag source is `q0118a`; birth-place raw soum source is `q0118b`.",
  "- If the respondent reports being born in the current place (`q0113 == 1` in 2020-2022; `q0117 == 1` in 2024), `birth_aimag` is filled from household/current `newaimag`.",
  "- This means some `birth_aimag` values equal current aimag by construction, but only when the birth-in-current-place question says so.",
  "",
  "## Key Result",
  paste0("- processed_differs_expected total: ", sum(audit_tbl$processed_differs_expected, na.rm = TRUE)),
  paste0("- analysis_sample rows: ", nrow(analysis)),
  "",
  "## Files",
  "- `output/tables/T9_hses_birth_aimag_source_labels.csv`",
  "- `output/tables/T9_hses_birth_aimag_raw_harmonized_audit.csv`",
  "- `output/tables/T9_hses_birth_aimag_analysis_sample_audit.csv`",
  "- `output/tables/T9_hses_birth_aimag_ivtr_sample_audit.csv`",
  "- `output/tables/T9_hses_birth_aimag_mismatches.csv`"
)

writeLines(report_lines, file.path(PATHS$out_root, "reports", "hses_birth_aimag_audit.md"), useBytes = TRUE)

cat("Raw variable labels:\n")
print(label_tbl, width = Inf)
cat("\nRaw/harmonized audit:\n")
print(audit_tbl, width = Inf)
cat("\nAnalysis sample audit:\n")
print(analysis_tbl, width = Inf)
cat("\nIVTR sample audit:\n")
print(ivtr_tbl, width = Inf)
cat("\nMismatches expected vs processed:\n")
print(mismatch_tbl, width = Inf)
cat("\nCompleted:", as.character(Sys.time()), "\n")
