# =============================================================================
# Landscape dynamics and conservation policy effectiveness in reservoir
# riparian buffers: fourteen reservoirs under Brazil's Forest Code, 1985-2024
# -----------------------------------------------------------------------------
# SCRIPT 3. FIGURES
#
# Every figure is drawn with ggplot2 to the journal specification: TIFF, 600
# dpi, LZW compression, column widths of 90, 140 and 190 mm, sans-serif type.
# Input comes from data/ and from the results that 02_tests.R writes.
#
# OUTPUT (figures/)
#   Figure_2_composition      land cover composition by band and year
#   Figure_3_trajectory       forest cover and its rate of change
#   Figure_4_event_study      event study
#   Figure_5_sensitivity      robustness to the composition of the set
#   Figure_6_gradient         distance-to-cover gradient
#   Figure_7_configuration    configuration metrics
#   Figure_8_compliance       native forest in the APP band and the 2008-2024 transition
#   Figure_S1_reservoirs      trajectory of each reservoir
#   Figure_S2_pretrends       pre-reform trends, APP band minus control band
#   Figure_S3_configuration   all eight configuration metrics
#
# PALETTE. Thematic and defined by the project: blue for water, dark green for
# forest, light green for herbaceous and shrub vegetation, orange for farming
# and pasture, red for non-vegetated areas. The distance bands use a separate
# scale so that they do not compete with the cover classes in the same panel.
#
# PACKAGES
#   ggplot2    required
#   patchwork  optional, composes the panels; without it the panels are saved
#              separately
#   ragg       optional, improves the TIFF output
#   install.packages(c("ggplot2", "patchwork", "ragg"))
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

suppressPackageStartupMessages(library(ggplot2))
use_patchwork <- requireNamespace("patchwork", quietly = TRUE)
if (use_patchwork) suppressPackageStartupMessages(library(patchwork))
if (!use_patchwork)
  message("patchwork not installed: panels will be saved separately.")

CLASS_LABELS <- c("Forest"                       = "Forest",
                  "Non-forest natural formation" = "Herbaceous and shrub vegetation",
                  "Farming and pasture"          = "Farming and pasture",
                  "Non-vegetated area"           = "Non-vegetated area",
                  "Water"                        = "Water")

# ------------------------------------------------------------------- input
read_required <- function(folder, file) {
  path <- file.path(folder, file)
  if (!file.exists(path))
    stop("Missing file: ", path, "\nRun 02_tests.R before this script.")
  read.csv(path, stringsAsFactors = FALSE)
}
composition   <- read_required(DIR_DATA, "composition_series.csv")
configuration <- read_required(DIR_DATA, "configuration_series.csv")
zones         <- read_required(DIR_DATA, "cadastral_zones.csv")
transitions   <- read_required(DIR_DATA, "cadastral_transitions.csv")
areas         <- read_required(DIR_DATA, "reservoir_areas.csv")
dynamics      <- read_required(DIR_RESULTS, "dynamics.csv")
event_tbl     <- read_required(DIR_RESULTS, "event_study.csv")
gradient_tbl  <- read_required(DIR_RESULTS, "spatial_gradient.csv")
sensitivity   <- read_required(DIR_RESULTS, "sensitivity.csv")

composition$Band <- factor(composition$Band, levels = BANDS)
forest <- composition[composition$Class == "Forest", ]
message("\nFigures:")

# =============================================================== FIGURE 2 ====
# Composition of each band over time. Stacked bars of the median across
# reservoirs, not the mean: with fourteen units and a skewed distribution, the
# mean is pulled by the extreme cases.

med <- aggregate(Pct_band ~ Band + Year + Class, data = composition,
                 FUN = median)
med$Class <- factor(med$Class, levels = names(CLASS_COLOURS))

g2 <- ggplot(med, aes(factor(Year), Pct_band, fill = Class)) +
  geom_col(width = 0.78, colour = "white", linewidth = 0.2) +
  geom_vline(xintercept = 4.5, linetype = "22", linewidth = 0.3, colour = GREY) +
  facet_wrap(~ Band, nrow = 1, labeller = labeller(Band = BAND_LABELS)) +
  scale_fill_manual(values = CLASS_COLOURS, labels = CLASS_LABELS) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.02))) +
  labs(x = NULL, y = "Share of band area (%)") +
  theme_publication() +
  theme(axis.text.x = element_text(angle = 90, vjust = 0.5, size = 6.2)) +
  guides(fill = guide_legend(nrow = 1, byrow = TRUE))
save_figure(g2, "Figure_2_composition", WIDTH_DOUBLE, 78)

# =============================================================== FIGURE 3 ====
# (a) forest cover over time, median with the interquartile ribbon;
# (b) rate of change per window, with bootstrap confidence intervals.

forest_summary <- do.call(rbind, lapply(
  split(forest, list(forest$Band, forest$Year), drop = TRUE),
  function(d) data.frame(
    Band = d$Band[1], Year = d$Year[1],
    med = median(d$Pct_terrestrial, na.rm = TRUE),
    q1  = quantile(d$Pct_terrestrial, 0.25, na.rm = TRUE),
    q3  = quantile(d$Pct_terrestrial, 0.75, na.rm = TRUE))))

g3a <- ggplot(forest_summary, aes(Year, med, colour = Band, fill = Band)) +
  geom_ribbon(aes(ymin = q1, ymax = q3), alpha = 0.09, colour = NA) +
  geom_vline(xintercept = YEAR_REFORM, linetype = "22", linewidth = 0.3,
             colour = GREY) +
  annotate("text", x = YEAR_REFORM + 0.6, y = Inf, label = "Forest Code, 2012",
           hjust = 0, vjust = 1.4, size = 2.1, colour = GREY) +
  geom_line(linewidth = 0.7) +
  geom_point(size = 1.5) +
  scale_colour_manual(values = BAND_COLOURS, labels = BAND_LABELS) +
  scale_fill_manual(values = BAND_COLOURS, guide = "none") +
  scale_x_continuous(breaks = c(1985, 1995, 2008, 2014, 2024)) +
  labs(x = "Year", y = "Forest cover (% of land area)",
       title = "(a) Forest cover over time") +
  theme_publication() +
  legend_inside(0.02, 0.99, c(0, 1)) +
  theme(legend.text = element_text(size = 6.5),
        legend.key.height = unit(8, "pt"))

d3 <- dynamics[dynamics$window %in% c("pre", "post"), ]
d3$band <- factor(d3$band, levels = rev(BANDS))
d3$window <- factor(d3$window, levels = c("pre", "post"),
                    labels = c("Before 2012 (1985-2011)",
                               "After 2012 (2011-2024)"))

g3b <- ggplot(d3, aes(median, band, colour = band, shape = window,
                      alpha = window)) +
  geom_vline(xintercept = 0, linewidth = 0.3, colour = GREY) +
  geom_linerange(aes(xmin = ci_lower, xmax = ci_upper),
                 position = position_dodge(width = 0.6), linewidth = 0.7) +
  geom_point(position = position_dodge(width = 0.6), size = 1.9,
             fill = "white") +
  geom_text(aes(x = ci_upper, label = ifelse(sig == "ns", "", sig)),
            position = position_dodge(width = 0.6), hjust = -0.4, size = 2.5,
            show.legend = FALSE) +
  scale_colour_manual(values = BAND_COLOURS, guide = "none") +
  scale_shape_manual(values = c(21, 23)) +
  scale_alpha_manual(values = c(0.55, 1), guide = "none") +
  scale_y_discrete(labels = BAND_LABELS) +
  labs(x = "Change in forest cover (percentage points per decade)", y = NULL,
       title = "(b) Rate of change, before and after the law") +
  theme_publication()

if (use_patchwork) {
  save_figure(g3a | g3b, "Figure_3_trajectory", WIDTH_DOUBLE, 78)
} else {
  save_figure(g3a, "Figure_3a_trajectory", WIDTH_SINGLE, 78)
  save_figure(g3b, "Figure_3b_rates", WIDTH_SINGLE, 78)
}

# =============================================================== FIGURE 4 ====
# Event study. The question is whether the APP band pulled away from the
# control band after the law and not before it. The year 2011 is the base and
# is therefore zero by construction. Points before the law are shown in light
# blue, points after it in green.

event_tbl$colour <- ifelse(event_tbl$period == "before", "#7fa8cc",
                    ifelse(event_tbl$period == "after",  "#1B7837", "#252525"))

g4 <- ggplot(event_tbl, aes(year, median)) +
  annotate("rect", xmin = -Inf, xmax = YEAR_REFORM, ymin = -Inf, ymax = Inf,
           fill = "#f2f2f2") +
  geom_hline(yintercept = 0, linewidth = 0.3, colour = GREY) +
  geom_vline(xintercept = YEAR_REFORM, linetype = "22", linewidth = 0.35,
             colour = GREY) +
  geom_line(colour = "#9e9e9e", linewidth = 0.4) +
  geom_linerange(aes(ymin = ci_lower, ymax = ci_upper, colour = I(colour)),
                 linewidth = 0.8) +
  geom_point(aes(colour = I(colour)), size = 2) +
  annotate("text", x = 1986, y = Inf, label = "Before the law",
           hjust = 0, vjust = 1.6, size = 2.2, colour = GREY) +
  annotate("text", x = YEAR_REFORM + 0.8, y = Inf, label = "After the law",
           hjust = 0, vjust = 1.6, size = 2.2, colour = GREY) +
  scale_x_continuous(breaks = BENCHMARKS) +
  labs(x = "Year",
       y = paste0("Forest cover, APP band minus control band\n",
                  "(percentage points, relative to 2011)"),
       title = "Did the APP band pull ahead after the law?") +
  theme_publication() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1),
        legend.position = "none")
save_figure(g4, "Figure_4_event_study", WIDTH_HALF, 80)

# =============================================================== FIGURE 5 ====
# Robustness. Panel (a) shows the result for each reservoir against its surface
# area, to make clear that no single case drives it. Panel (b) shows the median
# under every inclusion rule in sensitivity.csv: five size thresholds, then the
# ten reservoirs processed first and the four added afterwards.

treated <- forest[forest$Band == BAND_TREATED,
                  c("Reservoir", "Year", "Pct_terrestrial")]
control <- forest[forest$Band == BAND_CONTROL,
                  c("Reservoir", "Year", "Pct_terrestrial")]
paired <- merge(treated, control, by = c("Reservoir", "Year"),
                suffixes = c("_t", "_c"))
paired$diff <- paired$Pct_terrestrial_t - paired$Pct_terrestrial_c
base <- paired[paired$Year == YEAR_BASE, c("Reservoir", "diff")]
names(base)[2] <- "diff_base"
paired <- merge(paired, base, by = "Reservoir")
paired$relative <- paired$diff - paired$diff_base
panel_a <- merge(paired[paired$Year == 2024, c("Reservoir", "relative")],
                 areas, by = "Reservoir")

g5a <- ggplot(panel_a, aes(Surface_ha, relative)) +
  geom_hline(yintercept = 0, linewidth = 0.3, colour = GREY) +
  geom_point(colour = "#1B7837", size = 2) +
  scale_x_log10() +
  labs(x = "Reservoir surface area (ha, log scale)",
       y = "Forest cover difference in 2024\n(percentage points)",
       title = "(a) Result by reservoir size") +
  theme_publication()

# Short labels for the panel; the full wording is in sensitivity.csv and in
# Table 5. Scenarios added during revision are drawn in grey.
SCENARIO_LABELS <- c(
  "All reservoirs (primary)"               = "All fourteen (primary)",
  "Surface >= 20 ha"                       = "Surface >= 20 ha",
  "Surface >= 50 ha"                       = "Surface >= 50 ha",
  "Surface >= 100 ha"                      = "Surface >= 100 ha",
  "Surface >= 250 ha"                      = "Surface >= 250 ha",
  "Ten reservoirs of the original set"     = "Ten of the original set",
  "Four reservoirs added in the extension" = "Four added in the extension",
  "All but Santa Branca"                   = "All but Santa Branca",
  "Stable waterline (Paracambi, Anta and Rosal excluded)" =
    "Stable waterline (11)",
  "Stable waterline, Juturnaiba also excluded" =
    "Stable waterline, no Juturnaiba",
  "Stable waterline, Funil also excluded"  = "Stable waterline, no Funil",
  "Reservoirs on the state boundary excluded" = "No state-boundary reservoir")
REVISION_SCENARIOS <- names(SCENARIO_LABELS)[8:12]
sensitivity$added <- sensitivity$quantity %in% REVISION_SCENARIOS
sensitivity$quantity <- factor(SCENARIO_LABELS[sensitivity$quantity],
                               levels = rev(SCENARIO_LABELS[sensitivity$quantity]))
x_range <- range(c(sensitivity$ci_lower, sensitivity$ci_upper), na.rm = TRUE)
g5b <- ggplot(sensitivity, aes(median, quantity)) +
  geom_vline(xintercept = 0, linewidth = 0.3, colour = GREY) +
  geom_linerange(aes(xmin = ci_lower, xmax = ci_upper,
                     colour = I(ifelse(added, "#8c8c8c", "#1B7837"))),
                 linewidth = 0.8) +
  geom_point(aes(colour = I(ifelse(added, "#8c8c8c", "#1B7837"))), size = 2) +
  geom_text(aes(x = x_range[2] + 0.6,
                label = sprintf("n = %d   p = %.3f", n, p)),
            hjust = 0, size = 2.2, colour = "#555555") +
  coord_cartesian(xlim = c(x_range[1] - 0.5, x_range[2] + 7), clip = "off") +
  labs(x = "Forest cover difference in 2024 (percentage points)", y = NULL,
       title = "(b) Result under different reservoir sets") +
  theme_publication()

if (use_patchwork) {
  save_figure(g5a | g5b, "Figure_5_sensitivity", WIDTH_DOUBLE, 96)
} else {
  save_figure(g5a, "Figure_5a_by_reservoir", WIDTH_SINGLE, 78)
  save_figure(g5b, "Figure_5b_scenarios", WIDTH_SINGLE, 78)
}

# =============================================================== FIGURE 6 ====
# Gradient between distance from water and forest cover, at four benchmarks.
# Grey lines are individual reservoirs; the green line is the median. Kendall's
# W measures how far the reservoirs agree on the ordering of the bands.

YEARS_GRADIENT <- c(1985, 2008, 2014, 2024)
grad_data <- forest[forest$Year %in% YEARS_GRADIENT &
                    forest$Band %in% BANDS_EXCL, ]
grad_data$Band <- factor(grad_data$Band, levels = BANDS_EXCL)
# The facet variable must exist in every layer. Without this column the
# reservoir lines and the medians of all four years were drawn in every panel.
grad_data$year <- grad_data$Year
grad_median <- aggregate(Pct_terrestrial ~ Band + year, data = grad_data,
                         FUN = median)
labels_w <- gradient_tbl[gradient_tbl$year %in% YEARS_GRADIENT, ]
labels_w$text <- sprintf("W = %.2f\n%s", labels_w$kendall_w,
                         ifelse(labels_w$p < 0.001, "p < 0.001",
                                sprintf("p = %.3f", labels_w$p)))

# The two inner rings together form the APP band (0-100 m). They are shaded so
# that the band the Forest Code protects can be read directly off the panels.
g6 <- ggplot(grad_data, aes(Band, Pct_terrestrial)) +
  annotate("rect", xmin = 0.5, xmax = 2.5, ymin = -Inf, ymax = Inf,
           fill = "#fbe3c8", alpha = 0.7) +
  annotate("text", x = 1.5, y = -Inf, label = "APP band", vjust = -0.6,
           size = 2.1, colour = "#a35a00") +
  annotate("text", x = 3, y = -Inf, label = "Control", vjust = -0.6,
           size = 2.1, colour = "#555555") +
  geom_line(aes(group = Reservoir), colour = "#c8c8c8", linewidth = 0.3) +
  geom_line(data = grad_median, aes(group = 1), colour = "#1B7837",
            linewidth = 0.9) +
  geom_point(data = grad_median, colour = "#1B7837", size = 1.8) +
  geom_text(data = labels_w, aes(x = 0.7, y = Inf, label = text), hjust = 0,
            vjust = 1.2, size = 2.2, colour = "#555555", inherit.aes = FALSE) +
  facet_wrap(~ year, nrow = 1) +
  scale_x_discrete() +
  labs(x = "Distance from water", y = "Forest cover (% of land area)") +
  theme_publication() +
  theme(axis.text.x = element_text(angle = 25, hjust = 1, size = 6.5))
save_figure(g6, "Figure_6_gradient", WIDTH_DOUBLE, 70)

# =============================================================== FIGURE 7 ====
# Configuration: four metrics with plain-language labels. All eight appear in
# Figure S3.

SELECTED <- c(pland = "Forest area (% of band)", np = "Number of forest patches",
              pd = "Patch density (per 100 ha)", area_mn = "Mean patch size (ha)")
cfg <- configuration[configuration$metric %in% names(SELECTED) &
                     configuration$Band %in% c(BAND_TREATED, BAND_CONTROL), ]
cfg_median <- aggregate(value ~ Band + Year + metric, data = cfg, FUN = median)
cfg_median$metric <- factor(cfg_median$metric, levels = names(SELECTED),
                            labels = SELECTED)

TWO_COLOURS <- c("#E08214", "#1B7837")
names(TWO_COLOURS) <- c(BAND_TREATED, BAND_CONTROL)
TWO_LABELS <- BAND_LABELS[c(BAND_TREATED, BAND_CONTROL)]

g7 <- ggplot(cfg_median, aes(Year, value, colour = Band, shape = Band)) +
  geom_vline(xintercept = YEAR_REFORM, linetype = "22", linewidth = 0.3,
             colour = GREY) +
  geom_line(linewidth = 0.7) +
  geom_point(size = 1.6) +
  facet_wrap(~ metric, nrow = 1, scales = "free_y") +
  scale_colour_manual(values = TWO_COLOURS, labels = TWO_LABELS) +
  scale_shape_manual(values = c(16, 15), labels = TWO_LABELS) +
  scale_x_continuous(breaks = c(1985, 2008, 2024)) +
  labs(x = NULL, y = NULL,
       title = "More forest, in more and smaller pieces") +
  theme_publication()
save_figure(g7, "Figure_7_configuration", WIDTH_DOUBLE, 68)

# =============================================================== FIGURE 8 ====
# Native forest in the APP band and what happened to it between 2008 and 2024.
# The APP band is the 0-100 m reference band, not the licensed width of each
# reservoir.
# The red line at 25% is the ecological threshold from the fragmentation
# literature and is not a legal standard: the Code requires full cover.

totals <- zones[zones$Zone_type == "APP_band_reservoir", ]
totals <- totals[order(totals$Forest_pct), ]
totals$label <- factor(display(totals$Reservoir),
                       levels = display(totals$Reservoir))
stacked <- rbind(
  data.frame(label = totals$label, part = "Native forest",
             value = totals$Forest_pct),
  data.frame(label = totals$label, part = "Missing (deficit)",
             value = 100 - totals$Forest_pct))
stacked$part <- factor(stacked$part,
                       levels = c("Native forest", "Missing (deficit)"))

# Native forest is drawn from the left, so the bar length reads as cover and
# the dashed line at 25% can be compared with it directly.
g8a <- ggplot(stacked, aes(value, label, fill = part)) +
  geom_col(width = 0.62, position = position_stack(reverse = TRUE)) +
  geom_text(data = totals, aes(x = Forest_pct, y = label,
                               label = sprintf("%.0f", Forest_pct)),
            inherit.aes = FALSE, hjust = -0.25, size = 2, colour = "#ffffff") +
  geom_vline(xintercept = 25, linetype = "22", linewidth = 0.4,
             colour = "#D73027") +
  annotate("text", x = 26, y = nrow(totals) + 0.7,
           label = "25% ecological threshold", hjust = 0, size = 2,
           colour = "#D73027") +
  coord_cartesian(clip = "off") +
  scale_fill_manual(values = c("Native forest" = "#1B7837",
                               "Missing (deficit)" = "#E08214")) +
  scale_x_continuous(expand = expansion(mult = c(0, 0.02))) +
  labs(x = "Share of the APP band (%)", y = NULL,
       title = "(a) How much native forest the APP band still has") +
  theme_publication() +
  theme(legend.key.size = grid::unit(3, "mm"))

CATEGORIES <- c(Consolidated_in_use_ha   = "Cleared by 2008, still in use",
                Consolidated_restored_ha = "Cleared by 2008, restored",
                Cleared_after_2008_ha    = "Cleared after 2008",
                Native_retained_ha       = "Native cover kept")
transitions$size_class <- ifelse(
  transitions$Fiscal_modules <= 4,
  "Small holdings\n(<= 4 fiscal modules)", "Larger holdings\n(> 4 fiscal modules)")
transitions$size_class <- factor(transitions$size_class,
  levels = c("Small holdings\n(<= 4 fiscal modules)",
             "Larger holdings\n(> 4 fiscal modules)"))
totals_by_size <- aggregate(
  cbind(Consolidated_in_use_ha, Consolidated_restored_ha,
        Cleared_after_2008_ha, Native_retained_ha) ~ size_class,
  data = transitions, FUN = sum)
long <- reshape(totals_by_size, direction = "long",
                varying = names(CATEGORIES), v.names = "ha",
                timevar = "category", times = names(CATEGORIES),
                idvar = "size_class")
group_totals <- aggregate(ha ~ size_class, data = long, FUN = sum)
names(group_totals)[2] <- "total"
long <- merge(long, group_totals)
long$pct <- 100 * long$ha / long$total
long$category <- factor(long$category, levels = names(CATEGORIES),
                        labels = CATEGORIES)

g8b <- ggplot(long, aes(pct, size_class, fill = category)) +
  geom_col(width = 0.5, position = position_stack(reverse = TRUE)) +
  geom_text(aes(label = ifelse(pct >= 8, sprintf("%.0f", pct), "")),
            position = position_stack(vjust = 0.5, reverse = TRUE),
            size = 2.2, colour = "#ffffff") +
  scale_fill_manual(values = c("#E08214", "#A6D96A", "#D73027", "#1B7837")) +
  scale_x_continuous(expand = expansion(mult = c(0, 0.02))) +
  labs(x = "Share of the APP band inside registered properties (%)", y = NULL,
       title = "(b) What happened to the APP band, 2008 to 2024") +
  theme_publication() +
  guides(fill = guide_legend(nrow = 2, byrow = TRUE)) +
  theme(legend.key.size = grid::unit(3, "mm"))

if (use_patchwork) {
  save_figure(g8a | g8b, "Figure_8_compliance", WIDTH_DOUBLE, 84)
} else {
  save_figure(g8a, "Figure_8a_deficit", WIDTH_SINGLE, 84)
  save_figure(g8b, "Figure_8b_transition", WIDTH_SINGLE, 84)
}

# =============================================================================
# SUPPLEMENTARY FIGURES
# =============================================================================

# --------------------------------------------------------------- FIGURE S1 --
# Trajectory of each reservoir, APP band against control band. This is the
# panel that lets a reader confirm that the median conceals neither an isolated
# case nor a reversed trajectory at any single reservoir.

s1 <- forest[forest$Band %in% c(BAND_TREATED, BAND_CONTROL), ]
s1$label <- factor(display(s1$Reservoir),
                   levels = display(areas$Reservoir[order(-areas$Surface_ha)]))

gS1 <- ggplot(s1, aes(Year, Pct_terrestrial, colour = Band, shape = Band)) +
  geom_vline(xintercept = YEAR_REFORM, linetype = "22", linewidth = 0.25,
             colour = GREY) +
  geom_line(linewidth = 0.55) +
  geom_point(size = 1.1) +
  facet_wrap(~ label, ncol = 5) +
  scale_colour_manual(values = TWO_COLOURS, labels = TWO_LABELS) +
  scale_shape_manual(values = c(16, 15), labels = TWO_LABELS) +
  scale_x_continuous(breaks = c(1985, 2005, 2024)) +
  labs(x = "Year", y = "Forest cover (% of land area)") +
  theme_publication(7) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1, size = 5.6),
        strip.text = element_text(size = 7))
save_figure(gS1, "Figure_S1_reservoirs", WIDTH_DOUBLE, 105)

# --------------------------------------------------------------- FIGURE S2 --
# Pre-reform trends. The event study identifies an effect only if the two bands
# followed parallel trajectories before 2012. Here the difference between them
# is shown reservoir by reservoir, with the median highlighted.

s2 <- paired[, c("Reservoir", "Year", "relative")]
s2_median <- aggregate(relative ~ Year, data = s2, FUN = median)

gS2 <- ggplot(s2, aes(Year, relative)) +
  annotate("rect", xmin = -Inf, xmax = YEAR_REFORM, ymin = -Inf, ymax = Inf,
           fill = "#f2f2f2") +
  geom_hline(yintercept = 0, linewidth = 0.3, colour = GREY) +
  geom_vline(xintercept = YEAR_REFORM, linetype = "22", linewidth = 0.35,
             colour = GREY) +
  geom_line(aes(group = Reservoir), colour = "#c8c8c8", linewidth = 0.35) +
  geom_line(data = s2_median, aes(group = 1), colour = "#1B7837",
            linewidth = 0.9) +
  geom_point(data = s2_median, colour = "#1B7837", size = 1.7) +
  scale_x_continuous(breaks = BENCHMARKS) +
  labs(x = "Year",
       y = paste0("APP band minus control band\n",
                  "(percentage points, relative to 2011)"),
       title = "Each reservoir behind the median of Figure 4") +
  theme_publication() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))
save_figure(gS2, "Figure_S2_pretrends", WIDTH_HALF, 80)

# --------------------------------------------------------------- FIGURE S3 --
# All eight configuration metrics, in both bands. CLUMPY is shown with the frame
# correction described in Section 2.4: without it the index measures the shape
# of the band rather than the arrangement of forest within it.

METRIC_LABELS <- c(pland = "PLAND (%)", np = "NP (patches)",
                   pd = "PD (per 100 ha)", ed = "ED (m/ha)",
                   area_mn = "AREA_MN (ha)", enn_mn = "ENN_MN (m)",
                   cohesion = "COHESION", clumpy = "CLUMPY")
s3 <- configuration[configuration$Band %in% c(BAND_TREATED, BAND_CONTROL) &
                    configuration$metric %in% names(METRIC_LABELS), ]
s3_median <- aggregate(value ~ Band + Year + metric, data = s3, FUN = median)
s3_median$metric <- factor(s3_median$metric, levels = names(METRIC_LABELS),
                           labels = METRIC_LABELS)

gS3 <- ggplot(s3_median, aes(Year, value, colour = Band, shape = Band)) +
  geom_vline(xintercept = YEAR_REFORM, linetype = "22", linewidth = 0.25,
             colour = GREY) +
  geom_line(linewidth = 0.6) +
  geom_point(size = 1.3) +
  facet_wrap(~ metric, ncol = 4, scales = "free_y") +
  scale_colour_manual(values = TWO_COLOURS, labels = TWO_LABELS) +
  scale_shape_manual(values = c(16, 15), labels = TWO_LABELS) +
  scale_x_continuous(breaks = c(1985, 2005, 2024)) +
  labs(x = "Year", y = NULL) +
  theme_publication(7) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1, size = 5.8))
save_figure(gS3, "Figure_S3_configuration", WIDTH_DOUBLE, 95)

message("\nComplete. Figures written to ", DIR_FIGURES)
