# =============================================================================
# Landscape dynamics and conservation policy effectiveness in reservoir
# riparian buffers: fourteen reservoirs under Brazil's Forest Code, 1985-2024
# -----------------------------------------------------------------------------
# SCRIPT 2. STATISTICAL TESTS
#
# Reproduces every quantity reported in the manuscript from the CSV files in
# data/. Requires no GIS software and no spatial packages.
#
# OUTPUT (results/)
#   dynamics.csv               rates of change by band and window
#   triple_difference.csv      confirmatory quantity
#   event_study.csv            event-study coefficients
#   spatial_gradient.csv       distance-to-cover gradient
#   sensitivity.csv            sensitivity to the reservoir set
#   table_S2_boundary_effect.csv  Table S2 of the supplementary material
#   table_S3_by_reservoir.csv  Table S3 of the supplementary material
#   power_check.csv            minimum detectable effect of the signed-rank tests
#   definition_checks.csv      native non-forest vegetation, 30% threshold,
#                              declared APP in the control band
#   table_2_forest_cover.csv   Table 2 of the main text
#   band_composition_2024.csv  band composition in 2024, quoted in Section 3.1
#   table_6_compliance.csv     Table 6 of the main text
#   configuration.csv          configuration metrics, by band and window
#   cadastral_summary.csv      property-level compliance and the 2008 transition
#   size_dependence.csv        Spearman and Mann-Whitney tests on reservoir size
#   event_study_by_scenario.csv  event-study coefficients under every scenario
#   outlier_check.csv          Tukey fences for the 2024 coefficient
#   clumpy_default_trend.csv   trend of CLUMPY under the default denominator
#   table_S7_stable_waterline.csv  event study and triple difference without
#                              the three reservoirs impounded during the series
#   water_share_0_30m.csv      water share of the 0-30 m band (Table S8)
#
# Requirements: R >= 4.0, base packages only.
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
set.seed(SEED)

# =============================================================================
# 1. INPUT
# =============================================================================

composition <- read.csv(file.path(DIR_DATA, "composition_series.csv"),
                        stringsAsFactors = FALSE)
areas <- read.csv(file.path(DIR_DATA, "reservoir_areas.csv"),
                  stringsAsFactors = FALSE)

M <- lapply(BANDS, function(b) band_matrix(composition, b))
names(M) <- BANDS
RES <- rownames(M[[BAND_TREATED]])
cat("reservoirs:", length(RES), "| benchmarks:", length(BENCHMARKS), "\n\n")

WINDOWS <- list(pre = c(1985, 2011), post = c(2011, 2024), full = c(1985, 2024))

# =============================================================================
# 2. FOREST COVER DYNAMICS, BY BAND AND WINDOW
# =============================================================================

rows <- do.call(rbind, lapply(names(WINDOWS), function(w) {
  yrs <- WINDOWS[[w]]
  do.call(rbind, lapply(BANDS, function(b) {
    r <- paired_test(rate_per_decade(M[[b]], yrs[1], yrs[2]),
                     paste(yrs, collapse = "-"))
    cbind(band = b, window = w, r)
  }))
}))
rows$q <- ave(rows$p, rows$window, FUN = fdr)
rows$sig <- stars(rows$q)
write.csv(rows, file.path(DIR_RESULTS, "dynamics.csv"), row.names = FALSE)

cat("=== DYNAMICS (percentage points per decade) ===\n")
print(rows[, c("band", "window", "median", "ci_lower", "ci_upper",
               "same_sign", "q", "sig")], row.names = FALSE, digits = 3)

# Table 2 of the main text. Descriptive counterpart of the rates above: the
# level of forest cover in each band at each benchmark, as the median across the
# fourteen reservoirs with the interquartile range. No test, no resampling.

table_2 <- do.call(rbind, lapply(BANDS, function(b) {
  m <- M[[b]]
  data.frame(band = b, year = BENCHMARKS,
             median = round(apply(m, 2, median), 1),
             q1 = round(apply(m, 2, quantile, 0.25), 1),
             q3 = round(apply(m, 2, quantile, 0.75), 1),
             row.names = NULL)
}))
write.csv(table_2, file.path(DIR_RESULTS, "table_2_forest_cover.csv"),
          row.names = FALSE)

cat("\n=== TABLE 2: forest cover, percentage of terrestrial area ===\n")
print(table_2, row.names = FALSE)

# Composition of each band in 2024, over the whole band area rather than over
# the land. Section 3.1 quotes these shares to show why every forest value uses
# a terrestrial denominator: the innermost band is largely water by
# construction, being a 30 m ring drawn around a waterline.
c2024 <- composition[composition$Year == 2024, ]
band_2024 <- do.call(rbind, lapply(BANDS, function(b) {
  x <- c2024[c2024$Band == b, ]
  data.frame(band = b, class = CLASSES,
             median_pct_of_band = round(sapply(CLASSES, function(k)
               median(x$Pct_band[x$Class == k])), 1), row.names = NULL)
}))
write.csv(band_2024, file.path(DIR_RESULTS, "band_composition_2024.csv"),
          row.names = FALSE)

# =============================================================================
# 3. TRIPLE DIFFERENCE (confirmatory quantity, a family of one)
# =============================================================================
# Compares how much more forest the APP band gained than the control band
# after the reform, relative to that same difference before the reform. The
# earlier window acts as a placebo: without it, any divergence that already
# existed would be credited to the law.
#
# Being a single quantity declared in advance, it receives no multiplicity
# correction.

treated <- M[[BAND_TREATED]]
control <- M[[BAND_CONTROL]][rownames(treated), , drop = FALSE]
d_pre  <- rate_per_decade(treated, 1985, 2011) - rate_per_decade(control, 1985, 2011)
d_post <- rate_per_decade(treated, 2011, 2024) - rate_per_decade(control, 2011, 2024)

confirmatory <- rbind(
  paired_test(d_pre,           "Placebo, 1985-2011"),
  paired_test(d_post,          "Treatment, 2011-2024"),
  paired_test(d_post - d_pre,  "PRIMARY: triple difference"))
write.csv(confirmatory, file.path(DIR_RESULTS, "triple_difference.csv"),
          row.names = FALSE)

cat("\n=== TRIPLE DIFFERENCE ===\n")
print(confirmatory, row.names = FALSE, digits = 3)

# =============================================================================
# 4. EVENT STUDY
# =============================================================================
# The same treated-minus-control difference, now in levels, measured at each
# benchmark and expressed relative to its 2011 value.
#
# The four pre-reform benchmarks test the parallel-trends assumption that every
# difference-in-differences estimator requires and that a two-period design
# cannot examine (Wing, Simon and Bello-Gomez, 2018). Marcus and Sant'Anna
# (2021) show that different difference-in-differences procedures rest on
# different versions of that assumption and recover different parameters, with a
# trade-off between robustness and efficiency; the benchmark-by-benchmark
# formulation adopted here is the robust end of that trade-off, which is the
# appropriate choice when the assumption itself is under examination.
#
# On structural breaks: no exploratory search for a break point is performed.
# The intervention date is known (2012), and the event study is already the test
# for a regime change at that date, with the added advantage of estimating the
# preceding trajectory. Searching for a break point across eight irregularly
# spaced benchmarks would leave very few candidate positions and would require a
# sup-F distribution, because the conventional Chow p value no longer applies
# once the point is chosen by inspecting the data (Andrews, 1993).

diff_levels <- as.matrix(treated) - as.matrix(control)
event <- diff_levels - diff_levels[, as.character(YEAR_BASE)]

event_table <- do.call(rbind, lapply(BENCHMARKS, function(y) {
  if (y == YEAR_BASE) {
    return(data.frame(year = y, period = "reference", n = nrow(event),
                      median = 0, ci_lower = 0, ci_upper = 0,
                      same_sign = NA_integer_, p = NA_real_, r_rb = NA_real_))
  }
  r <- paired_test(event[, as.character(y)], as.character(y))
  cbind(year = y, period = ifelse(y < YEAR_BASE, "before", "after"),
        r[, setdiff(names(r), "quantity")])
}))
# Separate families: the pre-reform and post-reform benchmarks answer different
# questions and are corrected separately.
for (per in c("before", "after")) {
  i <- event_table$period == per
  event_table$q[i] <- fdr(event_table$p[i])
}
event_table$sig <- stars(event_table$q)
write.csv(event_table, file.path(DIR_RESULTS, "event_study.csv"), row.names = FALSE)

cat("\n=== EVENT STUDY (percentage points, relative to 2011) ===\n")
print(event_table[, c("year", "period", "median", "ci_lower", "ci_upper",
                      "same_sign", "p", "q", "sig")], row.names = FALSE, digits = 3)

# =============================================================================
# 5. SPATIAL GRADIENT: FOREST COVER AND DISTANCE FROM WATER
# =============================================================================
# The Friedman test is the non-parametric procedure for repeated measures in
# blocks: each reservoir contributes one value per band. Kendall's W measures
# how far the reservoirs agree on the ordering of the bands, which is the
# quantity of interest here, rather than merely whether the bands differ.

gradient <- do.call(rbind, lapply(BENCHMARKS, function(y) {
  X <- sapply(BANDS_EXCL, function(b) M[[b]][, as.character(y)])
  fr <- friedman.test(X)
  mean_ranks <- colMeans(t(apply(X, 1, rank)))
  data.frame(year = y, n = nrow(X), chi2 = unname(fr$statistic),
             df = unname(fr$parameter), p = fr$p.value,
             kendall_w = unname(fr$statistic) / (nrow(X) * (ncol(X) - 1)),
             ordering = paste(names(sort(mean_ranks, decreasing = TRUE)),
                              collapse = " > "))
}))
gradient$q <- fdr(gradient$p)
gradient$sig <- stars(gradient$q)
write.csv(gradient, file.path(DIR_RESULTS, "spatial_gradient.csv"), row.names = FALSE)

cat("\n=== SPATIAL GRADIENT ===\n")
print(gradient, row.names = FALSE, digits = 3)

# =============================================================================
# 6. SENSITIVITY TO THE COMPOSITION OF THE RESERVOIR SET
# =============================================================================
# The set spans four orders of magnitude in surface area. Every size threshold
# is reported, including those that weaken the result. None was chosen on the
# basis of a p value, which would be selection on the outcome. The primary
# analysis excludes no reservoir.
#
# Interpretation is split deliberately. The magnitude of the coefficient depends
# on set composition; its sign and its timing do not, and both hold under every
# threshold examined.

surface <- setNames(areas$Surface_ha, areas$Reservoir)
coef_2024 <- event[, "2024"]

# The last two scenarios are not size thresholds. Four reservoirs entered the
# study after the first ten had been processed, and splitting the set that way
# shows what the extension contributed. They are not the four smallest: two of
# them, Anta and Ilha dos Pombos, are among the larger water bodies in the set.
RES_ADDED <- c("SantaBranca", "SantaRosa", "IlhadosPombos", "Anta")

# The last five scenarios were added during revision, after the impoundment
# dates and the outlines of the boundary reservoirs were checked against the ANA/ANEEL reservoir layer and the state
# hydropower inventory (see RES_WATERLINE_CHANGED in 00_config.R). They are
# validity criteria defined without reference to the outcome, but they were not
# part of the original specification, and the manuscript says so.
scenarios <- list(
  "All reservoirs (primary)" = RES,
  "Surface >= 20 ha"         = RES[surface[RES] >= 20],
  "Surface >= 50 ha"         = RES[surface[RES] >= 50],
  "Surface >= 100 ha"        = RES[surface[RES] >= 100],
  "Surface >= 250 ha"        = RES[surface[RES] >= 250],
  "Ten reservoirs of the original set"     = setdiff(RES, RES_ADDED),
  "Four reservoirs added in the extension" = RES_ADDED,
  "All but Santa Branca"                   = setdiff(RES, "SantaBranca"),
  "Stable waterline (Paracambi, Anta and Rosal excluded)" =
    setdiff(RES, RES_WATERLINE_CHANGED),
  "Stable waterline, Juturnaiba also excluded" =
    setdiff(RES, c(RES_WATERLINE_CHANGED, RES_WATERLINE_EARLY)),
  "Stable waterline, Funil also excluded" =
    setdiff(RES, c(RES_WATERLINE_CHANGED, RES_LICENCE_2012)),
  "Reservoirs on the state boundary excluded" =
    setdiff(RES, RES_STATE_BOUNDARY))

sensitivity <- do.call(rbind, lapply(names(scenarios), function(k)
  paired_test(coef_2024[scenarios[[k]]], k)))
write.csv(sensitivity, file.path(DIR_RESULTS, "sensitivity.csv"), row.names = FALSE)

cat("\n=== SENSITIVITY (2024 coefficient) ===\n")
print(sensitivity, row.names = FALSE, digits = 3)

# The same scenarios at every benchmark, so that statements about the timing
# of the differential under each rule (for example, that the pre-reform
# coefficients remain non-significant under every size threshold) rest on a
# table rather than on inspection.
event_by_scenario <- do.call(rbind, lapply(names(scenarios), function(k)
  do.call(rbind, lapply(setdiff(BENCHMARKS, YEAR_BASE), function(y)
    cbind(scenario = k, year = y,
          period = ifelse(y < YEAR_BASE, "before", "after"),
          paired_test(event[scenarios[[k]], as.character(y)], "")[,
            c("n", "median", "ci_lower", "ci_upper", "same_sign", "p")])))))
write.csv(event_by_scenario, file.path(DIR_RESULTS, "event_study_by_scenario.csv"),
          row.names = FALSE)

# Size dependence, tested rather than merely asserted. Both tests are two-sided,
# because the study makes no directional prediction about reservoir size.
rho <- cor.test(log10(surface[RES]), coef_2024[RES], method = "spearman")
median_size <- median(surface[RES])
large <- coef_2024[RES[surface[RES] >= median_size]]
small <- coef_2024[RES[surface[RES] <  median_size]]
mw <- wilcox.test(large, small, alternative = "two.sided")

cat(sprintf(paste0("\nSpearman, log10(surface) against the 2024 coefficient: ",
                   "rho = %.3f, p = %.3f, n = %d\n"),
            unname(rho$estimate), rho$p.value, length(RES)))
cat(sprintf("Mann-Whitney, above against below median size: p = %.3f\n",
            mw$p.value))

# The same two tests applied to the native-vegetation deficit rather than to the event-study
# coefficient, so that the claim "the deficit does not vary with reservoir size"
# rests on a test and not on inspection.
zones <- read.csv(file.path(DIR_DATA, "cadastral_zones.csv"),
                  stringsAsFactors = FALSE)
zres <- zones[zones$Zone_type == "APP_band_reservoir", ]
rownames(zres) <- zres$Reservoir
rho_def <- suppressWarnings(cor.test(log10(surface[RES]),
                                     zres[RES, "Deficit_pct"],
                                     method = "spearman"))

size_dependence <- data.frame(
  test = c("Spearman, log10(surface) against the 2024 coefficient",
           "Mann-Whitney, above against below median surface",
           "Spearman, log10(surface) against the native-vegetation deficit"),
  statistic = c(unname(rho$estimate), unname(mw$statistic),
                unname(rho_def$estimate)),
  p = c(rho$p.value, mw$p.value, rho_def$p.value),
  n = c(length(RES), length(RES), length(RES)))
write.csv(size_dependence, file.path(DIR_RESULTS, "size_dependence.csv"),
          row.names = FALSE)
cat(sprintf("Spearman, log10(surface) against the native-vegetation deficit: rho = %.3f, p = %.3f\n",
            unname(rho_def$estimate), rho_def$p.value))
cat("Neither test is significant. The instability of the estimate with respect\n",
    "to set composition is real, but it is not shown to be explained by\n",
    "reservoir size.\n", sep = "")

# Extreme values of the 2024 coefficient, by Tukey's rule (1.5 times the
# interquartile range beyond the quartiles, quantile type 7). Reported so that
# the word "outlier" in the text rests on a stated criterion.
q_coef <- unname(quantile(coef_2024[RES], c(0.25, 0.75)))
iqr_coef <- q_coef[2] - q_coef[1]
fences <- c(q_coef[1] - 1.5 * iqr_coef, q_coef[2] + 1.5 * iqr_coef)
outlier_check <- data.frame(
  Reservoir = display(RES),
  Coefficient_2024_pp = round(coef_2024[RES], 2),
  Lower_fence = round(fences[1], 2),
  Upper_fence = round(fences[2], 2),
  Outside_fences = coef_2024[RES] < fences[1] | coef_2024[RES] > fences[2],
  row.names = NULL)
outlier_check <- outlier_check[order(outlier_check$Coefficient_2024_pp), ]
write.csv(outlier_check, file.path(DIR_RESULTS, "outlier_check.csv"),
          row.names = FALSE)
cat(sprintf("Tukey fences for the 2024 coefficient: %.2f to %.2f; outside: %s\n",
            fences[1], fences[2],
            paste(outlier_check$Reservoir[outlier_check$Outside_fences],
                  collapse = ", ")))

# -----------------------------------------------------------------------------
# 6b. EVENT STUDY AND TRIPLE DIFFERENCE WITH A STABLE WATERLINE (Table S7)
# -----------------------------------------------------------------------------
# The full event study and the confirmatory quantity recomputed without the
# three reservoirs whose water surface formed during the series. The same
# functions and the same families for the false discovery rate are used, so the
# two tables differ only in the reservoir set.
RES_STABLE <- setdiff(RES, RES_WATERLINE_CHANGED)
event_stable <- do.call(rbind, lapply(setdiff(BENCHMARKS, YEAR_BASE), function(y) {
  r <- paired_test(event[RES_STABLE, as.character(y)], as.character(y))
  cbind(year = y, period = ifelse(y < YEAR_BASE, "before", "after"),
        r[, setdiff(names(r), "quantity")])
}))
for (per in c("before", "after")) {
  i <- event_stable$period == per
  event_stable$q[i] <- fdr(event_stable$p[i])
}
td_stable <- paired_test((d_post - d_pre)[RES_STABLE], "")
td_stable <- cbind(year = NA, period = "triple difference",
                   td_stable[, setdiff(names(td_stable), "quantity")], q = NA)
table_S7 <- rbind(event_stable, td_stable)
write.csv(table_S7, file.path(DIR_RESULTS, "table_S7_stable_waterline.csv"),
          row.names = FALSE)
cat("\n=== EVENT STUDY AND TRIPLE DIFFERENCE, STABLE WATERLINE (n = ",
    length(RES_STABLE), ") ===\n", sep = "")
print(table_S7, row.names = FALSE, digits = 3)

# Water share of the innermost band at each benchmark (Table S8). This is the
# evidence, internal to the land cover series, that the waterline moved at the
# reservoirs listed in RES_WATERLINE_CHANGED and RES_WATERLINE_EARLY.
water_030 <- composition[composition$Band == "0-30 m" &
                         composition$Class == "Water",
                         c("Reservoir", "Year", "Pct_band")]
water_030 <- reshape(water_030, idvar = "Reservoir", timevar = "Year",
                     direction = "wide")
names(water_030) <- sub("^Pct_band\\.", "", names(water_030))
water_030 <- water_030[match(RESERVOIR_ORDER, water_030$Reservoir), ]
water_030[, -1] <- round(water_030[, -1], 1)
water_030$Reservoir <- display(water_030$Reservoir)
write.csv(water_030, file.path(DIR_RESULTS, "water_share_0_30m.csv"),
          row.names = FALSE)

# =============================================================================
# 7. TABLE S3 OF THE SUPPLEMENTARY MATERIAL
# =============================================================================
# Event-study coefficient and surface area for each reservoir. This is the table
# behind Figure 5a, and it lets a reader repeat the sensitivity analysis under
# any other inclusion rule.

table_s3 <- data.frame(
  Reservoir = display(RES),
  `Surface area (ha)` = round(surface[RES], 1),
  `APP band area (ha)` = round(zres[RES, "Area_ha"], 1),
  `Forest in APP band 2011 (%)` = round(M[[BAND_TREATED]][RES, "2011"], 1),
  `Forest in APP band 2024 (%)` = round(M[[BAND_TREATED]][RES, "2024"], 1),
  `Forest in control band 2024 (%)` = round(M[[BAND_CONTROL]][RES, "2024"], 1),
  `Event-study coefficient 2024 (pp)` = round(coef_2024[RES], 2),
  check.names = FALSE, row.names = NULL)
table_s3 <- table_s3[order(table_s3$`Surface area (ha)`), ]
write.csv(table_s3, file.path(DIR_RESULTS, "table_S3_by_reservoir.csv"),
          row.names = FALSE)

cat("\n=== TABLE S3 ===\n")
print(table_s3, row.names = FALSE)
cat("\nNote: coefficients are rounded to two decimals for display. The medians\n",
    "reported in the manuscript are computed on unrounded values, so\n",
    "recomputing from this table returns 1.04 pp rather than 1.05 pp.\n", sep = "")

# =============================================================================
# 8. CONFIGURATION OF THE FOREST CLASS
# =============================================================================
# Composition says how much forest there is; configuration says how it is
# arranged. The two bands are treated separately because they differ in the
# number of reservoirs: Santa Branca retains no forest cell inside the APP
# band at any benchmark, so its metrics are undefined rather than zero and it
# contributes to the control band only.
#
# Correction is applied within each window, across both bands and all eight
# metrics, because they answer one question together and are correlated with
# one another.

configuration <- read.csv(file.path(DIR_DATA, "configuration_series.csv"),
                          stringsAsFactors = FALSE)
METRICS <- c("pland", "np", "pd", "ed", "area_mn", "enn_mn", "cohesion",
             "clumpy")

metric_matrix <- function(band, metric) {
  d <- configuration[configuration$Band == band & configuration$metric == metric,
                     c("Reservoir", "Year", "value")]
  m <- reshape(d, idvar = "Reservoir", timevar = "Year", direction = "wide")
  rownames(m) <- m$Reservoir
  m <- m[, paste0("value.", BENCHMARKS), drop = FALSE]
  colnames(m) <- BENCHMARKS
  keep <- RESERVOIR_ORDER[RESERVOIR_ORDER %in% rownames(m)]
  as.matrix(m[keep, , drop = FALSE])
}

config_rows <- do.call(rbind, lapply(c(BAND_TREATED, BAND_CONTROL), function(b) {
  do.call(rbind, lapply(c("pre", "post"), function(w) {
    yrs <- WINDOWS[[w]]
    do.call(rbind, lapply(METRICS, function(k) {
      m <- metric_matrix(b, k)
      r <- paired_test(rate_per_decade(m, yrs[1], yrs[2]), k)
      cbind(band = b, window = w, r)
    }))
  }))
}))
# The family is the window: the eight metrics in the two bands answer one
# question together, which is whether the arrangement of forest changed in that
# period. Correcting within each band separately would treat the same question
# as two and would be less conservative.
config_rows$q <- ave(config_rows$p, config_rows$window, FUN = fdr)
config_rows$sig <- stars(config_rows$q)

# Triple difference on each metric: the same contrast as the confirmatory
# quantity, applied to arrangement rather than to amount. Restricted to the
# thirteen reservoirs measurable in both bands.
config_td <- do.call(rbind, lapply(METRICS, function(k) {
  mt <- metric_matrix(BAND_TREATED, k)
  mc <- metric_matrix(BAND_CONTROL, k)[rownames(mt), , drop = FALSE]
  dp  <- rate_per_decade(mt, 1985, 2011) - rate_per_decade(mc, 1985, 2011)
  dq  <- rate_per_decade(mt, 2011, 2024) - rate_per_decade(mc, 2011, 2024)
  cbind(band = "triple difference", window = "post minus pre",
        paired_test(dq - dp, k))
}))
config_td$q <- fdr(config_td$p)
config_td$sig <- stars(config_td$q)

configuration_out <- rbind(config_rows, config_td)
write.csv(configuration_out, file.path(DIR_RESULTS, "configuration.csv"),
          row.names = FALSE)

# The trend of clumpiness under the default denominator, which counts the
# analysis frame as class edge. Section 4.4 contrasts it with the corrected
# index; it is computed here so that the contrast rests on a test. Not used in
# any other result.
clumpy_default <- do.call(rbind, lapply(c(BAND_TREATED, BAND_CONTROL), function(b)
  do.call(rbind, lapply(c("pre", "post"), function(w) {
    yrs <- WINDOWS[[w]]
    cbind(band = b, window = w,
          paired_test(rate_per_decade(metric_matrix(b, "clumpy_frame_counted"),
                                      yrs[1], yrs[2]), "clumpy_frame_counted"))
  }))))
write.csv(clumpy_default, file.path(DIR_RESULTS, "clumpy_default_trend.csv"),
          row.names = FALSE)

# Table S2. What the boundary treatment does to clumpiness. The series carries
# the index twice, once with the analysis frame excluded from the adjacency
# denominator and once with it counted, so the effect of that single decision
# can be read across all 216 cases instead of at one reservoir. The comparison
# is reported by band because the distortion is a function of how narrow the
# landscape is: the APP band is 3.3 cells wide, the control band is not.
clumpy_pair <- reshape(
  configuration[configuration$metric %in% c("clumpy", "clumpy_frame_counted"),
                c("Reservoir", "Year", "Band", "metric", "value")],
  idvar = c("Reservoir", "Year", "Band"), timevar = "metric",
  direction = "wide")
names(clumpy_pair)[4:5] <- c("frame_excluded", "frame_counted")

boundary_row <- function(d, label) {
  rel <- 100 * abs(d$frame_counted - d$frame_excluded) / abs(d$frame_excluded)
  data.frame(
    Subset = label, n = nrow(d),
    `Pearson r` = round(cor(d$frame_excluded, d$frame_counted), 3),
    `Median relative difference (%)` = round(median(rel), 1),
    `Values outside [-1, 1], frame excluded` =
      sum(abs(d$frame_excluded) > 1),
    `Values outside [-1, 1], frame counted` =
      sum(abs(d$frame_counted) > 1),
    check.names = FALSE)
}
table_s2 <- rbind(
  boundary_row(clumpy_pair, "All cases"),
  boundary_row(clumpy_pair[clumpy_pair$Band == BAND_TREATED, ],
               "APP band, 0 to 100 m, 3.3 cells wide"),
  boundary_row(clumpy_pair[clumpy_pair$Band == BAND_CONTROL, ],
               "Control band, 100 to 500 m"))
write.csv(table_s2, file.path(DIR_RESULTS, "table_S2_boundary_effect.csv"),
          row.names = FALSE)

cat("\n=== TABLE S2: effect of the boundary treatment on clumpiness ===\n")
print(table_s2, row.names = FALSE)

cat("\n=== CONFIGURATION (per decade) ===\n")
print(configuration_out[, c("band", "window", "quantity", "n", "median",
                            "same_sign", "q", "sig")],
      row.names = FALSE, digits = 3)

# =============================================================================
# 9. COMPLIANCE OF THE APP BAND AND THE 2008 TRANSITION
# =============================================================================
# Two quantities that the manuscript reports separately and that must not be
# merged. The native-vegetation deficit is the complement of forest cover over
# the terrestrial area of the APP band (0-100 m, the 100 m standard of CONAMA
# Resolution 302/2002 for rural reservoirs, used as a common reference rather
# than as the licensed width of each reservoir): the Code requires native
# vegetation across the full width of the APP, so the deficit admits no
# threshold. Reaching 25% forest cover is an
# ecological criterion drawn from the fragmentation literature and carries no
# legal status.

table_6 <- data.frame(
  Reservoir = display(zres$Reservoir),
  `Surface (ha)` = round(surface[zres$Reservoir], 1),
  `APP band (ha)` = round(zres$Area_ha, 1),
  `Forest (%)` = round(zres$Forest_pct, 1),
  `Native-vegetation deficit (%)` = round(zres$Deficit_pct, 1),
  `Meets 25%` = ifelse(zres$Meets_25pct_threshold %in% c("True", "TRUE", TRUE),
                       "Yes", "No"),
  check.names = FALSE, row.names = NULL)
table_6 <- table_6[order(table_6$`Forest (%)`), ]
table_6 <- rbind(table_6, data.frame(
  Reservoir = "Median", `Surface (ha)` = NA, `APP band (ha)` = NA,
  `Forest (%)` = round(median(zres$Forest_pct), 1),
  `Native-vegetation deficit (%)` = round(median(zres$Deficit_pct), 1),
  `Meets 25%` = paste(sum(table_6$`Meets 25%` == "Yes"), "of", nrow(table_6)),
  check.names = FALSE))
write.csv(table_6, file.path(DIR_RESULTS, "table_6_compliance.csv"),
          row.names = FALSE)

cat("\n=== TABLE 6: native vegetation in the APP band ===\n")
print(table_6, row.names = FALSE)

# Property level. Two of the 199 registered holdings that intersect the buffers
# hold no land inside the APP band, so they admit no deficit and appear in the
# transition table only.
zprop <- zones[zones$Zone_type == "APP_band_property", ]

transitions <- read.csv(file.path(DIR_DATA, "cadastral_transitions.csv"),
                        stringsAsFactors = FALSE)
CATS <- c("Consolidated_in_use_ha", "Consolidated_restored_ha",
          "Cleared_after_2008_ha", "Native_retained_ha")

# One denominator throughout: the land of the APP band inside registered
# holdings that the 2008 to 2024 cross-tabulation classifies. Reporting the
# 2008 anthropic share over a wider total would make the four categories and
# the summary figure disagree by construction.
land_classified <- sum(transitions[, CATS])
share <- 100 * colSums(transitions[, CATS]) / land_classified

cadastral <- data.frame(
  quantity = c("Registered holdings intersecting the buffers",
               "Holdings with terrestrial area in the APP band",
               "Median native-vegetation deficit, property level (%)",
               "Holdings reaching 25% forest cover (%)",
               "APP-band land classified (ha)",
               "Consolidated and still in use (%)",
               "Consolidated and since restored (%)",
               "Cleared after 22 July 2008 (%)",
               "Native cover retained (%)",
               "Anthropic before the cut-off (%)",
               "Cleared after the cut-off (ha)",
               "Holdings with clearing after the cut-off"),
  value = c(nrow(transitions), nrow(zprop),
            round(median(zprop$Deficit_pct), 1),
            round(100 * mean(zprop$Meets_25pct_threshold %in%
                               c("True", "TRUE", TRUE)), 1),
            round(land_classified, 1),
            round(share[["Consolidated_in_use_ha"]], 1),
            round(share[["Consolidated_restored_ha"]], 1),
            round(share[["Cleared_after_2008_ha"]], 1),
            round(share[["Native_retained_ha"]], 1),
            round(share[["Consolidated_in_use_ha"]] +
                    share[["Consolidated_restored_ha"]], 1),
            round(sum(transitions$Cleared_after_2008_ha), 1),
            sum(transitions$Cleared_after_2008_ha > 0)))

# Split by holding size, which is what Article 61-A turns on.
by_class <- do.call(rbind, lapply(sort(unique(transitions$Fiscal_module_class)),
  function(k) {
    d <- transitions[transitions$Fiscal_module_class == k, ]
    sh <- 100 * colSums(d[, CATS]) / sum(d[, CATS])
    data.frame(quantity = paste0(k, ": ",
                 c("consolidated and still in use (%)",
                   "consolidated and since restored (%)",
                   "cleared after the cut-off (%)",
                   "native cover retained (%)",
                   "share of the declared area within the buffers (%)",
                   "holdings")),
               value = c(round(sh, 1),
                         round(100 * sum(d$Declared_area_ha) /
                                 sum(transitions$Declared_area_ha), 1),
                         nrow(d)))
  }))
cadastral <- rbind(cadastral, by_class)
write.csv(cadastral, file.path(DIR_RESULTS, "cadastral_summary.csv"),
          row.names = FALSE)

cat("\n=== CADASTRAL MODULE ===\n")
print(cadastral, row.names = FALSE)

# =============================================================================
# STATISTICAL POWER (added during revision)
# =============================================================================
# With fourteen paired units, a non-significant result says little unless the
# effect the design could have detected is known. Power of the signed-rank test
# is estimated by simulation: the observed values are centred on their median,
# so that the null hypothesis holds, a shift delta is added, and fourteen values
# are drawn with replacement. The share of draws with p < 0.05 is the power at
# that shift, and the minimum detectable effect is the smallest shift with a
# power of at least 0.8. The same draws are reused for every shift, so the power
# curve is monotone up to simulation error.
# The signed-rank p value is computed directly, with the normal approximation
# and tie correction that wilcox.test(exact = FALSE, correct = FALSE) uses, so
# that the 400,000 tests run in seconds; the result is identical.
signed_rank_p <- function(x) {
  x <- x[x != 0]
  n <- length(x)
  if (n == 0) return(1)
  r <- rank(abs(x))
  v <- sum(r[x > 0])
  ties <- rle(sort(abs(x)))$lengths
  sigma <- sqrt(n * (n + 1) * (2 * n + 1) / 24 - sum(ties^3 - ties) / 48)
  if (sigma == 0) return(1)
  2 * pnorm(-abs((v - n * (n + 1) / 4) / sigma))
}
power_at <- function(x0, idx, d) mean(apply(idx, 1, function(i) signed_rank_p(x0[i] + d) < 0.05))
# Coarse grid in steps of 0.5, then steps of 0.05 inside the interval where the
# power first reaches 0.8; power rises with the shift, so this finds the same
# value as a full grid in steps of 0.05.
power_check_one <- function(label, x, n_sim = 2000) {
  x0 <- x - median(x)
  set.seed(SEED)
  idx <- matrix(sample.int(length(x0), n_sim * length(x0), replace = TRUE), nrow = n_sim)
  coarse <- seq(0, 10, by = 0.5)
  pc <- sapply(coarse, function(d) power_at(x0, idx, d))
  k <- which(pc >= 0.8)[1]
  fine <- seq(coarse[k - 1], coarse[k], by = 0.05)
  pf <- sapply(fine, function(d) power_at(x0, idx, d))
  data.frame(quantity = label, n = length(x), observed_median = round(median(x), 2),
             mde_80 = fine[which(pf >= 0.8)[1]],
             power_at_observed = round(power_at(x0, idx, round(abs(median(x)) / 0.05) * 0.05), 2))
}
power_rows <- list(
  power_check_one("Event-study coefficient, 2024 (pp)", coef_2024[RES]),
  power_check_one("Triple difference (pp per decade)", d_post - d_pre))
power_check <- do.call(rbind, power_rows)
write.csv(power_check, file.path(DIR_RESULTS, "power_check.csv"), row.names = FALSE)
cat("\n=== STATISTICAL POWER ===\n")
print(power_check, row.names = FALSE)

# =============================================================================
# CHECKS ON THE DEFINITIONS (added during revision)
# =============================================================================
# Four quantities that bound how the cadastral results are read.
# 1. The deficit is the complement of forest cover, so native non-forest
#    vegetation (wetland, grassland, herbaceous sandbank) counts as deficit. Its
#    share of the APP band shows how much that choice matters.
# 2. The 25% ecological threshold against the value of about 30% reported for
#    the Atlantic Forest.
# 3. The control band lies outside the reservoir APP but crosses the APPs of
#    watercourses. The declared APP inside it is a lower bound on that overlap,
#    because declarations are incomplete.
# 4. Distinct holdings behind the 199 holding records, and the share of the
#    APP band that falls inside them. Declared holdings can overlap, so that
#    share is an upper bound on the part of the APP band the registry covers.
native_pct <- function(z) 100 * (z$Forest_ha + z$Non_forest_natural_ha) / z$Land_area_ha
nonforest_pct <- 100 * zres$Non_forest_natural_ha / zres$Land_area_ha
declared <- read.csv(file.path(DIR_DATA, "declared_app_zones.csv"),
                     check.names = FALSE, stringsAsFactors = FALSE)
comp_all <- read.csv(file.path(DIR_DATA, "composition_series.csv"),
                     stringsAsFactors = FALSE)
ctrl_2024 <- unique(comp_all[comp_all$Band == BAND_CONTROL & comp_all$Year == 2024,
                             c("Reservoir", "Land_area_ha")])
control_land <- sum(ctrl_2024$Land_area_ha)
declared_in_control <- sum(declared$`Outside the APP band (ha)`)

checks <- data.frame(
  quantity = c(
    "Native non-forest vegetation in the APP band, median across reservoirs (% of land)",
    "Native non-forest vegetation in the APP band, maximum across reservoirs (% of land)",
    "Reservoir with the maximum",
    "Deficit with native non-forest vegetation counted as native, reservoir median (%)",
    "Deficit with native non-forest vegetation counted as native, holding-record median (%)",
    "Reservoirs reaching 30% forest cover in the APP band",
    "Holding records reaching 30% forest cover (%)",
    "Declared APP in the control band (ha)",
    "Land area of the control band, 2024 (ha)",
    "Declared APP in the control band (% of its land area)",
    "Distinct holdings among the holding records",
    "Distinct holdings with clearing after the cut-off",
    "APP-band land inside holding records (ha)",
    "APP-band land inside holding records (% of the APP-band land)"),
  value = c(
    round(median(nonforest_pct), 1),
    round(max(nonforest_pct), 1),
    display(zres$Reservoir[which.max(nonforest_pct)]),
    round(median(100 - native_pct(zres)), 1),
    round(median(100 - native_pct(zprop)), 1),
    sum(zres$Forest_pct >= 30),
    round(100 * mean(zprop$Forest_pct >= 30), 1),
    round(declared_in_control, 1),
    round(control_land, 1),
    round(100 * declared_in_control / control_land, 1),
    length(unique(transitions$Holding_id)),
    length(unique(transitions$Holding_id[transitions$Cleared_after_2008_ha > 0])),
    round(land_classified, 1),
    round(100 * land_classified / sum(zres$Land_area_ha), 1)),
  stringsAsFactors = FALSE)
write.csv(checks, file.path(DIR_RESULTS, "definition_checks.csv"), row.names = FALSE)

cat("\n=== CHECKS ON THE DEFINITIONS ===\n")
print(checks, row.names = FALSE)

cat("\nComplete. Output written to ", DIR_RESULTS, "\n", sep = "")
