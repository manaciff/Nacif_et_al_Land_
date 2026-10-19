# Cleanup log

**19 August 2026.** Consolidation of the analysis into a single folder.

## What was removed and why

### `Analises_/` (RStudio project, superseded)

The folder held a working copy of the data, figures and results produced while
the analysis was in Portuguese. Every file was verified against the repository
before removal:

| Content | Verification |
|---|---|
| `dados/` (5 CSV) | Adopted as the official series; translated into `data/`. Values identical after translation. |
| `figuras/` (10 TIFF) | Byte-for-byte identical to `figures/`. |
| `resultados/` (7 CSV) | Numerically identical to `results/`. |
| `.RData`, `.Rhistory`, `.Rproj.user/` | Session artefacts, no analytical content. |

Eight rows were dropped in translation: Santa Branca, band 0 to 100 m, with
`metric` and `value` both empty. Santa Branca retains no forest cell inside its
legal APP at any benchmark, so no patch exists to measure and the configuration
metrics are undefined rather than zero. Empty placeholder rows carry no
information and would be read as missing data by any consumer of the file.

### `_arquivo_versao_portugues/` (previous scripts)

Five R scripts in Portuguese, superseded by the English versions in `R/`. The
translation renamed objects and messages; it altered no calculation. Removed
after the English versions were verified to reproduce the same output.

## A discrepancy worth recording

The series in `data/` now comes from the R pipeline (`R/01_spatial_pipeline.R`).
It differs from the earlier Python series in 308 of 2,240 rows, by one to sixteen
cells per zone, concentrated in the 100 to 500 m band. The cause is a boundary
convention: `terra::rasterize` and `rasterio.features.geometry_mask` disagree on
which cells at the edge of a buffer polygon fall inside it.

Every median reported in the manuscript is identical under the two pipelines
once rounded, with one exception: the post-reform rate in the 30 to 100 m band
is 2.82 pp per decade under R and 2.81 under Python. The bootstrap intervals,
two of the counts and one p value are not identical, which the audit of
29 August traced and resolved in favour of R. See `AUDITORIA_2026-08-29.md`.

The R series was adopted as official so that the repository is self-consistent:
anyone who clones it and runs `R/02_tests.R` obtains the values printed in the
manuscript.
