suppressPackageStartupMessages({ library(haven); library(dplyr) })
raw <- readRDS("data/raw/hses_raw.rds")
bv <- raw |> dplyr::filter(wave == 2024, type == "basicvars") |> dplyr::pull(data) |> .subset2(1)
x <- bv$newaimag
cat("class:", paste(class(x), collapse="/"), "\n")
cat("Unique values:\n")
vl <- attr(x, "labels")
if (!is.null(vl)) {
  for (i in seq_along(vl)) cat(sprintf("  %s = %s\n", vl[i], names(vl)[i]))
} else {
  print(sort(unique(x)))
}
