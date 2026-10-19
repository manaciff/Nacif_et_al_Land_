# Landscape dynamics and conservation policy effectiveness in reservoir riparian buffers

Fourteen reservoirs under Brazil's Forest Code, 1985 to 2024.

Data, code, figures and manuscript files for the article submitted to *Land*
(MDPI). Every value reported in the manuscript and in the supplementary material
can be recomputed from this repository.

- Repository: [GitHub URL ...]
- Archived release: [Zenodo DOI ...]

---

## What the study asks

The Brazilian Forest Code (Law 12,651/2012) requires native vegetation in the
Permanent Preservation Areas (APPs) that border artificial reservoirs. Testing
whether the mandate is associated with forest recovery means separating it from
the regional forest transition already under way in southeastern Brazil, and a
design with a single pre-reform observation cannot do that.

The study compares forest cover in a 0 to 100 m band around each reservoir (the
APP band) with a 100 to 500 m band of the same reservoir (the control band), at
eight benchmarks, four of them before the reform, so that the parallel-trends
assumption is tested rather than assumed.

The APP band is a reference width, not the legally required strip of each
reservoir. It reproduces the 100 m rural standard of CONAMA Resolution 302/2002;
the width that applies to each reservoir under Articles 4, 5 and 62 of Law
12,651/2012 depends on its licence and on its date of impoundment. The 25%
forest-cover criterion used in places is an ecological threshold from the
fragmentation literature and carries no legal status.

## Main results

| Quantity | Value |
|---|---|
| Event-study coefficient, 2024 | 1.04 pp (95% CI −0.60 to 3.72; q = 0.237) |
| Triple difference | 0.48 pp per decade (p = 0.510) |
| Pre-reform coefficients | none significant (q ≥ 0.529); they move toward zero from −1.50 pp in 1985 to 0.00 pp in 2008 |
| 2024 coefficient across reservoir sets | −1.70 to 2.82 pp (Table 6) |
| Without the three reservoirs impounded during the series | 0.44 pp (95% CI −1.12 to 2.45; p = 0.594) |
| Forest gain after the reform | significant in all four bands, 1.76 to 3.68 pp per decade |
| Distance band, partial RDA | adjusted R² = 0.241, p < 0.001 |
| Band × period interaction, partial RDA | adjusted R² = −0.0004 |
| Median native-vegetation deficit in the APP band | 77.4% by reservoir; 95.6% by holding record |
| APP band within holdings already anthropic in 2008 | 51.0% |
| APP band covered by a declared APP in the registry | 5.3% |
| Cleared after the 22 July 2008 cut-off | 1.4%, that is 67.9 ha in 49 of 199 holding records |

The divergence between the bands follows the reform in time, but its magnitude
is not distinguishable from zero and depends on reservoirs whose margins changed
during the series. These are associations; the design does not identify a
causal effect of the reform.

---

## Repository layout

```
.
├── R/                              analysis code, run in numerical order
│   ├── 00_config.R                 paths, constants, reservoir sets, helpers
│   ├── 01_spatial_pipeline.R       bands, composition, metrics, cadastral module
│   ├── 02_tests.R                  inference and the tables of the manuscript
│   ├── 03_figures.R                figures 2 to 8 and S1 to S3
│   ├── 04_redundancy_analysis.R    multivariate check, Table S4
│   └── 05_reservoir_characteristics.R  Table 2 and the cross-boundary shares
├── data/                           extracted series, one row per observation
├── results/                        tables written by the scripts (see results/README.md)
├── figures/                        TIFF (600 dpi, not versioned) and PNG copies
├── manuscript/                     manuscript for Land, version 13
├── supplementary/                  supplementary materials, document and spreadsheet
├── docs/                           Earth Engine scripts, audit and cleanup logs
└── .project_root                   marker used to locate the repository root
```

## Running the analysis

Open the project in R and run the scripts. No path needs editing and `setwd()`
is not required: `00_config.R` locates the project root through `here()` when
the package is installed, and otherwise from the location of the script.

```r
source("R/02_tests.R")                 # inference; Tables 3 to 7, S2, S3, S7, S8
source("R/03_figures.R")               # Figures 2 to 8 and S1 to S3
source("R/04_redundancy_analysis.R")   # multivariate check; Table S4
```

Two scripts rebuild inputs from layers that are not distributed here and are
optional:

- `R/01_spatial_pipeline.R` regenerates `data/` from the 112 clipped rasters,
  the reservoir outlines and the cadastral layers.
- `R/05_reservoir_characteristics.R` rebuilds `data/reservoir_characteristics.csv`
  (Table 2) from the reservoir outlines, which carry the attributes of the ANA
  layer *Massas d'Água*, and from the INEA basin layer at 1:50,000. With the IBGE
  state boundary (2024) it also rebuilds `results/cross_boundary_share.csv`, on
  the same 30 m grid and masks as script 01; the band areas it obtains are
  checked against `data/composition_series.csv` before anything is written.
  Set `DIR_VECTOR`, `FILE_BASINS` and `FILE_STATE` if the layers are not found
  automatically.

### Dependencies

```r
install.packages(c("ggplot2", "patchwork", "ragg"))        # figures
install.packages(c("vegan", "permute"))                    # script 04
install.packages(c("terra", "sf", "landscapemetrics"))     # scripts 01 and 05
install.packages("here")                                   # optional
```

`02_tests.R` runs on base R alone.

---

## Correspondence with the manuscript

The file names in `results/` predate the insertion of Table 2 (reservoir
characteristics) and keep their original numbers.

| Manuscript | File |
|---|---|
| Table 2 | `data/reservoir_characteristics.csv` |
| Table 3 | `results/table_2_forest_cover.csv` |
| Table 4 | `results/dynamics.csv` |
| Table 5 | `results/event_study.csv` |
| Table 6 | `results/sensitivity.csv` and `results/event_study_by_scenario.csv` |
| Table 7 | `results/table_6_compliance.csv` |
| Tables S1 to S4 | `results/table_S1_class_crosswalk.csv` to `results/table_S4_rda.csv` |
| Table S5 | `data/cadastral_transitions.csv` |
| Table S6 | `data/declared_app_zones.csv` |
| Table S7 | `results/table_S7_stable_waterline.csv` |
| Table S8 | `results/water_share_0_30m.csv` |

## Data dictionary

**`composition_series.csv`** (2,240 rows). Land cover area and share by
reservoir, band, benchmark and class.

| Column | Meaning |
|---|---|
| `Reservoir` | reservoir identifier |
| `Year` | benchmark year |
| `Band` | distance band: `0-30 m`, `30-100 m`, `0-100 m` (APP band), `100-500 m` (control band) |
| `Code` | analytical class code |
| `Class` | analytical class name |
| `Area_ha` | area of the class within the band |
| `Band_area_ha` | total area of the band, water included |
| `Land_area_ha` | land area of the band, water excluded |
| `Pct_band` | share of the total band area |
| `Pct_terrestrial` | share of the land area; `NA` for water |

**`configuration_series.csv`** (1,944 rows). Eight class-level metrics for the
forest class in the APP and control bands, plus `clumpy_frame_counted`, the
clumpiness index with the analysis frame left in the adjacency denominator. That
series is carried only so that Table S2 can quantify what this single decision
does to the index. In the APP band the series covers thirteen reservoirs: Santa
Branca retains no forest cell inside its APP band at any benchmark, so the
metrics are undefined rather than zero.

**`cadastral_zones.csv`** (211 rows). Native vegetation in the APP band, at
reservoir level (`APP_band_reservoir`, 14 rows) and by holding record
(`APP_band_property`, 197 rows). `Deficit_pct` is the share of the terrestrial
APP band without native vegetation. Two of the 199 holding records that
intersect the buffers hold no land inside the APP band and admit no deficit.

**`cadastral_transitions.csv`** (199 rows). Land cover of the APP band inside
each holding record in 2008 and 2024, cross-tabulated into four categories.
Article 61-A anchors the consolidated rural area to the occupation observed on
22 July 2008, and the registry cannot evidence that date because it postdates
the cut-off; the classification therefore comes from land cover. One holding of
24,980 ha intersects the buffers of five reservoirs and appears once for each,
so the 199 records correspond to 195 distinct holdings.

**`declared_app_zones.csv`** (14 rows). The APP as the landholder declared it,
within the 500 m buffer of each reservoir, split into the part inside the APP
band and the part outside it. See `docs/README_declared_app.md`.

**`reservoir_areas.csv`** (14 rows). Water surface area of each outline, in
hectares, from 0.3 ha to 3,102 ha.

**`reservoir_characteristics.csv`** (14 rows). Basin and sub-basin (INEA),
municipalities, states, main use, operator and impoundment date (ANA), surface
area in the ANA layer and in this study, a point on each water surface, and a
note with the source of any date not carried by the ANA layer.

### Holding identifiers

Holdings are identified by sequential codes (`H001` to `H195`) rather than by
their registry codes. The correspondence table is written by
`pseudonymize_holdings()` in `00_config.R` to `data/cadastral/holding_key.csv`,
which `.gitignore` excludes, so it stays on the machine that ran the pipeline.
Rerunning `01_spatial_pipeline.R` with the key in place reproduces the same codes.

### Data not distributed here

The 112 source rasters (390 MB), the reservoir outlines, the basin and state
layers and the cadastral shapefiles are not included. The rasters are
reproducible from the Earth Engine scripts in `docs/`. The cadastral layer is
public through SICAR but carries identifiable registry codes. See the README in
each subfolder of `data/`.

---

## Methodological choices worth knowing

**Bands are rings, not discs.** A 500 m buffer contains the 100 m buffer, so
comparing the two would compare one area with another that contains it. The
water surface is removed from every band, because the APP is the strip of land
around the reservoir. Masks are built once per reservoir and reused across the
eight benchmarks, so band definitions are identical over time.

**Four outlines stop at the state line.** At Anta, Funil, Ilha dos Pombos and
Rosal the outline covers only the water surface inside Rio de Janeiro, and the
bands, which were not clipped at the state line, are measured from that cut on
the far bank. `results/cross_boundary_share.csv` gives the share of each band
outside the state, and Table 6 reports the result without these reservoirs.

**Three reservoirs were impounded during the series.** Rosal (2000), Paracambi
(2012) and Anta (2013) did not have a reservoir margin at the earlier
benchmarks. `RES_WATERLINE_CHANGED` in `00_config.R` defines the scenario that
excludes them (Table S7), and `results/water_share_0_30m.csv` (Table S8) shows
the change in the water share of the innermost band.

**CLUMPY is computed here, not requested from the package.** `landscapemetrics`
counts cells outside the analysis mask in the adjacency denominator, which treats
the frame of the window as class edge. At 30 m the APP band is 3.3 cells wide, so
nearly every forest cell touches that frame. Under the default, Fontes Nova
returns −1.04, outside the range of the index, for a band that is 88.4% forest.
`clumpy_no_frame()` computes the index from its definition with the frame
excluded. Table S2 reports the difference between the two forms, and
`results/clumpy_default_trend.csv` the trend under the default. The seven other
metrics come from the package as it computes them.

**The row order is fixed, not sorted.** `order()` depends on the collation of
the machine: under a Portuguese locale Santana precedes Santa Rosa, under the C
locale it follows it. The bootstrap resamples positions, so interval bounds move
with the order. `RESERVOIR_ORDER` in `00_config.R` fixes the order under which
the published values were computed.

**The datum shift is pinned.** The reservoir outlines are in Albers on SAD69 and
the rasters in SIRGAS 2000. `CRS_VECTOR` fixes the three-parameter shift
published by IBGE, so the bands do not depend on whether PROJ can reach its grid
files.

**Medians and restricted permutation.** All paired tests are Wilcoxon
signed-rank with bootstrap confidence intervals from 10,000 resamples. In the
redundancy analysis, permutation is restricted to rows of the same reservoir,
because the 336 rows are fourteen units observed in three bands and eight years.

## Reproducibility notes

The seed is fixed at 7 and is set inside `boot_ci()` and inside each permutation
test, so each interval and each p value depends only on the data it describes.
The median of fourteen values is a discrete quantile, so an interval bound moves
by a few tenths of a percentage point if the number of resamples changes.
Permutation p values carry Monte Carlo error of about 0.003 near p = 0.05 at
4,999 permutations.

The published values were computed under R [version ...] with vegan [version
...]. On 19 October 2026, scripts 02, 03 and 04 were rerun under R 4.3.3 on
Ubuntu 24.04 (ggplot2 3.4.4, patchwork 1.2.0, ragg 1.2.7, vegan 2.6-4,
permute 0.9-7, sf 1.0-15, terra 1.7-65). Every file in `results/` and every
figure was reproduced without change, with one exception: the permutation p
value of the band × period term of the redundancy analysis, which is 1.0000 in
`table_S4_rda.csv` and 0.8198 under vegan 2.6-4. Its adjusted R² (−0.0004) and
the conclusion do not change.

`docs/AUDITORIA_2026-08-29.md` lists every value that changed in the audit of
29 August 2026, what it was, and which file it now comes from.

## Use of generative artificial intelligence

Claude (Anthropic) was used to assist in writing and debugging the R and Python
scripts, in checking the agreement between the manuscript and the outputs of
those scripts, and in revising the language of the manuscript. All analyses
were executed with the scripts in this repository, and every reported value was
taken from their outputs; the tool was not used to generate data. The authors
reviewed all code and text and take full responsibility for them.

---

## Citation

See `CITATION.cff`. Please cite the article rather than this repository alone.

## Licence

Code is released under the MIT Licence. Derived data in `data/` and `results/`
are released under CC BY 4.0. MapBiomas Collection 10 is distributed by the
MapBiomas project under its own terms.
