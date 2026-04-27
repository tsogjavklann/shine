# Full 2023 indiv variable dump
suppressPackageStartupMessages({ library(haven); library(dplyr) })

raw <- readRDS("data/raw/hses_raw.rds")
ind23 <- raw |> dplyr::filter(wave == 2023, type == "indiv") |> dplyr::pull(data) |> .subset2(1)

cat(sprintf("\n2023 indiv: %d rows, %d cols\n\n", nrow(ind23), ncol(ind23)))
cat("All 2023 indiv variables with labels:\n")
for (nm in names(ind23)) {
  l <- attr(ind23[[nm]], "label"); if (is.null(l)) l <- "(no label)"
  cat(sprintf("  %-12s | %s\n", nm, l))
}

cat("\n--- Also check 2023 hhold and basicvars ---\n")
hh23 <- raw |> dplyr::filter(wave == 2023, type == "hhold") |> dplyr::pull(data) |> .subset2(1)
cat(sprintf("\n2023 hhold: %d rows, %d cols\n", nrow(hh23), ncol(hh23)))
bv23 <- raw |> dplyr::filter(wave == 2023, type == "basicvars") |> dplyr::pull(data) |> .subset2(1)
cat(sprintf("2023 basicvars: %d rows, %d cols\n", nrow(bv23), ncol(bv23)))
cat(sprintf("2023 basicvars cols: %s\n", paste(names(bv23), collapse = ", ")))
