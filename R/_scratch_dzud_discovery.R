# =============================================================================
# DISCOVERY: NSO livestock tables for dzud IV
# =============================================================================
suppressPackageStartupMessages({
  library(dplyr); library(httr); library(jsonlite); library(stringr); library(tibble)
})

# Browse NSO API for agriculture tables
browse_pxweb <- function(path) {
  url <- paste0("https://data.1212.mn/api/v1/mn/NSO/", path)
  res <- GET(url, timeout(30))
  if (status_code(res) == 200) {
    fromJSON(content(res, "text", encoding="UTF-8"), simplifyVector = FALSE)
  } else NULL
}

cat("=== Top level NSO topics ===\n")
top <- browse_pxweb("")
if (!is.null(top)) {
  for (item in top) {
    cat(sprintf("  %s | %s\n", item$id, item$text))
  }
}

show <- function(node) {
  if (is.null(node)) { cat("  (NULL)\n"); return() }
  for (item in node) {
    if (is.list(item) && !is.null(item$id)) cat(sprintf("  [%s] %s | %s\n",
                                                        item$type %||% "?", item$id, item$text))
  }
}
`%||%` <- function(a, b) if (is.null(a)) b else a

cat("\n=== Industry,service > Livestock ===\n")
show(browse_pxweb("Industry,%20service/Livestock"))

cat("\n=== Population,household > Herdsmen ===\n")
show(browse_pxweb("Population,%20household/3_Herdsmen"))

cat("\n=== Economy,environment > Environment ===\n")
show(browse_pxweb("Economy,%20environment/Environment"))
