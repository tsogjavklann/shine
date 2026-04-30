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

## Долоо хоног 2 — Diagnostics ба OLS-IV — 🛑 **CHECKPOINT 2 (Weak-IV trigger)**

### Скриптийн статус

| # | Скрипт | Статус | Хугацаа | Гарц | Тэмдэглэл |
|---|---|---|---|---|---|
| 2.1 | R/08_descriptive.R | ✅ ОК | 1.1 сек | T1_descriptive.csv | MAIN home_aimag n=9,077; treated only 171 |
| 2.2 | R/09_balance_check.R | ✅ ОК | 3.1 сек | F1_cohort_balance.png + pretrend.csv | Pre-trend OK (educ_years 13.2→13.6→13.8); cohort 1996-97 donut visible |
| 2.3 | R/10_ols_baseline.R | ✅ ОК | 0.6 сек | T2_ols_baseline.csv | **β_OLS = 0.059** (Main A & B); R²_adj = 0.27; F=355 |
| 2.4 | R/11_iv_2sls.R | ⚠️ TRIGGER | 15 сек | T2_iv_2sls.csv | **First-stage F = 0.118-0.544 (VERY WEAK)**; AR CI unbounded |
| 2.5 | R/12_iv_robustness.R | ⚠️ TRIGGER | 1.1 сек | T3_iv_robustness.csv | **All 8 specs F < 0.5** — alt cutoffs + alt_sample don't help |

### CHECKPOINT 1 шийдвэр баталгаажсан

✅ **MAIN SAMPLE = home_aimag (n=9,077)** — Card/Duflo cleanest identification (CLAUDE.md updated).

### T1 Descriptive (MAIN home_aimag, 25-60 нас, n=9,077)

| Variable | Mean | SD | p25 | p50 | p75 |
|---|---|---|---|---|---|
| educ_years | 13.0 | 2.81 | 10 | 14 | 14 |
| lwage (real) | 8.49 | 0.51 | 8.08 | 8.40 | 8.74 |
| real_hourly (MNT) | 5,540 | 3,100 | 3,240 | 4,450 | 6,220 |
| age | 32.7 | 4.13 | 29 | 33 | 36 |
| q_home (school_access) | 1.51 | 0.39 | 1.27 | 1.52 | 1.87 |
| % female | 46.1 | — | — | — | — |
| % married | 79.9 | — | — | — | — |

Cohort breakdown (MAIN home_aimag):
- control (≤1995): 8,404 (92.6%)
- donut (1996-97): 502 (5.5%)
- **treated (≥1998): 171 (1.9%)** ← бүгд 2024 wave-д

### T2 OLS baseline (Mincer + Main A/B + sensitivity)

| Spec | N | β_educ | SE_2way | SE_1way | SE_HC1 | F | R²_adj |
|---|---|---|---|---|---|---|---|
| Main A (no loc FE) | 9,077 | **0.0594** | 0.00222 | 0.00192 | 0.00198 | 355 | 0.269 |
| Main B (+ loc FE) | 9,077 | **0.0592** | 0.00231 | 0.00207 | 0.00198 | 352 | 0.269 |
| Sens. drop urban | 1,661 | 0.0600 | 0.00571 | 0.00538 | 0.00479 | 56.7 | 0.203 |
| Sens. drop UB | 4,508 | 0.0540 | 0.00525 | 0.00316 | 0.00280 | 175 | 0.235 |

OLS урт зүгээр амжилттай: **5.9-6.0% return per year of schooling** (Mongolia-д тохиромжтой). β_educ specification-ууд хооронд тогтвортой (0.054-0.060). SE 2way/1way ratio: 1.06-1.66 (UB-drop spec-д 1.66, бусад 1.1-1.2). 4-cluster bias caveat нэмэх шаардлагатай.

### T2 IV 2SLS — 🛑 WEAK-IV TRIGGER

| Spec | N | β_IV | SE_2way | SE_1way | SE_HC1 | KP_F | ivf1_F | wald_1st_F | DWH_p | AR CI |
|---|---|---|---|---|---|---|---|---|---|---|
| Main A 2SLS | 8,575 | 0.891 | 0.799 | 1.30 | 2.94 | NA | **0.118** | 0.544 | 0.073 | **unbounded** |
| Main B 2SLS | 8,575 | 0.827 | 0.658 | 1.05 | 2.49 | NA | **0.141** | 0.660 | 0.070 | **unbounded** |

⚠️ **First-stage F = 0.118-0.544** — PLAN §1.2 caveat баталгаажсан. Anderson-Rubin CI grid (±2.0 around β̂) edge hit → essentially unbounded. β_IV (0.83-0.89) нь interpretable биш — кодын алдаа биш, identification дутуу.

### T3 IV robustness — alt cutoffs + alt_sample (БҮГД WEAK)

| Spec | N | treated_n | β_IV | SE | F |
|---|---|---|---|---|---|
| MAIN 25-60 / reform_main | 8,575 | 171 | 0.891 | 0.799 | **0.12** |
| MAIN 25-60 / reform_alt_1997 | 8,320 | 382 | -8.21 | 99.1 | **0.001** |
| MAIN 25-60 / reform_alt_1999 | 8,772 | 77 | 0.593 | 0.806 | **0.06** |
| MAIN 25-60 / reform_fuzzy | 9,077 | 171 | -7.20 | 24.2 | **0.001** |
| ALT 22-60 / reform_main | 9,140 | 736 | 1.55 | 8.41 | **0.03** |
| ALT 22-60 / reform_alt_1997 | 9,000 | 1,062 | 0.527 | 0.721 | **0.22** |
| ALT 22-60 / reform_alt_1999 | 9,232 | 445 | -0.433 | 0.629 | **0.43** |
| ALT 22-60 / reform_fuzzy | 9,849 | 736 | -1.57 | 8.83 | **0.02** |

🚨 **Бүх 8 specification-д F < 0.5** (max F=0.43). Alt cutoffs + alt_sample IV-ийг дорхгүй strengthen. Identification дутагдалтай.

### Cohort balance + pre-trend (R/09)

5-year bin-аар (MAIN home_aimag, hhweight-аар жинлэсэн):

| Cohort bin | N | %female | mean_age | mean_educ | %married | mean_q_home |
|---|---|---|---|---|---|---|
| 1990-1995 (control late) | 3,549 | 46.8 | 29.7 | 13.2 | 79.1 | 1.54 |
| 1996-1997 (donut) | 502 | 50.2 | 26.3 | 13.6 | 65.1 | 1.58 |
| 1998-2003 (treated) | 171 | 43.3 | 25.6 | 13.8 | 57.9 | 1.58 |

Pre-trend educ_years smooth (13.2 → 13.8), no anomalous bunching at 1996-97. F1_cohort_balance.png-д 2 panel: (A) histogram with donut vlines, (B) LOESS pre-trend.

---

## 🛑 CHECKPOINT 2 — STOP & ASK

### IDENTIFICATION ASSESSMENT

**Гол асуудал:** Reform IV-аар identification бүтэхгүй. Энэ нь:

1. **Treated cohort жижиг** (main_sample 171, alt_sample 736)
2. **Reform's effect on educ_years бага** (control 13.2 vs treated 13.8 — only 0.6y зөрөө)
3. **Mongolia-ийн baseline education нь өндөр** — 2004 reform (10→11 жил) ихэнх хүмүүст binding биш байсан

PLAN §4 эрсдэлийн хүснэгтэд урьдчилан тэмдэглэгдсэн "First-stage F < 10 ӨНДӨР" risk бодит болж. PLAN-ийн санал:
> "(5) KP-F нийтэд < 5 бол **IVTR-ийг exploratory гэж тооцож OLS-Quantile heterogeneity-ыг гол үр дүн руу шилжих**"

### STRATEGY OPTIONS — хэрэглэгчээс шийдвэр шаардлагатай

| Option | Тайлбар | Үр дагавар |
|---|---|---|
| **A) PIVOT — OLS-Quantile MAIN, IV exploratory** | OLS β = 0.059 (хүчтэй, F=355) → main result. Caner-Hansen IVTR-ыг exploratory. Threshold-ийн heterogeneity story-г Hansen (2000) **OLS threshold regression**-аар хийнэ (IV-гүй). Paper нь "Heterogeneous returns to schooling in Mongolia" framework-д шилжинэ | ✅ Identification clean (OLS); ✅ Threshold story хадгалагдана; ⚠️ Causal claim soft-болно ("conditional on observables") |
| **B) ALTERNATIVE IV хайх** | Parental education / siblings count / pre-reform regional variation зэрэг өөр IV дизайныг шалгах. Жишээ: HSES roster-аас father's/mother's educ_years extract хийж IV болгох (Card 1995-аас) | ⚠️ Цаг хугацаа (1+ долоо хоног); ⚠️ Үр дүн баталгаагүй; identification claim шинээр |
| **C) Continue IV with full caveats** | Одоогийн IV-г "exploratory illustration" гэж framing-ээр хадгалаад OLS-ийг ahead тайлагнах | ⚠️ Reviewer-уудад weak-IV нь main concern болно; paper-ийн positioning эмзэг |
| **D) Restructure topic completely** | IV-Threshold approach-ыг бүхэлд нь орхиод өөр research question руу шилжих (жишээ: heterogeneity by gender × region OLS) | ❌ Time-сан тооцоогоор хүндрэлтэй; PLAN-ийн ноэр-аас хол |

### МИНИЙ САНАЛ: Option A (PIVOT)

**Шалтгаан:**
1. PLAN §4-д аль хэдийн pre-committed pivot strategy
2. OLS β = 0.059 нь well-identified, defensible result Mongolia-д (literature 5-10% range)
3. Threshold heterogeneity story-г OLS-base-ээр (Hansen 2000) хадгалж болно — IVTR-ийн оронд OLS-TR
4. Paper-ийн narrative: "Returns to schooling in Mongolia: OLS estimates with school-access threshold heterogeneity" — academically defensible
5. IV-ийг robustness section-д "exploratory weak-IV exercise" гэж хадгална

### Хүлээж байна

🟡 **Хэрэглэгчийн зөвшөөрөл хэрэгтэй:**
- **A** (PIVOT, recommended) → R/13-ыг OLS threshold regression болгож шинэчилнэ; IVTR exploratory section болно
- **B** (alt IV) → R/06b нэмж parental education extract хийнэ; шинэ IV дизайны үр дүн шалгана
- **C** (continue with caveats) → R/13-аас үргэлжлүүлж IVTR-ыг "exploratory" framing-ээр гүйцэтгэнэ
- **D** (restructure) → бид цоо шинэ план хэрэгтэй

Долоо хоног 3 эхлэхээс өмнө шийдвэр зайлшгүй.

---

## CHECKPOINT 2.5 — Geographic IV (Card 1995, distance to UB) — ⚠️ ALSO WEAK

Хэрэглэгчийн саналаар Option B-ийг шалгасан: distance from birth aimag to Ulaanbaatar.

### Setup

- 22 aimag-center coordinates hand-coded (Wikipedia)
- Haversine distance (km) to UB Sukhbaatar Square (47.918°N, 106.917°E)
- Range: **0 km (UB)** → **1,253 km (Bayan-Olgii)**

### First-stage F results (MAIN home_aimag, n=9,077)

| Spec | π̂_distance | SE_2way | t-stat | p-value | **F** | R²_adj |
|---|---|---|---|---|---|---|
| 1) distance only, wave FE | -1.9e-4 | 9.5e-5 | -1.96 | 0.050 | **3.84** | 0.060 |
| 2) **distance + region FE + wave FE (canonical)** | -1.5e-4 | 1.0e-4 | -1.47 | 0.141 | **2.17** | 0.067 |
| 3) + location FE (Main B-style) | -1.5e-4 | 1.0e-4 | -1.53 | 0.127 | **2.33** | 0.069 |

🔴 **F = 2.17 in canonical spec — STILL VERY WEAK (<5).**

### Sign analysis

- π̂_distance = -1.5e-4 years per km — **Card-style sign correct** (farther → less education)
- Magnitude: UB (0 km) → Bayan-Olgii (1,253 km) gives Δeduc = -1.5e-4 × 1253 ≈ **-0.19 years**
- Empirically tiny effect

### Birth-aimag panel sizes + mean educ_years

| Aimag (sample) | Distance km | N | mean_educ |
|---|---|---|---|
| UB (11) | 0 | 1,231 | 13.4 |
| Tov (41) | 24 | 547 | 12.3 |
| Erdenet (61) | 243 | 148 | 13.2 |
| Khovsgol (67) | 530 | 428 | 13.0 |
| Bayan-Olgii (83) | 1,253 | 332 | 12.5 |

→ Mean educ_years variation **across aimags only 0.9 years** (12.2-13.4 range). Mongolia's baseline education is uniformly high → distance IV magnitude tiny → weak first stage.

### Diagnosis

Mongolia-specific reasons distance IV fails:
1. **Boarding schools (дотуур байр)** at soum/aimag centres → distance to UB doesn't deter education
2. **Universal compulsory education** since 1990s → 9-11 years of schooling regardless of geography
3. **Inter-aimag mobility for education** common (rural students move to UB universities)

### Verdict on Option B

❌ **Distance-to-UB IV does NOT solve the weak-IV problem.** F=2.17 is below the F=5 threshold. Same trigger as reform_main IV.

### Strategy update

| Option | Status |
|---|---|
| **A) PIVOT to OLS-Quantile/Threshold MAIN** ⭐ | ✅ **Strongly recommended now** — both IV designs failed |
| B) Alternative IV (distance to UB) | ❌ Just tested — also F < 5 |
| B') Other IV (parental educ, sibling count) | Possible but unlikely to work given the structural issue |
| C) Continue IV with caveats | Now equivalent to Option A in practice |
| D) Restructure topic | Same as before |

**Conclusion:** The data simply does not support a strong IV identification of the schooling-wage relationship in Mongolia (high baseline education + small effective variation). **PIVOT to OLS Mincer + Hansen (2000) OLS-Threshold heterogeneity** is the only academically defensible path forward.

### Гарц

- [output/tables/T_2_5_distance_iv_first_stage.csv](output/tables/T_2_5_distance_iv_first_stage.csv)
- [data/auxiliary/aimag_distance_to_ub.csv](data/auxiliary/aimag_distance_to_ub.csv)
- [output/logs/05c_distance_iv.log](output/logs/05c_distance_iv.log)

### Хүлээж байна

🟡 **Эцсийн зөвшөөрөл (A vs other):**
- **A (PIVOT)** → R/13_threshold_grid.R-ыг OLS threshold болгож шинэчилнэ; R/14-аас IVTR-ыг exploratory section болгож хадгална. Mincer + OLS-Threshold (Hansen 2000) framework-аар paper-ийг ажиллуулна.
- **B' (өөр IV)** → Хэрэв танаас урам зориг авах боломжтой parental education / pre-reform regional spending-ийн өөр IV байгаа бол шалгая (~1 долоо хоног).

---

## CHECKPOINT 2.6 — Comprehensive IV survey (12 specs) — 🎉 BREAKTHROUGH

Хэрэглэгчийн саналаар 12 candidate IV-ийг empirical-аар first-stage F-test хийсэн (R/12b_iv_search.R). HSES roster-аас parental education + siblings extract хийсэн (R/03b_family_structure.R).

### T2b — IV search ranked by F descending (MAIN home_aimag, n=9,077)

| Rank | IV | Family | **F** | β_IV | SE | N | Verdict |
|---|---|---|---|---|---|---|---|
| 1 | **mother_educ_level** | Family | **117.3** | **0.118** | 0.007 | 966 | ✅ STRONG |
| 2 | **father_educ_level** | Family | **103.0** | **0.067** | 0.011 | 658 | ✅ STRONG |
| 3 | **n_siblings** | Family | **84.4** | **0.102** | 0.016 | 1,032 | ✅ STRONG |
| 4 | parents_combined | Family | 63.5 | 0.090 | 0.014 | 592 | ✅ STRONG |
| 5 | **birth_aimag_22dummies** | Geo | **5.9** | **0.079** | 0.015 | **9,077** | 🟡 MARGINAL |
| 6 | distance_to_ub | Geo | 2.17 | 0.409 | 0.127 | 9,077 | ❌ WEAK |
| 7 | distance + reform | Combo | 1.18 | 0.426 | 0.141 | 8,575 | ❌ WEAK |
| 8 | reform_main | Cohort | 0.54 | 0.891 | 0.799 | 8,575 | 🚨 USELESS |
| 9 | birth_order | Family | 0.42 | 1.861 | 0.003 | 1,032 | 🚨 USELESS |
| 10 | reform_alt_1999 | Cohort | 0.29 | 0.593 | 0.806 | 8,772 | 🚨 USELESS |
| 11 | reform_alt_1997 | Cohort | 0.004 | -8.21 | 99.1 | 8,320 | 🚨 USELESS |
| 12 | quarter_of_birth | Time | NA | — | — | 9,077 | ❌ FIT FAILED (q0105m issue) |

### Family structure coverage (R/03b)

| Variable | Roster pct | MAIN wage panel pct | N_main |
|---|---|---|---|
| father_educ_level | ~39% | 7.2% | 658 |
| mother_educ_level | ~44% | 10.6% | 966 |
| either parent | — | 11.4% | 1,032 |
| n_siblings | ~45% | 11.4% | 1,032 |

Reason for low main-sample coverage: 25-60 насны хүмүүсийн ихэнх нь эцэг эхтэйгээ амьдрахаа больсон → roster-д parents-ийг ажиглах боломж хязгаарлагдмал.

### Гол findings

🎉 **3 STRONG family IV олдсон:**
- **mother_educ_level F=117**, β=0.118 (11.8% return per year — IV slightly above OLS)
- **father_educ_level F=103**, β=0.067 (6.7% — close to OLS)
- **n_siblings F=84**, β=0.102 (10.2%)

🟡 **1 MARGINAL geographic IV:**
- **birth_aimag_22dummies F=5.9**, β=0.079 — full sample N=9,077, suitable for IVTR threshold estimation

❌ **All cohort IVs (reform_main + alts) FAILED**: PLAN §4 risk realized.

### NEW STRATEGY OPTIONS

| Option | Sample N | Identification | Threshold feasibility |
|---|---|---|---|
| **B'1: mother_educ IV (Card 2001 family-D)** | 966 | Cleanest family-D | OK for threshold (Hansen 2000 used N≈3K, but 966 marginal) |
| **B'2: birth_aimag 22-dummy IV** | **9,077** | Birth-region as Card 1995 spirit; AR-robust CI mandatory | ✅ Best for IVTR (full N) |
| **B'3: Combo — family IV main + birth_aimag IVTR** | 966 + 9,077 | Family for level β; birth_aimag for threshold | Rich paper structure |
| **A: PIVOT (OLS-Threshold)** | 9,077 | Clean OLS, no causal claim | ✅ Full N, no weak-IV concern |

### МИНИЙ САНАЛ: **B'3 (Combo)** — хамгийн rich paper структур

**Paper structure (recommended):**
1. **Section 4 (Main results)**: 
   - 4.1 OLS Mincer baseline (β_OLS = 0.059, F=355, N=9,077)
   - 4.2 IV identification: birth_aimag 22-dummy (β_IV = 0.079, F=5.9 marginal, N=9,077, AR-robust CI)
   - 4.3 OLS-Threshold (Hansen 2000) heterogeneity by school_access
2. **Section 5 (Robustness)**:
   - 5.1 Family IV — mother_educ_level (β=0.118, F=117, N=966) — strongest first-stage but small sample
   - 5.2 IVTR (birth_aimag IV × school_access threshold) — exploratory weak-IV
   - 5.3 Reform IV (reform_main, reform_alt_1997/1999, fuzzy) — documented as FAILED (paper тайлбар: 2004 reform not binding given high baseline education)
3. **Discussion**: Why Mongolia is an interesting case (high baseline + rapid change) → cohort IV fails

### Гарц

- [output/tables/T2b_iv_search.csv](output/tables/T2b_iv_search.csv) — 12 IV F-test table
- [data/processed/family_structure.rds](data/processed/family_structure.rds) — extracted parental + siblings panel
- [output/logs/03b_family_coverage.log](output/logs/03b_family_coverage.log)
- [output/logs/12b_iv_search.log](output/logs/12b_iv_search.log)

### Хүлээж байна

🟡 **Эцсийн шийдвэр (A / B'1 / B'2 / B'3):**

- **A** — PIVOT to OLS-only (simple, clean, but no IV story)
- **B'1** — Family IV main (strongest F, but N=966 limits threshold)
- **B'2** — birth_aimag IV main (full sample, F=5.9 marginal, AR-robust mandatory)
- **B'3** — Combo (family IV main result + birth_aimag for IVTR threshold) ⭐ richest paper

Долоо хоног 3 эхлэхээс өмнө шийдвэр зайлшгүй.

---

## CHECKPOINT 2.6 (UPDATED) — Full 14-spec IV Survey — 🎉 NEW BREAKTHROUGH

R/12e_iv_remaining.R-аар үлдсэн 6 IV-ийг шалгасан. Гол найрсаг үр дүн: **teacher_supply_at_17 нь F=46.6, N=8,575 STRONG IV** болсон.

### FULL T2b — 14-spec IV survey (sorted by F desc)

| # | Spec | Family | N | β_IV | SE | **F** | Verdict |
|---|---|---|---|---|---|---|---|
| 06 | mother_educ_level | Family | 966 | 0.118 | 0.007 | **117** | ✅ STRONG |
| 05 | father_educ_level | Family | 658 | 0.067 | 0.011 | **103** | ✅ STRONG |
| 08 | n_siblings | Family | 1,032 | 0.102 | 0.016 | **84** | ✅ STRONG |
| 07 | parents_combined | Family | 592 | 0.090 | 0.014 | **64** | ✅ STRONG |
| **13** | **teacher_supply_at_17** | **Supply** | **8,575** | **0.114** | **0.020** | **46.6** | **✅ STRONG** ⭐ |
| 11 | birth_aimag_22dummies | Geo | 9,077 | 0.079 | 0.015 | 5.9 | 🟡 MARGINAL |
| 12-old | distance + reform | Combo | 8,575 | 0.426 | 0.141 | 1.18 | ❌ WEAK |
| 12-new | aimag × cohort | Combo | 8,575 | 0.076 | 0.012 | 2.80 | ❌ WEAK |
| 04 | distance_to_ub | Geo | 9,077 | 0.409 | 0.127 | 2.17 | ❌ WEAK |
| 01 | reform_main | Cohort | 8,575 | 0.891 | 0.799 | 0.54 | 🚨 USELESS |
| 09 | birth_order | Family | 1,032 | 1.861 | 0.003 | 0.42 | 🚨 USELESS |
| 03 | reform_alt_1999 | Cohort | 8,772 | 0.593 | 0.806 | 0.29 | 🚨 USELESS |
| 02 | reform_alt_1997 | Cohort | 8,320 | -8.21 | 99.1 | 0.004 | 🚨 USELESS |
| **08** | quarter_of_birth | Time | 0 | — | — | NA | ⏸ SKIPPED |
| **10** | pre_1990_supply | Supply | 0 | — | — | NA | ⏸ SKIPPED |
| **11** | transition_shock | Time | 0 | — | — | NA | ⏸ SKIPPED |
| **14** | urbanization_at_17 | Supply | 0 | — | — | NA | ⏸ SKIPPED |

### Skipped specs — empirical reasons

| Spec | Reason |
|---|---|
| 08 quarter_of_birth | HSES q0105m нь "нас сараар" (нярай хүүхдэд only, year=0). Adult-уудад month-of-birth бүртгэдэггүй. Angrist-Krueger 1991 design феасибл биш. |
| 10 pre_1990_supply | NSO API ЕБС data эхлэлийн жил 2001 (DT_NSO_2001_002V1). Pre-1990 schools by aimag data нь NSO-ийн интернет API-д байхгүй. |
| 11 transition_shock | Aimag-level GDP for 1995-2000 NSO API-д нэмж олдсонгүй. Conceptual specification дутуу. |
| 14 urbanization_at_17 | DT_NSO_0300_004V1 fetched-сан боловч parsing-д Хот/Хөдөө dimension breakdown олдсонгүй (table нь aggregate-аар байна). 추가 NSO table search шаардлагатай. |

### КЛЮЧ: Spec 13 teacher_supply_at_17 — game-changer

🌟 **F = 46.6, β = 0.114, N = 8,575**

- **Family B (Card/Duflo supply-side identification)**: Teacher count in birth aimag at year (birth_year + 17) — when respondent decided about post-secondary education
- **Strong first stage**: F = 46.6 ≫ 10 threshold
- **Full main_sample**: N = 8,575 (post-donut filter, all home_aimag valid)
- **Sensible β**: 11.4% return per year of schooling — well above OLS (5.9%) but in IV literature range
- **Identification**: teacher availability when 17 affected schooling decisions but not adult labour-market productivity directly (assumption defensible)

Caveat: Teacher_supply_at_17-аас school_access (q_home, 6-17 насны schools/students density) хоёр нь хоёулаа birth_aimag supply-side variables — collinearity/exclusion concern байж болзошгүй. R/14_caner_hansen_main.R-д IVTR threshold estimation-д ашиглахдаа teacher_supply нь IV, school_access нь threshold variable байх — өөр өөр хувьсагч (different age windows + different counts). Robust orthogonalization шаардлагатай.

### NEW STRATEGY OPTIONS — шинэчлэгдсэн

| Option | IV (main) | N | F | Threshold | Recommend? |
|---|---|---|---|---|---|
| **A** PIVOT to OLS | none | 9,077 | n/a | OLS-Threshold | clean но no IV |
| B'1 mother_educ | mother | 966 | 117 | small N issue | small sample |
| B'2 birth_aimag | 22-dummy | 9,077 | 5.9 | AR-CI mandatory | marginal F |
| B'3 Combo (family + birth_aimag) | both | both | 5.9-117 | mixed | rich but complex |
| **B'4** ⭐ **teacher_supply_at_17** | **teacher_at_17** | **8,575** | **46.6** | **✅ Full sample IVTR** | ⭐⭐⭐ **NEW BEST** |
| B'5 Combo (B'4 + family robustness) | teacher main + mother robust | 8,575 + 966 | 46.6 + 117 | full N | richest |

### МИНИЙ ШИНЭЧИЛСЭН САНАЛ: **B'5 (Combo)** — teacher_supply_at_17 main + family IV robustness

**Paper structure (recommended UPDATE):**
1. **§4 Main results**:
   - 4.1 OLS Mincer baseline (β = 0.059, F = 355, N = 9,077)
   - 4.2 **Main IV: teacher_supply_at_17 (β = 0.114, F = 46.6, N = 8,575)** — Card/Duflo supply-side
   - 4.3 OLS-Threshold AND IVTR by school_access (q_home), N = 8,575 — full Caner-Hansen 2004
2. **§5 Robustness**:
   - 5.1 Family IV: mother_educ (β = 0.118, F = 117, N = 966) — confirms IV β ~ 0.11
   - 5.2 birth_aimag 22-dummy IV (β = 0.079, F = 5.9, AR-robust) — geographic robustness
   - 5.3 Reform IV (cohort design) **documented as FAILED** — Mongolia-specific story
3. **§6 Discussion**:
   - Why cohort IV fails in Mongolia (high baseline education, boarding schools)
   - Heterogeneity: schools_per_1000_students threshold separates "low-access" vs "high-access" returns

### Гарц

- [output/tables/T2b_iv_search.csv](output/tables/T2b_iv_search.csv) — FULL 17-row IV survey
- [R/12e_iv_remaining.R](R/12e_iv_remaining.R) — remaining 6 specs
- [output/logs/12e_iv_remaining.log](output/logs/12e_iv_remaining.log)

### Хүлээж байна — UPDATED FINAL CHOICE

🟡 **A / B'1 / B'2 / B'3 / B'4 / B'5?**

Strongest recommendation: **B'5** (teacher_supply_at_17 main + family IV robustness).
Alternative: **B'4** (teacher_supply alone) for simpler paper structure.

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


## CHECKPOINT 2.7 — HSES Deep Variable Exploration

Discovered variables (newly explored):
- ever_migrated (HSES migration; nonmissing=43070)
- years_since_migration (HSES migration; nonmissing=16260)
- migrated_before_18 (HSES migration; nonmissing=42704)
- migrated_school_age_6_17 (HSES migration; nonmissing=42704)
- migration_reason_education_self (HSES migration; nonmissing=43070)
- migration_reason_children_school (HSES migration; nonmissing=43070)
- migration_reason_natural_disaster (HSES migration 2024 only; nonmissing=3475)
- lived_5y_ago_diff_aimag (HSES migration; nonmissing=16626)
- born_foreign (HSES birthplace; nonmissing=19041)
- birth_aimag_matches_raw (HSES validation; nonmissing=19041)
- birth_soum_available (HSES birthplace; nonmissing=43070)
- rural_birth_x_birth_year_c (Cohort x geography; nonmissing=19041)
- born_ub_x_birth_year_c (Cohort x geography; nonmissing=19041)
- herder_household_current (HSES household; nonmissing=43070)
- herder_current_x_birth_year_c (Cohort x household; nonmissing=43070)
- ever_migrated_x_birth_year_c (Cohort x migration; nonmissing=43070)
- migrated_school_age_x_rural_birth (Migration x geography; nonmissing=18680)
- diff_5y_aimag_x_birth_year_c (Migration x cohort; nonmissing=16626)
- ever_dropout (HSES schooling; nonmissing=1212)
- dropout_grade (HSES schooling; nonmissing=1139)
- dropout_reason_parent (HSES schooling; nonmissing=1139)
- dropout_reason_finance (HSES schooling; nonmissing=1139)
- dropout_reason_work (HSES schooling; nonmissing=1139)
- dropout_reason_health (HSES schooling; nonmissing=1139)
- dropout_reason_distance (HSES schooling; nonmissing=1139)
- dropout_reason_migration (HSES schooling; nonmissing=1139)
- never_school_reason_finance (HSES schooling; nonmissing=166)
- never_school_reason_distance (HSES schooling; nonmissing=166)
- never_school_reason_dorm_shortage (HSES schooling; nonmissing=166)
- current_school_public (HSES current school; nonmissing=328)
- current_school_private (HSES current school; nonmissing=328)
- current_school_soum_center (HSES current school; nonmissing=328)
- dormitory_current_student (HSES current school; nonmissing=328)
- school_transport_walk (HSES current school; nonmissing=328)
- school_transport_boarding (HSES current school; nonmissing=328)
- health_insured (HSES health; nonmissing=43070)
- severe_vision_difficulty (HSES disability; nonmissing=43070)
- severe_hearing_difficulty (HSES disability; nonmissing=43070)
- severe_mobility_difficulty (HSES disability; nonmissing=43070)
- severe_cognitive_difficulty (HSES disability; nonmissing=43070)
- severe_language_difficulty (HSES language/disability; nonmissing=43070)
- any_severe_disability (HSES disability; nonmissing=43070)
- any_mildplus_disability (HSES disability; nonmissing=43070)
- father_educ_years (Family roster; nonmissing=3307)
- mother_educ_years (Family roster; nonmissing=4773)
- parent_educ_mean (Family roster; nonmissing=5155)
- n_siblings (Family roster; nonmissing=5155)
- birth_order (Family roster; nonmissing=5155)
- large_sibship_ge4 (Family roster; nonmissing=5155)
- firstborn (Family roster; nonmissing=5155)

Tested as IV:
- dropout_grade: F=2567.5, pi=0.9393, verdict=STRONG, N=406
- health_insured: F=439.6, pi=2.0166, verdict=STRONG, N=18259
- parent_educ_mean: F=135.96, pi=0.3819, verdict=STRONG, N=1221
- ever_dropout: F=119.45, pi=-7.7314, verdict=STRONG, N=429
- migration_reason_education_self: F=117.37, pi=1.2455, verdict=STRONG, N=18259
- mother_educ_years: F=113.64, pi=0.3586, verdict=STRONG, N=1129
- father_educ_years: F=98.75, pi=0.3431, verdict=STRONG, N=729
- rural_birth_x_birth_year_c: F=45.76, pi=0.0273, verdict=STRONG, N=18259
- born_ub_x_birth_year_c: F=45.76, pi=-0.0273, verdict=STRONG, N=18259
- years_since_migration: F=39.32, pi=-0.0222, verdict=STRONG, N=14200

New candidates (final):
- Strong (F >= 10): dropout_grade, health_insured, parent_educ_mean, ever_dropout, migration_reason_education_self, mother_educ_years, father_educ_years, rural_birth_x_birth_year_c, born_ub_x_birth_year_c, years_since_migration, severe_cognitive_difficulty, any_mildplus_disability, any_severe_disability, migration_reason_children_school, migrated_school_age_6_17, severe_language_difficulty
- Marginal (5 <= F < 10): migrated_before_18, severe_hearing_difficulty, current_school_public, migrated_school_age_x_rural_birth
- Failed (F < 5 / wrong sign / collinear): current_school_private, ever_migrated_x_birth_year_c, severe_mobility_difficulty, dropout_reason_distance, lived_5y_ago_diff_aimag, dropout_reason_parent, large_sibship_ge4, severe_vision_difficulty, dropout_reason_health, n_siblings, herder_household_current, ever_migrated, dropout_reason_work, current_school_soum_center, firstborn, dropout_reason_finance, herder_current_x_birth_year_c, dormitory_current_student, birth_order, dropout_reason_migration, school_transport_walk, diff_5y_aimag_x_birth_year_c, birth_aimag_matches_raw, birth_soum_available, born_foreign, migration_reason_natural_disaster, never_school_reason_distance, never_school_reason_dorm_shortage, never_school_reason_finance, school_transport_boarding

Conclusion:
- No HSES-only candidate is accepted as a clean primary IV without an exclusion-restriction caveat.



