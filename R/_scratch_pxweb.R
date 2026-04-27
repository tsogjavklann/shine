suppressPackageStartupMessages({ library(httr); library(jsonlite) })

NSO_API <- "https://data.1212.mn/api/v1/mn/NSO/Economy,%20environment/Consumer%20Price%20Index/DT_NSO_0600_001V3.px"

# Build the JSON body manually as a UTF-8 string
body_str <- '{"query":[{"code":"Суурь он","selection":{"filter":"item","values":["1"]}},{"code":"Бүлэг","selection":{"filter":"item","values":["0"]}}],"response":{"format":"json-stat2"}}'

# Ensure UTF-8 encoded raw bytes
body_raw <- charToRaw(enc2utf8(body_str))

cat("Trying POST with raw UTF-8 body...\n")
r <- POST(NSO_API,
          add_headers("Content-Type" = "application/json; charset=utf-8",
                      Accept = "application/json"),
          body = body_raw,
          timeout(60))

cat("status:", status_code(r), "\n")
cat("content-type:", headers(r)$`content-type`, "\n")

if (status_code(r) == 200) {
  txt <- content(r, "text", encoding = "UTF-8")
  cat("first 200 chars:", substr(txt, 1, 200), "\n")
} else {
  cat("body:", content(r, "text", encoding = "UTF-8"), "\n")
}
