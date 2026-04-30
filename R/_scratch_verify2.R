suppressPackageStartupMessages({ library(haven); library(dplyr) })
raw <- readRDS("data/raw/hses_raw.rds")
get_df <- function(w, t) raw |> dplyr::filter(wave == w, type == t) |> dplyr::pull(data) |> .subset2(1)

inspect_var <- function(varname, file = "indiv", waves = c(2020, 2021, 2022, 2023, 2024)) {
  cat("\n>>> ", varname, " (", file, ")\n", sep="")
  for (w in waves) {
    d <- get_df(w, file)
    if (is.null(d) || !varname %in% names(d)) { cat(sprintf("  [%d] -- not present\n", w)); next }
    x <- d[[varname]]
    lbl <- attr(x, "label"); if (is.null(lbl)) lbl <- "(no label)"
    cat(sprintf("  [%d] %s\n", w, lbl))
    nz <- as.numeric(x[!is.na(x)])
    if (length(nz) > 0) {
      qs <- quantile(nz, c(.01, .25, .5, .75, .99), na.rm = TRUE)
      cat(sprintf("       n=%d  NA%%=%.1f  min=%g  p1=%g  p25=%g  med=%g  p75=%g  p99=%g  max=%g\n",
                  length(nz), 100*mean(is.na(x)), min(nz), qs[1], qs[2], qs[3], qs[4], qs[5], max(nz)))
    }
    vl <- attr(x, "labels")
    if (!is.null(vl) && length(vl) <= 25) {
      cat("       value labels:\n")
      for (i in seq_along(vl)) cat(sprintf("         %s = %s\n", vl[i], names(vl)[i]))
    }
  }
}

# Schooling years
inspect_var("q0213")
# Birth year (q0105y is age, but is there a birth-year direct?)
inspect_var("q0105y")
inspect_var("q0103")  # sex value labels

# Check 2024 q0118a value distribution to confirm birth-aimag pattern
cat("\n=========================\n")
cat("2024 q0118a vs q0114a distribution (to confirm 2024 q0118a = birth aimag)\n")
ind24 <- get_df(2024, "indiv")
if ("q0118a" %in% names(ind24)) {
  cat("q0118a present in 2024:\n")
  cat(sprintf("  range: %g to %g, n_nonNA=%d\n",
              min(ind24$q0118a, na.rm=T), max(ind24$q0118a, na.rm=T),
              sum(!is.na(ind24$q0118a))))
  # Top 10 values
  print(sort(table(ind24$q0118a), decreasing=TRUE)[1:15])
}
if ("q0114a" %in% names(ind24)) cat("q0114a present in 2024\n") else cat("q0114a NOT in 2024\n")

# Check 2024 newaimag distribution for comparison (current residence)
cat("\nFor comparison: 2024 newaimag (current aimag):\n")
bv24 <- get_df(2024, "basicvars")
if ("newaimag" %in% names(bv24)) {
  cat("Top 15 values:\n")
  print(sort(table(bv24$newaimag), decreasing=TRUE)[1:15])
}
