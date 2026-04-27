# CLAUDE.md — Төслийн контекст ба гол заалт

## Төсөл

**Сэдэв:** Монгол Улсад боловсролын бодит өгөөжийн босготой үнэлгээ — HSES 2020-2024 микро өгөгдөл, Caner & Hansen (2004) IV-Threshold

**Уралдаан:** СЭЗИС Эконометрикийн VIII Олимпиад, II шат

**Хэл:** Монгол хэл (бичвэрт). R код, нэр томьёо англи.

## Дэлгэрэнгүй

- Бүх ажлын урсгал, скриптийн дараалал, acceptance criteria — `PLAN.md`-д
- Скрипт ажиллуулах прогресс, илрүүлсэн алдаа, эцсийн N — `RESULTS_LOG.md`-д

## Цөм параметр (PLAN.md-аас товчилсон)

| Хэсэг | Утга |
|---|---|
| Sample | HSES **2020, 2021, 2022, 2024** (4 wave; **2023 хасагдсан**). Pooled, 22-60 (alt) / 25-60 (main) — `sample_flag`. **MAIN ANALYSIS SAMPLE = home_aimag subsample (N=9,849; q_home valid)** — Card/Duflo cleanest identification (CHECKPOINT 1 шийдвэр). Newaimag full-sample (N=23,331) → T6 col (7) robustness only |
| Y | ln(real hourly wage), CPI base 2020 = 100 |
| Endogenous | educ_years |
| **Үндсэн IV** | `reform_main` — donut: Z=1 if birth ≥ 1998, Z=0 if ≤ 1995, NA if 1996-1997 |
| **Robustness IV** | `reform_fuzzy` (0/0.5/1), `reform_alt_1997`, `reform_alt_1999` |
| Threshold variable | school_density (schools per 1000 students) — birth_aimag × age 6-17 дундаж |
| Controls | age, age², gender, marital, location (4-cat), region FE, wave FE |
| Cluster SE | `~aimag + wave` (жинхэнэ two-way; `^` НЕ ашиглана). **4 wave cluster** → few-cluster bias caveat |
| Weights | `weights = ~hhweight` ЗААВАЛ бүх OLS, 2SLS, IVTR-д. Unweighted нь T6 col (6b) sensitivity |
| Weak-IV inference | **Anderson-Rubin (AR) CI = гол**. Kleibergen-Paap rk Wald F (cluster-robust). **Stock-Yogo critical нь cluster-robust setting-д invalid — ашиглахгүй** |
| IVTR fit | **Interaction-based pooled** (D1/D2/Z1/Z2 §1.3); **sample split БИШ** |
| γ̂ CI | Hansen (2000) inverted LR (R/16). BCa CI optional биш |
| CPI | **2 series:** `cpi_annual` (Tier 1 q0436b deflation) + `cpi_monthly` (Tier 2 q0436a, prev-month) |
| Specifications | **Main A** (no location FE, raw schooling-to-wage) + **Main B** (location FE; bad-control caveat) |
| Bootstrap | 1000 rep, parallel; convergence < 0.5 → WARN + manual `BOOTSTRAP_REPS=2000` |

## Wage construction (2-tier, 2020-2024 only)

HSES Q4.36 нь sub-part: a = "сүүлийн сард" (monthly), b = "сүүлийн 12 сард" (annual). q0437/q0438/q0439 = months/days/hours decomposition; q0427 = weekly hours fallback.

```
Tier 1 (full annual decomposition):
  annual_hours = q0437 × q0438 × q0439
  hourly = q0436b (annual) / annual_hours

Tier 2 (fallback if q0437/q0438/q0439 NA):
  hourly = q0436a (monthly) / (q0427 × 4.33)
  (4.33 ≈ 52/12 = weeks/month)
```

## HSES variable mapping (R/02 inventory-аас илрүүлэгдсэн)

R/03_harmonize.R-д ашиглагдах **жинхэнэ** HSES 2020-2024 variable нэрс:

| Standard name | HSES var | Файл | Тайлбар |
|---|---|---|---|
| age | `q0105y` | indiv | 1.05 Нас /жил/ |
| sex | `q0103` | indiv | 1.03 Хүйс (1=эр, 2=эм) |
| marital | `q0106` | indiv | 1.06 Гэрлэлтийн байдал |
| birth_aimag | **wave-specific:** 2020-2022 = `q0114a`; 2024 = `q0118a` | indiv | "[НЭР] хаана төрсөн бэ? Аймаг/Нийслэл" — 2024-д асуулт 1.18 руу шилжсэн |
| birth_soum | wave-specific: q0114b (2020-2022), q0118b (2024) | indiv | Same logic |
| educ_max | `q0210` | indiv | 2.10 Эзэмшсэн боловсролын дээд түвшин |
| educ_years | `q0213` | indiv | 2.13 Нийт хэдэн жил сургуульд суралцсан |
| working_for_wage | `q0404` (last 7d, paid) | indiv | 4.04 наад зах нь 1 цаг ажилласан уу |
| q0436a | **monthly** cash earnings (А. Сүүлийн сард) | indiv | 4.36а |
| q0436b | **annual** cash earnings (Б. Сүүлийн 12 сард) | indiv | 4.36б |
| q0437 | months/year worked | indiv | 4.37 хэдэн сар хийсэн |
| q0438 | days/month | indiv | 4.38 сард хэдэн өдөр |
| q0439 | hours/day | indiv | 4.39 өдөрт хэдэн цаг |
| q0427 | weekly hours | indiv | 4.27 сүүлийн 7 хоногт цаг |
| aimag | `newaimag` | basicvars | NSO стандарт аймгийн код |
| region | `region` | basicvars | Region code |
| urban | `urban` | basicvars | Urban/rural |
| location | `location` | basicvars | 4-strata |
| hhsize | `hhsize` | basicvars | Household size |
| hhweight | `hhweight` | basicvars | Sample weight |
| month_interview | `month` | basicvars | Calendar month |

**Confirmed verification (R/02 codebook check):**

- 2020-2022: q0114a label = "хаана төрсөн? Аймаг" (BIRTH); q0118a = "хамгийн сүүлд аль аймаг, сумаас шилжиж ирсэн?" (MIGRATION)
- 2024: q0114a байхгүй; **q0118a label = "хаана төрсөн? Аймаг"** (асуулт 1.18 руу шилжсэн)
- 2023: HЭГГҮЙ — энэ wave хасагдсан

**Coverage эмпирикээр ~26%** → home_aimag subsample MAIN-д хүрэлцэх эсэхийг R/05-д шалгана. Хэрэв N≥10K → home_aimag MAIN; N<5K → newaimag fallback. Empirically determined.

## Хатуу мөрдөгдөх дүрэм

1. **Cluster:** `~aimag + wave` (две-way) — `^` тэмдэг ашиглавал interaction-cluster болж буруу.
2. **Donut:** main IV-д 1996, 1997 cohort-уудыг хасна.
3. **Acceptance:** preset effect size БИШ — full reporting, no suppression.
4. **Random seed:** `set.seed(2026)` — бүх скриптэд.
5. **Paths:** R/paths.R-аас ачаалагдана; шинэ хавтсыг гарын `dir.create`-ээр БИШ, `paths.R`-д бүртгэж нэмэх.
6. **Лог:** скрипт бүр өөрийн `output/logs/<NN>_<name>.log` файлд status + сводка бичинэ.

## Tool

- **R:** `C:/Program Files/R/R-4.4.3/bin/Rscript.exe`
- **Working dir:** `c:/tsogoo/Hicheel/erdem shinjilgeenii hural/ecnometric/shine`
- **here()** anchor: `.here` файл shine/-д суулгасан

## Файлын систем

```
shine/
├── PLAN.md             ← алгоритм, дараалал, acceptance
├── CLAUDE.md           ← энэ файл (товч)
├── RESULTS_LOG.md      ← скрипт бүрийн үр дүн
├── README.md
├── .here               ← here::here() anchor
├── renv.lock           ← R багц pin
├── data/
│   ├── hses_2020 ... hses_2024/   ← .dta файлууд (read-only)
│   ├── raw/            ← R/02 гарц
│   ├── processed/      ← R/03-07 гарцууд
│   └── auxiliary/            ← NSO API + manual fallback
├── R/                  ← скриптүүд (01-23 + paths.R)
└── output/
    ├── tables/         ← T1-T8 CSV
    ├── figures/        ← F1-F5 PNG (300 dpi)
    └── logs/           ← скрипт бүрийн log
```

## Ажлын горим

- Долоо хоног тус бүрд checkpoint → RESULTS_LOG.md-д бичиж STOP
- Гацвал 2 удаа автомат retry; 3 дахь алдаанд хэрэглэгчийн оролцоог хүлээх
- DESTRUCTIVE үйлдэлд (rm, file.remove) **зөвшөөрөл** заавал хүлээх

