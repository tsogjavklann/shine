sink(here::here("output/logs/_nso_test.log"), split = TRUE)
cat("=== NSO1212 API smoke test ===\n", as.character(Sys.time()), "\n\n")

library(NSO1212)
cat("Version:", as.character(packageVersion("NSO1212")), "\n\n")

cat("--- 1. all_tables() ---\n")
tab <- tryCatch(all_tables(try = 3L, timeout = 60L),
                error = function(e) { cat("ERROR:", conditionMessage(e), "\n"); NULL })
cat("class:", paste(class(tab), collapse="/"), "\n")
cat("length/nrow:", if (is.null(tab)) "NULL" else nrow(tab), "\n")
if (!is.null(tab) && nrow(tab) > 0) {
  cat("Names:\n"); print(names(tab))
  cat("\nFirst 3 rows:\n"); print(head(tab, 3))
}

cat("\n--- 2. Search for CPI tables in tab ---\n")
if (!is.null(tab) && nrow(tab) > 0) {
  cpi_rows <- tab[grepl("Хэрэглээ|CPI|consumer|инфляц", paste(tab$tbl_nm, tab$tbl_eng_nm), ignore.case = TRUE), ]
  cat("Found CPI candidates:", nrow(cpi_rows), "\n")
  print(head(cpi_rows[, c("tbl_id", "tbl_nm")], 20))
}

cat("\n--- 3. Try one common CPI table ---\n")
# Try a known CPI table
for (tid in c("DT_NSO_0500_001V1", "DT_NSO_0500_002V2", "DT_NSO_0500_005V2")) {
  cat("Trying", tid, "...\n")
  d <- tryCatch(get_table(tbl_id = tid, try = 2L, timeout = 30L),
                error = function(e) { cat("  ERROR:", conditionMessage(e), "\n"); NULL })
  cat("  result class:", paste(class(d), collapse="/"), "; nrow:", if (is.null(d)) "NULL" else nrow(d), "\n")
  if (!is.null(d) && nrow(d) > 0) { print(head(d, 2)); break }
}

sink()
