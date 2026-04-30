suppressPackageStartupMessages({ library(haven); library(dplyr) })
raw <- readRDS("data/raw/hses_raw.rds")
get_df <- function(w, t) raw |> dplyr::filter(wave == w, type == t) |> dplyr::pull(data) |> .subset2(1)

for (w in c(2020, 2021, 2022, 2024)) {
  ind <- get_df(w, "indiv")
  if (!"q0105m" %in% names(ind)) {
    cat(sprintf("[%d] q0105m: NOT PRESENT\n\n", w)); next
  }
  x <- ind$q0105m
  lbl <- attr(x, "label")
  cat(sprintf("[%d] q0105m label: %s\n", w, ifelse(is.null(lbl), "(none)", as.character(lbl))))
  cat(sprintf("       class: %s\n", paste(class(x), collapse="/")))
  cat(sprintf("       n=%d, n_NA=%d (%.1f%%), n_zero=%d\n",
              length(x), sum(is.na(x)), 100*mean(is.na(x)), sum(x == 0, na.rm=T)))
  nz <- as.numeric(x[!is.na(x) & x != 0])
  if (length(nz) > 0) {
    qs <- quantile(nz, c(0,.05,.25,.5,.75,.95,1), na.rm=T)
    cat(sprintf("       non-zero summary: min=%g  p5=%g  p25=%g  med=%g  p75=%g  p95=%g  max=%g  n=%d\n",
                qs[1], qs[2], qs[3], qs[4], qs[5], qs[6], qs[7], length(nz)))
  }
  # Cross-check with age — if age in months, q0105m + 12*q0105y = total months
  if ("q0105y" %in% names(ind)) {
    sub <- tibble(y = as.numeric(ind$q0105y), m = as.numeric(ind$q0105m)) |>
      filter(!is.na(y), !is.na(m), m > 0)
    cat(sprintf("       For non-zero m: max(m)=%g, max(y)=%g\n",
                max(sub$m, na.rm=T), max(sub$y, na.rm=T)))
    cat(sprintf("       If m is months-of-age: max should be ≤ 12\n"))
    cat(sprintf("       If m is birth-month: max should be 12\n"))
  }
  cat("\n")
}
