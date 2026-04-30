# Investigate 2023 wave specifically — variables seem renumbered
suppressPackageStartupMessages({
  library(haven); library(dplyr); library(stringr)
})

raw <- readRDS("data/raw/hses_raw.rds")
get_df <- function(w, t) raw |> dplyr::filter(wave == w, type == t) |> dplyr::pull(data) |> .subset2(1)

ind23 <- get_df(2023, "indiv")
cat(sprintf("\n2023 indiv: %d rows × %d cols\n", nrow(ind23), ncol(ind23)))
cat(sprintf("Variables starting with q01: %d\n", sum(grepl("^q01", names(ind23)))))
cat(sprintf("Variables starting with q02: %d\n", sum(grepl("^q02", names(ind23)))))
cat(sprintf("Variables starting with q03: %d\n", sum(grepl("^q03", names(ind23)))))
cat(sprintf("Variables starting with q04: %d\n", sum(grepl("^q04", names(ind23)))))
cat(sprintf("Variables starting with q05: %d\n", sum(grepl("^q05", names(ind23)))))

# Find variables with relevant labels
get_label <- function(x) {
  l <- attr(x, "label"); if (is.null(l)) "" else as.character(l)
}

cat("\n=== 2023: Variables with 'төрсөн' (born) in label ===\n")
for (nm in names(ind23)) {
  l <- get_label(ind23[[nm]])
  if (grepl("төрсөн|төрсэн|нутаг|home", l, ignore.case = TRUE)) {
    cat(sprintf("  %s: %s\n", nm, l))
  }
}

cat("\n=== 2023: Variables with 'боловсрол' (education) in label ===\n")
for (nm in names(ind23)) {
  l <- get_label(ind23[[nm]])
  if (grepl("боловсрол|сургууль|сурлага|education", l, ignore.case = TRUE)) {
    cat(sprintf("  %s: %s\n", nm, l))
  }
}

cat("\n=== 2023: Variables with 'цалин|орлого|wage|earn' in label ===\n")
for (nm in names(ind23)) {
  l <- get_label(ind23[[nm]])
  if (grepl("цалин|орлого|wage|earn|төгрөг", l, ignore.case = TRUE)) {
    cat(sprintf("  %s: %s\n", nm, l))
  }
}

cat("\n=== 2023: Variables with 'ажил|сар|7 хоногт|hours' in label ===\n")
for (nm in names(ind23)) {
  l <- get_label(ind23[[nm]])
  if (grepl("ажил|7 хоногт|hours|цаг", l, ignore.case = TRUE)) {
    cat(sprintf("  %s: %s\n", nm, l))
  }
}
