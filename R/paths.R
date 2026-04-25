# =============================================================================
# paths.R — төслийн зам helper
# -----------------------------------------------------------------------------
# Бүх 02-23 скрипт энэ файлыг `source(here::here("R", "paths.R"))`-аар уншина.
# 01_setup.R эхлээд бүх багцыг суулгасны дараа энэ файлыг хэрэглэнэ.
# =============================================================================

if (!requireNamespace("here", quietly = TRUE)) {
  install.packages("here", repos = "https://cloud.r-project.org")
}

PATHS <- list(
  root         = here::here(),
  data_root    = here::here("data"),
  data_raw     = here::here("data", "raw"),
  data_proc    = here::here("data", "processed"),
  data_aux     = here::here("data", "aux"),
  hses_2020    = here::here("data", "hses_2020"),
  hses_2021    = here::here("data", "hses_2021"),
  hses_2022    = here::here("data", "hses_2022"),
  hses_2023    = here::here("data", "hses_2023"),
  hses_2024    = here::here("data", "hses_2024"),
  out_root     = here::here("output"),
  out_tables   = here::here("output", "tables"),
  out_figures  = here::here("output", "figures"),
  out_logs     = here::here("output", "logs"),
  paper        = here::here("paper"),
  R_scripts    = here::here("R")
)

# Дутуу хавтсыг үүсгэх
invisible(lapply(PATHS, function(p) {
  if (!dir.exists(p)) dir.create(p, recursive = TRUE, showWarnings = FALSE)
}))
