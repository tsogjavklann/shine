# =============================================================================
# 21_rename_q_home_to_q_school_access.R
# -----------------------------------------------------------------------------
# Purpose:
#   Rename the misleading school-access threshold variable name:
#     q_home       -> q_school_access
#     n_years_home -> n_years_school_access
#
# Notes:
#   - This is a naming migration only.
#   - Raw data are not modified.
#   - The variable measures birth-aimag school access, not household/home
#     environment.
# =============================================================================

source(here::here("R", "paths.R"))

log_path <- file.path(PATHS$out_logs, "21_rename_q_home_to_q_school_access.log")
dir.create(dirname(log_path), recursive = TRUE, showWarnings = FALSE)
sink(log_path, append = FALSE, split = TRUE)

cat("21_rename_q_home_to_q_school_access.R\n")
cat("Started:", as.character(Sys.time()), "\n\n")

rename_cols <- function(x) {
  nm <- names(x)
  if ("q_home" %in% nm && !"q_school_access" %in% nm) {
    nm[nm == "q_home"] <- "q_school_access"
  }
  if ("n_years_home" %in% nm && !"n_years_school_access" %in% nm) {
    nm[nm == "n_years_home"] <- "n_years_school_access"
  }
  names(x) <- nm
  x
}

process_rds <- function(path, copy_to = NULL) {
  if (!file.exists(path)) {
    cat("SKIP missing RDS:", path, "\n")
    return(invisible(FALSE))
  }

  x <- readRDS(path)
  old_names <- names(x)
  x2 <- rename_cols(x)
  changed <- !identical(old_names, names(x2))

  if (changed) {
    saveRDS(x2, path)
    cat("UPDATED RDS:", path, "\n")
  } else {
    cat("NO CHANGE RDS:", path, "\n")
  }

  if (!is.null(copy_to)) {
    saveRDS(x2, copy_to)
    cat("WROTE CANONICAL COPY:", copy_to, "\n")
  }

  invisible(TRUE)
}

replace_text_file <- function(path) {
  if (normalizePath(path, winslash = "/", mustWork = FALSE) ==
      normalizePath(sys.frame(1)$ofile %||% "", winslash = "/", mustWork = FALSE)) {
    return(FALSE)
  }
  txt <- readLines(path, warn = FALSE, encoding = "UTF-8")
  old <- txt
  txt <- gsub("n_years_home", "n_years_school_access", txt, fixed = TRUE)
  txt <- gsub("q_home", "q_school_access", txt, fixed = TRUE)
  txt <- gsub("qhome", "qschool_access", txt, fixed = TRUE)
  txt <- gsub("Q_home", "Q_school_access", txt, fixed = TRUE)
  if (!identical(old, txt)) {
    writeLines(txt, path, useBytes = TRUE)
    cat("UPDATED TEXT:", path, "\n")
    return(TRUE)
  }
  FALSE
}

`%||%` <- function(x, y) if (is.null(x)) y else x

rds_map <- list(
  list(
    from = file.path(PATHS$data_proc, "school_access.rds"),
    to = NULL
  ),
  list(
    from = file.path(PATHS$data_proc, "analysis_sample.rds"),
    to = NULL
  ),
  list(
    from = file.path(PATHS$data_proc, "ivtr_ready_parent_educ_mean_qhome.rds"),
    to = file.path(PATHS$data_proc, "ivtr_ready_parent_educ_mean_qschool_access.rds")
  ),
  list(
    from = file.path(PATHS$data_proc, "ivtr_ready_pastore_parental_qhome.rds"),
    to = file.path(PATHS$data_proc, "ivtr_ready_pastore_parental_qschool_access.rds")
  ),
  list(
    from = file.path(PATHS$data_proc, "ch_residualized_qhome_parent_mean.rds"),
    to = file.path(PATHS$data_proc, "ch_residualized_qschool_access_parent_mean.rds")
  )
)

cat("RDS migration\n")
for (item in rds_map) {
  process_rds(item$from, item$to)
}

cat("\nText migration\n")
text_roots <- c(
  here::here("R"),
  file.path(PATHS$out_root, "reports"),
  PATHS$out_tables
)

this_script <- normalizePath(here::here("R", "21_rename_q_home_to_q_school_access.R"),
                             winslash = "/", mustWork = FALSE)

text_files <- unlist(lapply(text_roots, function(root) {
  if (!dir.exists(root)) return(character())
  list.files(root, pattern = "\\.(R|md|csv)$", recursive = TRUE, full.names = TRUE)
}), use.names = FALSE)
text_files <- text_files[
  normalizePath(text_files, winslash = "/", mustWork = FALSE) != this_script
]

n_text_changed <- 0L
for (path in text_files) {
  if (replace_text_file(path)) n_text_changed <- n_text_changed + 1L
}

cat("\nText files changed:", n_text_changed, "\n")
cat("Finished:", as.character(Sys.time()), "\n")

sink()
