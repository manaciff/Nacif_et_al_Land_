# Results

Tables written by the analysis scripts. The numbers in the file names follow
the original table order; the correspondence with the manuscript is in the main
README.

| File | Written by | Content |
|---|---|---|
| `table_2_forest_cover.csv` | `02_tests.R` | forest cover by band and benchmark (Table 3) |
| `band_composition_2024.csv` | `02_tests.R` | composition of each band in 2024 (Section 3.1) |
| `dynamics.csv` | `02_tests.R` | rates of change by band and window (Table 4) |
| `triple_difference.csv` | `02_tests.R` | confirmatory quantity and its placebo |
| `event_study.csv` | `02_tests.R` | event-study coefficients by benchmark (Table 5) |
| `spatial_gradient.csv` | `02_tests.R` | Friedman test and Kendall's W |
| `sensitivity.csv` | `02_tests.R` | 2024 coefficient under each inclusion rule (Table 6) |
| `event_study_by_scenario.csv` | `02_tests.R` | all event-study coefficients under each inclusion rule |
| `size_dependence.csv` | `02_tests.R` | Spearman and Mann-Whitney tests of size dependence |
| `outlier_check.csv` | `02_tests.R` | Tukey fences for the 2024 coefficient |
| `table_S7_stable_waterline.csv` | `02_tests.R` | event study and triple difference without the three reservoirs impounded during the series |
| `water_share_0_30m.csv` | `02_tests.R` | water share of the 0 to 30 m band (Table S8) |
| `configuration.csv` | `02_tests.R` | trends in the configuration metrics |
| `clumpy_default_trend.csv` | `02_tests.R` | clumpiness trend under the package default |
| `table_S2_boundary_effect.csv` | `02_tests.R` | effect of the frame on the clumpiness index |
| `table_S3_by_reservoir.csv` | `02_tests.R` | coefficient and cover per reservoir |
| `table_6_compliance.csv` | `02_tests.R` | native vegetation in the APP band by reservoir (Table 7) |
| `cadastral_summary.csv` | `02_tests.R` | holding-level deficit and 2008 to 2024 transition |
| `table_S4_rda.csv` | `04_redundancy_analysis.R` | variation partitioning |
| `cross_boundary_share.csv` | `05_reservoir_characteristics.R` | share of each band outside Rio de Janeiro |
| `table_S1_class_crosswalk.csv` | supplied | MapBiomas legend to the five analytical classes |

`table_S1_class_crosswalk.csv` is supplied rather than generated: it is the
lookup table applied inside Earth Engine before export (`docs/`).
