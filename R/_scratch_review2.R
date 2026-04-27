# Re-check: TRUE teachers_at_17 (raw count from NSO) vs q_school_access
suppressPackageStartupMessages({
  library(dplyr); library(tidyr); library(readr); library(stringr)
  library(httr); library(jsonlite); library(fixest); library(cli)
})
setFixest_estimation(panel.id = NULL)

# Re-fetch teachers from NSO
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
parse_jsonstat <- function(js) {
  dim_ids <- unlist(js$id)
  dim_info <- lapply(dim_ids, function(d) {
    cat <- js$dimension[[d]]$category
    idx <- unlist(cat$index); lab <- unlist(cat$label)
    ord <- order(idx)
    list(name=d, codes=names(idx)[ord], labels=lab[names(idx)[ord]])
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

aimag_lookup <- read_csv("data/auxiliary/aimag_lookup.csv", show_col_types = FALSE)
match_aimag <- function(name_vec) {
  trimmed <- str_trim(name_vec)
  aimag_lookup$hses_code[match(trimmed, aimag_lookup$aimag_mn)]
}

cli::cli_alert("Fetching teachers...")
js_teach <- fetch_pxweb(
  "https://data.1212.mn/api/v1/mn/NSO/Education,%20health/General%20educational%20schools/DT_NSO_2001_001V1.px",
  '{"query":[],"response":{"format":"json-stat2"}}'
)
t <- parse_jsonstat(js_teach)
teacher_supply <- t |>
  rename(aimag_mn = 1, year_chr = 2, teachers = value) |>
  mutate(hses_code = match_aimag(aimag_mn),
         year      = suppressWarnings(as.integer(str_trim(year_chr)))) |>
  filter(!is.na(hses_code), !is.na(year)) |>
  group_by(hses_code, year) |>
  summarise(teachers = first(teachers), .groups = "drop")

cli::cli_alert_success("Teachers data: {nrow(teacher_supply)} rows")
cat("\nTeacher counts by aimag (sample year=2010):\n")
print(teacher_supply |> filter(year == 2010) |> arrange(desc(teachers)), n = 25)
cat("\nUnit check — what's the magnitude?\n")
cat(sprintf("min: %g, max: %g\n", min(teacher_supply$teachers, na.rm=T), max(teacher_supply$teachers, na.rm=T)))
cat(sprintf("Likely 'thousands of teachers' if max ~30, else raw count if max ~10000+\n"))

# Load main + ed_supply
df  <- readRDS("data/processed/analysis_sample.rds") |> as_tibble()
ed_supply <- readRDS("data/auxiliary/school_density_by_aimag.rds") |> as_tibble()

main <- df |>
  filter(main_flag_25_60 == 1L,
         !is.na(q_school_access), is.finite(q_school_access), !is.na(birth_year),
         !is.na(educ_years), !is.na(lwage),
         !is.na(birth_aimag)) |>
  mutate(year_at_17 = birth_year + 17L) |>
  left_join(teacher_supply |> rename(teachers_at_17 = teachers),
            by = c("birth_aimag" = "hses_code", "year_at_17" = "year")) |>
  left_join(ed_supply |> select(hses_code, year, students),
            by = c("birth_aimag" = "hses_code", "year_at_17" = "year")) |>
  mutate(teacher_density_17 = teachers_at_17 / students)  # teachers per 1000 students

cli::cli_h1("CORRECT diagnostic: TRUE teachers_at_17 (raw count) vs q_school_access")

cor_check <- main |>
  filter(!is.na(teachers_at_17), !is.na(q_school_access))
cat(sprintf("\nN: %d\n", nrow(cor_check)))

cat("\n--- teachers_at_17 (RAW COUNT) vs q_school_access ---\n")
cat(sprintf("Pearson:  %.4f\n", cor(cor_check$teachers_at_17, cor_check$q_school_access)))
cat(sprintf("Spearman: %.4f\n", cor(cor_check$teachers_at_17, cor_check$q_school_access, method="spearman")))

cat("\n--- teacher_density_17 (teachers per 1000 students) vs q_school_access ---\n")
cor_check2 <- main |> filter(!is.na(teacher_density_17), !is.na(q_school_access))
cat(sprintf("Pearson:  %.4f\n", cor(cor_check2$teacher_density_17, cor_check2$q_school_access)))
cat(sprintf("Spearman: %.4f\n", cor(cor_check2$teacher_density_17, cor_check2$q_school_access, method="spearman")))

cat("\n--- teachers_at_17 vs aimag size proxy (number of students_at_17) ---\n")
cor_size <- main |> filter(!is.na(teachers_at_17), !is.na(students))
cat(sprintf("Pearson:  %.4f  (high = teachers ≈ aimag size)\n",
            cor(cor_size$teachers_at_17, cor_size$students)))

# Aimag-level
aimag_avg <- cor_check |>
  group_by(birth_aimag) |>
  summarise(teachers17_mean = mean(teachers_at_17),
            qschool_access_mean      = mean(q_school_access),
            .groups = "drop")
cat(sprintf("\nAimag-level (n=%d):\n", nrow(aimag_avg)))
cat(sprintf("  teachers_at_17 vs q_school_access Pearson: %.4f\n",
            cor(aimag_avg$teachers17_mean, aimag_avg$qschool_access_mean)))

cat("\nTop 10 aimags by teachers_at_17:\n")
print(aimag_avg |> arrange(desc(teachers17_mean)) |> slice(1:10))

# Variance decomposition
m_aimag <- feols(teachers_at_17 ~ as.factor(birth_aimag), data = cor_check, weights = ~hhweight)
cat(sprintf("\nteachers_at_17 ~ birth_aimag dummies: R² = %.4f\n", fitstat(m_aimag, "r2")$r2))
cat("(If R² ≈ 1: teachers_at_17 нь зөвхөн aimag-аас тогтсон → aimag size proxy)\n")

m_aimag_year <- feols(teachers_at_17 ~ as.factor(birth_aimag) * as.factor(birth_year),
                      data = cor_check, weights = ~hhweight)
cat(sprintf("teachers_at_17 ~ birth_aimag × birth_year: R² = %.4f\n",
            fitstat(m_aimag_year, "r2")$r2))

# Re-run first stage with TRUE teachers_at_17
cli::cli_h1("Re-run first stage: TRUE teachers_at_17 (raw count)")
fs <- feols(educ_years ~ teachers_at_17 + age + age2 + is_female + is_married | region + wave,
            data = main |> filter(!is.na(teachers_at_17), !is.na(educ_years)),
            weights = ~hhweight, cluster = ~aimag + wave)
print(fs)
cat("\nCluster-robust ivf1 from IV spec:\n")
iv <- feols(lwage ~ age + age2 + is_female + is_married | region + wave |
              educ_years ~ teachers_at_17,
            data = main |> filter(!is.na(teachers_at_17)),
            weights = ~hhweight, cluster = ~aimag + wave)
print(fitstat(iv, "ivf1"))


