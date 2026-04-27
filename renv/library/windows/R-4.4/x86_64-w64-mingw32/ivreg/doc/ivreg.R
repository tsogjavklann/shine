## ----setup, include=FALSE-----------------------------------------------------
knitr::opts_chunk$set(echo = TRUE, fig.height=4, fig.width=4)

## ----installation-cran, eval=FALSE--------------------------------------------
# install.packages("ivreg", dependencies = TRUE)

## ----installation-rforge, eval=FALSE------------------------------------------
# remotes::install_github("https://github.com/zeileis/ivreg/")

## ----data---------------------------------------------------------------------
data("SchoolingReturns", package = "ivreg")
summary(SchoolingReturns[, 1:8])

## ----lm-----------------------------------------------------------------------
m_ols <- lm(log(wage) ~ education + poly(experience, 2) + ethnicity + smsa + south,
  data = SchoolingReturns)
summary(m_ols)

## ----ivreg--------------------------------------------------------------------
library("ivreg")
m_iv <- ivreg(log(wage) ~ education + poly(experience, 2) + ethnicity + smsa + south |
  nearcollege + poly(age, 2) + ethnicity + smsa + south,
  data = SchoolingReturns)

## ----ivreg-alternative, eval=FALSE--------------------------------------------
# m_iv <- ivreg(log(wage) ~ ethnicity + smsa + south | education + poly(experience, 2) |
#   nearcollege + poly(age, 2), data = SchoolingReturns)

## ----ivreg-summary------------------------------------------------------------
summary(m_iv)

## ----modelsummary, message=FALSE----------------------------------------------
library("modelsummary")
m_list <- list(OLS = m_ols, IV = m_iv)
msummary(m_list)

## ----modelplot, fig.height=5, fig.width = 7-----------------------------------
modelplot(m_list, coef_omit = "Intercept|experience")

