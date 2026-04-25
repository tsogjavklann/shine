# =============================================================================
# 05_education_supply.R
# -----------------------------------------------------------------------------
# Зорилго : NSO PXWeb API-аас аймаг × жилийн ЕБС тоо + сурагчдын тоог татаж
#           school_density_{a,t} = ЕБС_тоо / (сурагч_тоо / 1000) хэмжүүрийг
#           бүтээх. Дараа нь wage_real panel дахь хүн бүрд:
#             q_i = (1/12) × Σ school_density_{home_aimag, t},  t ∈ [bya+6, bya+17]
#           бөгөөд home_aimag (q0114a/q0118a) ба newaimag_proxy хоёрт нь
#           school_access-ийг хоёуланг тооцоолно.
#           Empirical decision rule: home_aimag wage-panel N-аас хамаарч MAIN
#           vs ROBUSTNESS aimag сонголтыг тогтоо.
# Орц     : data/processed/wage_real.rds
# Гарц    : data/aux/school_density_by_aimag.rds (long: aimag × year × density)
#           data/aux/aimag_lookup.csv             (NSO valueText → HSES newaimag)
#           data/processed/school_access.rds      (id × q_home × q_new)
#           output/logs/05_aimag_coverage.log     (DECISION + diagnostics)
# =============================================================================

source(here::here("R", "paths.R"))
suppressPackageStartupMessages({
  library(dplyr); library(tidyr); library(readr); library(stringr)
  library(jsonlite); library(httr); library(cli); library(tictoc)
})

cli::cli_h1("05_education_supply.R — school_access threshold variable")
tic("Total")

# ---- 1. Wage panel ачаалах --------------------------------------------------
in_path <- file.path(PATHS$data_proc, "wage_real.rds")
if (!file.exists(in_path)) {
  cli::cli_abort("Орц олдсонгүй: {in_path}. Эхлээд R/04b_cpi_deflator.R-г ажиллуул.")
}
wage <- readRDS(in_path) |> as_tibble()
cli::cli_alert_info("Wage panel: {nrow(wage)} мөр; columns include birth_aimag, newaimag_proxy, birth_year")

# ---- 2. PXWeb fetcher (general) ---------------------------------------------
NSO_BASE <- "https://data.1212.mn/api/v1/mn/NSO/Education,%20health/General%20educational%20schools"

# Build query body — fetch ALL data (no filter) so we get every aimag × year
build_query <- function() {
  '{"query":[],"response":{"format":"json-stat2"}}'
}

fetch_table <- function(table_id, retries = 3L) {
  url <- paste0(NSO_BASE, "/", table_id, ".px")
  body_raw <- charToRaw(enc2utf8(build_query()))
  for (i in seq_len(retries)) {
    cli::cli_alert("PXWeb fetch [{table_id}] attempt {i}/{retries}...")
    res <- tryCatch(
      httr::POST(url,
                 httr::add_headers(
                   "Content-Type" = "application/json; charset=utf-8",
                   "Accept" = "application/json"),
                 body = body_raw,
                 httr::timeout(60)),
      error = function(e) { cli::cli_alert_warning("HTTP error: {conditionMessage(e)}"); NULL }
    )
    if (!is.null(res) && httr::status_code(res) == 200L) {
      txt <- httr::content(res, "text", encoding = "UTF-8")
      return(jsonlite::fromJSON(txt, simplifyVector = FALSE))
    }
    if (!is.null(res)) cli::cli_alert_warning("HTTP {httr::status_code(res)}: {substr(httr::content(res, 'text', encoding='UTF-8'), 1, 200)}")
  }
  NULL
}

# ---- 3. JSON-stat2 parser → long tibble (aimag × year × value) --------------
parse_jsonstat <- function(js, value_name = "value") {
  if (is.null(js)) return(NULL)
  # Dimension names — typically "Бүс" (region/aimag), "Он" (year), maybe others
  dim_ids <- unlist(js$id)
  size    <- unlist(js$size)

  # Get categories per dimension
  dim_info <- lapply(dim_ids, function(d) {
    cat <- js$dimension[[d]]$category
    idx <- unlist(cat$index)
    lab <- unlist(cat$label)
    # Sort by index value to align with values array
    ord <- order(idx)
    list(name = d, codes = names(idx)[ord], labels = lab[names(idx)[ord]])
  })

  # Build all combinations
  grid_lst <- lapply(dim_info, function(di) di$labels)
  names(grid_lst) <- dim_ids
  grid_df <- expand.grid(grid_lst, stringsAsFactors = FALSE, KEEP.OUT.ATTRS = FALSE)
  # values array is ordered by last dimension fastest (column-major in JSON-stat2)
  # In R expand.grid, first column varies fastest. We need to reverse to match.
  # Actually JSON-stat2 uses row-major: first dim slowest. expand.grid first col fastest.
  # So we need to use reversed expand.grid.
  grid_lst_rev <- rev(grid_lst)
  grid_df <- expand.grid(grid_lst_rev, stringsAsFactors = FALSE, KEEP.OUT.ATTRS = FALSE)
  grid_df <- grid_df[, rev(seq_along(grid_df)), drop = FALSE]
  names(grid_df) <- dim_ids

  vals <- unlist(js$value, use.names = FALSE)
  # Replace NULL with NA
  if (length(vals) != nrow(grid_df)) {
    cli::cli_alert_warning("Grid {nrow(grid_df)} != values {length(vals)} — using min")
    n <- min(nrow(grid_df), length(vals))
    grid_df <- grid_df[seq_len(n), , drop = FALSE]
    vals <- vals[seq_len(n)]
  }
  grid_df[[value_name]] <- suppressWarnings(as.numeric(vals))
  as_tibble(grid_df)
}

# ---- 4. Fetch schools + students --------------------------------------------
js_schools  <- fetch_table("DT_NSO_2001_002V1")
js_students <- fetch_table("DT_NSO_2001_004V1")

if (is.null(js_schools) || is.null(js_students)) {
  cli::cli_abort("Education tables fetch failed. NSO API эсвэл network асуудал.")
}

t_schools  <- parse_jsonstat(js_schools,  "schools")
t_students <- parse_jsonstat(js_students, "students")

cli::cli_alert_success("Fetched schools: {nrow(t_schools)} rows; students: {nrow(t_students)} rows")

# ---- 5. NSO aimag-name → HSES newaimag-code lookup --------------------------
# HSES newaimag value labels (Latin transliteration):
#   11=Ulaanbaatar; 21=Dornod; 22=Sukhbaatar; 23=Khentii; 41=Tov; 42=Govisumber;
#   43=Selenge; 44=Dornogovi; 45=Darkhan-Uul; 46=Omnogovi; 48=Dundgovi;
#   61=Orkhon; 62=Ovorkhangai; 63=Bulgan; 64=Bayankhongor; 65=Arkhangai;
#   67=Khovsgol; 81=Zavkhan; 82=Govi-Altai; 83=Bayan-Olgii; 84=Khovd; 85=Uvs.
# Mongolian-name (NSO) ↔ HSES newaimag code mapping:
aimag_lookup <- tribble(
  ~aimag_mn,          ~hses_code,
  "Улаанбаатар",        11L,
  "Дорнод",             21L,
  "Сүхбаатар",          22L,
  "Хэнтий",             23L,
  "Төв",                41L,
  "Говьсүмбэр",         42L,
  "Сэлэнгэ",            43L,
  "Дорноговь",          44L,
  "Дархан-Уул",         45L,
  "Өмнөговь",           46L,
  "Дундговь",           48L,
  "Орхон",              61L,
  "Өвөрхангай",         62L,
  "Булган",             63L,
  "Баянхонгор",         64L,
  "Архангай",           65L,
  "Хөвсгөл",            67L,
  "Завхан",             81L,
  "Говь-Алтай",         82L,
  "Баян-Өлгий",         83L,
  "Ховд",               84L,
  "Увс",                85L
)
write_csv(aimag_lookup, file.path(PATHS$data_aux, "aimag_lookup.csv"))

# Function: trim leading whitespace from NSO valueText, match to HSES code
match_aimag <- function(name_vec) {
  trimmed <- str_trim(name_vec)
  m <- aimag_lookup$hses_code[match(trimmed, aimag_lookup$aimag_mn)]
  m
}

# ---- 6. Combine schools + students by (aimag, year) -------------------------
# Detect dimension names robustly (Бүс / Он in Mongolian)
prep <- function(df, vname) {
  # First column likely "Бүс" (region), second "Он" (year), value name = vname
  region_col <- names(df)[1]
  year_col   <- names(df)[2]
  df |>
    rename(aimag_mn = !!region_col, year_chr = !!year_col) |>
    mutate(
      hses_code = match_aimag(aimag_mn),
      year      = suppressWarnings(as.integer(str_trim(year_chr)))
    ) |>
    filter(!is.na(hses_code), !is.na(year))   # drop national totals + region totals
}

s_clean <- prep(t_schools,  "schools") |>
  group_by(hses_code, year) |>
  summarise(schools = first(schools), .groups = "drop")   # dedup
n_clean <- prep(t_students, "students") |>
  group_by(hses_code, year) |>
  summarise(students = first(students), .groups = "drop") # dedup

cli::cli_alert_info("After mapping + dedup: schools {nrow(s_clean)}, students {nrow(n_clean)}")

# NOTE: NSO students column is **already in thousands** (e.g., UB 2020 = 317
# means 317,000). Therefore school_density = schools / students directly gives
# "schools per 1000 students" without further division.
ed_supply <- inner_join(
  s_clean |> select(hses_code, year, schools),
  n_clean |> select(hses_code, year, students),
  by = c("hses_code", "year")
) |>
  mutate(
    school_density = schools / students   # schools per 1000 students
  ) |>
  filter(!is.na(schools), !is.na(students), students > 0)

cli::cli_alert_success("ed_supply: {nrow(ed_supply)} rows; year range [{min(ed_supply$year)}, {max(ed_supply$year)}]")

saveRDS(ed_supply, file.path(PATHS$data_aux, "school_density_by_aimag.rds"))
write_csv(ed_supply, file.path(PATHS$data_aux, "school_density_by_aimag.csv"))

# ---- 7. Compute school_access for each individual ---------------------------
# q_i = (1/12) × Σ_{t = birth_year+6}^{birth_year+17} school_density_{aimag, t}
# Need: long-form (id × ages 6..17 × candidate aimag) → join with ed_supply
compute_qi <- function(panel, aimag_col, supply) {
  panel |>
    transmute(id, birth_year, aimag_eval = .data[[aimag_col]]) |>
    filter(!is.na(birth_year), !is.na(aimag_eval)) |>
    crossing(age_at_t = 6:17) |>
    mutate(year = birth_year + age_at_t) |>
    left_join(supply |> select(hses_code, year, school_density),
              by = c("aimag_eval" = "hses_code", "year" = "year")) |>
    group_by(id) |>
    summarise(
      q_value      = mean(school_density, na.rm = TRUE),
      n_years_obs  = sum(!is.na(school_density)),
      .groups = "drop"
    )
}

cli::cli_alert("Computing q for home_aimag (q0114a/q0118a)...")
q_home <- compute_qi(wage, "birth_aimag", ed_supply) |>
  rename(q_home = q_value, n_years_home = n_years_obs)

cli::cli_alert("Computing q for newaimag_proxy (current residence)...")
q_new <- compute_qi(wage, "newaimag_proxy", ed_supply) |>
  rename(q_new = q_value, n_years_new = n_years_obs)

school_access <- wage |>
  select(id, wave, birth_year, birth_aimag, newaimag_proxy) |>
  left_join(q_home, by = "id") |>
  left_join(q_new,  by = "id")

# Coverage on the wage panel
n_total       <- nrow(school_access)
n_home_valid  <- sum(!is.na(school_access$q_home) & is.finite(school_access$q_home))
n_new_valid   <- sum(!is.na(school_access$q_new)  & is.finite(school_access$q_new))

cli::cli_h2("school_access coverage in wage panel ({n_total} obs)")
cli::cli_alert_info("Home_aimag valid (q_home not NaN): {n_home_valid} ({round(100*n_home_valid/n_total,1)}%)")
cli::cli_alert_info("Newaimag valid (q_new not NaN):   {n_new_valid} ({round(100*n_new_valid/n_total,1)}%)")

# Distribution sumamary
qsum <- function(x, label) {
  x <- x[!is.na(x) & is.finite(x)]
  if (length(x) == 0L) return(tibble(label = label, n = 0L))
  q <- quantile(x, c(.05, .25, .5, .75, .95))
  tibble(label = label, n = length(x), mean = mean(x), sd = sd(x),
         p5 = q[1], p25 = q[2], median = q[3], p75 = q[4], p95 = q[5])
}
sa_summary <- bind_rows(
  qsum(school_access$q_home, "q_home"),
  qsum(school_access$q_new,  "q_new")
)
print(sa_summary)

saveRDS(school_access, file.path(PATHS$data_proc, "school_access.rds"))
write_csv(sa_summary, file.path(PATHS$out_logs, "05_school_access_summary.csv"))

# ---- 8. Decision rule (MAIN vs ROBUSTNESS aimag) ----------------------------
decision <- if (n_home_valid >= 10000L) {
  "HOME_AIMAG_MAIN"
} else if (n_home_valid >= 5000L) {
  "ASK_USER"
} else {
  "NEWAIMAG_MAIN_HOME_FALLBACK"
}

cli::cli_h2("DECISION RULE")
switch(decision,
  HOME_AIMAG_MAIN = cli::cli_alert_success(
    "N_home={n_home_valid} ≥ 10,000 → **MAIN = home_aimag** (Card/Duflo cleanest); newaimag T6 robustness"
  ),
  ASK_USER = cli::cli_alert_warning(
    "N_home={n_home_valid} ∈ [5K, 10K) → **CHECKPOINT: ask user**. RESULTS_LOG.md-д бичээд STOP"
  ),
  NEWAIMAG_MAIN_HOME_FALLBACK = cli::cli_alert_warning(
    "N_home={n_home_valid} < 5,000 → **MAIN = newaimag (soft claim)**; home_aimag subsample T6 robustness"
  )
)

# ---- 9. Лог + checkpoint ----------------------------------------------------
log_path <- file.path(PATHS$out_logs, "05_aimag_coverage.log")
sink(log_path, append = FALSE)
cat("==========================================================\n")
cat("05_education_supply.R лог  ", as.character(Sys.time()), "\n")
cat("==========================================================\n")
cat(sprintf("Wage panel rows:           %d\n", n_total))
cat(sprintf("home_aimag valid q_home:   %d (%.2f%%)\n", n_home_valid, 100*n_home_valid/n_total))
cat(sprintf("newaimag valid q_new:      %d (%.2f%%)\n", n_new_valid,  100*n_new_valid/n_total))
cat(sprintf("\nDecision: %s\n", decision))
cat("\nschool_access distribution:\n"); print(sa_summary)
cat("\ned_supply year range: ", min(ed_supply$year), "-", max(ed_supply$year), "\n", sep="")
cat("ed_supply by year (n_aimags):\n")
print(ed_supply |> count(year) |> arrange(year))
sink()

toc()
cli::cli_alert_success("Гарцууд: school_density_by_aimag.rds, school_access.rds, 05_aimag_coverage.log")
cli::cli_alert_info("Дараагийн алхам: R/06_iv_construction.R")
