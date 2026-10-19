# Figures

`R/03_figures.R` writes Figures 2 to 8 and S1 to S3 as TIFF at 600 dpi with LZW
compression, at the journal column widths of 90, 140 and 190 mm. The TIFF files
are excluded from version control by `.gitignore` because of their size.

The PNG files are 300 dpi copies of the same figures, kept under version control
so that they can be viewed online. `Figure_1_study_area.png` is the location map,
prepared in a GIS and taken from the manuscript at 220 dpi; it is not produced by
the R scripts.

Run `source("R/03_figures.R")` to regenerate the ten TIFF files.
