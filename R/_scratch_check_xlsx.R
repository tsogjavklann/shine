suppressPackageStartupMessages({
  library(readxl); library(dplyr); library(here); library(stringr)
})
options(width = 140)

xlsx_files <- list.files(here("data"), pattern = "\\.xlsx$", full.names = TRUE)
cat(sprintf("Found %d xlsx files in data/\n\n", length(xlsx_files)))

for (f in xlsx_files) {
  fname <- basename(f)
  cat("==================================================================\n")
  cat(sprintf("ФАЙЛ: %s\n", fname))
  cat(sprintf("Хэмжээ: %d KB\n", round(file.size(f)/1024)))
  cat("==================================================================\n")

  sheets <- excel_sheets(f)
  cat(sprintf("Sheet-ууд (%d): %s\n", length(sheets), paste(sheets, collapse = ", ")))

  # Read first sheet
  df <- tryCatch(read_excel(f, sheet = 1, .name_repair = "minimal"),
                 error = function(e) { cat(sprintf("Read error: %s\n", conditionMessage(e))); NULL })
  if (is.null(df)) next

  cat(sprintf("\nХэмжээ: %d мөр × %d багана\n", nrow(df), ncol(df)))
  cat("Эхний 5 мөр (бүх багана):\n")
  print(head(df, 5), n = 5)
  cat("\nБагана нэр:\n")
  print(names(df))
  cat("\n\n")
}
