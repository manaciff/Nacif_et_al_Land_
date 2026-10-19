# Rasters (not distributed)

The 112 clipped rasters, named `<Reservoir>_ext_<year>.tif`, are not included in
this repository because of their size (390 MB).

They are reproducible from the Earth Engine scripts in `docs/`, which export
MapBiomas Collection 10 reclassified to the five analytical classes, on a common
grid with the origin fixed at a multiple of the 30 m cell size.

Place them here, or point `DIR_RASTER` at their location, only if you intend to
run `R/01_spatial_pipeline.R`. The extracted series in `data/` are sufficient to
reproduce every result in the manuscript without them.
