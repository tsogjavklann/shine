# Extra diagnostics for the plausible "dzud should matter in rural Mongolia" channel.

options(warn = 1)

get_script_path <- function() {
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", args, value = TRUE)
  if (length(file_arg) == 0) return(file.path("codex", "R", "03_dzud_logic_checks.R"))
  sub("^--file=", "", file_arg[[1]])
}

script_dir <- dirname(normalizePath(get_script_path(), winslash = "/", mustWork = FALSE))
project_root <- normalizePath(file.path(script_dir, "..", ".."), winslash = "/", mustWork = TRUE)
codex_root <- file.path(project_root, "codex")
invisible(lapply(file.path(codex_root, c("output/tables", "output/logs")), dir.create, recursive = TRUE, showWarnings = FALSE))

sink(file.path(codex_root, "output/logs/03_dzud_logic_checks.log"), split = TRUE)
on.exit(sink(), add = TRUE)

required_pkgs <- c("dplyr", "tidyr", "readr", "fixest", "tibble", "purrr")
missing_pkgs <- required_pkgs[!vapply(required_pkgs, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_pkgs) > 0) stop("Missing required R packages: ", paste(missing_pkgs, collapse = ", "))

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(readr)
  library(fixest)
  library(tibble)
  library(purrr)
})

aimag_codes <- c(11, 21, 22, 23, 41, 42, 43, 44, 45, 46, 48, 61, 62, 63, 64, 65, 67, 81, 82, 83, 84, 85)

cohort_bin <- function(birth_year) {
  factor(case_when(
    birth_year < 1970 ~ "pre1970",
    birth_year >= 1970 & birth_year <= 1974 ~ "1970-74",
    birth_year >= 1975 & birth_year <= 1979 ~ "1975-79",
    birth_year >= 1980 & birth_year <= 1984 ~ "1980-84",
    birth_year >= 1985 & birth_year <= 1989 ~ "1985-89",
    birth_year >= 1990 & birth_year <= 1994 ~ "1990-94",
    birth_year >= 1995 ~ "post1995",
    TRUE ~ NA_character_
  ), levels = c("pre1970", "1970-74", "1975-79", "1980-84", "1985-89", "1990-94", "post1995"))
}

make_exposure <- function(people, panel, start_age = 12L, end_age = 17L) {
  expected_n <- end_age - start_age + 1
  panel_use <- panel %>% select(aimag_code, year, loss_rate, dzud5, dzud10, dzud_p75)
  people %>%
    select(row_id, birth_aimag, birth_year) %>%
    crossing(age_at_exposure = start_age:end_age) %>%
    mutate(year = birth_year + age_at_exposure) %>%
    left_join(panel_use, by = c("birth_aimag" = "aimag_code", "year" = "year")) %>%
    group_by(row_id) %>%
    summarise(
      n_complete = sum(!is.na(loss_rate)),
      dzud_cum_12_17 = ifelse(n_complete == expected_n, sum(loss_rate), NA_real_),
      dzud_count5_12_17 = ifelse(n_complete == expected_n, sum(dzud5 == 1, na.rm = TRUE), NA_real_),
      dzud_p75_count_12_17 = ifelse(n_complete == expected_n, sum(dzud_p75 == 1, na.rm = TRUE), NA_real_),
      .groups = "drop"
    )
}

fit_fs <- function(data, sample_name, iv_var) {
  df <- data %>%
    filter(!is.na(educ_years), !is.na(.data[[iv_var]]), !is.na(birth_aimag),
           !is.na(birth_cohort), !is.na(wave), !is.na(age), !is.na(age2))
  if (nrow(df) < 100 || dplyr::n_distinct(df[[iv_var]]) < 2) {
    return(tibble(sample = sample_name, iv_var = iv_var, pi_hat = NA_real_, pi_p = NA_real_,
                  F_first = NA_real_, N = nrow(df), verdict = "NOT_ESTIMATED"))
  }
  rhs <- paste(c(iv_var, "age", "age2", "female", "married", "urban"), collapse = " + ")
  fml <- as.formula(paste0("educ_years ~ ", rhs, " | birth_aimag + birth_cohort + wave"))
  fit <- tryCatch(
    feols(fml, data = df, weights = ~hhweight, vcov = ~birth_aimag, notes = FALSE),
    error = function(e) feols(fml, data = df, weights = ~hhweight, vcov = "hetero", notes = FALSE)
  )
  ct <- as.data.frame(coeftable(fit))
  ct$term <- rownames(ct)
  hit <- ct[ct$term == iv_var, , drop = FALSE]
  p_col <- grep("^Pr\\(", names(hit), value = TRUE)[1]
  if (nrow(hit) == 0) {
    return(tibble(sample = sample_name, iv_var = iv_var, pi_hat = NA_real_, pi_p = NA_real_,
                  F_first = NA_real_, N = nobs(fit), verdict = "COLLINEAR"))
  }
  pi_hat <- hit$Estimate[[1]]
  se <- hit[["Std. Error"]][[1]]
  f_first <- (pi_hat / se)^2
  tibble(
    sample = sample_name,
    iv_var = iv_var,
    pi_hat = pi_hat,
    pi_p = hit[[p_col]][[1]],
    F_first = f_first,
    N = nobs(fit),
    verdict = case_when(
      pi_hat >= 0 ~ "WRONG_SIGN",
      f_first >= 10 ~ "STRONG",
      f_first >= 5 ~ "MARGINAL",
      TRUE ~ "WEAK"
    )
  )
}

dzud_panel <- readRDS(file.path(codex_root, "data/cleaned/dzud_panel.rds"))
wage <- readRDS(file.path(codex_root, "data/cleaned/hses_dzud_exposure.rds")) %>%
  mutate(sample_source = "wage_sample")

harm <- readRDS(file.path(project_root, "data/processed/hses_harmonized.rds"))
all_adults <- harm %>%
  transmute(
    id = as.character(id),
    educ_years = as.numeric(educ_years),
    birth_year = as.integer(birth_year),
    birth_aimag = as.integer(birth_aimag),
    age = as.numeric(age),
    age2 = age^2,
    female = as.integer(as.numeric(sex) == 2),
    married = as.integer(as.numeric(marital) == 2),
    urban = as.integer(as.numeric(urban) == 1),
    hhweight = ifelse(is.finite(as.numeric(hhweight)) & as.numeric(hhweight) > 0, as.numeric(hhweight), 1),
    wave = as.integer(wave),
    row_id = row_number(),
    sample_source = "all_adults_25_60"
  ) %>%
  filter(age >= 25, age <= 60, birth_aimag %in% aimag_codes, !is.na(birth_year), !is.na(educ_years)) %>%
  mutate(
    birth_cohort = cohort_bin(birth_year),
    rural_birth = as.integer(birth_aimag != 11)
  )
all_adults <- all_adults %>% left_join(make_exposure(all_adults, dzud_panel), by = "row_id")

wage2 <- wage %>%
  mutate(
    birth_cohort = cohort_bin(birth_year),
    rural_birth = as.integer(birth_aimag != 11),
    sample_source = "wage_sample"
  )

make_samples <- function(df, prefix) {
  list(
    all = df,
    rural_birth = df %>% filter(rural_birth == 1),
    current_rural = df %>% filter(urban == 0),
    birth_1980_1999 = df %>% filter(birth_year >= 1980, birth_year <= 1999),
    rural_birth_1980_1999 = df %>% filter(rural_birth == 1, birth_year >= 1980, birth_year <= 1999)
  ) %>%
    purrr::imap(~ mutate(.x, sample_label = paste(prefix, .y, sep = "_")))
}

sample_list <- c(make_samples(wage2, "wage"), make_samples(all_adults, "all_adults"))
iv_vars <- c("dzud_cum_12_17", "dzud_count5_12_17", "dzud_p75_count_12_17")

logic_checks <- purrr::imap_dfr(sample_list, function(df, nm) {
  purrr::map_dfr(iv_vars, ~ fit_fs(df, unique(df$sample_label)[1], .x))
})

coverage <- bind_rows(
  wage2 %>% mutate(sample = "wage"),
  all_adults %>% mutate(sample = "all_adults")
) %>%
  mutate(
    cohort = cohort_bin(birth_year),
    complete_12_17 = !is.na(dzud_cum_12_17)
  ) %>%
  group_by(sample, cohort) %>%
  summarise(
    N = n(),
    complete_12_17_N = sum(complete_12_17),
    complete_12_17_share = mean(complete_12_17),
    .groups = "drop"
  )

write_csv(logic_checks, file.path(codex_root, "output/tables/T2c_dzud_logic_checks.csv"))
write_csv(coverage, file.path(codex_root, "output/tables/T2c_dzud_exposure_coverage_by_cohort.csv"))

cat("Saved T2c_dzud_logic_checks.csv rows:", nrow(logic_checks), "\n")
cat("Saved T2c_dzud_exposure_coverage_by_cohort.csv rows:", nrow(coverage), "\n")
print(logic_checks, n = nrow(logic_checks))
