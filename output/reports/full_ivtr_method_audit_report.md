# Full IVTR Method Audit

Generated: 2026-04-27 10:55:22.95841

## Audit Summary
- Data construction audit: PASS=12, WARNING=1, FAIL=0.
- IV audit: PASS=6, WARNING=0, FAIL=0.
- Threshold validity audit: PASS=4, WARNING=2, FAIL=0.
- CH-style estimation audit: PASS=0, WARNING=6, FAIL=0.
- Bootstrap audit: PASS=0, WARNING=6, FAIL=0.

## 1. Data Construction Audit
# A tibble: 13 × 9
   variable       source_variables formula_or_rule missing_count nonmissing_rate
   <chr>          <chr>            <chr>                   <int>           <dbl>
 1 lwage          wage or ln_wage  log(wage) for …             0           1    
 2 educ_years     education level… years of schoo…             0           1    
 3 father_educ_y… father_educ_lev… documented lev…          1147           0.640
 4 mother_educ_y… mother_educ_lev… documented lev…           239           0.925
 5 parent_educ_m… father_educ_yea… rowMeans(cbind…             0           1    
 6 age2           age              age^2                       0           1    
 7 birth_cohort   birth_year       cohort bands f…             0           1    
 8 log_distance_… birth_aimag, di… log(pmax(dista…             0           1    
 9 q_school_acce… birth_aimag, sc… computed schoo…             0           1    
10 student_teach… school_supply_p… student_teache…             0           1    
11 student_teach… student_teacher… mean(at_16, at…             0           1    
12 student_teach… student_teacher… mean(at_16, at…             0           1    
13 student_teach… student_teacher… mean(at_17, at…             0           1    
   pre_outcome_or_predetermined could_mechanically_us…¹ status verification_note
   <lgl>                        <lgl>                   <chr>  <chr>            
 1 TRUE                         FALSE                   PASS   Present in analy…
 2 TRUE                         FALSE                   PASS   Endogenous regre…
 3 TRUE                         FALSE                   PASS   Used as parent i…
 4 TRUE                         FALSE                   PASS   Used as parent i…
 5 TRUE                         FALSE                   PASS   Max abs differen…
 6 TRUE                         FALSE                   PASS   Max abs differen…
 7 TRUE                         FALSE                   PASS   Used as fixed ef…
 8 TRUE                         FALSE                   PASS   Max abs formula …
 9 TRUE                         FALSE                   WARNI… Not a home-envir…
10 TRUE                         FALSE                   PASS   Higher means mor…
11 TRUE                         FALSE                   PASS   Max abs formula …
12 TRUE                         FALSE                   PASS   Max abs formula …
13 TRUE                         FALSE                   PASS   Max abs formula …
# ℹ abbreviated name: ¹​could_mechanically_use_lwage_or_educ_years

## 2. IV Audit
# A tibble: 6 × 14
  q_variable                      parent_rebuild_max_ab…¹ parent_used_as_thres…²
  <chr>                                             <dbl> <lgl>                 
1 q_school_access                                      NA FALSE                 
2 log_distance_to_ub                                   NA FALSE                 
3 student_teacher_ratio_at_17                           0 FALSE                 
4 student_teacher_ratio_avg_16_17                       0 FALSE                 
5 student_teacher_ratio_avg_16_18                       0 FALSE                 
6 student_teacher_ratio_avg_17_18                       0 FALSE                 
  father_mother_used_as…³ educ_years_leakage_i…⁴ first_stage_coef first_stage_se
  <lgl>                   <lgl>                             <dbl>          <dbl>
1 FALSE                   FALSE                             0.365         0.0157
2 FALSE                   FALSE                             0.362         0.0153
3 FALSE                   FALSE                             0.379         0.0403
4 FALSE                   FALSE                             0.356         0.0172
5 FALSE                   FALSE                             0.356         0.0172
6 FALSE                   FALSE                             0.362         0.0153
# ℹ abbreviated names: ¹​parent_rebuild_max_abs_diff, ²​parent_used_as_threshold, ³​father_mother_used_as_extra_main_iv, ⁴​educ_years_leakage_into_iv_detected
# ℹ 7 more variables: first_stage_F <dbl>, weak_iv_flag <lgl>, low_regime_first_stage_F <dbl>, high_regime_first_stage_F <dbl>,
#   low_regime_first_stage_status <chr>, high_regime_first_stage_status <chr>, status <chr>

## 3. Threshold Variable Validity Audit
# A tibble: 6 × 11
  q_variable      q_type variation_level     N unique_q_values corr_q_educ_years
  <chr>           <chr>  <chr>           <int>           <int>             <dbl>
1 q_school_access conti… individual con…  3188             356           0.00137
2 log_distance_t… order… birth_aimag le…  3188              22          -0.0371 
3 student_teache… conti… birth_aimag-ye…  1032             296          -0.0537 
4 student_teache… conti… birth_aimag-ye…  3113             339          -0.0443 
5 student_teache… conti… birth_aimag-ye…  3113             339          -0.0455 
6 student_teache… conti… birth_aimag-ye…  3188             359          -0.0491 
  corr_q_lwage corr_q_parent_educ_mean q_used_only_as_threshold_…¹ caveat status
         <dbl>                   <dbl> <lgl>                       <chr>  <chr> 
1      -0.0612                -0.157   TRUE                        Earli… WARNI…
2      -0.106                 -0.240   TRUE                        Only … WARNI…
3       0.0538                 0.0517  TRUE                        Schoo… PASS  
4       0.0198                 0.00867 TRUE                        Schoo… PASS  
5       0.0218                 0.00765 TRUE                        Schoo… PASS  
6       0.0231                 0.00553 TRUE                        Schoo… PASS  
# ℹ abbreviated name: ¹​q_used_only_as_threshold_not_iv

## 4. Caner-Hansen-Style Estimation Audit
# A tibble: 6 × 17
  q_variable                      residualized_dataset_…¹ residualized_variabl…²
  <chr>                           <lgl>                   <lgl>                 
1 q_school_access                 TRUE                    TRUE                  
2 log_distance_to_ub              TRUE                    TRUE                  
3 student_teacher_ratio_at_17     TRUE                    TRUE                  
4 student_teacher_ratio_avg_16_17 TRUE                    TRUE                  
5 student_teacher_ratio_avg_16_18 TRUE                    TRUE                  
6 student_teacher_ratio_avg_17_18 TRUE                    TRUE                  
  threshold_q_not_residualized grid_search_over_q trimming_rule_detected
  <lgl>                        <lgl>              <lgl>                 
1 TRUE                         TRUE               TRUE                  
2 TRUE                         TRUE               TRUE                  
3 TRUE                         TRUE               TRUE                  
4 TRUE                         TRUE               TRUE                  
5 TRUE                         TRUE               TRUE                  
6 TRUE                         TRUE               TRUE                  
# ℹ abbreviated names: ¹​residualized_dataset_exists, ²​residualized_variables_present
# ℹ 11 more variables: gamma_minimum_objective_ok <lgl>, N_low_matches <lgl>, N_high_matches <lgl>, endogenous_regime_regressors_ok <lgl>,
#   regime_instruments_ok <lgl>, rank_X <dbl>, rank_Z <dbl>, rank_XZ_W_ZX <dbl>, condition_number_main <dbl>, warnings <chr>, status <chr>

## 5. Bootstrap / Inference Audit
# A tibble: 6 × 14
  q_variable      B_used successful_draws failed_draws warning_draws beta_low_ci
  <chr>            <dbl>            <dbl>        <dbl>         <dbl> <chr>      
1 q_school_access    399              399            0            21 [0.0714, 0…
2 log_distance_t…    399              399            0            69 [0.0682, 0…
3 student_teache…    399              399            0             0 [0.0425, 0…
4 student_teache…    399              399            0             0 [0.0596, 0…
5 student_teache…   1999             1999            0             1 [0.0587, 0…
6 student_teache…    399              399            0             0 [0.0558, 0…
  beta_high_ci     beta_diff_ci    beta_diff_ci_contain…¹ centered_bootstrap_p…²
  <chr>            <chr>           <lgl>                                   <dbl>
1 [0.0580, 0.1143] [-0.0579, 0.01… TRUE                                   0.108 
2 [0.0471, 0.1188] [-0.0632, 0.02… TRUE                                   0.128 
3 [0.0762, 0.1844] [-0.0272, 0.07… TRUE                                   0.0802
4 [0.0846, 0.1650] [0.0042, 0.067… FALSE                                  0.123 
5 [0.0819, 0.1511] [-0.0008, 0.05… TRUE                                   0.114 
6 [0.0800, 0.1504] [0.0044, 0.060… FALSE                                  0.0451
# ℹ abbreviated names: ¹​beta_diff_ci_contains_zero, ²​centered_bootstrap_p_value
# ℹ 4 more variables: sign_based_p_value <dbl>, percentile_ci_vs_centered_p_inconsistency <lgl>, final_bootstrap_recommendation <chr>, status <chr>

## 6. Comparison Table
# A tibble: 6 × 17
  q_variable         N number_of_clusters unique_q_values gamma_hat low_regime_N
  <chr>          <int>              <int>           <int>     <dbl>        <dbl>
1 q_school_acce…  3188                 22             356      1.04          793
2 log_distance_…  3188                 22              22      6.23         2086
3 student_teach…  1032                 22             296     25.5           855
4 student_teach…  3113                 22             339     19.7          1017
5 student_teach…  3113                 22             339     19.6          1007
6 student_teach…  3188                 22             359     19.5          1051
  high_regime_N beta_low beta_high beta_diff first_stage_F bootstrap_B
          <dbl>    <dbl>     <dbl>     <dbl>         <dbl>       <dbl>
1          2395   0.120     0.0909   -0.0296         602.          399
2          1102   0.110     0.0795   -0.0306         558.          399
3           177   0.0970    0.138     0.0412          88.5         399
4          2096   0.0868    0.111     0.0238         427.          399
5          2106   0.0874    0.110     0.0224         427.         1999
6          2137   0.0784    0.109     0.0310         558.          399
  bootstrap_CI_beta_diff centered_bootstrap_p_va…¹ sign_based_p_value conclusion
  <chr>                                      <dbl>              <dbl> <chr>     
1 [-0.0579, 0.0162]                         0.108              0.140  not suppo…
2 [-0.0632, 0.0277]                         0.128              0.160  not suppo…
3 [-0.0272, 0.0793]                         0.0802             0.105  suggestive
4 [0.0042, 0.0676]                          0.123              0.0401 not suppo…
5 [-0.0008, 0.0584]                         0.114              0.0530 not suppo…
6 [0.0044, 0.0608]                          0.0451             0.0401 suggestive
# ℹ abbreviated name: ¹​centered_bootstrap_p_value
# ℹ 1 more variable: main_limitation <chr>

## 7. Final Methodology Verdict
# A tibble: 7 × 3
  question                                           
  <chr>                                              
1 Is the pipeline technically correct?               
2 Is it defensible as Caner-Hansen-style IVTR?       
3 Is it a full exact Caner-Hansen (2004) replication?
4 Best main threshold candidate                      
5 Robustness-only thresholds                         
6 Safe claim                                         
7 Overclaim                                          
  answer                                                                   label
  <chr>                                                                    <chr>
1 READY WITH CAVEATS                                                       READ…
2 READY WITH CAVEATS                                                       READ…
3 NOT READY                                                                NOT …
4 student_teacher_ratio_avg_17_18, conditional on B=1999 confirmation      READ…
5 q_school_access, log_distance_to_ub, student_teacher_ratio_at_17, stude… READ…
6 Education returns appear higher in the high student-teacher-ratio regim… READ…
7 Claiming exact Caner-Hansen replication, causal effect of q, or definit… FAIL 

## Exact Wording for Thesis/Report

### Methodology Paragraph
I estimate a Caner-Hansen-style instrumental-variable threshold regression to examine whether the return to education differs across predetermined threshold regimes. The outcome is log wage (`lwage`), the endogenous regressor is years of education (`educ_years`), and the instrument is mean parental education (`parent_educ_mean`). The model residualizes the outcome, endogenous regressor, instrument, and controls with respect to birth-aimag, birth-cohort, and survey-wave fixed effects, while keeping the threshold variable in levels. The threshold is selected by a grid search that minimizes the weighted 2SLS residual sum of squares, and regime-specific returns are estimated using a two-step GMM/IV procedure with cluster-robust inference by birth aimag.

### Threshold Variable Paragraph
The preferred threshold candidate is `student_teacher_ratio_avg_17_18`, defined as the average number of students per teacher in the respondent's birth aimag when the respondent was age 17 and age 18. Higher values indicate a more crowded school environment, or lower teacher intensity. This threshold is predetermined relative to adult wages and is used only to split regimes; it is not used as an instrument.

### IV Caveat Paragraph
The instrument, `parent_educ_mean`, is strongly related to the respondent's schooling in the first stage. However, the exclusion restriction is not directly testable. Parental education may affect adult wages through family background, networks, aspirations, and unobserved ability channels, so the IV estimates should be interpreted with this caveat.

### Inference Caveat Paragraph
This implementation should be described as Caner-Hansen-style rather than an exact replication of Caner and Hansen (2004). The fixed effects are handled through residualization, the threshold search uses a 2SLS objective, and uncertainty is assessed with cluster bootstrap inference. Because there are only 22 birth-aimag clusters, bootstrap inference may be noisy; therefore the final threshold result should rely on the higher-replication bootstrap rather than the screening bootstrap.

### Final Result Paragraph
In the current B=399 bootstrap run, the `student_teacher_ratio_avg_17_18` threshold produces a positive difference between the high- and low-crowding regimes, with the high-crowding regime showing a larger estimated return to education. This evidence is suggestive. It should not be presented as final strong evidence until the B=1999 bootstrap confirms that the beta-difference confidence interval excludes zero and the bootstrap p-value remains below conventional thresholds. The threshold should not be interpreted as causing wage returns; the result is evidence of heterogeneous education returns across school-crowding regimes.
