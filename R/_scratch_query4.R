inv <- readr::read_csv("output/logs/02_variable_inventory.csv", show_col_types = FALSE)

cat("\n=== Identifier-related (identif, member, person, hhid, pid) ===\n")
print(inv |> dplyr::filter(grepl("^identif|member|person|^hhid|^pid|^id$", var_name, ignore.case = TRUE)) |>
        dplyr::distinct(var_name, file_type, var_label) |>
        dplyr::arrange(file_type, var_name), n = 30)

cat("\n=== indiv first 5 vars per wave (likely identifiers) ===\n")
print(inv |> dplyr::filter(file_type == "indiv") |>
        dplyr::group_by(wave) |>
        dplyr::slice(1:8) |>
        dplyr::arrange(wave, var_name), n = 50)

cat("\n=== hhold first 5 vars ===\n")
print(inv |> dplyr::filter(file_type == "hhold") |>
        dplyr::distinct(var_name, var_label) |>
        dplyr::arrange(var_name) |>
        dplyr::slice(1:20), n = 20)

cat("\n=== q0101 (hh roster line / member num?) ===\n")
print(inv |> dplyr::filter(grepl("^q010[0-9]$|^q01[0-2][0-9]a?b?$", var_name)) |>
        dplyr::distinct(var_name, var_label) |>
        dplyr::group_by(var_name) |>
        dplyr::slice(1) |>
        dplyr::arrange(var_name), n = 30)
