suppressPackageStartupMessages({ library(dplyr); library(readr) })
ed <- readRDS("data/auxiliary/school_density_by_aimag.rds")

cat("=== ed_supply sample (Завхан=81, Улаанбаатар=11) ===\n")
print(ed |> filter(hses_code %in% c(81, 11)) |> arrange(hses_code, year))

cat("\n=== Range checks ===\n")
cat("schools range:", range(ed$schools, na.rm=T), "\n")
cat("students range:", range(ed$students, na.rm=T), "\n")
cat("density range:", range(ed$school_density, na.rm=T), "\n")

cat("\n=== Recent year (2020) all aimags ===\n")
print(ed |> filter(year == 2020) |> arrange(hses_code), n = 25)


