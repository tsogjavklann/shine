# =============================================================================
# VERIFY ALL CHECKPOINT 2.6 CALCULATIONS
# Бүх дүгнэлтийг тоогоор баталгаажуулна
# =============================================================================
suppressPackageStartupMessages({
  library(dplyr); library(tidyr); library(readr); library(stringr)
  library(httr); library(jsonlite); library(fixest); library(cli); library(tibble)
})
setFixest_estimation(panel.id = NULL)
options(width = 130)

# -----------------------------------------------------------------------------
# 1. NSO TEACHER DATA FETCH — verify
# -----------------------------------------------------------------------------
fetch_pxweb <- function(url, body_str) {
  body_raw <- charToRaw(enc2utf8(body_str))
  res <- POST(url, add_headers("Content-Type"="application/json; charset=utf-8"),
              body = body_raw, timeout(60))
  if (status_code(res) == 200) jsonlite::fromJSON(content(res, "text", encoding="UTF-8"), simplifyVector=FALSE) else NULL
}
parse_jsonstat <- function(js) {
  dim_ids <- unlist(js$id)
  dim_info <- lapply(dim_ids, function(d) {
    cat <- js$dimension[[d]]$category
    idx <- unlist(cat$index); lab <- unlist(cat$label)
    ord <- order(idx); list(codes=names(idx)[ord], labels=lab[names(idx)[ord]])
  })
  grid_lst_rev <- rev(setNames(lapply(dim_info, function(di) di$labels), dim_ids))
  grid_df <- expand.grid(grid_lst_rev, stringsAsFactors=FALSE, KEEP.OUT.ATTRS=FALSE)
  grid_df <- grid_df[, rev(seq_along(grid_df)), drop=FALSE]
  names(grid_df) <- dim_ids
  vals <- unlist(js$value, use.names=FALSE)
  n <- min(nrow(grid_df), length(vals))
  grid_df <- grid_df[seq_len(n),,drop=FALSE]
  grid_df$value <- as.numeric(vals[seq_len(n)])
  as_tibble(grid_df)
}

cli::cli_h1("VERIFY 1: NSO teachers data")
js <- fetch_pxweb(
  "https://data.1212.mn/api/v1/mn/NSO/Education,%20health/General%20educational%20schools/DT_NSO_2001_001V1.px",
  '{"query":[],"response":{"format":"json-stat2"}}'
)

aimag_lookup <- read_csv("data/auxiliary/aimag_lookup.csv", show_col_types = FALSE)
match_aimag <- function(name_vec) {
  trimmed <- str_trim(name_vec)
  aimag_lookup$hses_code[match(trimmed, aimag_lookup$aimag_mn)]
}

t_raw <- parse_jsonstat(js) |>
  rename(aimag_mn=1, year_chr=2, teachers=value) |>
  mutate(year = suppressWarnings(as.integer(str_trim(year_chr))))

teacher_supply <- t_raw |>
  mutate(hses_code = match_aimag(aimag_mn)) |>
  filter(!is.na(hses_code), !is.na(year)) |>
  group_by(hses_code, year) |>
  summarise(teachers = first(teachers), .groups = "drop")

cat(sprintf("Year range: %d-%d\n", min(teacher_supply$year), max(teacher_supply$year)))
cat(sprintf("N matched aimags: %d\n", length(unique(teacher_supply$hses_code))))
cat(sprintf("Total cells (aimag-year): %d\n", nrow(teacher_supply)))

# -----------------------------------------------------------------------------
# 2. MERGE TO HSES — verify N
# -----------------------------------------------------------------------------
cli::cli_h1("VERIFY 2: Merge teachers_at_17 to HSES analysis sample")

df <- readRDS("data/processed/analysis_sample.rds") |> as_tibble()
ed_supply <- readRDS("data/auxiliary/school_density_by_aimag.rds") |> as_tibble()

main <- df |>
  filter(main_flag_25_60 == 1L,
         !is.na(q_school_access), is.finite(q_school_access),
         !is.na(birth_year),
         !is.na(educ_years), !is.na(lwage),
         !is.na(birth_aimag)) |>
  mutate(year_at_17 = birth_year + 17L) |>
  left_join(teacher_supply |> rename(teachers_at_17 = teachers),
            by = c("birth_aimag" = "hses_code", "year_at_17" = "year")) |>
  left_join(ed_supply |> select(hses_code, year, students),
            by = c("birth_aimag" = "hses_code", "year_at_17" = "year")) |>
  mutate(teacher_density_17 = teachers_at_17 / students)

cat(sprintf("HSES main sample N (after filters): %d\n", nrow(main)))
cat(sprintf("With teachers_at_17 (non-NA): %d (%.1f%%)\n",
            sum(!is.na(main$teachers_at_17)),
            100*mean(!is.na(main$teachers_at_17))))
cat(sprintf("With teacher_density_17 (non-NA): %d (%.1f%%)\n",
            sum(!is.na(main$teacher_density_17)),
            100*mean(!is.na(main$teacher_density_17))))

cat("\n--- Year-at-17 distribution ---\n")
print(main |> count(year_at_17) |> arrange(year_at_17), n = 50)

# -----------------------------------------------------------------------------
# 3. RAW teachers_at_17 — F-stat & R² verify
# -----------------------------------------------------------------------------
cli::cli_h1("VERIFY 3: RAW teachers_at_17 IV diagnostics")

iv_data <- main |> filter(!is.na(teachers_at_17), !is.na(students), !is.na(hhweight))
cat(sprintf("IV sample N: %d\n\n", nrow(iv_data)))

# First stage
fs_raw <- feols(educ_years ~ teachers_at_17 + age + age2 + is_female + is_married | region + wave,
                data = iv_data, weights = ~hhweight, cluster = ~aimag + wave)
cat("First stage (teachers_at_17 raw count):\n")
print(coeftable(fs_raw)["teachers_at_17", , drop = FALSE])

# IV
iv_raw <- feols(lwage ~ age + age2 + is_female + is_married | region + wave |
                  educ_years ~ teachers_at_17,
                data = iv_data, weights = ~hhweight, cluster = ~aimag + wave)
cat("\nIV F-stat (cluster-robust ivf1):\n")
print(fitstat(iv_raw, "ivf1"))

# R² with birth_aimag dummies
r2_aimag <- feols(teachers_at_17 ~ as.factor(birth_aimag), data = iv_data, weights = ~hhweight)
cat(sprintf("\nR² of teachers_at_17 ~ birth_aimag dummies: %.4f\n",
            fitstat(r2_aimag, "r2")$r2))
cat("(If R² ≈ 1: teachers_at_17 нь зөвхөн aimag-аас тогтсон)\n")

# Pearson cor with q_school_access
cor_check <- iv_data |> filter(!is.na(q_school_access))
cat(sprintf("\nPearson cor(teachers_at_17, q_school_access) = %.4f, N = %d\n",
            cor(cor_check$teachers_at_17, cor_check$q_school_access), nrow(cor_check)))

# -----------------------------------------------------------------------------
# 4. NORMALIZED teacher_density_17 — F-stat verify
# -----------------------------------------------------------------------------
cli::cli_h1("VERIFY 4: NORMALIZED teacher_density_17 IV diagnostics")

dens_data <- main |> filter(!is.na(teacher_density_17), is.finite(teacher_density_17), !is.na(hhweight))
cat(sprintf("Density sample N: %d\n\n", nrow(dens_data)))

fs_dens <- feols(educ_years ~ teacher_density_17 + age + age2 + is_female + is_married | region + wave,
                 data = dens_data, weights = ~hhweight, cluster = ~aimag + wave)
cat("First stage (teacher_density_17):\n")
print(coeftable(fs_dens)["teacher_density_17", , drop = FALSE])

iv_dens <- feols(lwage ~ age + age2 + is_female + is_married | region + wave |
                   educ_years ~ teacher_density_17,
                 data = dens_data, weights = ~hhweight, cluster = ~aimag + wave)
cat("\nIV F-stat (cluster-robust ivf1):\n")
print(fitstat(iv_dens, "ivf1"))

# -----------------------------------------------------------------------------
# 5. birth_order pathology — verify
# -----------------------------------------------------------------------------
cli::cli_h1("VERIFY 5: birth_order pathology")

fam <- readRDS("data/processed/family_structure.rds") |> as_tibble()
main_bo <- main |> left_join(fam |> select(id, n_siblings, birth_order), by = "id")

cat(sprintf("birth_order NA rate: %.1f%%\n", 100*mean(is.na(main_bo$birth_order))))
cat(sprintf("birth_order non-NA mean: %.3f, median: %.0f\n",
            mean(main_bo$birth_order, na.rm=T), median(main_bo$birth_order, na.rm=T)))
cat("Distribution:\n")
print(table(main_bo$birth_order, useNA = "no"))

bo_data <- main_bo |> filter(!is.na(birth_order), !is.na(hhweight))
fs_bo <- feols(educ_years ~ birth_order + age + age2 + is_female + is_married | region + wave,
               data = bo_data, weights = ~hhweight, cluster = ~aimag + wave)
cat("\nFirst stage (birth_order):\n")
print(coeftable(fs_bo)["birth_order", , drop = FALSE])

iv_bo <- feols(lwage ~ age + age2 + is_female + is_married | region + wave |
                 educ_years ~ birth_order,
               data = bo_data, weights = ~hhweight, cluster = ~aimag + wave)
cat("\nIV F-stat (cluster-robust ivf1):\n")
print(fitstat(iv_bo, "ivf1"))

# -----------------------------------------------------------------------------
# 6. aimag × cohort — verify
# -----------------------------------------------------------------------------
cli::cli_h1("VERIFY 6: aimag × cohort cell distribution")

main_cells <- main |>
  mutate(cohort_bin = case_when(
    birth_year >= 1960 & birth_year <= 1969 ~ "1960s",
    birth_year >= 1970 & birth_year <= 1979 ~ "1970s",
    birth_year >= 1980 & birth_year <= 1989 ~ "1980s",
    birth_year >= 1990 & birth_year <= 1995 ~ "1990-95",
    birth_year >= 1996 & birth_year <= 1997 ~ "donut",
    birth_year >= 1998                      ~ "post1998",
    TRUE ~ NA_character_))

cells <- main_cells |> filter(!is.na(cohort_bin), cohort_bin != "donut") |>
  count(birth_aimag, cohort_bin)
cat(sprintf("Total (aimag × cohort) cells: %d (max 22 × 5 = 110)\n", nrow(cells)))
cat(sprintf("Cells with N < 30: %d\n", sum(cells$n < 30)))
cat(sprintf("Cells with N >= 30: %d\n", sum(cells$n >= 30)))
cat(sprintf("Median cell size: %d\n", median(cells$n)))

m_cells <- feols(educ_years ~ as.factor(birth_aimag) * as.factor(cohort_bin),
                 data = main_cells |> filter(!is.na(cohort_bin), cohort_bin != "donut"),
                 weights = ~hhweight)
cat(sprintf("\nR² of educ_years ~ aimag × cohort: %.4f\n", fitstat(m_cells, "r2")$r2))

cli::cli_h1("VERIFICATION COMPLETE")


