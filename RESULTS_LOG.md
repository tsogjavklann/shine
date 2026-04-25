# RESULTS_LOG.md — Скрипт ажиллах прогресс ба үр дүн

---

## Долоо хоног 1 — Өгөгдлийн бэлтгэл — ✅ **CHECKPOINT 1**

### Скриптийн статус

| # | Скрипт | Статус | Хугацаа | Гарц | Тэмдэглэл |
|---|---|---|---|---|---|
| 1.1 | R/01_setup.R | ✅ ОК | 5.7 сек | renv.lock + setup.log | mongolstats GitHub fail (NSO1212 CRAN-аас амжилттай) |
| 1.2 | R/02_import_hses.R | ✅ ОК | 14.7 сек | 15/15 .dta уншиж raw_list (414K row) + variable inventory | 2023 wave 27 col гэж илрүүлсэн (бусад 250+) |
| 1.3 | R/03_harmonize.R | ✅ ОК | 3.9 сек | 234,690 row × 31 col (4 wave; 2023 хасагдсан) | Wave-specific birth_aimag (q0114a 2020-22, q0118a 2024) |
| 1.4 | R/04_wage_construction.R | ✅ ОК | <1 сек | 43,070 wage panel | Tier 1 99.9%, Tier 2 0.1% (q0427 байхгүй цөөн case) |
| 1.4b | R/04b_cpi_deflator.R | ✅ ОК | <1 сек | cpi_annual + cpi_monthly + wage_real | NSO PXWeb API амжилттай (real 2020=100) |
| 1.5 | R/05_education_supply.R | ✅ ОК | 1.5 сек | school_density + school_access | NSO API амжилттай; **CHECKPOINT TRIGGER** N_home=9849 ∈ [5K,10K) |
| 1.6 | R/06_iv_construction.R | ✅ ОК | <1 сек | iv_assignment (4 IV variants) | Treated cohort (alt_sample): main=2165, alt_1997=3046 |
| 1.7 | R/07_merge_final.R | ✅ ОК | 1.2 сек | analysis_sample.rds (43,070 row × 64 col) | sample_flag: main 40,779 / alt-only 2,291 |

### Final analysis_sample sizes

| Sample | N | Тайлбар |
|---|---|---|
| **alt_sample (22-60)** | **43,070** | Бүх | full |
| **main_sample (25-60)** | **40,779** | Стандарт Mincer |
| alt-only (22-24) | 2,291 | Treated cohort өргөтгөх |

Pre-filter wave breakdown: 2020 ≈ 11K, 2021 ≈ 7K, 2022 ≈ 15K, 2024 ≈ 10K (после wage filter).

### 4 IV-ийн 0/1 хуваарилалт

**main_sample (25-60):**

| IV | control (0) | treated (1) | NA (donut) |
|---|---|---|---|
| reform_main      | 39,018 | **438**   | 1,323 |
| reform_alt_1997  | —      | **996**   | — |
| reform_alt_1999  | —      | **210**   | — |
| reform_fuzzy     | 39,018 | 438 + 1,323 (0.5) | 0 |

**alt_sample (22-60):**

| IV | control | treated | NA |
|---|---|---|---|
| reform_main      | 39,018 | **2,165** | 1,887 |
| reform_alt_1997  | 37,868 | **3,046** | 2,156 |
| reform_alt_1999  | 40,024 | **1,341** | 1,705 |

⚠️ **First-stage strength concern активжсан:** 25-60 main sample-д reform_main treated = 438 (1.1%). 22-60 alt sample нь 5× нэмэгдсэн (2,165, 5.0%). PLAN-ийн §1.2 caveat-аас баталгаажсан — alt_sample, alt_1997 cutoff, AR-robust CI заавал ашиглана.

### CPI series (NSO PXWeb API, ХҮИ улсын 2020=100)

- Source: `DT_NSO_0600_001V3` (national, monthly, all 14 groups Ерөнхий = "0")
- API endpoint: `data.1212.mn/api/v1/mn/NSO/.../Consumer Price Index/`
- **Coverage 2018-01 → 2026-03** (Tier 2 prev-month merge-д бүрэн хангагдсан)
- Annual range: [89.8, 167.5]
- Wave averages: 2020=100.0; 2021=107.4; 2022=124.0; 2024=146.4
- Real wage 2020 → 2024: 4,385 → 5,769 (1.32× өсөлт)

### school_access (Card/Duflo proxy)

- Source: NSO API `DT_NSO_2001_002V1` (schools) + `DT_NSO_2001_004V1` (students)
- Year range: **2000-2025** (cohort age 6-17 окно бүрэн хангагдсан)
- Note: NSO students column is **already in thousands** — formula `schools / students` = schools per 1000 students
- Distribution (q_home, n=9,849):
  - mean 1.55, sd 0.38, p5=0.90, p25=1.27, p50=1.52, p75=1.87, p95=2.13
- Distribution (q_new, n=23,331):
  - mean 1.39, sd 0.41, p5=0.89, p25=1.00, p50=1.38, p75=1.74, p95=2.06

### home_aimag coverage + DECISION

- **q_home valid in wage panel:** 9,849 / 43,070 = **22.9%**
- **q_new valid:** 23,331 / 43,070 = **54.2%**
- **DECISION ZONE:** N_home = 9,849 ∈ [5K, 10K) → **CHECKPOINT TRIGGER (PLAN §1.3 эмпирик rule)**

🟡 **Хэрэглэгчийн шийдвэр шаардлагатай:**

| Сонголт | Үр дагавар |
|---|---|
| **A) home_aimag MAIN (recommended Card/Duflo)** | N=9,849 — threshold estimation power хязгаарлагдмал ч identification cleanest. Anderson-Rubin CI онцгой чухал |
| **B) newaimag MAIN (soft claim)** | N=23,331 — threshold power илүү, гэхдээ migration noise. "Supply-side proxy at current residence" |

**Recommendation:** Хувилбар **A** (home_aimag MAIN) — N бараг 10K threshold-той бөгөөд hardcore IV-Threshold paper-уудад 9-10K sample-д ажилладаг (Hansen 2000, Caner-Hansen 2004). newaimag full sample T6 col (7) robustness-аар үлдэх.

### Wage method (Tier 1 vs Tier 2)

| Wave | Tier 1 (q0436b annual) | Tier 2 (q0436a monthly) | Tier 2 % |
|---|---|---|---|
| 2020 | 10,891 | 14 | 0.13% |
| 2021 | 6,694 | 3 | 0.04% |
| 2022 | 15,117 | 32 | 0.21% |
| 2024 | 10,311 | 8 | 0.08% |

Tier 1 (annual decomposition) бараг бүгдэд хэрэгжсэн — q0436b + q0437/q0438/q0439 4 хувьсагч HSES 2020-2024-д стандарт байна.

### NSO API status

- **CPI:** ✅ NSO PXWeb API амжилттай (manual CSV fallback байгаа боловч ашиглагдаагүй)
- **Education supply:** ✅ NSO PXWeb API амжилттай (schools + students by aimag, 2000-2025)
- **NSO1212 R package:** ❌ `all_data()` функц эстэжэн → шууд httr POST (charToRaw/enc2utf8) ашиглав

### 22-24 насны caveat

- 2,291 row (5.32% of analysis_sample) нь 22-24 насны хүмүүс
- HSES-д currently_student variable (q0214) R/03-д extract хийгдээгүй
- working_for_wage = 1 filter аль хэдийн ажилласан тул overlap бага байх ёстой
- Нэмэлт filter R/19_subsample_iv.R sensitivity-д нэмж болно

---

## Долоо хоног 2 — Diagnostics ба OLS-IV (TBD)
[Хэрэглэгчийн "ok, долоо хоног 2 руу" зөвшөөрлийг хүлээж байна]

| # | Скрипт | Статус |
|---|---|---|
| 2.1 | R/08_descriptive.R | ⏳ pending |
| 2.2 | R/09_balance_check.R | ⏳ pending |
| 2.3 | R/10_ols_baseline.R | ⏳ pending |
| 2.4 | R/11_iv_2sls.R | ⏳ pending |
| 2.5 | R/12_iv_robustness.R | ⏳ pending |

---

## Долоо хоног 3 — IVTR (TBD)
| # | Скрипт | Статус |
|---|---|---|
| 3.1 | R/13_threshold_grid.R | ⏳ pending |
| 3.2 | R/14_caner_hansen_main.R | ⏳ pending |
| 3.3 | R/15_threshold_bootstrap.R | ⏳ pending |
| 3.4 | R/16_threshold_inverse_lr.R | ⏳ pending |
| 3.5 | R/17_regime_table.R | ⏳ pending |

---

## Долоо хоног 4 — Robustness + бичвэр (TBD)
| # | Скрипт | Статус |
|---|---|---|
| 4.1 | R/18_alt_thresholds.R | ⏳ pending |
| 4.1b | R/18b_nominal_wage_check.R | ⏳ pending |
| 4.1c | R/18c_unweighted.R | ⏳ pending |
| 4.1d | R/18d_aimag_robustness.R | ⏳ pending |
| 4.1e | R/18e_main_b_location.R | ⏳ pending |
| 4.2 | R/19_subsample_iv.R | ⏳ pending |
| 4.3 | R/20_alt_iv.R | ⏳ pending |
| 4.3b | R/20b_heckman.R | ⏳ pending |
| 4.4 | R/21_placebo.R | ⏳ pending |
| 4.5 | R/22_figures.R | ⏳ pending |
| 4.6 | R/23_tables_export.R | ⏳ pending |
| 4.7 | R/99_replication.R | ⏳ pending |

---

## Илрүүлсэн алдаа ба fallback ашигласан тохиолдол

| Огноо | Скрипт | Алдаа | Шийдэл | Статус |
|---|---|---|---|---|
| 2026-04-26 | R/01_setup.R | here() resolved to ecnometric/ parent (no .here) | Created `.here` in shine/ | ✅ ОК |
| 2026-04-26 | R/01_setup.R | install.packages(dep=TRUE) → BiocVersion error | dep=NA (strong only) + per-package tryCatch | ✅ ОК |
| 2026-04-26 | R/01_setup.R | setFixest_se() removed in fixest 0.14 | Removed line; per-call cluster only | ✅ ОК |
| 2026-04-26 | R/01_setup.R | mongolstats GitHub repo not found | Skipped — NSO1212 (CRAN) is primary | ⚠️ accepted |
| 2026-04-26 | R/02_import_hses.R | 2023 wave 27-col stripped sub-sample | Discovered & dropped from 4-wave main | ⚠️ documented |
| 2026-04-26 | R/04b | NSO1212::all_data() removed in v1.4 | Direct httr POST (charToRaw + enc2utf8 for Cyrillic) | ✅ ОК |
| 2026-04-26 | R/05 | school_density formula 1000× off (students col already in thousands) | `schools / students` (no extra div by 1000) | ✅ ОК |
| 2026-04-26 | R/05 | NSO education table duplicates per (aimag,year) | dedup via group_by(...).first() | ✅ ОК |
| 2026-04-26 | R/07 | dplyr select syntax (negative selection) | Refactored to setdiff outside select() | ✅ ОК |

---

## CHECKPOINT 1 — STOP

**Долоо хоног 1 бүрэн дууссан.** Хэрэглэгчээс шийдвэр шаардлагатай:

1. **Home_aimag vs Newaimag MAIN сонголт:** N_home = 9,849 (just under 10K threshold). Минийгээ recommend **A: home_aimag MAIN, newaimag T6 col (7) robustness**.
2. **"ok, долоо хоног 2 руу"** зөвшөөрөл — R/08-R/12 (Diagnostics + OLS/2SLS baseline) эхлүүлэх.
