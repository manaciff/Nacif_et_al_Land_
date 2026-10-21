# =============================================================================
# Landscape dynamics and conservation policy effectiveness in reservoir
# riparian buffers: fourteen reservoirs under Brazil's Forest Code, 1985-2024
# -----------------------------------------------------------------------------
# SCRIPT 5. RESERVOIR CHARACTERISTICS (Table 2 of the manuscript)
#
# Builds data/reservoir_characteristics.csv from two public layers:
#   - the reservoir outlines, which carry the attributes of the ANA reservoir
#     layer (name, main use, operator, municipalities, states and the
#     impoundment date recorded in field dtreserv, source ANEEL);
#   - the hydrographic basin layer of the State of Rio de Janeiro at 1:50,000
#     (INEA), joined at a point guaranteed to lie on each water surface.
#
# A second section writes results/cross_boundary_share.csv, the share of each
# band that lies outside Rio de Janeiro, measured against the IBGE state
# boundary (2024) on the same 30 m grid and with the same masks as script 01,
# results/neighbour_overlap.csv, the part of each control band that falls in
# the APP band or the water of a neighbouring reservoir, and
# results/watercourse_app_control.csv, the part of each control band within
# 30 m of a mapped watercourse.
#
# Like script 01, it is optional: the CSV files it writes are already in the
# repository, and the layers are not distributed with it. It exists so that the
# table and the boundary shares can be audited end to end.
#
# Requirements: sf; terra for the second section.
# =============================================================================

if (!exists("PROJECT_ROOT")) {
  this_file <- tryCatch(normalizePath(sys.frame(1)$ofile), error = function(e) NA)
  if (is.na(this_file)) {
    args <- commandArgs(trailingOnly = FALSE)
    f <- sub("^--file=", "", args[grep("^--file=", args)])
    this_file <- if (length(f)) normalizePath(f[1]) else NA
  }
  PROJECT_ROOT <- if (!is.na(this_file)) dirname(dirname(this_file)) else getwd()
}
source(file.path(PROJECT_ROOT, "R", "00_config.R"))
suppressPackageStartupMessages(library(sf))

# Same pinned datum shift as script 01: South America Albers on SAD69, moved to
# SIRGAS 2000 with the three-parameter shift published by IBGE.
CRS_VECTOR <- paste("+proj=aea +lat_0=-32 +lon_0=-60 +lat_1=-5 +lat_2=-42",
                    "+x_0=0 +y_0=0 +ellps=aust_SA",
                    "+towgs84=-67.35,3.88,-38.22 +units=m +no_defs")

# The basin layer is looked for beside the reservoir outlines first, then in the
# folder of auxiliary layers of the research repository (find_upwards() is in
# 00_config.R).
if (!exists("FILE_BASINS") || is.na(FILE_BASINS))
FILE_BASINS <- first_existing(
  if (!is.na(DIR_VECTOR)) file.path(DIR_VECTOR, "gpl_bacia_hidro_50.shp"),
  find_upwards(PROJECT_ROOT, file.path("08_Dados_GIS_Auxiliares",
                                       "gpl_bacia_hidro_50",
                                       "gpl_bacia_hidro_50.shp")))
if (is.na(DIR_VECTOR) || is.na(FILE_BASINS))
  stop("Reservoir outlines or basin layer not found. Set DIR_VECTOR and ",
       "FILE_BASINS before running this script.")

basins <- st_read(FILE_BASINS, quiet = TRUE)
areas  <- read.csv(file.path(DIR_DATA, "reservoir_areas.csv"),
                   stringsAsFactors = FALSE)

field <- function(x, name) if (name %in% names(x)) as.character(x[[name]][1]) else NA_character_

rows <- lapply(RESERVOIR_ORDER, function(r) {
  outline <- st_read(file.path(DIR_VECTOR, paste0(r, ".shp")), quiet = TRUE)
  suppressWarnings(st_crs(outline) <- CRS_VECTOR)
  # A point on the surface, not the centroid, which can fall outside a
  # dendritic reservoir.
  pt <- st_point_on_surface(st_union(outline))
  pt <- st_transform(pt, st_crs(basins))
  hit <- st_intersects(pt, basins)[[1]]
  joined <- if (length(hit)) "within" else "nearest"
  if (!length(hit)) hit <- st_nearest_feature(pt, basins)
  ll <- st_coordinates(st_transform(pt, 4326))
  data.frame(
    Reservoir      = r,
    Name_ANA       = field(outline, "nmoriginal"),
    Basin_INEA     = basins$bacias_[hit[1]],
    Sub_basin_INEA = basins$sub_bacias[hit[1]],
    Basin_join     = joined,
    Municipalities = field(outline, "nmmun"),
    States         = field(outline, "nmufe"),
    Main_use_ANA   = field(outline, "usoprinc"),
    Operator_ANA   = field(outline, "nmemp"),
    Impoundment_ANA = field(outline, "dtreserv"),
    # Area of the whole water surface as recorded in the ANA layer. For the
    # four reservoirs on the state boundary the outline used here covers only
    # the part inside Rio de Janeiro, and Surface_ha (this study) is smaller.
    Surface_ANA_ha = round(as.numeric(field(outline, "nuareaha")), 1),
    Longitude      = round(ll[1, "X"], 4),
    Latitude       = round(ll[1, "Y"], 4),
    stringsAsFactors = FALSE)
})
chars <- do.call(rbind, rows)
chars <- merge(chars, areas, by = "Reservoir", sort = FALSE)
chars <- chars[match(RESERVOIR_ORDER, chars$Reservoir), ]

# Impoundment information not carried by the ANA layer. Each entry names its
# source, and nothing is filled in without one.
chars$Impoundment_note <- ""
chars$Impoundment_note[chars$Reservoir == "Anta"] <-
  "Under construction, year 2013 (INEA/COPPETEC 2014, RT-05, Table 3.2.1.2)"
chars$Impoundment_note[chars$Reservoir == "Paracambi"] <-
  "In operation in 2012 (INEA/COPPETEC 2014, RT-05, Table 3.2.1.2)"
chars$Impoundment_note[chars$Reservoir == "Funil"] <-
  "Operating licence issued by IBAMA in June 2012 (INEA/COPPETEC 2014, RT-05, Section 3.3.3)"
chars$Impoundment_note[chars$Reservoir == "Juturnaiba"] <-
  paste("No date in the ANA layer; built by DNOS between 1978 and 1982 (Prolagos 2024,",
        "Plano de Seguranca da Barragem de Juturnaiba, Vol. IV PAE, Section 3.3);",
        "water share of the 0-30 m band rises from 1985 to 2008")

write.csv(chars, file.path(DIR_DATA, "reservoir_characteristics.csv"),
          row.names = FALSE, fileEncoding = "UTF-8")
print(chars[, c("Reservoir", "Basin_INEA", "Sub_basin_INEA", "Basin_join",
                "Main_use_ANA", "Impoundment_ANA")], row.names = FALSE)

# =============================================================================
# BANDS ACROSS THE STATE BOUNDARY
# =============================================================================
# Four reservoirs lie on the state boundary, and their outlines cover only the
# part of the water surface inside Rio de Janeiro. The bands were not clipped at
# the state line, so part of each band lies in Minas Gerais, Sao Paulo or
# Espirito Santo. The masks are rebuilt here exactly as in band_masks() of
# script 01: same pinned datum shift, same projection, and a 30 m grid whose
# origin is a multiple of the cell size, which is the grid of the exported
# rasters. The band areas obtained this way equal Band_area_ha in
# data/composition_series.csv, which is the check that the masks are the same.

if (!exists("FILE_STATE") || is.na(FILE_STATE))
FILE_STATE <- first_existing(
  if (!is.na(DIR_VECTOR)) file.path(DIR_VECTOR, "rj_uf2024.shp"),
  find_upwards(PROJECT_ROOT, file.path("08_Dados_GIS_Auxiliares", "RJ_UF",
                                       "rj_uf2024.shp")))

if (is.na(FILE_STATE) || !requireNamespace("terra", quietly = TRUE)) {
  message("State boundary or terra not available: cross_boundary_share.csv not rebuilt.")
} else {
  suppressPackageStartupMessages(library(terra))
  CRS_METRIC <- "EPSG:31983"   # SIRGAS 2000 / UTM 23S, the projection of the rasters
  state <- st_transform(st_make_valid(st_read(FILE_STATE, quiet = TRUE)), CRS_METRIC)
  composition <- read.csv(file.path(DIR_DATA, "composition_series.csv"),
                          stringsAsFactors = FALSE)
  share_rows <- lapply(RESERVOIR_ORDER, function(r) {
    outline <- st_read(file.path(DIR_VECTOR, paste0(r, ".shp")), quiet = TRUE)
    suppressWarnings(st_crs(outline) <- CRS_VECTOR)
    outline <- st_transform(st_union(outline), CRS_METRIC)
    bb <- st_bbox(st_buffer(outline, 600))
    grid <- rast(ext(floor(bb["xmin"] / 30) * 30, ceiling(bb["xmax"] / 30) * 30,
                     floor(bb["ymin"] / 30) * 30, ceiling(bb["ymax"] / 30) * 30),
                 resolution = 30, crs = CRS_METRIC)
    cells <- function(geom) {
      m <- rasterize(vect(st_sf(geometry = geom)), grid, field = 1, background = 0)
      values(!is.na(m) & m == 1)[, 1] %in% TRUE
    }
    water   <- cells(outline)
    m100    <- cells(st_buffer(outline, 100)) & !water
    control <- cells(st_buffer(outline, 500)) & !water & !m100
    inside  <- cells(st_geometry(state))
    # Check against the extracted series: the masks must be those of script 01.
    ref <- composition[composition$Reservoir == r & composition$Year == 2024, ]
    stopifnot(isTRUE(all.equal(sum(m100) * 0.09,
                               unique(ref$Band_area_ha[ref$Band == "0-100 m"]))),
              isTRUE(all.equal(sum(control) * 0.09,
                               unique(ref$Band_area_ha[ref$Band == "100-500 m"]))))
    data.frame(
      Reservoir = display(r),
      `Control band outside Rio de Janeiro (%)` =
        round(100 * sum(control & !inside) / sum(control), 1),
      `APP band outside Rio de Janeiro (%)` =
        round(100 * sum(m100 & !inside) / sum(m100), 1),
      check.names = FALSE)
  })
  cross <- do.call(rbind, share_rows)
  cross <- cross[order(-cross$`Control band outside Rio de Janeiro (%)`), ]
  write.csv(cross, file.path(DIR_RESULTS, "cross_boundary_share.csv"), row.names = FALSE)
  print(cross, row.names = FALSE)

  # Neighbouring reservoirs. Where two reservoirs lie less than a kilometre
  # apart, the control band of one can reach the APP band or the water of the
  # other, so part of a control band is itself protected land. Measured on the
  # grid of the reservoir whose control band is examined.
  outlines <- lapply(setNames(RESERVOIR_ORDER, RESERVOIR_ORDER), function(r) {
    o <- st_read(file.path(DIR_VECTOR, paste0(r, ".shp")), quiet = TRUE)
    suppressWarnings(st_crs(o) <- CRS_VECTOR)
    st_transform(st_union(o), CRS_METRIC)
  })
  pair_rows <- list()
  for (a in RESERVOIR_ORDER) for (b in RESERVOIR_ORDER) {
    if (a == b || as.numeric(st_distance(outlines[[a]], outlines[[b]])) > 1100) next
    bb <- st_bbox(st_buffer(outlines[[a]], 600))
    grid <- rast(ext(floor(bb["xmin"] / 30) * 30, ceiling(bb["xmax"] / 30) * 30,
                     floor(bb["ymin"] / 30) * 30, ceiling(bb["ymax"] / 30) * 30),
                 resolution = 30, crs = CRS_METRIC)
    cells <- function(geom) {
      m <- rasterize(vect(st_sf(geometry = geom)), grid, field = 1, background = 0)
      values(!is.na(m) & m == 1)[, 1] %in% TRUE
    }
    water_a <- cells(outlines[[a]])
    control <- cells(st_buffer(outlines[[a]], 500)) & !water_a &
               !cells(st_buffer(outlines[[a]], 100))
    water_b <- cells(outlines[[b]])
    app_b   <- cells(st_buffer(outlines[[b]], 100)) & !water_b
    if (!any(control & (app_b | water_b))) next
    pair_rows[[length(pair_rows) + 1]] <- data.frame(
      `Control band of` = display(a), `Neighbour` = display(b),
      `Distance (m)` = round(as.numeric(st_distance(outlines[[a]], outlines[[b]]))),
      `In the APP band of the neighbour (ha)` = round(sum(control & app_b) * 0.09, 1),
      `In the water of the neighbour (ha)` = round(sum(control & water_b) * 0.09, 1),
      `In the APP band of the neighbour (% of the control band)` =
        round(100 * sum(control & app_b) / sum(control), 1),
      check.names = FALSE)
  }
  neighbours <- do.call(rbind, pair_rows)
  write.csv(neighbours, file.path(DIR_RESULTS, "neighbour_overlap.csv"), row.names = FALSE)
  print(neighbours, row.names = FALSE)

  # Watercourse APPs inside the control band. The control band lies outside the
  # APP of the reservoir but is crossed by the watercourses that drain into it,
  # whose margins are APPs of at least 30 m (Law 12,651/2012, Art. 4, I). The
  # share of the control band within 30 m of a mapped watercourse measures how
  # much of the control band is itself protected land. The drainage comes from
  # the ANA Base Hidrografica Ottocodificada of the Paraiba do Sul (2017
  # release), which covers the reservoirs of that basin; where the control band
  # holds no mapped watercourse (stream density below 0.5 km per km2), the
  # reservoir lies outside the release and is reported as NA. The 30 m width is
  # the minimum of the Code, so the share is a lower bound for wider channels.
  if (!exists("FILE_BHO") || is.na(FILE_BHO))
  FILE_BHO <- first_existing(
    if (!is.na(DIR_VECTOR)) file.path(DIR_VECTOR, "bho_trechos_reservatorios.shp"),
    file.path(DIR_DATA, "vectors", "bho_trechos_reservatorios.shp"),
    find_upwards(PROJECT_ROOT, file.path("08_Dados_GIS_Auxiliares",
                                         "GEOFT_BHO_TRECHO_DRENAGEM",
                                         "GEOFT_BHO_TRECHO_DRENAGEM.shp")))
  if (is.na(FILE_BHO)) {
    message("Drainage layer not found: watercourse_app_control.csv not rebuilt.")
  } else {
    wc_rows <- lapply(RESERVOIR_ORDER, function(r) {
      o <- outlines[[r]]
      win <- st_as_text(st_as_sfc(st_bbox(st_transform(st_buffer(o, 600), "EPSG:4674"))))
      streams <- st_read(FILE_BHO, wkt_filter = win, quiet = TRUE)
      streams <- st_transform(st_geometry(streams), CRS_METRIC)
      bb <- st_bbox(st_buffer(o, 600))
      grid <- rast(ext(floor(bb["xmin"] / 30) * 30, ceiling(bb["xmax"] / 30) * 30,
                       floor(bb["ymin"] / 30) * 30, ceiling(bb["ymax"] / 30) * 30),
                   resolution = 30, crs = CRS_METRIC)
      cells <- function(geom) {
        m <- rasterize(vect(st_sf(geometry = geom)), grid, field = 1, background = 0)
        values(!is.na(m) & m == 1)[, 1] %in% TRUE
      }
      water   <- cells(o)
      control <- cells(st_buffer(o, 500)) & !water & !cells(st_buffer(o, 100))
      ring <- st_difference(st_buffer(o, 500), st_buffer(o, 100))
      inside <- if (length(streams)) suppressWarnings(st_intersection(streams, ring)) else streams
      km <- if (length(inside)) sum(as.numeric(st_length(inside))) / 1000 else 0
      density <- km / (as.numeric(st_area(ring)) / 1e6)
      share <- NA_real_
      if (density >= 0.5) {
        app <- cells(st_union(st_buffer(inside, 30)))
        share <- round(100 * sum(control & app) / sum(control), 1)
      }
      data.frame(Reservoir = display(r),
                 `Mapped watercourses in the control band (km)` = round(km, 1),
                 `Stream density (km per km2)` = round(density, 2),
                 `Control band within 30 m of a watercourse (%)` = share,
                 check.names = FALSE)
    })
    wc <- do.call(rbind, wc_rows)
    write.csv(wc, file.path(DIR_RESULTS, "watercourse_app_control.csv"), row.names = FALSE)
    print(wc, row.names = FALSE)
  }
}
