inv <- readr::read_csv("output/logs/02_variable_inventory.csv", show_col_types = FALSE)

cat("\n=== q0436* and q043*-q044* full labels (wage block) ===\n")
print(inv |> dplyr::filter(file_type == "indiv",
                            grepl("^q043[5-9]|^q044", var_name)) |>
        dplyr::distinct(var_name, wave, var_label) |>
        dplyr::arrange(var_name, wave) |>
        dplyr::group_by(var_name) |>
        dplyr::slice(1) |>
        dplyr::ungroup(), n = 50)

cat("\n=== q021* (boловсрол / education) per wave ===\n")
print(inv |> dplyr::filter(file_type == "indiv",
                            grepl("^q021|^q022|^q023", var_name)) |>
        dplyr::distinct(var_name, var_label) |>
        dplyr::group_by(var_name) |>
        dplyr::slice(1) |>
        dplyr::ungroup() |>
        dplyr::arrange(var_name), n = 50)

cat("\n=== Education first 10 indiv vars q02* ===\n")
print(inv |> dplyr::filter(file_type == "indiv",
                            grepl("^q02", var_name)) |>
        dplyr::distinct(var_name, var_label) |>
        dplyr::group_by(var_name) |>
        dplyr::slice(1) |>
        dplyr::ungroup() |>
        dplyr::arrange(var_name) |>
        dplyr::slice(1:30), n = 30)
