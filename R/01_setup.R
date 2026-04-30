# =============================================================================
# 01_setup.R
# -----------------------------------------------------------------------------
# Зорилго : R session-ийг шинжилгээнд бэлдэх.
#           1) renv::init() (Долоо хоног 1 — lockfile)
#           2) шаардлагатай багц суулгах + ачаалах
#           3) R/paths.R-ээс PATHS list ачаалах
#           4) global option тохируулах (seed, theme)
#           5) sessionInfo() ба ажиллуулсан хугацааг setup.log-д бичих
# Уралдаан: СЭЗИС Эконометрикийн VIII Олимпиад, II шат, 2026
# Сэдэв   : HSES 2020-2024 IV-Threshold үнэлгээ (Caner & Hansen, 2004)
# Ашиглах : Шинэ session бүрд эхэнд `source("R/01_setup.R")` дуудах,
#           эсвэл нэг удаа `Rscript R/01_setup.R`-аар суулгах.
# =============================================================================

t_start <- Sys.time()

# ---- 0. CRAN зэрэгцээний толгой --------------------------------------------
options(
  repos  = c(CRAN = "https://cloud.r-project.org"),
  Ncpus  = max(1L, parallel::detectCores() - 1L),
  warn   = 1
)

# ---- 1. paths.R ачаалах -----------------------------------------------------
# (here-ийг хамгийн түрүүнд суулгах хэрэгтэй учир дараах helper)
ensure_pkg <- function(p) {
  if (!requireNamespace(p, quietly = TRUE)) install.packages(p)
}
ensure_pkg("here")
source(here::here("R", "paths.R"))   # → PATHS list

# ---- 2. renv: lockfile эхлүүлэх (Долоо хоног 1, нэг удаа) -------------------
renv_lock <- file.path(PATHS$root, "renv.lock")
if (!file.exists(renv_lock)) {
  ensure_pkg("renv")
  message("renv::init() ажиллаж байна — энэ удаа л нэг удаа...")
  tryCatch(
    renv::init(bare = FALSE, restart = FALSE, force = TRUE),
    error = function(e) {
      warning("renv::init() алдаа: ", conditionMessage(e),
              "\nГар ажилгаагаар `renv::init()` хийж дахин эхлүүлж болно.")
    }
  )
} else {
  message("renv.lock байна — `renv::restore()` шаардлагатай эсэхийг шалгана уу.")
}

# ---- 3. CRAN багцуудын жагсаалт ---------------------------------------------
cran_pkgs <- c(
  # Data wrangling
  "tidyverse", "haven", "data.table", "janitor", "labelled",
  # Project / paths / IO
  "fs", "glue", "readr", "writexl",
  # Econometrics
  "fixest",          # high-dimensional FE, IV, clustered SE
  "ivreg",           # дэвшилтэт IV diagnostics
  "AER",             # Anderson-Rubin, classical 2SLS reference
  "sandwich",        # robust / clustered VCOV
  "lmtest",          # coeftest()
  "boot",            # bootstrap (1000+ replication)
  "car",             # linearHypothesis(), Wald
  "sampleSelection", # Heckman two-step (T8)
  # Threshold backup
  "strucchange",
  # Tables / figures
  "broom", "modelsummary", "kableExtra", "ggplot2", "scales",
  # Reproducibility / debug
  "rlang", "cli", "tictoc"
)

# GitHub-аас суулгах багц (NSO open data clients)
gh_pkgs <- list(
  NSO1212     = "zorigtbaatar/NSO1212",
  mongolstats = "soyolgerel/mongolstats"
)

# ---- 4. CRAN багц суулгах --------------------------------------------------
# ВАЖНО: dependencies = NA (Depends/Imports/LinkingTo) л суулгана.
# `dependencies = TRUE` нь Suggests-ийг recurse хийж Bioconductor cascade
# (BiocManager → BiocVersion) гарч ирэх учир ашиглахгүй.
# Алдаа гарсан багцыг тус тусад нь catch хийж бусдыг үргэлжлүүлнэ.
install_if_missing <- function(pkgs) {
  installed <- rownames(installed.packages())
  todo <- setdiff(pkgs, installed)
  if (!length(todo)) {
    message("Бүх CRAN багц суулгагдсан.")
    return(invisible())
  }
  message(sprintf("CRAN-аас %d багц суулгаж эхэлж байна: %s",
                  length(todo), paste(todo, collapse = ", ")))
  failed <- character()
  for (p in todo) {
    ok <- tryCatch(
      {
        install.packages(p, dependencies = NA, quiet = FALSE)
        p %in% rownames(installed.packages())
      },
      error = function(e) {
        warning(sprintf("[%s] суулгахад алдаа: %s", p, conditionMessage(e)))
        FALSE
      }
    )
    if (!ok) failed <- c(failed, p)
  }
  if (length(failed)) {
    warning(sprintf("Дараах %d багц суулгагдсангүй: %s",
                    length(failed), paste(failed, collapse = ", ")))
  }
}

install_gh_if_missing <- function(gh_list) {
  installed <- rownames(installed.packages())
  if (!"remotes" %in% installed) {
    install.packages("remotes", dependencies = NA)
  }
  for (nm in names(gh_list)) {
    if (!nm %in% installed) {
      message(sprintf("GitHub-аас %s (%s) суулгаж байна...", nm, gh_list[[nm]]))
      tryCatch(
        remotes::install_github(gh_list[[nm]],
                                upgrade = "never",
                                dependencies = NA,
                                quiet = TRUE),
        error = function(e) {
          warning(sprintf("[%s] суулгахад алдаа: %s", nm, conditionMessage(e)))
        }
      )
    }
  }
}

install_if_missing(cran_pkgs)
install_gh_if_missing(gh_pkgs)

# ---- 5. Багцуудыг ачаалах ---------------------------------------------------
core_load <- c(
  "tidyverse", "haven", "data.table", "janitor", "labelled",
  "fs", "glue",
  "fixest", "ivreg", "AER", "sandwich", "lmtest", "boot", "car",
  "sampleSelection",
  "broom", "modelsummary", "ggplot2",
  "cli", "tictoc",
  "parallel"     # bootstrap-д ашиглана (base R-ийн нэг хэсэг)
)
invisible(lapply(core_load, function(p) {
  suppressPackageStartupMessages(library(p, character.only = TRUE))
}))

for (p in names(gh_pkgs)) {
  if (requireNamespace(p, quietly = TRUE)) {
    suppressPackageStartupMessages(library(p, character.only = TRUE))
  }
}

# ---- 6. Global option тохиргоо ----------------------------------------------
set.seed(2026)
options(
  scipen = 99,
  digits = 4,
  dplyr.summarise.inform = FALSE,
  fixest_notes = FALSE
)

# fixest хэв маяг — feols бүрд cluster-ыг тус бүрд бичнэ (§1.6 ~aimag + wave,
# жинхэнэ two-way) тул глобал default-ыг өөрчлөхгүй. setFixest_se() нь fixest
# 0.12+ дотор setFixest_vcov() болсон, бид per-call-аар vcov тогтоох учир хэрэггүй.
setFixest_estimation(panel.id = NULL)

# ggplot2 default theme
theme_set(theme_minimal(base_family = "sans", base_size = 11))

# ---- 7. setup.log бичих -----------------------------------------------------
log_path <- file.path(PATHS$out_logs, "setup.log")

t_end <- Sys.time()
elapsed <- round(as.numeric(difftime(t_end, t_start, units = "secs")), 1)

sink(log_path, append = FALSE)
cat("==========================================================\n")
cat("01_setup.R лог  ", as.character(t_end), "\n")
cat("==========================================================\n")
cat(sprintf("Эхэлсэн : %s\n", t_start))
cat(sprintf("Дуусcан : %s\n", t_end))
cat(sprintf("Элапс   : %.1f сек\n", elapsed))
cat("\n--- PATHS ---\n")
for (nm in names(PATHS)) cat(sprintf("  %-12s %s\n", nm, PATHS[[nm]]))
cat("\n--- Loaded packages ---\n")
loaded <- sort(unique(c(core_load, names(gh_pkgs))))
for (p in loaded) {
  if (requireNamespace(p, quietly = TRUE)) {
    cat(sprintf("  %-18s %s\n", p, as.character(packageVersion(p))))
  }
}
cat("\n--- sessionInfo() ---\n")
print(sessionInfo())
sink()

# ---- 8. Тэмдэглэгээ ---------------------------------------------------------
cli::cli_h1("Setup дууслаа")
cli::cli_alert_success("R version : {R.version.string}")
cli::cli_alert_success("Working   : {PATHS$root}")
cli::cli_alert_success("Лог       : {log_path}")
cli::cli_alert_info("Хугацаа   : {elapsed} сек")
cli::cli_alert_info("Дараагийн алхам: R/02_import_hses.R")
