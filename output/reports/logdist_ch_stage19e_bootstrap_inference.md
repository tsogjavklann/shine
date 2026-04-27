# Stage 19E: Bootstrap Inference for log_distance_to_ub CH-style IV Threshold Model

Generated: 2026-04-27 00:24:25.310575

## 1. Bootstrap Method
- Cluster bootstrap by `birth_aimag`.
- Each draw resamples birth_aimag clusters with replacement and stacks all observations from selected clusters.
- The 2SLS threshold grid search is recomputed within each bootstrap draw.
- GMM slopes are estimated at each draw-specific threshold.
- `log_distance_to_ub` remains a threshold variable only; it is not used as an IV.
- Seed: 20260426.

## 2. Clusters and Replications
- Number of clusters: 22
- Requested bootstrap replications: 399
- Successful draws: 399
- Failed draws: 0
- Warning-flagged draws: 69

## 3. Observed gamma_hat and Bootstrap CI
- Observed gamma_hat: 6.2288
- Observed distance cutoff in km: 507.1563
- gamma 2.5% / 5% / 50% / 95% / 97.5%: 0.0000 / 0.0000 / 5.8937 / 6.2288 / 6.2288
- distance cutoff 2.5% / 5% / 50% / 95% / 97.5%: 0.0000 / 0.0000 / 362.7433 / 507.1563 / 507.1563

## 4. Observed Regime Slopes and Bootstrap CIs
- beta_low observed: 0.1101; percentile CI: [0.0682, 0.1270]
- beta_high observed: 0.0795; percentile CI: [0.0471, 0.1188]
- beta_diff observed: -0.0306; percentile CI: [-0.0632, 0.0277]

## 5. Bootstrap Threshold-Effect p-value
- bootstrap p-value: 0.1278
- beta_diff CI contains zero: TRUE

## 6. Asymptotic vs Bootstrap
- Stage 19D asymptotic/Wald p-value: 0.3506
- Stage 19E bootstrap p-value: 0.1278

## 7. Inference Conclusion
Bootstrap inference does not strongly support geographic threshold heterogeneity in education returns at the 5% level.
Do not interpret log_distance_to_ub as causing wage returns.

## 8. Caveats
- Only 22 clusters are available, so cluster bootstrap inference may be noisy.
- log_distance_to_ub has only 22 unique values.
- The threshold is birth-aimag-level.
- Resampling birth_aimag clusters also resamples threshold values.
- Matrix condition numbers were high in prior stages.
- Parental education may affect wages through family background, networks, and unobserved ability channels.
- FE residualization is an approximation to the high-dimensional fixed-effects threshold model.
