suppressPackageStartupMessages({
  library(httr); library(jsonlite); library(dplyr); library(tibble); library(stringr); library(readr); library(here)
})
options(width = 140, pillar.print_max = Inf)

# 1. Browse Regional development > Livestock
browse <- function(path) {
  url <- paste0("https://data.1212.mn/api/v1/mn/NSO/", path)
  res <- GET(url, timeout(30))
  if (status_code(res) != 200) return(NULL)
  fromJSON(content(res, "text", encoding="UTF-8"), simplifyVector=FALSE)
}

cat("================================================================\n")
cat("Regional development > Livestock — БҮХ хүснэгт\n")
cat("================================================================\n\n")
sub <- browse("Regional%20development/Livestock")
if (!is.null(sub)) {
  for (it in sub) cat(sprintf("  [%s] %s | %s\n", it$type, it$id, it$text))
}

# 2. Fetch DT_NSO_1001_136V1 metadata
cat("\n================================================================\n")
cat("DT_NSO_1001_136V1.px metadata\n")
cat("================================================================\n\n")
url_136 <- "https://data.1212.mn/api/v1/mn/NSO/Regional%20development/Livestock/DT_NSO_1001_136V1.px"
res <- GET(url_136, timeout(30))
cat(sprintf("Status: %d\n", status_code(res)))
m <- fromJSON(content(res, "text", encoding="UTF-8"), simplifyVector=FALSE)
cat(sprintf("Title: %s\n\n", m$title))
for (v in m$variables) {
  cat(sprintf("[%s] %s — %d values\n", v$code, v$text, length(v$values)))
  head_n <- min(8, length(v$values))
  for (i in seq_len(head_n)) {
    cat(sprintf("    %s = %s\n", v$values[[i]], v$valueTexts[[i]]))
  }
  if (length(v$values) > head_n) cat(sprintf("    ... (+%d more)\n", length(v$values)-head_n))
  cat("\n")
}

# 3. Try fetch with empty query
cat("\n================================================================\n")
cat("Бодит өгөгдөл татах\n")
cat("================================================================\n\n")
fetch <- function(url, body) {
  br <- charToRaw(enc2utf8(body))
  POST(url, add_headers("Content-Type"="application/json; charset=utf-8"),
       body = br, timeout(120))
}
res2 <- fetch(url_136, '{"query":[],"response":{"format":"json-stat2"}}')
cat(sprintf("POST empty query: status=%d, length=%d\n", status_code(res2),
            nchar(content(res2, "text", encoding="UTF-8"))))
if (status_code(res2) != 200) {
  cat(sprintf("Body preview: %s\n", substr(content(res2, "text", encoding="UTF-8"), 1, 200)))
}
