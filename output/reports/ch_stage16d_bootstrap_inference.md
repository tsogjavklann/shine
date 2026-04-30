# Stage 16D: Bootstrap Inference for q_school_access CH-style IV Threshold Model

Generated: 2026-04-26 22:26:29.136131

## 1. Bootstrap Method
- Cluster bootstrap by `birth_aimag`.
- Each draw resamples birth_aimag clusters with replacement and stacks all observations from selected clusters.
- The 2SLS threshold grid search is recomputed within each bootstrap draw.
- GMM slopes are estimated at each draw-specific threshold.
- Seed: 20260426.

## 2. Clusters and Replications
- Number of clusters: 22
- Requested bootstrap replications: 399
- Successful draws: 399
- Failed draws: 0
- Warning-flagged draws: 21

## 3. Observed gamma_hat and Bootstrap CI
- Observed gamma_hat: 1.0380
- gamma 2.5% / 5% / 50% / 95% / 97.5%: 1.0205 / 1.0323 / 1.2159 / 1.8080 / 1.8401

## 4. Observed Regime Slopes and Bootstrap CIs
- beta_low observed: 0.1205; percentile CI: [0.0714, 0.1315]
- beta_high observed: 0.0909; percentile CI: [0.0580, 0.1143]
- beta_diff observed: -0.0296; percentile CI: [-0.0579, 0.0162]

## 5. Bootstrap Threshold-Effect p-value
- bootstrap p-value: 0.1078
- beta_diff CI contains zero: TRUE

## 6. Asymptotic vs Bootstrap
- Stage 16C asymptotic/Wald p-value: 0.0704
- Stage 16D bootstrap p-value: 0.1078

## 7. Inference Conclusion
Bootstrap inference does not strongly support threshold heterogeneity in education returns across q_school_access regimes at the 5% level.
Do not interpret q_school_access as causing wage returns.

## 8. Caveats
- Only 22 clusters are available, so cluster bootstrap inference may be noisy.
- Matrix condition numbers are high in prior stages.
- Parental education may affect wages through family background, networks, and unobserved ability channels.
- q_school_access threshold exogeneity remains an identifying assumption.
- FE residualization is an approximation to the high-dimensional fixed-effects threshold model.
