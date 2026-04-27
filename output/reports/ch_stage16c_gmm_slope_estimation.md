# Stage 16C: GMM Slope Estimation at q_school_access gamma_hat

Generated: 2026-04-26 22:12:42.702455

## 1. gamma_hat Used
- gamma_hat: 1.0380

## 2. GMM Method
- Residualized variables from Stage 16A are used.
- Regime interactions are formed at the Stage 16B threshold.
- First-step GMM uses W0 = solve((Z'Z)/n).
- Second-step GMM uses the inverse moment covariance matrix.
- Main weighting matrix: cluster-robust S by birth_aimag

## 3. Matrix Diagnostics
- N: 3188
- N_low: 793
- N_high: 2395
- rank(X): 7
- rank(Z): 7
- rank(Z'Z): 7
- rank(X'Z): 7
- condition number Z'Z: 181749.0532
- condition number X'Z W Z'X: 449660.2693
- near-singular warning: FALSE

## 4. GMM Regime Slopes
- beta_low_GMM: 0.1205, SE: 0.0053, p-value: 0.0000
- beta_high_GMM: 0.0909, SE: 0.0150, p-value: 0.0000
- beta_high - beta_low: -0.0296

## 5. Wald Test
- Wald statistic: 3.6345
- p-value: 0.0704
- inference reference: F(1, G-1)

## 6. Comparison with Stage 16B 2SLS Slopes
- beta_low_2SLS: 0.1205 vs beta_low_GMM: 0.1205
- beta_high_2SLS: 0.0909 vs beta_high_GMM: 0.0909

## 7. Numerical Warnings
- No numerical warnings recorded.

## 8. Decision
Proceed to Stage 16D bootstrap inference.

## 9. Caveats
- Do not call this the final full result until Stage 16D bootstrap/inference is complete.
- Parental education may affect wages through family background, networks, and unobserved ability channels.
- q_school_access threshold exogeneity remains an identifying assumption.
- Stage 16C did not run bootstrap inference.
