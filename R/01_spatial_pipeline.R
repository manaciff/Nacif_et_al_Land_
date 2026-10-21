# =============================================================================
# Landscape dynamics and conservation policy effectiveness in reservoir
# riparian buffers: fourteen reservoirs under Brazil's Forest Code, 1985-2024
# -----------------------------------------------------------------------------
# SCRIPT 1. COMPLETE SPATIAL PIPELINE
#
# Reproduces, from the source rasters and vector outlines:
#
#   A. delineation of the distance bands as mutually exclusive rings
#   B. land cover composition by class, band, reservoir and year
#   C. configuration metrics for the forest class
#   D. cadastral module: native vegetation in the APP band (0-100 m) and the
#      2008 to 2024 transition
#   E. declared APP: what the landholder registered, inside and outside the
#      APP band
#
# It writes the same CSV files that feed 02_tests.R and 03_figures.R. Running
# this script is optional: those CSV files are already in data/. It exists so
# that the extraction is auditable end to end.
#
# INPUT. Located by 00_config.R. Nothing needs to be copied into this folder.
#   rasters/     <Reservoir>_ext_<year>.tif   112 files, already reclassified to
#                the five analytical classes and on a common grid
#   vectors/     <Reservoir>.shp              water surface of each reservoir
#   cadastral/   car_active_pending.shp       registered holdings, active or
#                pending status
#
# OUTPUT (data/)
#   composition_series.csv, configuration_series.csv, cadastral_zones.csv,
#   cadastral_transitions.csv, reservoir_areas.csv, declared_app_zones.csv
#
# PACKAGES
#   terra             raster input and map algebra
#   sf                vector geometry and spatial predicates
#   landscapemetrics  configuration metrics
#   install.packages(c("terra", "sf", "landscapemetrics"))
#
# RUN TIME. Ten to twenty minutes in total, dominated by the configuration
# metrics. The cadastral module uses a spatial filter on read rather than an
# attribute filter: the cadastral file carries a spatial index and responds in
# seconds, whereas an attribute scan over 67,000 features takes many minutes.
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

suppressPackageStartupMessages({ library(terra); library(sf) })
set.seed(SEED)

CRS_METRIC <- "EPSG:31983"   # SIRGAS 2000 / UTM 23S, the projection of the rasters

# The reservoir outlines are stored in the MapBiomas working projection, South
# America Albers on the SAD69 datum. Moving them to SIRGAS 2000 requires a datum
# shift, and PROJ chooses one at run time: the NTv2 grid br_ibge_SAD69_003 where
# the machine can reach cdn.proj.org, and a ballpark transformation where it
# cannot. The two differ by tens of metres, which changes which 30 m cells fall
# inside a 100 m buffer and therefore changes every metric downstream. The
# transformation is pinned here to the three-parameter shift published by IBGE,
# so the bands do not depend on the network state of the machine that runs this
# script. This is the transformation under which the series in data/ was built.
CRS_VECTOR <- paste("+proj=aea +lat_0=-32 +lon_0=-60 +lat_1=-5 +lat_2=-42",
                    "+x_0=0 +y_0=0 +ellps=aust_SA",
                    "+towgs84=-67.35,3.88,-38.22 +units=m +no_defs")
PIXEL_HA   <- 0.09           # a 30 by 30 m cell in hectares
THRESHOLD  <- 25             # ecological threshold, as a percentage of cover

message("\nSpatial inputs:")
check_inputs(required = TRUE)

# =============================================================================
# A. DISTANCE BANDS
# =============================================================================
# The bands are mutually exclusive rings. A GIS buffer is a disc: the 500 m
# buffer contains the 100 m buffer entirely, and comparing the two would compare
# one area with another that contains it. The water surface is removed from
# every band, because the APP is the strip of land around the reservoir and not
# the impounded water.
#
# All years of a reservoir share the same grid, so the masks are built once and
# reused across the eight benchmarks. Band definitions are therefore identical
# over time by construction, and no part of the observed change can come from a
# window that moved.

band_masks <- function(reservoir) {
  reference <- rast(file.path(DIR_RASTER,
                              sprintf("%s_ext_%d.tif", reservoir, BENCHMARKS[1])))
  outline <- st_read(file.path(DIR_VECTOR, paste0(reservoir, ".shp")),
                     quiet = TRUE)
  suppressWarnings(st_crs(outline) <- CRS_VECTOR)
  outline <- st_transform(st_union(outline), CRS_METRIC)

  rasterise <- function(distance) {
    geom <- if (distance == 0) outline else st_buffer(outline, distance)
    m <- rasterize(vect(st_sf(geometry = geom)), reference, field = 1,
                   background = 0)
    !is.na(m) & m == 1
  }
  water <- rasterise(0)
  m30   <- rasterise(30)  & !water
  m100  <- rasterise(100) & !water
  m500  <- rasterise(500) & !water

  list(`0-30 m`    = m30,
       `30-100 m`  = m100 & !m30,     # exclusive by construction
       `0-100 m`   = m100,
       `100-500 m` = m500 & !m100)    # exclusive by construction
}

# =============================================================================
# B. COMPOSITION
# =============================================================================

message("\n[B] Composition by class, band and year")
comp_rows <- list()
for (r in RESERVOIRS) {
  masks <- band_masks(r)
  for (year in BENCHMARKS) {
    ras <- rast(file.path(DIR_RASTER, sprintf("%s_ext_%d.tif", r, year)))
    for (b in names(masks)) {
      inside <- values(masks[[b]])[, 1]
      vals <- values(ras)[, 1][inside %in% TRUE]
      for (cl in CLASSES) {
        comp_rows[[length(comp_rows) + 1]] <- data.frame(
          Reservoir = r, Year = year, Band = b,
          Code = unname(CLASS_CODES[cl]), Class = cl,
          Area_ha = sum(vals == CLASS_CODES[cl], na.rm = TRUE) * PIXEL_HA)
      }
    }
  }
  message("  ", r)
}
composition <- do.call(rbind, comp_rows)

# Percentages over the whole band and over the land area, excluding water. The
# innermost band is largely water by construction, since it is a 30 m ring drawn
# around a waterline, so forest is always expressed over the land denominator.
key <- with(composition, paste(Reservoir, Year, Band))
composition$Band_area_ha <- ave(composition$Area_ha, key, FUN = sum)
composition$Land_area_ha <- ave(
  ifelse(composition$Class == "Water", 0, composition$Area_ha), key, FUN = sum)
composition$Pct_band <- 100 * composition$Area_ha / composition$Band_area_ha
composition$Pct_terrestrial <- ifelse(
  composition$Class == "Water", NA_real_,
  100 * composition$Area_ha / composition$Land_area_ha)
write.csv(composition, file.path(DIR_DATA, "composition_series.csv"),
          row.names = FALSE)
message("  -> composition_series.csv (", nrow(composition), " rows)")

# Water surface area of each reservoir.
reservoir_areas <- do.call(rbind, lapply(RESERVOIRS, function(r) {
  outline <- st_transform(
    st_union(st_read(file.path(DIR_VECTOR, paste0(r, ".shp")), quiet = TRUE)),
    CRS_METRIC)
  data.frame(Reservoir = r,
             Surface_ha = round(as.numeric(st_area(outline)) / 1e4, 2))
}))
write.csv(reservoir_areas, file.path(DIR_DATA, "reservoir_areas.csv"),
          row.names = FALSE)

# =============================================================================
# C. CONFIGURATION METRICS
# =============================================================================
# Computed only for the 0 to 100 m and 100 to 500 m bands. The 0 to 30 m and
# 30 to 100 m bands are excluded because at 30 m resolution they are 1.0 and 2.3
# cells wide, and no patch can be wider than the band that contains it, so any
# shape metric would describe the geometry of the analysis window rather than
# the arrangement of forest within it.
#
# Parameters: an eight-neighbour rule, because a four-neighbour rule would split
# diagonal corridors artificially; an edge depth of one cell, the smallest value
# representable at this resolution; and cells outside the focal class set to NA
# rather than zero, so that the package does not treat them as a second class.
#
# CLUMPY. landscapemetrics counts cells outside the analysis mask in the
# adjacency denominator, which in a narrow band makes the index measure the
# shape of the band rather than the arrangement of forest inside it. See
# Section 2.4 of the manuscript for the full argument.
#
# The argument count_boundary does not fix this. It belongs to the edge metrics,
# lsm_c_te and lsm_c_ed, and lsm_c_clumpy ignores it, so passing it through
# calculate_lsm leaves the index at its default. The correction is therefore
# implemented here, from the definition of the index, and it replaces the value
# the package returns. Verification: under the default, Fontes Nova returns
# -1.08 in the APP band in 2024, outside the range of an index defined on [-1, 1],
# for a band that is 88.4% forest; under the implementation below it returns
# 0.85, and no value in the series falls outside the range.
#
# Note on sample size: in the APP band the analysis covers thirteen
# reservoirs. Santa Branca retains no forest cell inside its APP band at any
# benchmark, so no patch exists to measure and the metrics are undefined rather
# than zero.

#' Clumpiness with the analysis frame excluded from the adjacency denominator.
#'
#' The index rests on the proportion of like adjacencies, gii / (gii + gik).
#' Cells outside the landscape, that is water, no data, and everything beyond
#' the band, are neither like nor unlike adjacencies: they are not adjacencies.
#' Counting them, as the default does, inflates gik wherever the landscape is
#' narrow, and a riparian band is narrow by definition.
#'
#' @param cls   matrix of class codes, NA outside the landscape
#' @param valid logical matrix, TRUE inside the landscape
#' @param focal code of the focal class
#' @param frame TRUE reinstates the frame in the denominator, which is the
#'   behaviour the correction removes. Kept so that the two can be compared.
clumpy_no_frame <- function(cls, valid, focal = 4L, frame = FALSE) {
  b <- valid & (cls == focal); b[is.na(b)] <- FALSE
  a_class <- sum(b); a_land <- sum(valid)
  if (a_class == 0 || a_land == 0) return(NA_real_)
  shift <- function(m, dr, dc) {
    n <- nrow(m); p <- ncol(m); out <- matrix(FALSE, n, p)
    rs <- max(1, 1 - dr):min(n, n - dr); cs <- max(1, 1 - dc):min(p, p - dc)
    out[rs, cs] <- m[rs + dr, cs + dc]; out
  }
  gii <- 0; gik <- 0
  for (d in list(c(1, 0), c(-1, 0), c(0, 1), c(0, -1))) {
    nb <- shift(b, d[1], d[2]); nv <- shift(valid, d[1], d[2])
    gii <- gii + sum(b & nb)
    gik <- gik + if (frame) sum(b & !nb) else sum(b & !nb & nv)
  }
  if (gii + gik == 0) return(NA_real_)
  gi <- gii / (gii + gik); pi_class <- a_class / a_land
  if (gi < pi_class && pi_class < 0.5) (gi - pi_class) / pi_class
  else (gi - pi_class) / (1 - pi_class)
}

if (requireNamespace("landscapemetrics", quietly = TRUE)) {
  message("\n[C] Configuration metrics")
  METRICS <- c("lsm_c_pland", "lsm_c_np", "lsm_c_pd", "lsm_c_ed",
               "lsm_c_area_mn", "lsm_c_enn_mn", "lsm_c_cohesion",
               "lsm_c_clumpy")
  cfg_rows <- list()
  for (r in RESERVOIRS) {
    masks <- band_masks(r)
    for (year in BENCHMARKS) {
      ras <- rast(file.path(DIR_RASTER, sprintf("%s_ext_%d.tif", r, year)))
      for (b in c(BAND_TREATED, BAND_CONTROL)) {
        layer <- ras
        # Land denominator: water and no-data are removed from the landscape.
        layer[!(masks[[b]] %in% TRUE) |
              !(values(ras)[, 1] %in% c(4, 5, 15, 22))] <- NA
        if (sum(!is.na(values(layer))) < 10) next
        m <- landscapemetrics::calculate_lsm(
          layer, what = METRICS, directions = 8, count_boundary = FALSE,
          edge_depth = 1, progress = FALSE)
        m <- m[m$class == 4, ]        # forest class
        if (!nrow(m)) next
        # Replace the package value of CLUMPY with the frame-excluded index.
        dims  <- c(nrow(ras), ncol(ras))
        vals  <- values(layer)[, 1]
        valid <- matrix(!is.na(vals), dims[1], dims[2], byrow = TRUE)
        cls   <- matrix(vals,         dims[1], dims[2], byrow = TRUE)
        m$value[m$metric == "clumpy"] <- clumpy_no_frame(cls, valid, frame = FALSE)
        # The same index with the frame counted is kept alongside it, so that
        # Table S2 can quantify what the boundary treatment does to the index
        # across the whole series rather than at a single reservoir.
        m <- rbind(m, transform(m[m$metric == "clumpy", ][1, ],
                                metric = "clumpy_frame_counted",
                                value  = clumpy_no_frame(cls, valid, frame = TRUE)))
        cfg_rows[[length(cfg_rows) + 1]] <- data.frame(
          Reservoir = r, Year = year, Band = b, Class = "Forest",
          metric = m$metric, value = m$value)
      }
    }
    message("  ", r)
  }
  configuration <- do.call(rbind, cfg_rows)
  write.csv(configuration, file.path(DIR_DATA, "configuration_series.csv"),
            row.names = FALSE)
  message("  -> configuration_series.csv (", nrow(configuration), " rows)")
} else {
  message("\n[C] landscapemetrics not installed; step skipped. ",
          "Run install.packages('landscapemetrics')")
}

# =============================================================================
# D. CADASTRAL MODULE
# =============================================================================
# Compliance of the APP band, by reservoir and by registered holding, and the
# transition of the APP between 2008 and 2024.
#
# Article 61-A anchors the consolidated rural area to the anthropic occupation
# observed on 22 July 2008. The cadastral date field cannot serve that purpose,
# because the registry postdates the cut-off and the earliest record in the
# state dataset is from 2014. The classification is therefore made from land
# cover evidence, by cross-tabulating 2008 against 2024.
#
# The registry covers rural landholdings and not water bodies, so the
# property-level assessment exists only where a registered holding intersects
# the reservoir buffer. Reservoir-level compliance is computed from land cover
# over the entire APP band and does not depend on the registry.

if (!is.na(FILE_CADASTRE)) {
  message("\n[D] Cadastral module")
  ANTHROPIC <- c(15, 22)
  NATIVE    <- c(4, 5)
  zones <- list()
  transitions <- list()

  for (r in RESERVOIRS) {
    r24 <- rast(file.path(DIR_RASTER, sprintf("%s_ext_2024.tif", r)))
    r08 <- rast(file.path(DIR_RASTER, sprintf("%s_ext_2008.tif", r)))
    masks <- band_masks(r)
    inside_app <- values(masks[[BAND_TREATED]])[, 1] %in% TRUE

    zone_composition <- function(selection) {
      v <- values(r24)[, 1][selection]
      areas_by_class <- sapply(CLASSES, function(cl)
        sum(v == CLASS_CODES[cl], na.rm = TRUE) * PIXEL_HA)
      total <- sum(areas_by_class)
      land <- total - areas_by_class[["Water"]]
      if (land <= 0) return(NULL)
      forest_pct <- 100 * areas_by_class[["Forest"]] / land
      data.frame(t(areas_by_class), Area_ha = total, Land_area_ha = land,
                 Water_pct = 100 * areas_by_class[["Water"]] / total,
                 Forest_pct = forest_pct,
                 Deficit_pct = 100 - forest_pct,
                 Meets_25pct_threshold = forest_pct >= THRESHOLD,
                 check.names = FALSE)
    }

    # 1. The reservoir as a whole.
    z <- zone_composition(inside_app)
    if (!is.null(z)) zones[[length(zones) + 1]] <-
      cbind(Zone_type = "APP_band_reservoir", Reservoir = r, Zone = r, z)

    # 2. Registered holdings. A spatial filter is applied on read, not an
    #    attribute clause, for the reason given in the header.
    outline <- st_transform(
      st_union(st_read(file.path(DIR_VECTOR, paste0(r, ".shp")), quiet = TRUE)),
      CRS_METRIC)
    box <- st_bbox(st_transform(st_buffer(outline, 120), 4674))
    holdings <- tryCatch(
      st_read(FILE_CADASTRE, quiet = TRUE,
              wkt_filter = st_as_text(st_as_sfc(box))),
      error = function(e) NULL)
    if (is.null(holdings) || !nrow(holdings)) {
      message("  ", r, ": no registered holdings"); next
    }

    holdings <- holdings[holdings$status %in% c("AT", "PE"), ]
    holdings <- st_transform(st_make_valid(holdings), CRS_METRIC)
    holdings <- holdings[
      st_intersects(holdings, st_buffer(outline, 100), sparse = FALSE)[, 1], ]
    if (!nrow(holdings)) {
      message("  ", r, ": no holdings intersecting the APP"); next
    }
    # One record per holding: nine holdings intersect more than one reservoir.
    holdings <- aggregate(
      holdings[, c("Fiscal_modules", "Declared_area_ha", "Municipality")],
      by = list(Property_code = holdings$Property_code),
      FUN = function(x) x[1], do_union = TRUE)

    ids <- rasterize(vect(holdings), r24, field = seq_len(nrow(holdings)),
                     background = 0)
    id_values <- values(ids)[, 1]

    for (i in seq_len(nrow(holdings))) {
      selection <- inside_app & (id_values %in% i)
      if (!sum(selection)) next
      z <- zone_composition(selection)
      if (!is.null(z)) zones[[length(zones) + 1]] <-
        cbind(Zone_type = "APP_band_property", Reservoir = r,
              Zone = holdings$Property_code[i], z)
      v08 <- values(r08)[, 1][selection]
      v24 <- values(r24)[, 1][selection]
      anthropic_08 <- v08 %in% ANTHROPIC
      native_08    <- v08 %in% NATIVE
      anthropic_24 <- v24 %in% ANTHROPIC
      native_24    <- v24 %in% NATIVE
      transitions[[length(transitions) + 1]] <- data.frame(
        Reservoir = r, Property_code = holdings$Property_code[i],
        APP_band_ha = sum(selection) * PIXEL_HA,
        Fiscal_modules = holdings$Fiscal_modules[i],
        Declared_area_ha = holdings$Declared_area_ha[i],
        Municipality = holdings$Municipality[i],
        Anthropic_2008_ha = sum(anthropic_08) * PIXEL_HA,
        Native_2008_ha = sum(native_08) * PIXEL_HA,
        Consolidated_in_use_ha = sum(anthropic_08 & anthropic_24) * PIXEL_HA,
        Consolidated_restored_ha = sum(anthropic_08 & native_24) * PIXEL_HA,
        Cleared_after_2008_ha = sum(native_08 & anthropic_24) * PIXEL_HA,
        Native_retained_ha = sum(native_08 & native_24) * PIXEL_HA)
    }
    message("  ", r, ": ", nrow(holdings), " holdings")
  }

  zones <- do.call(rbind, zones)
  transitions <- do.call(rbind, transitions)
  transitions$Fiscal_module_class <- ifelse(
    transitions$Fiscal_modules <= 4,
    "<= 4 fiscal modules (Art. 61-A)", "> 4 fiscal modules (general rule)")
  # Replace the CAR codes by sequential identifiers before anything is written
  # to data/; the key stays in data/cadastral/, outside the repository.
  pseudo <- pseudonymize_holdings(zones, transitions)
  zones <- pseudo$zones; transitions <- pseudo$transitions
  write.csv(zones, file.path(DIR_DATA, "cadastral_zones.csv"), row.names = FALSE)
  write.csv(transitions, file.path(DIR_DATA, "cadastral_transitions.csv"),
            row.names = FALSE)
  message("  -> cadastral_zones.csv (", nrow(zones), "), ",
          "cadastral_transitions.csv (", nrow(transitions), ")")
} else {
  message("\n[D] Cadastral layer not found; step skipped.")
}

message("\nSpatial pipeline complete. Continue with 02_tests.R")

# =============================================================================
# E. DECLARED APP AROUND THE RESERVOIR
# =============================================================================
# The cadastral module above measures the APP band (0 to 100 m). This
# section measures what the landholder declared, which is a different object and
# the one the assessing agency actually receives. Two quantities follow: how much
# of the declared APP falls inside the APP band, and how much of it falls
# outside, along the drainage network of the same holding.
#
# The layer carries no spatial index, so GDAL resolves wkt_filter with a
# sequential scan of its 412,037 features. The scan takes about a minute per
# reservoir on a local disk, which is why the read is done once per reservoir
# rather than once per zone.
if (!is.null(FILE_CADASTRE_APP) && file.exists(FILE_CADASTRE_APP)) {
  message("\n[E] Declared APP")
  decl_rows <- list()
  for (r in RESERVOIR_ORDER) {
    ref     <- rast(file.path(DIR_RASTER, sprintf("%s_ext_%d.tif", r, BENCHMARKS[1])))
    masks   <- band_masks(r)
    outline <- st_read(file.path(DIR_VECTOR, paste0(r, ".shp")), quiet = TRUE)
    suppressWarnings(st_crs(outline) <- CRS_VECTOR)
    outline <- st_transform(st_union(outline), CRS_METRIC)
    water   <- values(rasterize(vect(st_sf(geometry = outline)), ref,
                                field = 1, background = 0))[, 1] %in% 1
    m100    <- values(masks[[BAND_TREATED]])[, 1] %in% TRUE
    m500    <- values(masks[[BAND_CONTROL]])[, 1] %in% TRUE | m100
    cellha  <- prod(res(ref)) / 10000
    v2024   <- values(rast(file.path(DIR_RASTER, sprintf("%s_ext_2024.tif", r))))[, 1]

    win <- st_as_text(st_as_sfc(st_bbox(st_transform(st_buffer(outline, 500),
                                                     "EPSG:4674"))))
    g <- st_read(FILE_CADASTRE_APP, wkt_filter = win, quiet = TRUE)
    g <- g[g$ind_status %in% c("AT", "PE"), ]
    if (!nrow(g)) {
      decl_rows[[r]] <- data.frame(Reservoir = display(r),
        `Declared APP polygons` = 0L, `Registered holdings` = 0L,
        `Declared APP in the 500 m buffer (ha)` = 0, `Inside the APP band (ha)` = 0,
        `Outside the APP band (ha)` = 0, `APP band covered by a declaration (%)` = 0,
        `Declared APP over the water surface (ha)` = 0,
        `Reservoir-margin APP polygons` = 0L,
        `Reservoir-margin APP in the buffer (ha)` = 0,
        `Forest inside the declared APP (%)` = NA_real_, check.names = FALSE)
      next
    }
    geom <- st_make_valid(st_transform(st_geometry(g), CRS_METRIC))
    geom <- geom[!st_is_empty(geom)]
    # Rasterised as a set rather than dissolved: union over several thousand
    # self-declared polygons requires valid topology that the registry does not
    # guarantee, and overlap disappears in a binary mask anyway.
    burn <- function(x) values(rasterize(vect(st_sf(geometry = x)), ref,
                                         field = 1, background = 0))[, 1] %in% 1
    decl <- burn(geom)
    study <- decl & m500; inside <- decl & m100; outside <- study & !m100
    margin <- g[grepl("Reservatorio artificial", g$nom_tema), ]
    margin_ha <- 0
    if (nrow(margin)) {
      gm <- st_make_valid(st_transform(st_geometry(margin), CRS_METRIC))
      gm <- gm[!st_is_empty(gm)]
      if (length(gm)) margin_ha <- sum(burn(gm) & m500) * cellha
    }
    forest <- function(mask) {
      k <- mask & (v2024 %in% c(4, 5, 15, 22))
      if (!sum(k)) return(NA_real_)
      100 * sum(k & v2024 == 4) / sum(k)
    }
    decl_rows[[r]] <- data.frame(
      Reservoir = display(r),
      `Declared APP polygons` = nrow(g),
      `Registered holdings` = length(unique(g$cod_imovel)),
      `Declared APP in the 500 m buffer (ha)` = round(sum(study) * cellha, 1),
      `Inside the APP band (ha)` = round(sum(inside) * cellha, 1),
      `Outside the APP band (ha)` = round(sum(outside) * cellha, 1),
      `APP band covered by a declaration (%)` =
        round(100 * sum(inside) / sum(m100), 1),
      `Declared APP over the water surface (ha)` =
        round(sum(decl & water) * cellha, 1),
      `Reservoir-margin APP polygons` = nrow(margin),
      `Reservoir-margin APP in the buffer (ha)` = round(margin_ha, 1),
      `Forest inside the declared APP (%)` = round(forest(inside), 1),
      check.names = FALSE)
    message("  ", r)
  }
  declared <- do.call(rbind, decl_rows)
  declared <- declared[order(-declared$`Declared APP in the 500 m buffer (ha)`), ]
  write.csv(declared, file.path(DIR_DATA, "declared_app_zones.csv"),
            row.names = FALSE)
  message("  -> declared_app_zones.csv (", nrow(declared), " rows)")
}
