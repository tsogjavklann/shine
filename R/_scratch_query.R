inv <- readr::read_csv("output/logs/02_variable_inventory.csv", show_col_types = FALSE)

cat("\n=== basicvars vars (all) ===\n")
print(inv |> dplyr::filter(file_type == "basicvars") |>
        dplyr::distinct(var_name, var_label) |>
        dplyr::arrange(var_name), n = 100)

cat("\n=== indiv: q01* (demographic) ===\n")
print(inv |> dplyr::filter(file_type == "indiv", grepl("^q01", var_name)) |>
        dplyr::distinct(var_name, var_label) |>
        dplyr::arrange(var_name), n = 50)

cat("\n=== indiv: q02* (location) ===\n")
print(inv |> dplyr::filter(file_type == "indiv", grepl("^q02", var_name)) |>
        dplyr::distinct(var_name, var_label) |>
        dplyr::arrange(var_name), n = 30)

cat("\n=== Vars by file_type with 'month' or 'year' or 'huis' or 'sar' or 'on' ===\n")
print(inv |> dplyr::filter(grepl("intmon|intyear|svym|svmo|month|year|surv|wave|qtr",
                                 var_name, ignore.case = TRUE)) |>
        dplyr::distinct(var_name, file_type, var_label) |>
        dplyr::arrange(var_name), n = 30)

cat("\n=== q03* (education) ===\n")
print(inv |> dplyr::filter(file_type == "indiv", grepl("^q03", var_name)) |>
        dplyr::distinct(var_name, var_label) |>
        dplyr::arrange(var_name), n = 30)
