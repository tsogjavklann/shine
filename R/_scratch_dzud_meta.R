suppressPackageStartupMessages({
  library(httr); library(jsonlite)
})

show_meta <- function(table_id, subdir) {
  url <- paste0("https://data.1212.mn/api/v1/mn/NSO/", subdir, "/", table_id)
  res <- GET(url, timeout(30))
  if (status_code(res) != 200) {
    cat(sprintf("FAIL %s: %d\n", table_id, status_code(res))); return()
  }
  meta <- fromJSON(content(res, "text", encoding="UTF-8"), simplifyVector=FALSE)
  cat(sprintf("\n========== %s ==========\n", table_id))
  cat(sprintf("Title: %s\n", meta$title))
  for (v in meta$variables) {
    cat(sprintf("\n  [%s] %s — %d values\n",
                v$code, v$text, length(v$values)))
    head_n <- min(8, length(v$values))
    for (i in seq_len(head_n)) {
      cat(sprintf("    %s = %s\n", v$values[[i]], v$valueTexts[[i]]))
    }
    if (length(v$values) > head_n) cat(sprintf("    ... (+%d more)\n", length(v$values)-head_n))
  }
}

show_meta("DT_NSO_1001_011V1.px", "Industry,%20service/Livestock")  # large livestock abnormal loss aimag-qtr
show_meta("DT_NSO_1001_029V1.px", "Industry,%20service/Livestock")  # large livestock abnormal loss bag-khoroo-year
show_meta("DT_NSO_1001_013V3.px", "Industry,%20service/Livestock")  # diseased livestock loss bag-khoroo-year

# Browse Historical data
browse_pxweb <- function(path) {
  url <- paste0("https://data.1212.mn/api/v1/mn/NSO/", path)
  res <- GET(url, timeout(30))
  if (status_code(res) != 200) return(NULL)
  fromJSON(content(res, "text", encoding="UTF-8"), simplifyVector = FALSE)
}
cat("\n========== Historical data ==========\n")
hist <- browse_pxweb("Historical%20data")
if (!is.null(hist)) {
  for (item in hist) cat(sprintf("  [%s] %s | %s\n", item$type, item$id, item$text))
}
