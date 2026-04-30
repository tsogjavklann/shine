# Stage 19D: log_distance_to_ub GMM Slope Estimation

Generated: 2026-04-27 00:17:14.410966

## 1. gamma_hat Used
- gamma_hat: 6.2288
- distance cutoff in km: 507.1563

## 2. GMM Method
- Residualized variables from Stage 19B are used.
- Regime interactions are formed at the Stage 19C threshold.
- First-step GMM uses W0 = solve((Z'Z)/n).
- Second-step GMM uses the inverse moment covariance matrix.
- Main weighting matrix: cluster-robust S by birth_aimag
- `log_distance_to_ub` is used only as a threshold variable, not as an IV.

## 3. Matrix Diagnostics
- N: 3188
- N_low: 2086
- N_high: 1102
- rank(X): 7
- rank(Z): 7
- rank(Z'Z): 7
- rank(X'Z): 7
- rank(X'Z W Z'X): 7
- condition number Z'Z: 181692.7656
- condition number S_robust: 158337.4939
- condition number S_cluster: 166039.2049
- condition number X'Z W Z'X: 378623.7018
- near-singular warning: FALSE

## 4. GMM Regime Slopes
- beta_low_GMM: 0.1101, SE: 0.0074, p-value: 0.0000
- beta_high_GMM: 0.0795, SE: 0.0315, p-value: 0.0198
- beta_high - beta_low: -0.0306

## 5. Wald Test
- Wald statistic: 0.9115
- p-value: 0.3506
- inference reference: F(1, G-1)

## 6. Comparison with Stage 19C 2SLS Slopes
- beta_low_2SLS: 0.1101 vs beta_low_GMM: 0.1101
- beta_high_2SLS: 0.0795 vs beta_high_GMM: 0.0795

## 7. Numerical Warnings
- No numerical warnings recorded.

## 8. Decision
Proceed to Stage 19E bootstrap inference.

## 9. Caveats
- Do not call this the final full result until Stage 19E bootstrap inference is complete.
- Do not interpret log_distance_to_ub as causing wage returns.
- Education returns should be described as differing across geographic/labor-market-access regimes only if inference supports it.
- log_distance_to_ub is a birth-aimag-level threshold with only 22 unique values.
- Parental education may affect wages through family background, networks, and unobserved ability channels.
- Stage 19D did not run bootstrap inference.
