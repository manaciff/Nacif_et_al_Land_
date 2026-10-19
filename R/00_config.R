# =============================================================================
# Landscape dynamics and conservation policy effectiveness in reservoir
# riparian buffers: fourteen reservoirs under Brazil's Forest Code, 1985-2024
# -----------------------------------------------------------------------------
# SCRIPT 0. SHARED CONFIGURATION
#
# Loaded by every other script. Defines paths, constants, the colour palette,
# the plotting theme and the statistical helper functions. Produces no output.
#
# PATHS
# -----------------------------------------------------------------------------
# Two roots are distinguished, and confusing them is the origin of most path
# errors in projects of this kind:
#
#   PROJECT_ROOT  the analysis folder, which holds data/, results/ and
#                 figures/. This is where the RStudio project opens.
#   REPO_ROOT     the root of the research repository, which holds the rasters,
#                 the reservoir outlines and the cadastral layer. These are
#                 shared with the GIS desktop project and with the Python code.
#
# Both are discovered automatically. Nothing needs editing, and neither depends
# on the working directory, which is precisely what changes between sessions
# and breaks hard-coded paths.
# =============================================================================

# ------------------------------------------------------------ helper functions

#' Path of the file currently being executed, whether it was called with
#' source(), with Rscript, or with the RStudio Source button. Returns NA when
#' the path cannot be determined.
current_file <- function() {
  for (i in seq_len(sys.nframe())) {
    f <- sys.frame(i)$ofile
    if (!is.null(f)) return(tryCatch(normalizePath(f), error = function(e) NA))
  }
  args <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", args[grep("^--file=", args)])
  if (length(f)) return(tryCatch(normalizePath(f[1]), error = function(e) NA))
  if (requireNamespace("rstudioapi", quietly = TRUE) &&
      rstudioapi::isAvailable()) {
    f <- tryCatch(rstudioapi::getSourceEditorContext()$path,
                  error = function(e) "")
    if (nzchar(f)) return(normalizePath(f))
  }
  NA_character_
}

#' Walk up the directory tree until a folder containing one of the markers is
#' found. Returns NA if none is found within ten levels.
walk_up_to <- function(start, markers) {
  d <- normalizePath(start, mustWork = FALSE)
  for (i in 1:10) {
    if (any(file.exists(file.path(d, markers)))) return(d)
    parent <- dirname(d)
    if (identical(parent, d)) break
    d <- parent
  }
  NA_character_
}

#' First existing path among a list of candidates.
first_existing <- function(...) {
  candidates <- unlist(list(...))
  found <- candidates[file.exists(candidates)]
  if (length(found)) normalizePath(found[1], mustWork = FALSE) else NA_character_
}

# ----------------------------------------------------------- analysis root (R)
# Order of precedence: an already defined variable, then here(), then the
# folder of the script itself, then the first folder above the working
# directory that contains data/.
if (!exists("PROJECT_ROOT")) {
  PROJECT_ROOT <- NA_character_

  if (requireNamespace("here", quietly = TRUE)) {
    PROJECT_ROOT <- tryCatch(here::here(), error = function(e) NA_character_)
    if (!is.na(PROJECT_ROOT) && !dir.exists(file.path(PROJECT_ROOT, "data")))
      PROJECT_ROOT <- NA_character_        # here() located a different root
  }
  if (is.na(PROJECT_ROOT)) {
    this_file <- current_file()
    if (!is.na(this_file))
      PROJECT_ROOT <- walk_up_to(dirname(this_file), "data")
  }
  if (is.na(PROJECT_ROOT)) PROJECT_ROOT <- walk_up_to(getwd(), "data")
  if (is.na(PROJECT_ROOT)) PROJECT_ROOT <- getwd()
}

DIR_DATA    <- file.path(PROJECT_ROOT, "data")
DIR_RESULTS <- file.path(PROJECT_ROOT, "results")
DIR_FIGURES <- file.path(PROJECT_ROOT, "figures")
for (d in c(DIR_RESULTS, DIR_FIGURES))
  dir.create(d, showWarnings = FALSE, recursive = TRUE)

if (!dir.exists(DIR_DATA)) {
  stop("Folder 'data' not found from: ", PROJECT_ROOT,
       "\n\nSet the root manually before running, using forward slashes:",
       "\n  PROJECT_ROOT <- 'C:/path/to/repository'",
       "\n  source(file.path(PROJECT_ROOT, 'R', '02_tests.R'))")
}

# ------------------------------------------------------------ repository root
# Marked by the file .project_root. If that file is removed, the fallback is
# the presence of any of the spatial data folders.
REPO_MARKERS <- c(".project_root", "rasters", "vectors", "cadastral")
if (!exists("REPO_ROOT")) {
  REPO_ROOT <- walk_up_to(PROJECT_ROOT, REPO_MARKERS)
  if (is.na(REPO_ROOT)) REPO_ROOT <- walk_up_to(getwd(), REPO_MARKERS)
  if (is.na(REPO_ROOT)) REPO_ROOT <- PROJECT_ROOT
}

message("Analysis root:   ", PROJECT_ROOT)
message("Repository root: ", REPO_ROOT)

# ------------------------------------------------------- spatial input layers
# Resolved from a list of candidate locations rather than from a single fixed
# path, so the code runs whether the data sit in the repository, inside data/,
# or in a local copy, without anyone editing the script.
# A path set by the user before sourcing this file takes precedence.
if (!exists("DIR_RASTER") || is.na(DIR_RASTER))
DIR_RASTER <- first_existing(
  file.path(REPO_ROOT, "rasters"),
  file.path(DIR_DATA, "rasters"),
  file.path(PROJECT_ROOT, "rasters"))

if (!exists("DIR_VECTOR") || is.na(DIR_VECTOR))
DIR_VECTOR <- first_existing(
  file.path(REPO_ROOT, "vectors"),
  file.path(DIR_DATA, "vectors"),
  file.path(PROJECT_ROOT, "vectors"))

FILE_CADASTRE_APP <- first_existing(
  file.path(REPO_ROOT, "08_Dados_GIS_Auxiliares", "APPS", "APPS_1.shp"),
  file.path(DIR_DATA, "cadastral", "app_declarada.shp"))

if (!exists("FILE_CADASTRE") || is.na(FILE_CADASTRE))
FILE_CADASTRE <- first_existing(
  file.path(REPO_ROOT, "cadastral", "car_active_pending.shp"),
  file.path(DIR_DATA, "cadastral", "car_active_pending.shp"))

#' Report which spatial inputs were located. Called by the spatial pipeline;
#' the inference and figure scripts do not need any of them.
check_inputs <- function(required = FALSE) {
  items <- list(rasters = DIR_RASTER, vectors = DIR_VECTOR,
                cadastre = FILE_CADASTRE)
  missing <- names(items)[vapply(items, is.na, logical(1))]
  for (n in names(items))
    message(sprintf("  %-9s %s", n,
                    if (is.na(items[[n]])) "not found" else items[[n]]))
  if (required && length(missing))
    stop("Not found: ", paste(missing, collapse = ", "),
         ".\nThis script is optional: the extracted series are already in ",
         DIR_DATA,
         ".\nTo repeat the extraction, set the paths manually before running:",
         "\n  DIR_RASTER    <- '.../rasters'",
         "\n  DIR_VECTOR    <- '.../vectors'",
         "\n  FILE_CADASTRE <- '.../cadastral/car_active_pending.shp'")
  invisible(missing)
}

# ---------------------------------------------------------------- constants
BENCHMARKS   <- c(1985, 1990, 1995, 2008, 2011, 2014, 2020, 2024)
YEAR_BASE    <- 2011      # reference year of the event study
YEAR_REFORM  <- 2012      # Law 12,651/2012 takes effect
BAND_TREATED <- "0-100 m"
BAND_CONTROL <- "100-500 m"
BANDS        <- c("0-30 m", "30-100 m", "0-100 m", "100-500 m")
BANDS_EXCL   <- c("0-30 m", "30-100 m", "100-500 m")  # mutually exclusive rings
N_BOOT       <- 10000
SEED         <- 7

CLASSES <- c("Forest", "Non-forest natural formation", "Farming and pasture",
             "Non-vegetated area", "Water")
CLASS_CODES <- c(Forest = 4, `Non-forest natural formation` = 5,
                 `Farming and pasture` = 15, `Non-vegetated area` = 22,
                 Water = 30)

RESERVOIRS <- c("FontesNova", "Funil", "Juturnaiba", "Paracambi",
                "PereiraPassos", "Rosal", "Santana", "Saracuruna", "Tocos",
                "Vigario", "Anta", "IlhadosPombos", "SantaBranca", "SantaRosa")

# Fixed row order for every matrix and every factor built below. Sorting with
# order() would delegate the decision to the collation of the machine, and the
# two orders in play here differ: under a Portuguese locale Santana precedes
# Santa Rosa, under the C locale it follows it. The medians do not care, but the
# bootstrap resamples positions rather than values, so the interval bounds move
# with the order, and a reader on another machine would not reproduce them. The
# order below is the one under which the published values were computed.
RESERVOIR_ORDER <- c("Anta", "FontesNova", "Funil", "IlhadosPombos",
                     "Juturnaiba", "Paracambi", "PereiraPassos", "Rosal",
                     "SantaBranca", "Santana", "SantaRosa", "Saracuruna",
                     "Tocos", "Vigario")

# Reservoirs whose water surface formed during the series. At the earlier
# benchmarks the 0-100 m band of these three was not yet the margin of a
# reservoir, and at two of them impoundment and licensing coincide with the
# reform. Sources:
#   Paracambi  small hydropower plant in operation in 2012 (INEA/COPPETEC, 2014,
#              RT-05, Table 3.2.1.2; ANA/ANEEL reservoir layer, dtreserv)
#   Anta       under construction, year 2013 (INEA/COPPETEC, 2014, RT-05,
#              Table 3.2.1.2)
#   Rosal      impounded in 2000 (ANA/ANEEL reservoir layer, dtreserv)
# The MapBiomas series agrees: the water share of the 0-30 m band rises between
# 2011 and 2014 at Paracambi and Anta and between 1995 and 2008 at Rosal (see
# results/water_share_0_30m.csv). These reservoirs are excluded in a sensitivity
# scenario added during revision; the primary analysis keeps all fourteen.
RES_WATERLINE_CHANGED <- c("Paracambi", "Anta", "Rosal")

# Two further cases reported as separate scenarios. At Juturnaiba the water
# share of the 0-30 m band rises from 1985 to 2008, before the reform; the ANA
# layer carries no date, and the dam was built by DNOS between 1978 and 1982
# (Prolagos, 2024, dam safety plan, Vol. IV, Section 3.3). Funil was impounded in
# 1970, but its operating licence was issued by IBAMA in June 2012
# (INEA/COPPETEC, 2014, RT-05, Section 3.3.3), so licence conditions coincide
# with the reform.
RES_WATERLINE_EARLY  <- "Juturnaiba"
RES_LICENCE_2012     <- "Funil"

# Reservoirs on the state boundary. Their outlines in the input layer are
# restricted to the part of the water surface inside Rio de Janeiro (the ANA
# layer gives 1,225.9 ha for Anta, 3,384.4 ha for Funil, 568.0 ha for Ilha dos
# Pombos and 189.6 ha for Rosal; see data/reservoir_characteristics.csv). The
# bands were not clipped at the state line, but on the far bank of a boundary
# river they are measured from the cut line rather than from the shore. These
# four are excluded in a further sensitivity scenario.
RES_STATE_BOUNDARY <- c("Anta", "Funil", "IlhadosPombos", "Rosal")

DISPLAY_NAMES <- c(FontesNova = "Fontes Nova", IlhadosPombos = "Ilha dos Pombos",
                   PereiraPassos = "Pereira Passos", SantaBranca = "Santa Branca",
                   SantaRosa = "Santa Rosa", Juturnaiba = "Juturnaiba",
                   Vigario = "Vigario")
display <- function(r) ifelse(r %in% names(DISPLAY_NAMES), DISPLAY_NAMES[r], r)

# ------------------------------------------------------------------- palette
# Thematic rather than arbitrary: blue for water, dark green for forest, light
# green for herbaceous and shrub vegetation, orange for farming and pasture,
# red for non-vegetated areas.
CLASS_COLOURS <- c("Forest"                        = "#1B7837",
                   "Non-forest natural formation"  = "#A6D96A",
                   "Farming and pasture"           = "#E08214",
                   "Non-vegetated area"            = "#D73027",
                   "Water"                         = "#2166AC")

BAND_COLOURS <- c("0-30 m" = "#08519C", "30-100 m" = "#4292C6",
                  "0-100 m" = "#E08214", "100-500 m" = "#1B7837")
BAND_LABELS  <- c("0-30 m" = "0-30 m", "30-100 m" = "30-100 m",
                  "0-100 m" = "0-100 m (APP band)",
                  "100-500 m" = "100-500 m (control band)")

GREY <- "#4d4d4d"

# =============================================================================
# PSEUDONYMIZATION OF THE CADASTRAL CODES
# =============================================================================
#' The CAR code identifies a holding. The public data in data/ carry a
#' sequential identifier instead (H001, H002, ...), and the key that links the
#' two is written to data/cadastral/holding_key.csv, which .gitignore keeps out
#' of the repository. An existing key is reused, so identifiers stay stable when
#' the pipeline is run again; codes not yet in the key receive the next number.
pseudonymize_holdings <- function(zones, transitions,
                                  key_file = file.path(DIR_DATA, "cadastral",
                                                       "holding_key.csv")) {
  key <- if (file.exists(key_file))
    read.csv(key_file, stringsAsFactors = FALSE) else
    data.frame(Property_code = character(0), Holding_id = character(0))
  codes <- unique(transitions$Property_code)
  codes <- codes[!grepl("^H[0-9]{3,}$", codes)]
  new <- setdiff(codes, key$Property_code)
  if (length(new)) {
    start <- nrow(key)
    key <- rbind(key, data.frame(
      Property_code = new,
      Holding_id = sprintf("H%03d", start + seq_along(new)),
      stringsAsFactors = FALSE))
    dir.create(dirname(key_file), showWarnings = FALSE, recursive = TRUE)
    write.csv(key, key_file, row.names = FALSE)
  }
  lookup <- setNames(key$Holding_id, key$Property_code)
  swap <- function(x) ifelse(x %in% names(lookup), lookup[x], x)
  transitions$Property_code <- swap(transitions$Property_code)
  names(transitions)[names(transitions) == "Property_code"] <- "Holding_id"
  prop <- zones$Zone_type == "APP_band_property"
  zones$Zone[prop] <- swap(zones$Zone[prop])
  list(zones = zones, transitions = transitions)
}

# =============================================================================
# STATISTICAL FUNCTIONS
# =============================================================================

#' Percentile bootstrap confidence interval for the median.
#'
#' With fourteen units, asymptotic formulae for the median are unreliable. The
#' bootstrap resamples the data themselves and assumes no distribution. The
#' median of fourteen values is a discrete quantile, so the bounds land on a
#' small set of attainable values and move by a few tenths of a percentage
#' point when the resampling sequence changes. The seed is therefore set inside
#' the function, and every interval in the manuscript is reproducible from the
#' data alone.
boot_ci <- function(x, R = N_BOOT, conf = 0.95) {
  x <- x[is.finite(x)]
  if (length(x) < 3) return(c(lower = NA_real_, upper = NA_real_))
  # The seed is set inside the function, not once at the top of the script, so
  # that each interval depends only on the data it summarises. Seeding once at
  # the start makes every interval depend on how many resamples were drawn
  # before it, and inserting or reordering a single test then shifts intervals
  # that were not touched. Seeding here makes each published interval
  # reproducible on its own.
  set.seed(SEED)
  draws <- replicate(R, median(sample(x, length(x), replace = TRUE)))
  a <- (1 - conf) / 2
  c(lower = unname(quantile(draws, a)), upper = unname(quantile(draws, 1 - a)))
}

#' Paired Wilcoxon signed-rank test against a null median of zero, with effect
#' size.
#'
#' Wilcoxon rather than the t test: with fourteen units, normality cannot be
#' verified reliably and a single outlying observation shifts the mean. The
#' effect size is the rank-biserial correlation, which is stable in small
#' samples. The count of observations sharing the sign of the median accompanies
#' every test because, at this sample size, it conveys consistency more directly
#' than a p value.
paired_test <- function(x, label = "") {
  x <- x[is.finite(x)]
  if (sum(x != 0) < 3) {
    return(data.frame(quantity = label, n = length(x), median = NA_real_,
                      ci_lower = NA_real_, ci_upper = NA_real_,
                      same_sign = NA_integer_, p = NA_real_, r_rb = NA_real_))
  }
  tt <- suppressWarnings(wilcox.test(x, mu = 0, exact = FALSE, correct = FALSE))
  ci <- boot_ci(x)
  med <- median(x)
  nz <- x[x != 0]
  n <- length(nz)
  t_plus <- sum(rank(abs(nz))[nz > 0])
  data.frame(quantity = label, n = length(x), median = med,
             ci_lower = unname(ci["lower"]), ci_upper = unname(ci["upper"]),
             same_sign = sum(sign(x) == sign(med)),
             p = tt$p.value, r_rb = 4 * t_plus / (n * (n + 1)) - 1,
             row.names = NULL)
}

#' Benjamini and Hochberg (1995) false discovery rate. Preferred over
#' Bonferroni because the metrics are correlated with one another, which makes
#' Bonferroni unnecessarily conservative here.
fdr <- function(p) p.adjust(p, method = "BH")

stars <- function(q) {
  ifelse(is.na(q), "",
  ifelse(q < 0.001, "***", ifelse(q < 0.01, "**", ifelse(q < 0.05, "*", "ns"))))
}

#' Reservoir-by-year matrix of one variable, for a single distance band.
band_matrix <- function(data, band, class = "Forest",
                        value = "Pct_terrestrial") {
  d <- data[data$Class == class & data$Band == band,
            c("Reservoir", "Year", value)]
  m <- reshape(d, idvar = "Reservoir", timevar = "Year", direction = "wide")
  rownames(m) <- m$Reservoir
  m <- m[, paste0(value, ".", BENCHMARKS), drop = FALSE]
  colnames(m) <- BENCHMARKS
  as.matrix(m[RESERVOIR_ORDER, , drop = FALSE])
}

#' Rate of change in percentage points per decade. The windows span 26 and 13
#' years, so expressing rates per decade makes them comparable.
rate_per_decade <- function(m, y0, y1) {
  (m[, as.character(y1)] - m[, as.character(y0)]) / (y1 - y0) * 10
}

# =============================================================================
# PLOTTING THEME, JOURNAL SPECIFICATION
# =============================================================================
# Column widths: 90 mm single, 140 mm one and a half, 190 mm full page. Minimum
# resolution is 300 dpi for colour halftone and 1000 dpi for line art; 600 dpi
# is used, which satisfies both. Sans-serif type, 7 to 9 pt after reduction.
# TIFF with LZW compression.

WIDTH_SINGLE <- 90
WIDTH_HALF   <- 140
WIDTH_DOUBLE <- 190
DPI          <- 600

theme_publication <- function(base = 8) {
  ggplot2::theme_bw(base_size = base, base_family = "sans") +
    ggplot2::theme(
      panel.border     = ggplot2::element_blank(),
      panel.grid.minor = ggplot2::element_blank(),
      panel.grid.major = ggplot2::element_line(linewidth = 0.2, colour = "#ebebeb"),
      axis.line   = ggplot2::element_line(linewidth = 0.3, colour = GREY),
      axis.ticks  = ggplot2::element_line(linewidth = 0.3, colour = GREY),
      axis.text   = ggplot2::element_text(colour = GREY, size = base - 1),
      plot.title  = ggplot2::element_text(size = base + 0.5, face = "bold", hjust = 0),
      plot.title.position = "plot",
      strip.background = ggplot2::element_blank(),
      strip.text  = ggplot2::element_text(size = base, face = "bold", hjust = 0),
      legend.background = ggplot2::element_blank(),
      legend.key   = ggplot2::element_blank(),
      legend.title = ggplot2::element_blank(),
      legend.position = "bottom",
      legend.margin = ggplot2::margin(0, 0, 0, 0),
      plot.margin = ggplot2::margin(4, 6, 2, 2))
}

#' Legend placed inside the panel, with syntax valid across ggplot2 versions.
#' From version 3.5.0 the coordinates go in legend.position.inside; before that
#' they went directly in legend.position. Without this bridge the code fails in
#' one of the two families.
legend_inside <- function(x, y, anchor = c(x, y)) {
  modern <- utils::packageVersion("ggplot2") >= "3.5.0"
  if (modern) {
    ggplot2::theme(legend.position = "inside",
                   legend.position.inside = c(x, y),
                   legend.justification = anchor)
  } else {
    ggplot2::theme(legend.position = c(x, y),
                   legend.justification = anchor)
  }
}

#' Save a figure as TIFF in the journal specification. Uses ragg when it is
#' available, because its output is more faithful, and falls back to the base
#' device otherwise.
save_figure <- function(p, name, width_mm = WIDTH_DOUBLE, height_mm = 80) {
  file <- file.path(DIR_FIGURES, paste0(name, ".tiff"))
  if (requireNamespace("ragg", quietly = TRUE)) {
    ragg::agg_tiff(file, width = width_mm, height = height_mm, units = "mm",
                   res = DPI, compression = "lzw", background = "white",
                   scaling = 1)
  } else {
    grDevices::tiff(file, width = width_mm, height = height_mm, units = "mm",
                    res = DPI, compression = "lzw", bg = "white",
                    type = if (capabilities("cairo")) "cairo" else "Xlib")
  }
  print(p)
  grDevices::dev.off()
  message("  ", basename(file), "  (", width_mm, " x ", height_mm, " mm, ",
          DPI, " dpi)")
  invisible(file)
}
