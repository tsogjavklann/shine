# =============================================================================
# 03_harmonize.R
# -----------------------------------------------------------------------------
# Зорилго : R/02-ийн raw_list-аас 4 wave (2020, 2021, 2022, 2024) дотор
#           variable нэр + кодлогдсон утгыг нэгтгэж harmonized panel үүсгэх.
#           2023 wave хасагдсан (labour-force-only sub-sample, education/
#           wage decomposition variables дутуу — R/02 codebook verification).
# Орц     : data/raw/hses_raw.rds
# Гарц    : data/processed/hses_harmonized.rds
# Лог     : output/logs/03_harmonize.log + 03_birth_aimag_coverage.csv
# =============================================================================
# Wave-specific birth_aimag mapping:
#   2020, 2021, 2022 → q0114a (q0114b = soum)
#   2024             → q0118a (q0118b = soum, асуулт 1.18 руу шилжсэн)
#   2023             → DROPPED entire wave
# =============================================================================

source(here::here("R", "paths.R"))
suppressPackageStartupMessages({
  library(dplyr); library(tidyr); library(purrr); library(readr)
  library(haven); library(labelled); library(cli); library(tictoc)
})

cli::cli_h1("03_harmonize.R")
tic("Total")

# ---- 1. raw_list ачаалах ----------------------------------------------------
raw_path <- file.path(PATHS$data_raw, "hses_raw.rds")
if (!file.exists(raw_path)) {
  cli::cli_abort("Орц олдсонгүй: {raw_path}. Эхлээд R/02_import_hses.R-г ажиллуул.")
}
raw <- readRDS(raw_path)
cli::cli_alert_info("raw_list ачаалсан: {nrow(raw)} (wave × type) row")

# Helper: pick a (wave, type) data frame
pick_df <- function(w, t) {
  d <- raw |> dplyr::filter(wave == w, type == t) |> dplyr::pull(data)
  if (length(d) == 0L || is.null(d[[1L]])) NULL else d[[1L]]
}

# ---- 2. WAVES (2023 excluded) -----------------------------------------------
KEEP_WAVES <- c(2020L, 2021L, 2022L, 2024L)

# ---- 3. Per-wave processor --------------------------------------------------
# birth_aimag/birth_soum ялгаатай: 2020-2022 → q0114a/b; 2024 → q0118a/b.
process_wave <- function(w) {
  cli::cli_alert("[{w}] processing...")

  ind <- pick_df(w, "indiv")
  bv  <- pick_df(w, "basicvars")
  if (is.null(ind) || is.null(bv)) {
    cli::cli_alert_warning("[{w}] indiv эсвэл basicvars дутуу — алгасч байна")
    return(NULL)
  }

  # Wave-specific birth aimag/soum source columns
  if (w %in% c(2020L, 2021L, 2022L)) {
    bcol_a <- "q0114a"; bcol_b <- "q0114b"
  } else if (w == 2024L) {
    bcol_a <- "q0118a"; bcol_b <- "q0118b"
  } else {
    bcol_a <- NA_character_; bcol_b <- NA_character_
  }

  # Strip haven_labelled to plain numeric for downstream regression safety
  zap <- function(x) {
    if (inherits(x, "haven_labelled")) labelled::remove_labels(x) |> as.numeric()
    else if (is.factor(x)) as.numeric(as.character(x))
    else x
  }

  # Pull a single column safely (returns NA vector if missing)
  grab <- function(df, col) {
    if (col %in% names(df)) zap(df[[col]]) else rep(NA_real_, nrow(df))
  }

  # ---- 3.1 indiv-level fields ----
  ind_std <- tibble(
    identif       = as.numeric(ind$identif),
    ind_id        = as.numeric(ind$ind_id),
    age           = grab(ind, "q0105y"),
    sex           = grab(ind, "q0103"),
    marital       = grab(ind, "q0106"),
    relation_head = grab(ind, "q0102"),
    educ_level    = grab(ind, "q0210"),
    educ_years    = grab(ind, "q0213"),
    work7d_pay    = grab(ind, "q0404"),       # 1=Yes, 2=No (HSES coding)
    q0436a        = grab(ind, "q0436a"),
    q0436b        = grab(ind, "q0436b"),
    q0436c        = grab(ind, "q0436c"),
    q0437         = grab(ind, "q0437"),
    q0438         = grab(ind, "q0438"),
    q0439         = grab(ind, "q0439"),
    q0427         = grab(ind, "q0427"),
    birth_aimag   = if (!is.na(bcol_a)) grab(ind, bcol_a) else NA_real_,
    birth_soum    = if (!is.na(bcol_b)) grab(ind, bcol_b) else NA_real_
  )

  # working_for_wage: 1 → 1, 2 → 0, NA → NA
  ind_std <- ind_std |>
    mutate(working_for_wage = case_when(
      work7d_pay == 1 ~ 1L,
      work7d_pay == 2 ~ 0L,
      TRUE            ~ NA_integer_
    ))

  # ---- 3.2 basicvars-level fields (household) ----
  bv_std <- tibble(
    identif         = as.numeric(bv$identif),
    aimag           = grab(bv, "newaimag"),
    newaimag_proxy  = grab(bv, "newaimag"),
    region          = grab(bv, "region"),
    urban           = grab(bv, "urban"),
    location        = grab(bv, "location"),
    hhsize          = grab(bv, "hhsize"),
    hhweight        = grab(bv, "hhweight"),
    month_interview = grab(bv, "month")
  ) |>
    distinct(identif, .keep_all = TRUE)

  # ---- 3.3 join ----
  out <- ind_std |>
    left_join(bv_std, by = "identif") |>
    mutate(
      wave            = w,
      year_month      = sprintf("%d-%02d", w, as.integer(month_interview)),
      birth_year      = wave - as.integer(age),
      id              = sprintf("%d-%.0f-%.0f", w, identif, ind_id)
    )

  cli::cli_alert_success(
    "[{w}] harmonized: {nrow(out)} мөр; ",
    "birth_aimag coverage: {round(100 * mean(!is.na(out$birth_aimag)), 1)}%; ",
    "educ_years coverage: {round(100 * mean(!is.na(out$educ_years)), 1)}%"
  )
  out
}

# ---- 4. Run all waves --------------------------------------------------------
panels <- purrr::map(KEEP_WAVES, process_wave)
panel <- bind_rows(panels)
cli::cli_alert_success("Pooled panel: {nrow(panel)} мөр × {ncol(panel)} багана ({length(KEEP_WAVES)} wave)")

# ---- 5. Validation ----------------------------------------------------------
# Educ_years range check (non-fatal; flag только)
bad_educ <- sum(panel$educ_years > 26 | panel$educ_years < 0, na.rm = TRUE)
if (bad_educ > 0) {
  cli::cli_alert_warning("educ_years range warning: {bad_educ} мөр (0-26 хязгаараас гадуур, NA-аар орлуулна)")
  panel <- panel |>
    mutate(educ_years = if_else(educ_years < 0 | educ_years > 26, NA_real_, educ_years))
}

# ---- 6. Coverage хүснэгт (wave × variable) ----------------------------------
coverage_tbl <- panel |>
  group_by(wave) |>
  summarise(
    n             = n(),
    n_age_25_60   = sum(age >= 25 & age <= 60, na.rm = TRUE),
    pct_birth_aimag = round(100 * mean(!is.na(birth_aimag)), 1),
    pct_newaimag    = round(100 * mean(!is.na(newaimag_proxy)), 1),
    pct_educ_years  = round(100 * mean(!is.na(educ_years)), 1),
    pct_q0436b      = round(100 * mean(!is.na(q0436b)), 1),
    pct_q0436a      = round(100 * mean(!is.na(q0436a)), 1),
    pct_q0427       = round(100 * mean(!is.na(q0427)), 1),
    pct_hhweight    = round(100 * mean(!is.na(hhweight)), 1),
    .groups = "drop"
  )
cli::cli_h2("Wave × coverage")
print(coverage_tbl)

write_csv(coverage_tbl, file.path(PATHS$out_logs, "03_birth_aimag_coverage.csv"))

# ---- 7. Хадгалах ------------------------------------------------------------
out_path <- file.path(PATHS$data_proc, "hses_harmonized.rds")
saveRDS(panel, out_path)

# Лог
log_path <- file.path(PATHS$out_logs, "03_harmonize.log")
sink(log_path, append = FALSE)
cat("==========================================================\n")
cat("03_harmonize.R лог  ", as.character(Sys.time()), "\n")
cat("==========================================================\n")
cat(sprintf("Waves kept (2023 excluded): %s\n", paste(KEEP_WAVES, collapse=", ")))
cat(sprintf("Pooled panel: %d rows × %d cols\n", nrow(panel), ncol(panel)))
cat(sprintf("\nColumn names:\n  %s\n\n", paste(names(panel), collapse=", ")))
cat("Wave × coverage (%):\n"); print(coverage_tbl)
cat("\nbad educ_years (>26 or <0) flagged → NA: ", bad_educ, "\n")
sink()

toc()
cli::cli_alert_success("Гарц: {out_path}  ({nrow(panel)} мөр)")
cli::cli_alert_info("Дараагийн алхам: R/04_wage_construction.R")
