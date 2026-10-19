# Reading the declared APP layer

`R/01_spatial_pipeline.R`, section E, reads the state APP layer with
`sf::st_read(..., wkt_filter = )`. The layer holds 412,037 features and carries
no spatial index, so GDAL resolves the filter with a sequential scan. On a local
disk the scan runs at about 60 MB per second, which puts a full pass over the
1.3 GB geometry file at roughly twenty seconds and the whole section at a few
minutes for the fourteen reservoirs.

Two details of the layer matter for anyone repeating this.

The polygons are in geographic coordinates on SIRGAS 2000 (EPSG:4674), while the
rasters are in SIRGAS 2000 / UTM 23S. The transformation between the two is a
projection change on the same datum and needs no grid, unlike the reservoir
outlines, which are stored on SAD69 and whose datum shift is pinned in
`CRS_VECTOR`.

Topology is not guaranteed. `st_union` over the several thousand polygons of a
single reservoir fails on holes that no shell contains, which is why section E
rasterises the set instead of dissolving it. Overlap between declared polygons
disappears in a binary mask, so the area accounting is unaffected.

The status filter is the same one the property module uses, that is active or
pending, applied to `ind_status`. Suspended and cancelled registrations are
excluded.
