# Audit of 29 August 2026

Every number in the manuscript, the supplementary material and this README was
checked against the output of `R/02_tests.R` and `R/04_redundancy_analysis.R`,
re-run from `data/` on R 4.3.3. This file records what the audit found, what
changed, and where each corrected value comes from. The manuscript that carries
these corrections is `Manuscrito_v12.docx`; `Manuscrito_v11.docx` is kept beside
it so the two can be compared.

## 1. Two pipelines, two sets of numbers

The manuscript was drawing its tables from the Python pipeline while the
repository, the README and the methods handbook were drawing theirs from R. The
two agree on every median, but not on the bootstrap intervals, on two counts,
or on one p value, because the two rasterisation conventions differ in 308 of
2,240 rows of the composition series.

The R pipeline is now the single source. Table 2, Table 3, Table 4, Table 5,
Table 6, Table S2, Table S3 and Table S4 of the manuscript were rewritten from
`results/`.

## 2. Defects found in the code

**Clumpiness was not corrected.** `01_spatial_pipeline.R` passed
`count_boundary = FALSE` to `calculate_lsm()`, but that argument governs the
edge metrics and `lsm_c_clumpy` ignores it. The published
`configuration_series.csv` therefore carried the uncorrected index: Fontes Nova
in the treated band read -1.038 in 2024, the very value Section 2.4 cites as
proof that the default is inadmissible. Anyone re-running the repository would
have found clumpiness falling significantly in both bands, which is the
artefact the manuscript says it removed.

The correction is now written out from the definition of the index in
`clumpy_no_frame()`, which excludes the analysis frame from the adjacency
denominator. The series was regenerated from the 112 rasters and the reservoir
outlines. Verification: PLAND recomputed from the rebuilt masks matches the
stored series exactly, to nine decimal places, in all 216 cases, so the masks
are the same ones the published series was built on; the corrected index at
Fontes Nova in 1985 is 0.823 in R and 0.8229 in the independent Python
implementation; and no value in the series now falls outside the interval on
which the index is defined. Clumpiness does not change significantly in either
band, which is what Sections 3.7 and 4.4 report.

**The datum transformation was left to the machine.** The reservoir outlines
are stored in Albers on SAD69 and the rasters in SIRGAS 2000. PROJ resolves
that shift with the IBGE NTv2 grid where it can reach `cdn.proj.org` and with a
ballpark transformation where it cannot. The two differ by tens of metres,
which moves the 100 m buffer across cell boundaries and changes every metric
downstream: under the ballpark transformation the forest share of the treated
band at Tocos in 2024 reads 46.9% instead of 38.1%. The three-parameter shift
published by IBGE is now pinned in `CRS_VECTOR`, and it reproduces the
published series exactly.

**Bootstrap intervals were not reproducible.** `set.seed(7)` was called once at
the top of the script, so each interval depended on how many resamples had been
drawn before it. Re-running the unmodified script did not return the intervals
stored in `results/`. The seed is now set inside `boot_ci()`, and the same
change was made for the permutation tests in `04_redundancy_analysis.R`. Every
interval and every permutation p value now depends only on the quantity it
describes. Medians, p values from the Wilcoxon tests, q values and counts are
unaffected.

## 3. Values corrected in the manuscript

| Location | Was | Is | Source |
|---|---|---|---|
| Abstract, Table 4, Table 5, Sections 3.3 and 4.1: 2024 event-study interval | -0.61 to 4.06, -0.61 to 4.25 and -0.60 to 4.21, in three places | -0.60 to 3.72 | `event_study.csv`, `sensitivity.csv` |
| Table 3, 0-30 m, pre-reform, upper bound | 2.75 | 2.60 | `dynamics.csv` |
| Table 3, 0-100 m, pre-reform, upper bound | 2.44 | 2.43 | `dynamics.csv` |
| Table 3, 100-500 m, pre-reform, same sign and q | 9 of 14, q = 0.158 | 8 of 14, q = 0.177 | `dynamics.csv` |
| Table 3, 30-100 m, post-reform, lower bound | 0.71 | 0.96 | `dynamics.csv` |
| Table 3, 100-500 m, post-reform, upper bound | 4.82 | 4.40 | `dynamics.csv` |
| Table 4, 1985 and 1995 upper bounds | 0.65 and 2.53 | 0.68 and 1.55 | `event_study.csv` |
| Table 4, 2014, p and q | 0.650 | 0.600 | `event_study.csv` |
| Table 4, 2020 interval | 0.13 to 1.59 | 0.16 to 1.58 | `event_study.csv` |
| Table 5, threshold of 20 ha, upper bound | 4.59 | 4.60 | `sensitivity.csv` |
| Section 3.4, placebo and treatment intervals | -0.47 to 3.12 and -1.48 to 2.53 | -0.46 to 2.86 and -1.45 to 2.53 | `triple_difference.csv` |
| Table 6, median forest cover | 24.8% | 22.6% | `table_6_compliance.csv` |
| Table 6 and Table S3, APP area at six reservoirs | 447.2, 508.1, 2,150.2, 513.9, 434.3, 2,668.2 | 447.3, 508.2, 2,150.9, 514.0, 434.5, 2,668.9 | `cadastral_zones.csv` |
| Table 6 and Table S3, Vigario | 38.8% forest, 61.2% deficit | 38.9% and 61.1% | `cadastral_zones.csv` |
| Table S3, coefficients at Tocos, Saracuruna, Rosal and Anta | -0.28, -0.61, 7.01, 5.24 | -0.24, -0.60, 7.02, 5.25 | `table_S3_by_reservoir.csv` |
| Table 2 | seven benchmarks, values from the Python run | eight benchmarks, values from `table_2_forest_cover.csv` | `table_2_forest_cover.csv` |
| Table S4, p for period and for the interaction | 0.0212 and 1.0000 | 0.0216 and 0.8322 | `table_S4_rda.csv` |
| Section 3.8 and abstract, share anthropic in 2008 | 50.4% | 51.0% | `cadastral_summary.csv` |
| Sections 3.8 and 4.2, Spearman p for the legal deficit | 0.626 | 0.627 | `size_dependence.csv` |

The 2008 figure moved because it was computed over a wider denominator than
the four transition categories that follow it in the same sentence: 4,963 ha
against 4,785 ha, a difference of 178 ha. Both now use the land of the legal
APP that the 2008 to 2024 cross-tabulation classifies.

## 4. Statements corrected

**"The four smallest reservoirs".** Section 3.5 attributed the median of
-1.70 pp to the four smallest reservoirs. The row in Table 5 is the four
reservoirs added when the set was extended, which are Santa Branca, Santa Rosa,
Ilha dos Pombos and Anta. Two of them are among the larger water bodies, and
the four smallest return a median of -1.45 pp, not -1.70 pp.

**"The two smallest water bodies have the most negative coefficients".** The
two smallest are Santa Branca, of 0.3 ha, and Tocos, of 12.5 ha, and Tocos
returns -0.24 pp. The two most negative coefficients belong to Santa Rosa, of
21.7 ha, and Santa Branca. The abstract, the highlights and Sections 3.5 and
4.2 now say so.

**Truncation at state boundaries.** Section 2.1 reported that the extraction
restored areas truncated for Rosal, by 63.6%, and Funil, by 11.1%. Recomputed
against the IBGE state boundary, the control band that lies outside Rio de
Janeiro is 46.8% at Anta, 41.8% at Ilha dos Pombos, 39.8% at Rosal and 9.8% at
Funil. Two reservoirs with more area across the line than Rosal were missing
from the sentence. See `results/cross_boundary_share.csv`.

**Watersheds.** The abstract said six; Section 2.1 lists seven. Both now say
seven.

**Table S2.** The table compared the eight metrics against a reference run that
the cleanup of 19 August removed from the repository, so it could not be
reproduced. It is now a comparison of the two forms of the clumpiness index,
computed from the same definition across all 216 cases, written by
`02_tests.R`. Only clumpiness is affected by the boundary treatment, so the
seven other metrics no longer appear in it.

## 5. Tables that had no script

`02_tests.R` now writes Table 2, Table 6, the configuration tests of
Section 3.7, the cadastral summary of Section 3.8, the size-dependence tests
and Table S2, none of which was produced by any script before. The class
crosswalk of Table S1 remains a static file, because it is a legend and not a
computation.

---

# Second pass, 29 August 2026, evening

The author ran the whole pipeline on her own machine. Eight values came back
different from the run reported above, and the declared APP was recomputed for
all fourteen reservoirs.

## 6. The results depended on the language of the operating system

Seven of the eight differences trace to one cause. `order()` sorts character
vectors by the collation of the machine, and the two collations in play disagree
on a single pair: under a Portuguese locale Santana precedes Santa Rosa, under
the C locale it follows it. Medians, p values, q values and the sign counts do
not care about row order. The bootstrap does, because `sample()` draws positions
rather than values, so the same seed applied to a differently ordered vector
returns different resamples. Reordering the vector by hand reproduced the
author's 2.748839 for the upper bound of the 0 to 30 m pre-reform interval to the
sixth decimal, which closed the diagnosis.

`RESERVOIR_ORDER` in `00_config.R` now fixes the order, and `band_matrix()`,
`metric_matrix()` and the reservoir factor of the redundancy analysis all use it.
Under that order the six bootstrap bounds and the permutation p value of the
period term reproduce the author's run exactly.

Two values changed in the manuscript as a result: the upper bound of the
0 to 30 m pre-reform interval, from 2.60 to 2.75, and the lower bound of the
30 to 100 m post-reform interval, from 0.96 to 0.71. Both are the values the
earlier Python pipeline had also produced, which is consistent, since that
pipeline ran on the same machine.

## 7. One value that the order does not explain

The permutation p of the band by period interaction is 1.0000 on the author's
machine and 0.8198 here, under any seed and under either row order. The observed
statistic is identical in both, R squared of 0.0003 and adjusted R squared of
-0.0004, so the difference is in the permutation distribution and not in the
model. The remaining candidate is the version of vegan or of permute. The
manuscript reports 1.0000, which is what the authoring environment returns, and
the reading does not change either way: the term explains no variation. The
versions should be pinned in the repository before submission.

## 8. The declared APP now covers all fourteen reservoirs

Section 5 stated that the declared zones were restricted to ten reservoirs
because the cadastral layer carries no spatial index and a full scan exceeded the
available processing time. The claim does not hold: a sequential pass over the
1.3 GB geometry file of 412,037 features runs in 23 seconds at 60 MB per second,
and the whole extraction, including the attribute table, in under a minute.

Section E of `01_spatial_pipeline.R` now computes the declared zones for the
fourteen reservoirs and writes `data/declared_app_zones.csv`. The result is
reported in Section 3.8 and in Table S6, and it gives the third recommendation of
Section 6 the numbers it lacked: of the 1,235.8 ha declared inside the buffers,
433.7 ha fall within the legal strip and 802.3 ha outside it, the declaration
covers 5.3% of the legal APP, and 170.5 ha of declared polygons sit on the water
surface itself.

## 9. Values corrected in this pass

| Location | Was | Is |
|---|---|---|
| Table 3, 0-30 m, pre-reform, upper bound | 2.60 | 2.75 |
| Table 3, 30-100 m, post-reform, lower bound | 0.96 | 0.71 |
| Table S4, p for the period term | 0.0216 | 0.0206 |
| Table S4, p for the interaction | 0.8322 | 1.0000 |
| Section 3.9, p for the period term | 0.022 | 0.021 |
| Section 3.9, p for the interaction | 0.832 | 1.000 |
| Section 5, the declared zones | restricted to ten reservoirs | complete for fourteen |
| Figure 5 caption | five size thresholds | five thresholds and two set splits |

Table 5 also gained the row for the ten reservoirs processed first, which is the
1.84 pp with p = 0.017 that the methods handbook quotes, and Section 3.5 now
states it. Section 3.1 quotes four band shares that no output file carried;
`02_tests.R` now writes them to `results/band_composition_2024.csv`.

## 10. Verification

343 automatic comparisons between the tables of the manuscript and the output
files, without divergence. The supplementary workbook was rebuilt from the same
files, and its six sheets match them row for row.

---

# Third pass, 31 August 2026

The author re-ran the whole pipeline. Every output file reproduces the committed
values, so the fixed row order removed the dependence on the locale of the
machine. The comparison between the manuscript tables and the output files was
repeated: 343 values, no divergence.

## 11. A claim in Section 2.3 that the analysis does not support

Section 2.3 stated that "section 3.8 presents reservoir-specific APP analysis
using the actual legal boundaries for a more direct assessment". No such analysis
exists. The area of the legal APP in the cadastral module was compared against
the area of the 0 to 100 m band for the fourteen reservoirs and the two are
identical to the hundredth of a hectare, from 6.93 ha at Santa Branca to
2,668.86 ha at Fontes Nova. The legal APP of this study is the 0 to 100 m band.

The sentence was removed, and Section 2.5 now opens by stating that the legal APP
is operationalised as the band of Section 2.3 because the licensed width of each
undertaking was not available. The reader is told once what the term denotes,
which is what the statutory quantity and the analytical construct sharing a name
required.

## 12. Redundancy removed

Section 2.3 argued the same point in three consecutive paragraphs, the second and
third of which restated the first over some 250 words. The three were condensed
into two: the definition of the bands, then the compromise the uniform width
represents, with the direction of the bias in both senses and the reference to
Luke et al. (2019).

The Conclusion closed with six sentences of recommendations for future work, five
of which Section 6 already carried. The close now names the one design change the
study supports, a minimum effect size registered in advance and anchored to the
licensed width, and ends there.
