suppressPackageStartupMessages({
  library(dplyr); library(fixest); library(httr); library(jsonlite); library(stringr)
})
setFixest_estimation(panel.id = NULL)

# Re-fetch teachers
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
  grid_df <- grid_df[seq_len(n),,drop=FALSE]; grid_df$value <- as.numeric(vals[seq_len(n)])
  tibble::as_tibble(grid_df)
}
lookup <- readr::read_csv("data/auxiliary/aimag_lookup.csv", show_col_types=FALSE)

js <- fetch_pxweb("https://data.1212.mn/api/v1/mn/NSO/Education,%20health/General%20educational%20schools/DT_NSO_2001_001V1.px",
                  '{"query":[],"response":{"format":"json-stat2"}}')
t <- parse_jsonstat(js) |>
  dplyr::rename(aimag_mn=1, year_chr=2, teachers=value) |>
  dplyr::mutate(hses_code = lookup$hses_code[match(stringr::str_trim(aimag_mn), lookup$aimag_mn)],
                year = suppressWarnings(as.integer(stringr::str_trim(year_chr)))) |>
  dplyr::filter(!is.na(hses_code), !is.na(year)) |>
  dplyr::group_by(hses_code, year) |>
  dplyr::summarise(teachers = first(teachers), .groups="drop")

ed <- readRDS("data/auxiliary/school_density_by_aimag.rds")
df <- readRDS("data/processed/analysis_sample.rds") |> tibble::as_tibble() |>
  dplyr::filter(main_flag_25_60 == 1L, !is.na(q_school_access), is.finite(q_school_access),
                !is.na(birth_year), !is.na(educ_years), !is.na(lwage),
                !is.na(birth_aimag)) |>
  dplyr::mutate(year_at_17 = birth_year + 17L) |>
  dplyr::left_join(t |> dplyr::rename(teachers_at_17 = teachers),
                   by = c("birth_aimag" = "hses_code", "year_at_17" = "year")) |>
  dplyr::left_join(ed |> dplyr::select(hses_code, year, students),
                   by = c("birth_aimag" = "hses_code", "year_at_17" = "year")) |>
  dplyr::mutate(teacher_density_17 = teachers_at_17 / students)

cat("teacher_density_17 distribution:\n")
print(summary(df$teacher_density_17))
cat(sprintf("\nN with both: %d\n", sum(!is.na(df$teacher_density_17) & !is.na(df$lwage))))

# IV with NORMALIZED teacher_density
iv <- feols(lwage ~ age + age2 + is_female + is_married | region + wave |
              educ_years ~ teacher_density_17,
            data = df |> dplyr::filter(!is.na(teacher_density_17)),
            weights = ~hhweight, cluster = ~aimag + wave)
cat("\n=== teacher_density_17 (NORMALIZED) IV ===\n")
print(summary(iv))
cat("\nivf1 (cluster-robust):\n"); print(fitstat(iv, "ivf1"))

# First stage manual
fs <- feols(educ_years ~ teacher_density_17 + age + age2 + is_female + is_married | region + wave,
            data = df |> dplyr::filter(!is.na(teacher_density_17)),
            weights = ~hhweight, cluster = ~aimag + wave)
cat("\nFirst stage (educ ~ teacher_density_17 + ctrls):\n")
print(coeftable(fs)["teacher_density_17", , drop = FALSE])


