# Cadastral layers (not distributed)

`car_active_pending.shp` holds the rural landholdings registered in the Rural
Environmental Registry (CAR) for Rio de Janeiro State, filtered to active or
pending status; suspended and cancelled registrations are excluded. The file is
not redistributed here: it is public through the national registry (SICAR), is
governed by its terms, and carries identifiable registry codes.

Obtain it from SICAR, filter `status` to `AT` or `PE`, and place it here, or
point `FILE_CADASTRE` at its location.

The derived tables in `data/cadastral_zones.csv` and
`data/cadastral_transitions.csv` identify holdings by sequential codes (`H001`
to `H195`). `R/01_spatial_pipeline.R` writes the correspondence between those
codes and the registry codes to `holding_key.csv` in this folder. The folder is
excluded from version control, so the key stays on the machine that ran the
pipeline.
