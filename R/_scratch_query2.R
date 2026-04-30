inv <- readr::read_csv("output/logs/02_variable_inventory.csv", show_col_types = FALSE)

cat("\n=== q04* (labour & wage) per wave ===\n")
print(inv |> dplyr::filter(file_type == "indiv", grepl("^q04", var_name)) |>
        dplyr::distinct(var_name, wave, var_label) |>
        dplyr::arrange(var_name, wave), n = 200)

cat("\n=== q021* (boловрол / education) per wave ===\n")
print(inv |> dplyr::filter(file_type == "indiv", grepl("^q021", var_name)) |>
        dplyr::distinct(var_name, wave, var_label) |>
        dplyr::arrange(var_name, wave), n = 80)
