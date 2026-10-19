# Vector layers (not distributed)

`R/01_spatial_pipeline.R` and `R/05_reservoir_characteristics.R` read the
following layers, none of which is redistributed here.

- Reservoir outlines, one shapefile per reservoir named `<Reservoir>.shp`, in
  South America Albers on SAD69. They are polygons of the ANA layer *Massas
  d'Água* (version 2019) and carry its attributes, including `nmoriginal`,
  `usoprinc`, `nmemp`, `dtreserv` and `nuareaha`. At Anta, Funil, Ilha dos
  Pombos and Rosal the outline covers only the water surface inside Rio de
  Janeiro.
- `gpl_bacia_hidro_50.shp`, the hydrographic basin layer of Rio de Janeiro at
  1:50,000 (INEA, GeoINEA), used by script 05.
- `rj_uf2024.shp`, the boundary of the State of Rio de Janeiro (IBGE, 2024),
  used by script 05 to measure the share of each band outside the state.

Place them here, or point `DIR_VECTOR`, `FILE_BASINS` and `FILE_STATE` at their
locations, only if you intend to run scripts 01 or 05. The extracted series in
`data/` are sufficient to reproduce every result in the manuscript without them.
