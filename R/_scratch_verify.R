# Verify codebook claims against actual HSES 2020-2024 data
suppressPackageStartupMessages({
  library(haven); library(dplyr); library(purrr)
})

raw <- readRDS("data/raw/hses_raw.rds")

# Helper: pull data for (wave, file_type)
get_df <- function(w, t) {
  raw |> dplyr::filter(wave == w, type == t) |> dplyr::pull(data) |> .subset2(1)
}

# ---- Helper: print full label + value summary for a variable across waves
inspect_var <- function(varname, file = "indiv", waves = c(2020, 2021, 2022, 2023, 2024)) {
  cat("\n===========================================================\n")
  cat(sprintf(">>> %s (file=%s)\n", varname, file))
  cat("===========================================================\n")
  for (w in waves) {
    d <- get_df(w, file)
    if (is.null(d) || !varname %in% names(d)) {
      cat(sprintf("\n  [%d] -- not present\n", w))
      next
    }
    x <- d[[varname]]
    lbl <- attr(x, "label"); if (is.null(lbl)) lbl <- "(no label)"
    cat(sprintf("\n  [%d] label: %s\n", w, lbl))
    cat(sprintf("       class: %s; n_total: %d; n_NA: %d (%.1f%%); n_zero: %d\n",
                paste(class(x), collapse="/"),
                length(x), sum(is.na(x)), 100*mean(is.na(x)), sum(x == 0, na.rm = TRUE)))
    nz <- x[!is.na(x) & x != 0]
    if (is.numeric(nz) && length(nz) > 0) {
      qs <- quantile(nz, c(.01, .25, .5, .75, .99), na.rm = TRUE)
      cat(sprintf("       non-zero summary: min=%g  p1=%g  p25=%g  median=%g  p75=%g  p99=%g  max=%g  n=%d\n",
                  min(nz), qs[1], qs[2], qs[3], qs[4], qs[5], max(nz), length(nz)))
    }
    # Value labels (haven_labelled)
    vl <- attr(x, "labels")
    if (!is.null(vl) && length(vl) > 0 && length(vl) <= 15) {
      cat("       value labels:\n")
      for (i in seq_along(vl)) cat(sprintf("         %s = %s\n", vl[i], names(vl)[i]))
    }
  }
}

# ---- 1. WAGE VARIABLES (CRITICAL) ----
inspect_var("q0436a")  # monthly OR annual?
inspect_var("q0436b")  # monthly OR annual?
inspect_var("q0436c")  # bonus?
inspect_var("q0437")   # months/year worked
inspect_var("q0438")   # days/month
inspect_var("q0439")   # hours/day
inspect_var("q0427")   # weekly hours

# ---- 2. BIRTH AIMAG (CRITICAL) ----
inspect_var("q0114a")  # birth aimag claim 1
inspect_var("q0118a")  # birth aimag claim 2
inspect_var("q0114b")
inspect_var("q0118b")

# ---- 3. EDUCATION ----
inspect_var("q0210")   # education level
inspect_var("q0213")   # schooling years

# ---- 4. DEMOGRAPHICS ----
inspect_var("q0103")   # sex
inspect_var("q0105y")  # age (years)
inspect_var("q0106")   # marital
inspect_var("q0102")   # relation to head

# ---- 5. WORKING FOR WAGE ----
inspect_var("q0404")   # last 7 days paid work
