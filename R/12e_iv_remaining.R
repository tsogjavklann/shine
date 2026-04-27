# =============================================================================
# 12e_iv_remaining.R
# -----------------------------------------------------------------------------
# Зорилго : Үлдсэн 6 IV-ийг empirical-аар шалгаж 14-row T2b table-ыг нэмэх.
# Орц     : data/processed/analysis_sample.rds
#           data/auxiliary/school_density_by_aimag.rds (R/05)
# Гарц    : output/tables/T2b_iv_search.csv (FULL UPDATE — 14 row)
#           output/logs/12e_iv_remaining.log
# =============================================================================
# Үлдсэн 6 IV statuses:
#   Spec 7  birth_order        — already in R/12b (F=0.42 USELESS); included as-is
#   Spec 8  quarter_of_birth   — SKIPPED (q0105m нь нярай нас, төрсөн сар БИШ)
#   Spec 10 pre_1990_supply    — NSO API check (likely SKIPPED, 2000+ only)
#   Spec 11 transition_shock   — SKIPPED (no aimag-GDP 1995-2000 data identified)
#   Spec 12 aimag × cohort     — Acemoglu-Angrist 2000-style; full sample IV
#   Spec 13 teacher_supply_17  — fetch DT_NSO_2001_001V1, density at age 17
#   Spec 14 urbanization_17    — fetch DT_NSO_0300_004V1 urban share at age 17
# =============================================================================

source(here::here("R", "paths.R"))
suppressPackageStartupMessages({
  library(dplyr); library(tidyr); library(readr); library(stringr)
  library(httr); library(jsonlite)
  library(fixest); library(cli); library(tictoc)
})
setFixest_estimation(panel.id = NULL)
set.seed(2026)

cli::cli_h1("12e_iv_remaining.R — remaining 6 IV specs")
tic("Total")

# ---- 0. NSO PXWeb fetcher (UTF-8 raw POST) ---------------------------------
fetch_pxweb <- function(url, body_str, retries = 3L) {
  body_raw <- charToRaw(enc2utf8(body_str))
  for (i in seq_len(retries)) {
    res <- tryCatch(
      httr::POST(url,
                 httr::add_headers("Content-Type" = "application/json; charset=utf-8",
                                   "Accept" = "application/json"),
                 body = body_raw, httr::timeout(60)),
      error = function(e) NULL)
    if (!is.null(res) && httr::status_code(res) == 200L) {
      txt <- httr::content(res, "text", encoding = "UTF-8")
      return(jsonlite::fromJSON(txt, simplifyVector = FALSE))
    }
  }
  NULL
}

# Parse json-stat2 → long tibble with all dim valueText cols + value
parse_jsonstat <- function(js) {
  if (is.null(js)) return(NULL)
  dim_ids <- unlist(js$id)
  dim_info <- lapply(dim_ids, function(d) {
    cat <- js$dimension[[d]]$category
    idx <- unlist(cat$index)
    lab <- unlist(cat$label)
    ord <- order(idx)
    list(name = d, codes = names(idx)[ord], labels = lab[names(idx)[ord]])
  })
  grid_lst_rev <- rev(setNames(lapply(dim_info, function(di) di$labels), dim_ids))
  grid_df <- expand.grid(grid_lst_rev, stringsAsFactors = FALSE, KEEP.OUT.ATTRS = FALSE)
  grid_df <- grid_df[, rev(seq_along(grid_df)), drop = FALSE]
  names(grid_df) <- dim_ids
  vals <- unlist(js$value, use.names = FALSE)
  n <- min(nrow(grid_df), length(vals))
  grid_df <- grid_df[seq_len(n), , drop = FALSE]
  grid_df$value <- suppressWarnings(as.numeric(vals[seq_len(n)]))
  as_tibble(grid_df)
}

# ---- 1. Aimag name → HSES code lookup ---------------------------------------
aimag_lookup <- read_csv(file.path(PATHS$data_aux, "aimag_lookup.csv"),
                         show_col_types = FALSE)
match_aimag <- function(name_vec) {
  trimmed <- str_trim(name_vec)
  aimag_lookup$hses_code[match(trimmed, aimag_lookup$aimag_mn)]
}

# ---- 2. Load analysis_sample + restrict ------------------------------------
df <- readRDS(file.path(PATHS$data_proc, "analysis_sample.rds")) |> as_tibble()
main <- df |>
  filter(main_flag_25_60 == 1L,
         !is.na(q_school_access), is.finite(q_school_access),
         !is.na(birth_year),
         !is.na(educ_years), !is.na(lwage),
         !is.na(age), !is.na(is_female), !is.na(is_married),
         !is.na(region), !is.na(wave), !is.na(aimag), !is.na(hhweight),
         !is.na(birth_aimag))
cli::cli_alert_info("MAIN home_aimag: {nrow(main)} rows")

# ---- 3. Spec 12: AIMAG × COHORT INTERACTION ---------------------------------
# Cohort bins (Acemoglu-Angrist 2000-style)
main <- main |>
  mutate(
    cohort_bin = case_when(
      birth_year >= 1960 & birth_year <= 1969 ~ "1960s",
      birth_year >= 1970 & birth_year <= 1979 ~ "1970s",
      birth_year >= 1980 & birth_year <= 1989 ~ "1980s",
      birth_year >= 1990 & birth_year <= 1995 ~ "1990-95",
      birth_year >= 1996 & birth_year <= 1997 ~ "donut",
      birth_year >= 1998                       ~ "post1998",
      TRUE ~ NA_character_
    )
  )

# Drop donut for IV (consistent with reform_main donut design)
main_iv <- main |> filter(cohort_bin != "donut" | is.na(cohort_bin))

# IV: aimag × cohort interaction; use as.factor on both
spec12_data <- main_iv |> filter(!is.na(cohort_bin))

# Number of (aimag × cohort) cells expected: 22 × 5 = 110, but minus donut → 5 bins
# minus baseline → 4 dummies × 22 aimags = 88 instruments

cli::cli_alert("Spec 12: aimag × cohort IV (Acemoglu-Angrist-style)")

# ---- 4. Spec 13: TEACHER_SUPPLY_AT_17 — fetch teachers from NSO ------------
# DT_NSO_2001_001V1 = ЕБС-ийн үндсэн багш, аймаг, нийслэл, жилээр
TEACHER_URL <- "https://data.1212.mn/api/v1/mn/NSO/Education,%20health/General%20educational%20schools/DT_NSO_2001_001V1.px"
cli::cli_alert("Spec 13: fetching teacher supply (DT_NSO_2001_001V1)...")
js_teach <- fetch_pxweb(TEACHER_URL, '{"query":[],"response":{"format":"json-stat2"}}')

teacher_supply <- if (!is.null(js_teach)) {
  t <- parse_jsonstat(js_teach)
  cli::cli_alert_success("Teacher table: {nrow(t)} rows")
  # Bus, Он column-уудыг detect
  t |> rename(aimag_mn = 1, year_chr = 2, teachers = value) |>
    mutate(hses_code = match_aimag(aimag_mn),
           year      = suppressWarnings(as.integer(str_trim(year_chr)))) |>
    filter(!is.na(hses_code), !is.na(year)) |>
    group_by(hses_code, year) |>
    summarise(teachers = first(teachers), .groups = "drop")
} else {
  cli::cli_alert_warning("Teacher fetch failed — Spec 13 will be SKIPPED")
  NULL
}

# Compute teacher_supply_at_17: at year = birth_year + 17
if (!is.null(teacher_supply)) {
  main_iv <- main_iv |>
    mutate(year_at_17 = birth_year + 17L) |>
    left_join(teacher_supply |> rename(teachers_at_17 = teachers),
              by = c("birth_aimag" = "hses_code", "year_at_17" = "year"))
  n_teach <- sum(!is.na(main_iv$teachers_at_17))
  cli::cli_alert_info("teachers_at_17 valid: {n_teach}/{nrow(main_iv)}")
}

# ---- 5. Spec 14: URBANIZATION_AT_17 — fetch DT_NSO_0300_004V1 --------------
# Хот/хөдөөгөөр population by aimag/year
URBAN_URL <- "https://data.1212.mn/api/v1/mn/NSO/Population,%20household/1_Population,%20household/DT_NSO_0300_004V1.px"
cli::cli_alert("Spec 14: fetching urbanization (DT_NSO_0300_004V1)...")
js_urban <- fetch_pxweb(URBAN_URL, '{"query":[],"response":{"format":"json-stat2"}}')

urbanization <- if (!is.null(js_urban)) {
  u <- parse_jsonstat(js_urban)
  cli::cli_alert_success("Urban table: {nrow(u)} rows × {ncol(u)} cols")
  cli::cli_alert_info("Columns: {paste(names(u), collapse = ', ')}")
  u
} else {
  cli::cli_alert_warning("Urban fetch failed — Spec 14 SKIPPED")
  NULL
}

urb_long <- NULL
if (!is.null(urbanization)) {
  # Detect "Хот" / "Хөдөө" dim values; columns vary by table
  # Standard: aimag (Бүс), year (Он), location (Бүсчилэл/Байршил), value
  loc_col <- names(urbanization)[3]  # third dim usually
  aimag_col <- names(urbanization)[1]
  year_col  <- names(urbanization)[2]

  urb_long <- urbanization |>
    rename(aimag_mn = !!aimag_col, year_chr = !!year_col,
           loc_chr = !!loc_col) |>
    mutate(hses_code = match_aimag(aimag_mn),
           year      = suppressWarnings(as.integer(str_trim(year_chr))),
           loc_clean = str_trim(loc_chr)) |>
    filter(!is.na(hses_code), !is.na(year))

  # Pivot to urban_share per (aimag, year)
  urb_wide <- urb_long |>
    group_by(hses_code, year, loc_clean) |>
    summarise(value = first(value), .groups = "drop") |>
    pivot_wider(names_from = loc_clean, values_from = value, values_fill = 0)
  cli::cli_alert_info("urb_wide cols: {paste(names(urb_wide), collapse=', ')}")
  # Common loc labels: "Хот", "Хөдөө"
  if ("Хот" %in% names(urb_wide) && "Хөдөө" %in% names(urb_wide)) {
    urb_wide <- urb_wide |>
      mutate(urban_share = `Хот` / pmax(`Хот` + `Хөдөө`, 1, na.rm = TRUE))
    main_iv <- main_iv |>
      left_join(urb_wide |> select(hses_code, year, urban_share),
                by = c("birth_aimag" = "hses_code", "year_at_17" = "year"))
    n_urb <- sum(!is.na(main_iv$urban_share))
    cli::cli_alert_info("urban_share at 17 valid: {n_urb}/{nrow(main_iv)}")
  } else {
    cli::cli_alert_warning("Хот/Хөдөө columns not found in urb_wide — using NA")
    main_iv$urban_share <- NA_real_
  }
}

# ---- 6. Spec 10 placeholder: pre-1990 schools ------------------------------
# Pre-1990 data check: schools table starts at 2001 in NSO. Use 2001 as oldest.
# This is "earliest available", treat as proxy for pre-reform supply.
# Skip: does not represent true pre-1990 supply.

# ---- 7. Run remaining IV specs ---------------------------------------------
CTRLS <- "age + age2 + is_female + is_married"
FE    <- "region + wave"

run_iv <- function(data, iv_expr, label, family,
                   require_n = 1000L) {
  iv_vars <- str_split(iv_expr, "\\s*\\+\\s*")[[1]]
  iv_vars_strip <- str_remove_all(iv_vars, "as\\.factor\\(|\\)|interaction\\(|,.*$")
  for (v in iv_vars_strip) {
    if (v %in% names(data)) data <- data[!is.na(data[[v]]), , drop = FALSE]
  }
  N <- nrow(data)
  if (N < require_n) {
    return(tibble(spec = label, family = family, N = N, iv = iv_expr,
                  pi_hat = NA, se_pi = NA, t_pi = NA, F_first = NA,
                  beta_iv = NA, se_beta = NA, sargan_p = NA_real_,
                  verdict = sprintf("⏭ N=%d < %d (skipped)", N, require_n)))
  }
  iv_str <- paste("lwage ~", CTRLS, "|", FE, "| educ_years ~", iv_expr)
  m_iv <- tryCatch(
    feols(as.formula(iv_str), data = data, weights = ~hhweight,
          cluster = ~aimag + wave),
    error = function(e) NULL)
  if (is.null(m_iv)) {
    return(tibble(spec = label, family = family, N = N, iv = iv_expr,
                  pi_hat = NA, se_pi = NA, t_pi = NA, F_first = NA,
                  beta_iv = NA, se_beta = NA, sargan_p = NA_real_,
                  verdict = "❌ FIT FAILED"))
  }
  # F (KP if available, else ivf1)
  fs_F <- tryCatch(fitstat(m_iv, "ivf1.kpr")[[1]]$stat, error = function(e) NA_real_)
  if (is.na(fs_F)) fs_F <- tryCatch(fitstat(m_iv, "ivf1")[[1]]$stat, error = function(e) NA_real_)
  endog_name <- grep("^fit_", names(coef(m_iv)), value = TRUE)
  if (length(endog_name) == 0L) endog_name <- "educ_years"
  beta <- coef(m_iv)[endog_name]
  se_b <- se(m_iv, cluster = ~aimag + wave)[endog_name]
  sargan_p <- tryCatch(fitstat(m_iv, "sargan")[[1]]$p, error = function(e) NA_real_)
  verdict <- case_when(
    is.na(fs_F) ~ "F NA",
    fs_F >= 10 ~ "✅ STRONG (F≥10)",
    fs_F >= 5  ~ "🟡 MARGINAL",
    fs_F >= 1  ~ "❌ WEAK (F<5)",
    TRUE       ~ "🚨 USELESS (F<1)"
  )
  tibble(spec = label, family = family, N = N, iv = iv_expr,
         pi_hat = NA_real_, se_pi = NA_real_, t_pi = NA_real_,
         F_first = unname(fs_F),
         beta_iv = unname(beta), se_beta = unname(se_b),
         sargan_p = sargan_p, verdict = verdict)
}

# Run Spec 12, 13, 14 + skip records for 8, 10, 11
new_results <- list()

# Spec 12: aimag × cohort
new_results$s12 <- run_iv(spec12_data,
                          "as.factor(birth_aimag) : as.factor(cohort_bin)",
                          "12 aimag x cohort", "Combo", require_n = 5000L)

# Spec 13: teacher_supply_at_17
if (!is.null(teacher_supply)) {
  new_results$s13 <- run_iv(main_iv |> filter(!is.na(teachers_at_17)),
                            "teachers_at_17",
                            "13 teacher_supply_17", "Supply",
                            require_n = 1000L)
} else {
  new_results$s13 <- tibble(spec = "13 teacher_supply_17", family = "Supply",
                            N = NA, iv = "teachers_at_17",
                            pi_hat = NA, se_pi = NA, t_pi = NA,
                            F_first = NA, beta_iv = NA, se_beta = NA,
                            sargan_p = NA_real_, verdict = "⏸ SKIPPED — NSO fetch failed")
}

# Spec 14: urbanization at 17
if (!is.null(urb_long) && "urban_share" %in% names(main_iv)) {
  new_results$s14 <- run_iv(main_iv |> filter(!is.na(urban_share)),
                            "urban_share",
                            "14 urbanization_17", "Supply",
                            require_n = 1000L)
} else {
  new_results$s14 <- tibble(spec = "14 urbanization_17", family = "Supply",
                            N = NA, iv = "urban_share",
                            pi_hat = NA, se_pi = NA, t_pi = NA,
                            F_first = NA, beta_iv = NA, se_beta = NA,
                            sargan_p = NA_real_, verdict = "⏸ SKIPPED — NSO fetch failed")
}

# Spec 8: quarter_of_birth — explicit skip with empirical reason
new_results$s8 <- tibble(spec = "08 quarter_of_birth", family = "Time",
                         N = 0L, iv = "as.factor(quarter_birth)",
                         pi_hat = NA, se_pi = NA, t_pi = NA,
                         F_first = NA, beta_iv = NA, se_beta = NA,
                         sargan_p = NA_real_,
                         verdict = "⏸ SKIPPED — q0105m нь нярай нас (НЕ birth month); HSES adult-уудад month-of-birth бүртгэдэггүй")

# Spec 10: pre-1990 schools — skip with reason
new_results$s10 <- tibble(spec = "10 pre_1990_supply", family = "Supply",
                          N = 0L, iv = "pre_1990_schools",
                          pi_hat = NA, se_pi = NA, t_pi = NA,
                          F_first = NA, beta_iv = NA, se_beta = NA,
                          sargan_p = NA_real_,
                          verdict = "⏸ SKIPPED — NSO API эхлэлийн жил 2001 (pre-1990 data байхгүй)")

# Spec 11: transition shock — skip
new_results$s11 <- tibble(spec = "11 transition_shock", family = "Time",
                          N = 0L, iv = "aimag_gdp_shock_1996_2000",
                          pi_hat = NA, se_pi = NA, t_pi = NA,
                          F_first = NA, beta_iv = NA, se_beta = NA,
                          sargan_p = NA_real_,
                          verdict = "⏸ SKIPPED — aimag-GDP 1995-2000 NSO API-д нэмж олдсонгүй; conceptual specification дутуу")

new_block <- bind_rows(new_results) |>
  mutate(across(c(pi_hat, se_pi, t_pi, F_first, beta_iv, se_beta, sargan_p),
                ~ if (is.numeric(.x)) round(.x, 5) else .x))

cli::cli_h2("New 6 specs results")
print(new_block)

# ---- 8. Merge with old T2b → full 14-row table -----------------------------
old_t2b <- read_csv(file.path(PATHS$out_tables, "T2b_iv_search.csv"),
                    show_col_types = FALSE)
# Avoid duplicate spec 7 (already in old as "09 birth_order"); keep old.
# Drop spec 10 (quarter_of_birth FIT FAILED) from old, add new s8 reasoned skip
old_t2b_clean <- old_t2b |> filter(!str_detect(spec, "^10 quarter"))

T2b_full <- bind_rows(old_t2b_clean, new_block) |>
  arrange(desc(coalesce(F_first, -1)))

cli::cli_h2("FULL T2b — 14-spec IV survey")
print(T2b_full, n = Inf)

write_csv(T2b_full, file.path(PATHS$out_tables, "T2b_iv_search.csv"))

log_path <- file.path(PATHS$out_logs, "12e_iv_remaining.log")
sink(log_path, append = FALSE)
cat("==========================================================\n")
cat("12e_iv_remaining.R — Remaining 6 IV specs  ", as.character(Sys.time()), "\n")
cat("==========================================================\n")
cat("\nNEW BLOCK results (specs 8, 10, 11, 12, 13, 14):\n"); print(new_block, n = Inf)
cat("\nFULL 14-spec T2b table (sorted by F desc):\n"); print(T2b_full, n = Inf)
cat("\nVerdict summary:\n")
print(table(T2b_full$verdict))
sink()

toc()
cli::cli_alert_success("Гарц: T2b_iv_search.csv (FULL 14 row); 12e_iv_remaining.log")


