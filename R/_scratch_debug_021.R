suppressPackageStartupMessages({ library(httr); library(jsonlite) })

url <- "https://data.1212.mn/api/v1/mn/NSO/Industry,%20service/Livestock/DT_NSO_1001_021V1.px"

# Try 1: empty query
b1 <- '{"query":[],"response":{"format":"json-stat2"}}'
r1 <- POST(url, add_headers("Content-Type"="application/json; charset=utf-8"),
           body = charToRaw(enc2utf8(b1)), timeout(120))
cat(sprintf("Empty query: status=%d, body length=%d\n", status_code(r1),
            nchar(content(r1, "text", encoding="UTF-8"))))
cat(sprintf("First 500 chars: %s\n\n", substr(content(r1, "text", encoding="UTF-8"), 1, 500)))

# Try 2: species filter
b2 <- '{"query":[{"code":"Малын төрөл","selection":{"filter":"item","values":["0"]}}],"response":{"format":"json-stat2"}}'
r2 <- POST(url, add_headers("Content-Type"="application/json; charset=utf-8"),
           body = charToRaw(enc2utf8(b2)), timeout(120))
cat(sprintf("Species filter: status=%d, body length=%d\n", status_code(r2),
            nchar(content(r2, "text", encoding="UTF-8"))))
cat(sprintf("First 500 chars: %s\n\n", substr(content(r2, "text", encoding="UTF-8"), 1, 500)))

# Try 3: GET metadata
r3 <- GET(url, timeout(30))
cat(sprintf("GET metadata: status=%d\n", status_code(r3)))
m <- fromJSON(content(r3, "text", encoding="UTF-8"), simplifyVector=FALSE)
cat(sprintf("Title: %s\nNumber of variables: %d\n", m$title, length(m$variables)))
for (v in m$variables) {
  cat(sprintf("  code='%s' text='%s' n_values=%d\n", v$code, v$text, length(v$values)))
}
