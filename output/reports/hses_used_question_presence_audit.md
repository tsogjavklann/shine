# HSES Used Question Presence Audit

Generated from raw `.dta` metadata and selected-column reads for HSES 2020-2024.

## Files Read
|   wave | file_type   | file                              |   n_rows |   n_cols |
|-------:|:------------|:----------------------------------|---------:|---------:|
|   2020 | basicvars   | data\hses_2020\basicvars (11).dta |    16460 |       11 |
|   2020 | hhold       | data\hses_2020\01_hhold (11).dta  |    16460 |       90 |
|   2020 | indiv       | data\hses_2020\02_indiv (12).dta  |    59737 |      177 |
|   2021 | basicvars   | data\hses_2021\basicvars (12).dta |    11199 |       11 |
|   2021 | hhold       | data\hses_2021\01_hhold (12).dta  |    11199 |       90 |
|   2021 | indiv       | data\hses_2021\02_indiv (13).dta  |    40129 |      177 |
|   2022 | basicvars   | data\hses_2022\basicvars (13).dta |    22995 |       12 |
|   2022 | hhold       | data\hses_2022\01_hhold (13).dta  |    22995 |      111 |
|   2022 | indiv       | data\hses_2022\02_indiv (14).dta  |    80926 |      177 |
|   2023 | basicvars   | data\hses_2023\basicvars (14).dta |     8550 |       12 |
|   2023 | hhold       | data\hses_2023\01_hhold (14).dta  |     8550 |       47 |
|   2023 | indiv       | data\hses_2023\02_indiv (15).dta  |    30284 |       27 |
|   2024 | basicvars   | data\hses_2024\basicvars.dta      |    15513 |       14 |
|   2024 | hhold       | data\hses_2024\01_hhold.dta       |    15513 |      132 |
|   2024 | indiv       | data\hses_2024\02_indiv.dta       |    53898 |      184 |

## Pipeline Component Check
|   wave | component                              | required_vars                                                                                   | ok    | note                                                                           |
|-------:|:---------------------------------------|:------------------------------------------------------------------------------------------------|:------|:-------------------------------------------------------------------------------|
|   2020 | basicvars controls/weights             | identif,newaimag,region,urban,location,hhsize,hhweight,month                                    | True  |                                                                                |
|   2020 | demographic/education/wage variables   | identif,ind_id,q0102,q0103,q0105y,q0106,q0210,q0213,q0404,q0436a,q0436b,q0437,q0438,q0439,q0427 | True  |                                                                                |
|   2020 | birth place variables used by pipeline | q0113,q0114a,q0114b                                                                             | True  | Correct birth-place source. q0118a/b exist but are migration-origin questions. |
|   2021 | basicvars controls/weights             | identif,newaimag,region,urban,location,hhsize,hhweight,month                                    | True  |                                                                                |
|   2021 | demographic/education/wage variables   | identif,ind_id,q0102,q0103,q0105y,q0106,q0210,q0213,q0404,q0436a,q0436b,q0437,q0438,q0439,q0427 | True  |                                                                                |
|   2021 | birth place variables used by pipeline | q0113,q0114a,q0114b                                                                             | True  | Correct birth-place source. q0118a/b exist but are migration-origin questions. |
|   2022 | basicvars controls/weights             | identif,newaimag,region,urban,location,hhsize,hhweight,month                                    | True  |                                                                                |
|   2022 | demographic/education/wage variables   | identif,ind_id,q0102,q0103,q0105y,q0106,q0210,q0213,q0404,q0436a,q0436b,q0437,q0438,q0439,q0427 | True  |                                                                                |
|   2022 | birth place variables used by pipeline | q0113,q0114a,q0114b                                                                             | True  | Correct birth-place source. q0118a/b exist but are migration-origin questions. |
|   2023 | basicvars controls/weights             | identif,newaimag,region,urban,location,hhsize,hhweight,month                                    | True  |                                                                                |
|   2023 | demographic/education/wage variables   | identif,ind_id,q0102,q0103,q0105y,q0106,q0210,q0213,q0404,q0436a,q0436b,q0437,q0438,q0439,q0427 | False |                                                                                |
|   2023 | birth place variables used by pipeline | q0113,q0114a,q0114b,q0117,q0118a,q0118b                                                         | False | 2023 checked but not used in final pipeline.                                   |
|   2024 | basicvars controls/weights             | identif,newaimag,region,urban,location,hhsize,hhweight,month                                    | True  |                                                                                |
|   2024 | demographic/education/wage variables   | identif,ind_id,q0102,q0103,q0105y,q0106,q0210,q0213,q0404,q0436a,q0436b,q0437,q0438,q0439,q0427 | True  |                                                                                |
|   2024 | birth place variables used by pipeline | q0117,q0118a,q0118b                                                                             | True  | Correct birth-place source; question shifted to 1.18.                          |

## Key Findings
- The current pipeline can use HSES 2020, 2021, 2022, and 2024 for demographic, education, wage, location, and survey-weight variables.
- 2023 files exist, but the individual file does not contain the wage/education/birth-place variable set needed by this pipeline, so excluding 2023 is justified.
- Birth-place coding changes: 2020-2022 use `q0113`, `q0114a`, `q0114b`; 2024 uses `q0117`, `q0118a`, `q0118b`.
- In 2020-2022, `q0118a/b` are present but their labels indicate migration origin, not birth place; using them as birth place for those years would be wrong.

## Full Variable Audit
|   wave | file_type   | var_name   | role                                                      | present   | pct_nonmissing   | label                                                                            |
|-------:|:------------|:-----------|:----------------------------------------------------------|:----------|:-----------------|:---------------------------------------------------------------------------------|
|   2020 | basicvars   | identif    | household id / merge key                                  | True      | 100.0            | group(identif)                                                                   |
|   2020 | basicvars   | newaimag   | current aimag / proxy when born in current place          | True      | 100.0            | New code of aimag                                                                |
|   2020 | basicvars   | region     | region control                                            | True      | 100.0            | Region                                                                           |
|   2020 | basicvars   | urban      | urban/rural control                                       | True      | 100.0            | Urban/rural                                                                      |
|   2020 | basicvars   | location   | location control                                          | True      | 100.0            | Strata 4 locations                                                               |
|   2020 | basicvars   | hhsize     | household size                                            | True      | 100.0            | Household size                                                                   |
|   2020 | basicvars   | hhweight   | survey weight                                             | True      | 100.0            | Last weight                                                                      |
|   2020 | basicvars   | month      | interview month / CPI merge                               | True      | 100.0            | Calendar month of the interview                                                  |
|   2020 | indiv       | identif    | household id / merge key                                  | True      | 100.0            | group(identif)                                                                   |
|   2020 | indiv       | ind_id     | person id / merge key                                     | True      | 100.0            | Хувийн дугаар                                                                    |
|   2020 | indiv       | q0102      | relation to household head                                | True      | 100.0            | 1.02 Өрхийн тэргүүлэгчтэй ямар хамааралтай в                                     |
|   2020 | indiv       | q0103      | sex                                                       | True      | 100.0            | 1.03 Хүйс                                                                        |
|   2020 | indiv       | q0105y     | age in years                                              | True      | 100.0            | 1.05 Нас /жил/                                                                   |
|   2020 | indiv       | q0105m     | age/birth month if available                              | True      | 2.22             | 1.05 Нас /сар/                                                                   |
|   2020 | indiv       | q0106      | marital status                                            | True      | 67.22            | 1.06 Гэрлэлтийн байдал                                                           |
|   2020 | indiv       | q0107      | spouse person id                                          | True      | 40.86            | 1.07 Эхнэр нөхрийн хувийн дугаар                                                 |
|   2020 | indiv       | q0113      | born in current place flag, 2020-2022                     | True      | 97.36            | 1.13 [НЭР] энэ нутагт төрсөн үү?                                                 |
|   2020 | indiv       | q0114a     | birth aimag for 2020-2022                                 | True      | 29.18            | 1.14 [НЭР] хаана төрсөн бэ? Аймаг/ Нийслэл                                       |
|   2020 | indiv       | q0114b     | birth soum for 2020-2022                                  | True      | 28.99            | 1.14 [НЭР] хаана төрсөн бэ? Сум/ дүүрэг                                          |
|   2020 | indiv       | q0117      | born in current place flag, 2024                          | True      | 25.24            | 1.17 [НЭР] хамгийн сүүлд хаанаас шилжиж ирсэн                                    |
|   2020 | indiv       | q0118a     | birth aimag in 2024; migration aimag in 2020-2022         | True      | 25.24            | 1.18 [НЭР] хамгийн сүүлд аль аймаг, сумаас шил                                   |
|   2020 | indiv       | q0118b     | birth soum in 2024; migration soum in 2020-2022           | True      | 24.87            | 1.18 [НЭР] хамгийн сүүлд аль аймаг, сумаас шил                                   |
|   2020 | indiv       | q0210      | education level                                           | True      | 85.77            | 2.10 [НЭР]-ын/ийн эзэмшсэн  боловсролын дээд т                                   |
|   2020 | indiv       | q0213      | total schooling years                                     | True      | 85.77            | 2.13 [НЭР] нийт хэдэн жил сургуульд  суралцсан                                   |
|   2020 | indiv       | q0404      | paid work in last 7 days                                  | True      | 85.96            | 4.04 [НЭР] сүүлийн 7 хоногт наад зах нь 1 цаг ям                                 |
|   2020 | indiv       | q0436a     | main job wage amount, component used in wage construction | True      | 23.93            | 4.36 [НЭР] нь сүүлийн 12 сард үндсэн ажлаасаа х                                  |
|   2020 | indiv       | q0436b     | main job wage amount, component used in wage construction | True      | 23.93            | 4.36 [НЭР] нь сүүлийн 12 сард үндсэн ажлаасаа х                                  |
|   2020 | indiv       | q0436c     | main job wage component, extra/reference                  | True      | 23.93            | 4.36 [НЭР] нь сүүлийн 12 сард үндсэн ажлаасаа х                                  |
|   2020 | indiv       | q0437      | months worked in last 12 months                           | True      | 38.08            | 4.37 [НЭР] энэ ажлыг хэдэн сар хийсэн бэ?                                        |
|   2020 | indiv       | q0438      | days per month worked                                     | True      | 38.08            | 4.38 [НЭР] ажилласан сарууддаа энэ ажилд сард                                    |
|   2020 | indiv       | q0439      | hours per day worked                                      | True      | 38.08            | 4.39 [НЭР] ажилласан саруудын өдрүүддээ энэ а                                    |
|   2020 | indiv       | q0427      | hours worked in last 7 days                               | True      | 35.15            | 4.27 [НЭР] сүүлийн 7 хоногт үндсэн ажилдаа ний                                   |
|   2021 | basicvars   | identif    | household id / merge key                                  | True      | 100.0            | group(identif)                                                                   |
|   2021 | basicvars   | newaimag   | current aimag / proxy when born in current place          | True      | 100.0            | New code of aimag                                                                |
|   2021 | basicvars   | region     | region control                                            | True      | 100.0            | Region                                                                           |
|   2021 | basicvars   | urban      | urban/rural control                                       | True      | 100.0            | Urban/rural                                                                      |
|   2021 | basicvars   | location   | location control                                          | True      | 100.0            | Strata 4 locations                                                               |
|   2021 | basicvars   | hhsize     | household size                                            | True      | 100.0            | Household size                                                                   |
|   2021 | basicvars   | hhweight   | survey weight                                             | True      | 100.0            |                                                                                  |
|   2021 | basicvars   | month      | interview month / CPI merge                               | True      | 100.0            | Calendar month of the interview                                                  |
|   2021 | indiv       | identif    | household id / merge key                                  | True      | 100.0            | group(identif)                                                                   |
|   2021 | indiv       | ind_id     | person id / merge key                                     | True      | 100.0            | Хувийн дугаар                                                                    |
|   2021 | indiv       | q0102      | relation to household head                                | True      | 100.0            | 1.02 Өрхийн тэргүүлэгчтэй ямар хамааралтай вэ?                                   |
|   2021 | indiv       | q0103      | sex                                                       | True      | 100.0            | 1.03 Хүйс                                                                        |
|   2021 | indiv       | q0105y     | age in years                                              | True      | 100.0            | 1.05 Нас /жил/                                                                   |
|   2021 | indiv       | q0105m     | age/birth month if available                              | True      | 1.97             | 1.05 Нас /сар/                                                                   |
|   2021 | indiv       | q0106      | marital status                                            | True      | 67.26            | 1.06 Гэрлэлтийн байдал                                                           |
|   2021 | indiv       | q0107      | spouse person id                                          | True      | 40.61            | 1.07 Эхнэр нөхрийн хувийн дугаар                                                 |
|   2021 | indiv       | q0113      | born in current place flag, 2020-2022                     | True      | 97.91            | 1.13 [НЭР] энэ нутагт төрсөн үү?                                                 |
|   2021 | indiv       | q0114a     | birth aimag for 2020-2022                                 | True      | 27.3             | 1.14 [НЭР] хаана төрсөн бэ? Аймаг/ Нийслэл                                       |
|   2021 | indiv       | q0114b     | birth soum for 2020-2022                                  | True      | 27.11            | 1.14 [НЭР] хаана төрсөн бэ? Сум/ дүүрэг                                          |
|   2021 | indiv       | q0117      | born in current place flag, 2024                          | True      | 23.67            | 1.17 [НЭР] хамгийн сүүлд хаанаас шилжиж ирсэн бэ?                                |
|   2021 | indiv       | q0118a     | birth aimag in 2024; migration aimag in 2020-2022         | True      | 23.67            | 1.18 [НЭР] хамгийн сүүлд аль аймаг, сумаас шилжиж ирсэн бэ? Аймаг/ Нийслэл       |
|   2021 | indiv       | q0118b     | birth soum in 2024; migration soum in 2020-2022           | True      | 23.4             | 1.18 [НЭР] хамгийн сүүлд аль аймаг, сумаас шилжиж ирсэн бэ? Сум/ дүүрэг          |
|   2021 | indiv       | q0210      | education level                                           | True      | 86.96            | 2.10 [НЭР]-ын/ийн эзэмшсэн  боловсролын дээд түвшинг хэлнэ үү?                   |
|   2021 | indiv       | q0213      | total schooling years                                     | True      | 86.96            | 2.13 [НЭР] нийт хэдэн жил сургуульд  суралцсан бэ?                               |
|   2021 | indiv       | q0404      | paid work in last 7 days                                  | True      | 87.08            | 4.04 [НЭР] сүүлийн 7 хоногт наад зах нь 1 цаг ямар нэг цалин хөлс, төлбөртэй ажи |
|   2021 | indiv       | q0436a     | main job wage amount, component used in wage construction | True      | 21.39            | 4.36 [НЭР] нь сүүлийн 12 сард үндсэн ажлаасаа хэдэн төгрөгийн цалин авсан бэ? Сү |
|   2021 | indiv       | q0436b     | main job wage amount, component used in wage construction | True      | 21.39            | 4.36 [НЭР] нь сүүлийн 12 сард үндсэн ажлаасаа хэдэн төгрөгийн цалин авсан бэ? Сү |
|   2021 | indiv       | q0436c     | main job wage component, extra/reference                  | True      | 21.39            | 4.36 [НЭР] нь сүүлийн 12 сард үндсэн ажлаасаа хэдэн төгрөгийн цалин авсан бэ? Ур |
|   2021 | indiv       | q0437      | months worked in last 12 months                           | True      | 36.83            | 4.37 [НЭР] энэ ажлыг хэдэн сар хийсэн бэ?                                        |
|   2021 | indiv       | q0438      | days per month worked                                     | True      | 36.83            | 4.38 [НЭР] ажилласан сарууддаа энэ ажилд сард  дунджаар  хэдэн өдөр зарцуулсан б |
|   2021 | indiv       | q0439      | hours per day worked                                      | True      | 36.83            | 4.39 [НЭР] ажилласан саруудын өдрүүддээ энэ ажилд өдөрт   дунджаар хэдэн цаг зар |
|   2021 | indiv       | q0427      | hours worked in last 7 days                               | True      | 34.53            | 4.27 [НЭР] сүүлийн 7 хоногт үндсэн ажилдаа нийтдээ хэдэн цаг зарцуулсан бэ?      |
|   2022 | basicvars   | identif    | household id / merge key                                  | True      | 100.0            | group(identif)                                                                   |
|   2022 | basicvars   | newaimag   | current aimag / proxy when born in current place          | True      | 100.0            | New code of aimag                                                                |
|   2022 | basicvars   | region     | region control                                            | True      | 100.0            | Region                                                                           |
|   2022 | basicvars   | urban      | urban/rural control                                       | True      | 100.0            | Urban/rural                                                                      |
|   2022 | basicvars   | location   | location control                                          | True      | 100.0            | Strata 4 locations                                                               |
|   2022 | basicvars   | hhsize     | household size                                            | True      | 100.0            | Household size                                                                   |
|   2022 | basicvars   | hhweight   | survey weight                                             | True      | 100.0            |                                                                                  |
|   2022 | basicvars   | month      | interview month / CPI merge                               | True      | 100.0            | Calendar month of the interview                                                  |
|   2022 | indiv       | identif    | household id / merge key                                  | True      | 100.0            | group(identif)                                                                   |
|   2022 | indiv       | ind_id     | person id / merge key                                     | True      | 100.0            | Хувийн дугаар                                                                    |
|   2022 | indiv       | q0102      | relation to household head                                | True      | 100.0            | 1.02 Өрхийн тэргүүлэгчтэй ямар хамааралтай вэ?                                   |
|   2022 | indiv       | q0103      | sex                                                       | True      | 100.0            | 1.03 Хүйс                                                                        |
|   2022 | indiv       | q0105y     | age in years                                              | True      | 100.0            | 1.05 Нас /жил/                                                                   |
|   2022 | indiv       | q0105m     | age/birth month if available                              | True      | 1.58             | 1.05 Нас /сар/                                                                   |
|   2022 | indiv       | q0106      | marital status                                            | True      | 67.52            | 1.06 Гэрлэлтийн байдал                                                           |
|   2022 | indiv       | q0107      | spouse person id                                          | True      | 40.63            | 1.07 Эхнэр нөхрийн хувийн дугаар                                                 |
|   2022 | indiv       | q0113      | born in current place flag, 2020-2022                     | True      | 96.75            | 1.13 [НЭР] энэ нутагт төрсөн үү?                                                 |
|   2022 | indiv       | q0114a     | birth aimag for 2020-2022                                 | True      | 26.82            | 1.14 [НЭР] хаана төрсөн бэ? Аймаг/ Нийслэл                                       |
|   2022 | indiv       | q0114b     | birth soum for 2020-2022                                  | True      | 26.67            | 1.14 [НЭР] хаана төрсөн бэ? Сум/ дүүрэг                                          |
|   2022 | indiv       | q0117      | born in current place flag, 2024                          | True      | 20.84            | 1.17 [НЭР] хамгийн сүүлд хаанаас шилжиж ирсэн бэ?                                |
|   2022 | indiv       | q0118a     | birth aimag in 2024; migration aimag in 2020-2022         | True      | 20.84            | 1.18 [НЭР] хамгийн сүүлд аль аймаг, сумаас шилжиж ирсэн бэ? Аймаг/ Нийслэл       |
|   2022 | indiv       | q0118b     | birth soum in 2024; migration soum in 2020-2022           | True      | 20.63            | 1.18 [НЭР] хамгийн сүүлд аль аймаг, сумаас шилжиж ирсэн бэ? Сум/ дүүрэг          |
|   2022 | indiv       | q0210      | education level                                           | True      | 86.28            | 2.10 [НЭР]-ын/ийн эзэмшсэн  боловсролын дээд түвшинг хэлнэ үү?                   |
|   2022 | indiv       | q0213      | total schooling years                                     | True      | 86.28            | 2.13 [НЭР] нийт хэдэн жил сургуульд  суралцсан бэ?                               |
|   2022 | indiv       | q0404      | paid work in last 7 days                                  | True      | 86.52            | 4.04 [НЭР] сүүлийн 7 хоногт наад зах нь 1 цаг ямар нэг цалин хөлс, төлбөртэй ажи |
|   2022 | indiv       | q0436a     | main job wage amount, component used in wage construction | True      | 23.03            | 4.36 [НЭР] нь сүүлийн 12 сард үндсэн ажлаасаа хэдэн төгрөгийн цалин авсан бэ? Сү |
|   2022 | indiv       | q0436b     | main job wage amount, component used in wage construction | True      | 23.03            | 4.36 [НЭР] нь сүүлийн 12 сард үндсэн ажлаасаа хэдэн төгрөгийн цалин авсан бэ? Сү |
|   2022 | indiv       | q0436c     | main job wage component, extra/reference                  | True      | 23.03            | 4.36 [НЭР] нь сүүлийн 12 сард үндсэн ажлаасаа хэдэн төгрөгийн цалин авсан бэ? Ур |
|   2022 | indiv       | q0437      | months worked in last 12 months                           | True      | 36.11            | 4.37 [НЭР] энэ ажлыг хэдэн сар хийсэн бэ?                                        |
|   2022 | indiv       | q0438      | days per month worked                                     | True      | 36.11            | 4.38 [НЭР] ажилласан сарууддаа энэ ажилд сард  дунджаар  хэдэн өдөр зарцуулсан б |
|   2022 | indiv       | q0439      | hours per day worked                                      | True      | 36.11            | 4.39 [НЭР] ажилласан саруудын өдрүүддээ энэ ажилд өдөрт   дунджаар хэдэн цаг зар |
|   2022 | indiv       | q0427      | hours worked in last 7 days                               | True      | 34.01            | 4.27 [НЭР] сүүлийн 7 хоногт үндсэн ажилдаа нийтдээ хэдэн цаг зарцуулсан бэ?      |
|   2023 | basicvars   | identif    | household id / merge key                                  | True      | 100.0            | group(identif)                                                                   |
|   2023 | basicvars   | newaimag   | current aimag / proxy when born in current place          | True      | 100.0            | New code of aimag                                                                |
|   2023 | basicvars   | region     | region control                                            | True      | 100.0            | Region                                                                           |
|   2023 | basicvars   | urban      | urban/rural control                                       | True      | 100.0            | Urban/rural                                                                      |
|   2023 | basicvars   | location   | location control                                          | True      | 100.0            | Strata 4 locations                                                               |
|   2023 | basicvars   | hhsize     | household size                                            | True      | 100.0            | Household size                                                                   |
|   2023 | basicvars   | hhweight   | survey weight                                             | True      | 100.0            |                                                                                  |
|   2023 | basicvars   | month      | interview month / CPI merge                               | True      | 100.0            | Calendar month of the interview                                                  |
|   2023 | indiv       | identif    | household id / merge key                                  | True      | 100.0            | group(identif)                                                                   |
|   2023 | indiv       | ind_id     | person id / merge key                                     | True      | 100.0            | Хувийн дугаар                                                                    |
|   2023 | indiv       | q0102      | relation to household head                                | True      | 100.0            | 1.02 Өрхийн тэргүүлэгчтэй ямар хамааралтай вэ?                                   |
|   2023 | indiv       | q0103      | sex                                                       | True      | 100.0            | 1.03 Хүйс                                                                        |
|   2023 | indiv       | q0105y     | age in years                                              | True      | 100.0            | 1.05 Нас /жил/                                                                   |
|   2023 | indiv       | q0105m     | age/birth month if available                              | True      | 1.73             | 1.05 Нас /сар/                                                                   |
|   2023 | indiv       | q0106      | marital status                                            | True      | 67.57            | 1.06 Гэрлэлтийн байдал                                                           |
|   2023 | indiv       | q0107      | spouse person id                                          | True      | 40.82            | 1.07 Эхнэр нөхрийн хувийн дугаар                                                 |
|   2023 | indiv       | q0113      | born in current place flag, 2020-2022                     | False     |                  |                                                                                  |
|   2023 | indiv       | q0114a     | birth aimag for 2020-2022                                 | False     |                  |                                                                                  |
|   2023 | indiv       | q0114b     | birth soum for 2020-2022                                  | False     |                  |                                                                                  |
|   2023 | indiv       | q0117      | born in current place flag, 2024                          | False     |                  |                                                                                  |
|   2023 | indiv       | q0118a     | birth aimag in 2024; migration aimag in 2020-2022         | False     |                  |                                                                                  |
|   2023 | indiv       | q0118b     | birth soum in 2024; migration soum in 2020-2022           | False     |                  |                                                                                  |
|   2023 | indiv       | q0210      | education level                                           | True      | 35.41            | 2.10 [НЭР] сүүлийн 12 сард үндсэн ажлаасаа гадна нэмэлт/давхар цалинтай ажил/орл |
|   2023 | indiv       | q0213      | total schooling years                                     | False     |                  |                                                                                  |
|   2023 | indiv       | q0404      | paid work in last 7 days                                  | False     |                  |                                                                                  |
|   2023 | indiv       | q0436a     | main job wage amount, component used in wage construction | False     |                  |                                                                                  |
|   2023 | indiv       | q0436b     | main job wage amount, component used in wage construction | False     |                  |                                                                                  |
|   2023 | indiv       | q0436c     | main job wage component, extra/reference                  | False     |                  |                                                                                  |
|   2023 | indiv       | q0437      | months worked in last 12 months                           | False     |                  |                                                                                  |
|   2023 | indiv       | q0438      | days per month worked                                     | False     |                  |                                                                                  |
|   2023 | indiv       | q0439      | hours per day worked                                      | False     |                  |                                                                                  |
|   2023 | indiv       | q0427      | hours worked in last 7 days                               | False     |                  |                                                                                  |
|   2024 | basicvars   | identif    | household id / merge key                                  | True      | 100.0            | group(identif)                                                                   |
|   2024 | basicvars   | newaimag   | current aimag / proxy when born in current place          | True      | 100.0            | New code of aimag                                                                |
|   2024 | basicvars   | region     | region control                                            | True      | 100.0            | Region                                                                           |
|   2024 | basicvars   | urban      | urban/rural control                                       | True      | 100.0            | Urban/rural                                                                      |
|   2024 | basicvars   | location   | location control                                          | True      | 100.0            | Strata 4 locations                                                               |
|   2024 | basicvars   | hhsize     | household size                                            | True      | 100.0            | Household size                                                                   |
|   2024 | basicvars   | hhweight   | survey weight                                             | True      | 100.0            | Raked weights                                                                    |
|   2024 | basicvars   | month      | interview month / CPI merge                               | True      | 100.0            | Month                                                                            |
|   2024 | indiv       | identif    | household id / merge key                                  | True      | 100.0            | group(identif)                                                                   |
|   2024 | indiv       | ind_id     | person id / merge key                                     | True      | 100.0            | Хувийн дугаар                                                                    |
|   2024 | indiv       | q0102      | relation to household head                                | True      | 100.0            | 1.02 Өрхийн тэргүүлэгчтэй ямар хамааралтай вэ?                                   |
|   2024 | indiv       | q0103      | sex                                                       | True      | 100.0            | 1.03 Хүйс                                                                        |
|   2024 | indiv       | q0105y     | age in years                                              | True      | 100.0            | 1.05 Нас /жил/                                                                   |
|   2024 | indiv       | q0105m     | age/birth month if available                              | True      | 1.5              | 1.05 Нас /сар/                                                                   |
|   2024 | indiv       | q0106      | marital status                                            | True      | 68.58            | 1.06 Гэрлэлтийн байдал                                                           |
|   2024 | indiv       | q0107      | spouse person id                                          | True      | 41.15            | 1.07 Эхнэр нөхрийн хувийн дугаар                                                 |
|   2024 | indiv       | q0113      | born in current place flag, 2020-2022                     | True      | 100.0            | 1.13 Асуултанд хамрагдах эсэх                                                    |
|   2024 | indiv       | q0114a     | birth aimag for 2020-2022                                 | False     |                  |                                                                                  |
|   2024 | indiv       | q0114b     | birth soum for 2020-2022                                  | False     |                  |                                                                                  |
|   2024 | indiv       | q0117      | born in current place flag, 2024                          | True      | 95.5             | 1.17 [НЭР] энэ нутаг буюу [АЙМАГ]-ын/ийн [СУМ]-нд төрсөн үү?                     |
|   2024 | indiv       | q0118a     | birth aimag in 2024; migration aimag in 2020-2022         | True      | 26.17            | 1.18 [НЭР] хаана төрсөн бэ? Аймаг/ Нийслэл                                       |
|   2024 | indiv       | q0118b     | birth soum in 2024; migration soum in 2020-2022           | True      | 26.04            | 1.18 [НЭР] хаана төрсөн бэ? Сум/ дүүрэг                                          |
|   2024 | indiv       | q0210      | education level                                           | True      | 86.34            | 2.10 [НЭР]-ын/ийн эзэмшсэн  боловсролын дээд түвшинг хэлнэ үү?                   |
|   2024 | indiv       | q0213      | total schooling years                                     | True      | 86.34            | 2.13 [НЭР] нийт хэдэн жил сургуульд  суралцсан бэ?                               |
|   2024 | indiv       | q0404      | paid work in last 7 days                                  | True      | 86.34            | 4.04 [НЭР] сүүлийн 7 хоногт наад зах нь 1 цаг ямар нэг цалин хөлс, төлбөртэй ажи |
|   2024 | indiv       | q0436a     | main job wage amount, component used in wage construction | True      | 23.31            | 4.36 [НЭР] нь сүүлийн 12 сард үндсэн ажлаасаа хэдэн төгрөгийн цалин авсан бэ? Сү |
|   2024 | indiv       | q0436b     | main job wage amount, component used in wage construction | True      | 23.31            | 4.36 [НЭР] нь сүүлийн 12 сард үндсэн ажлаасаа хэдэн төгрөгийн цалин авсан бэ? Сү |
|   2024 | indiv       | q0436c     | main job wage component, extra/reference                  | True      | 23.31            | 4.36 [НЭР] нь сүүлийн 12 сард үндсэн ажлаасаа хэдэн төгрөгийн цалин авсан бэ? Ур |
|   2024 | indiv       | q0437      | months worked in last 12 months                           | True      | 36.29            | 4.37 [НЭР] энэ ажлыг хэдэн сар хийсэн бэ?                                        |
|   2024 | indiv       | q0438      | days per month worked                                     | True      | 36.29            | 4.38 [НЭР] ажилласан сарууддаа энэ ажилд сард  дунджаар  хэдэн өдөр зарцуулсан б |
|   2024 | indiv       | q0439      | hours per day worked                                      | True      | 36.29            | 4.39 [НЭР] ажилласан саруудын өдрүүддээ энэ ажилд өдөрт   дунджаар хэдэн цаг зар |
|   2024 | indiv       | q0427      | hours worked in last 7 days                               | True      | 34.59            | 4.27 [НЭР] сүүлийн 7 хоногт үндсэн ажилдаа нийтдээ хэдэн цаг зарцуулсан бэ?      |