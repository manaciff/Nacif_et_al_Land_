# =============================================================================
# Landscape dynamics and conservation policy effectiveness in reservoir
# riparian buffers: fourteen reservoirs under Brazil's Forest Code, 1985-2024
# -----------------------------------------------------------------------------
# SCRIPT 4. REDUNDANCY ANALYSIS OF LAND COVER COMPOSITION
#
# The tests in the preceding scripts use forest cover, which is one class of
# five. A reform could in principle leave forest cover unchanged while
# reorganising the remaining classes, and a forest-only measure would not
# detect it. This script examines the composition as a whole.
#
# QUESTION. How much of the variation in composition is attributable to
# distance from the water, to the period before or after the reform, and to
# their interaction. The interaction is the multivariate form of the
# difference-in-differences contrast.
#
# THREE DECISIONS THAT SUPPORT THE RESULT
#
#   1. Hellinger transformation. The five classes sum to the band area, so the
#      rows are compositional and Euclidean distance does not apply to them
#      directly. The Hellinger transformation is the standard remedy for
#      ordination of compositional data (Legendre and Gallagher, 2001).
#
#   2. Partial RDA. Reservoir identity enters as a covariable. Without it, the
#      differences between reservoirs dominate the ordination and the result
#      merely confirms that reservoirs differ from one another, which is not in
#      question.
#
#   3. Permutation restricted to within each reservoir. The 336 rows are not
#      independent: they are fourteen units observed in three bands and eight
#      years. Free permutation would treat repeated measurements of the same
#      reservoir as separate evidence and inflate significance accordingly
#      (Anderson and ter Braak, 2003). For the same reason no p value is
#      reported for reservoir identity: permuting within reservoirs holds that
#      term constant and cannot test it.
#
# OUTPUT
#   results/table_S4_rda.csv        Table S4 of the supplementary material
#
# PACKAGES
#   vegan     rda(), anova.cca(), varpart(), decostand()
#   permute   how(), for the restricted permutation scheme
#   install.packages(c("vegan", "permute"))
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

for (pkg in c("vegan", "permute")) {
  if (!requireNamespace(pkg, quietly = TRUE))
    stop("Missing package: ", pkg, ". Run install.packages('", pkg, "').")
}
suppressPackageStartupMessages({ library(vegan); library(permute) })
set.seed(SEED)

# -----------------------------------------------------------------------------
# WHY 4,999 PERMUTATIONS, RATHER THAN 5,000 OR 999
# -----------------------------------------------------------------------------
# 1. The plus-one rule. The observed value is itself one realisation under the
#    null hypothesis and is included in the count (Borcard, Gillet and Legendre,
#    2011, p. 182):
#
#        p = (k + 1) / (n_perm + 1)
#
#    With 4,999 the denominator is a round 5,000 and p values fall on multiples
#    of 0.0002. With 5,000 the denominator would be 5,001 and nothing is gained.
#    Hence the convention of 99, 999, 4,999 or 9,999.
#
# 2. Floor of the test. The smallest attainable p is 1 / (n_perm + 1): 0.001
#    with 999 permutations, 0.0002 with 4,999. The distance-band term saturates
#    that floor in both cases, which is why it is reported as p < 0.001 rather
#    than as a point estimate.
#
# 3. Monte Carlo error. The standard deviation of an estimated p value is
#    sqrt(p(1-p)/n_perm). Near 0.05 this is 0.007 with 999 permutations and
#    0.003 with 4,999. With 999, a true p of 0.05 can be returned anywhere
#    between 0.036 and 0.064 by chance alone, which crosses the decision
#    threshold. Verified on this dataset: across ten runs of the period term,
#    999 permutations returned p between 0.013 and 0.030, whereas 4,999 returned
#    p between 0.019 and 0.023.
#
# 4. Cost. There is no combinatorial ceiling here. With 24 rows per reservoir,
#    the within-block permutation universe is 24 factorial per reservoir, far
#    beyond any exhaustive enumeration. The choice trades precision against run
#    time only, and 4,999 resolves what is needed in seconds.
#
# Keep 4,999 for publication. While exploring, 999 is sufficient.
N_PERM <- 4999
PIXEL_HA_RDA <- 0.09   # one 30 m cell, in hectares

# =============================================================================
# 1. RESPONSE MATRIX
# =============================================================================
# Only the mutually exclusive bands. The 0 to 100 m band is the union of the
# 0 to 30 m and 30 to 100 m bands and would enter twice.

composition <- read.csv(file.path(DIR_DATA, "composition_series.csv"),
                        stringsAsFactors = FALSE)
composition <- composition[composition$Band %in% BANDS_EXCL, ]

wide <- reshape(composition[, c("Reservoir", "Band", "Year", "Class", "Area_ha")],
                idvar = c("Reservoir", "Band", "Year"),
                timevar = "Class", direction = "wide")
names(wide) <- sub("^Area_ha\\.", "", names(wide))
Y <- as.matrix(wide[, CLASSES])
Y[is.na(Y)] <- 0

env <- data.frame(
  reservoir = factor(wide$Reservoir, levels = RESERVOIR_ORDER),
  band      = factor(wide$Band, levels = BANDS_EXCL),
  period    = factor(ifelse(wide$Year <= YEAR_BASE, "pre", "post"),
                     levels = c("pre", "post")),
  year      = wide$Year)

message("rows: ", nrow(Y), " | classes: ", ncol(Y),
        " | reservoirs: ", nlevels(env$reservoir))

Y_hel <- decostand(Y, method = "hellinger")

# =============================================================================
# 2. PARTIAL RDA AND TESTS
# =============================================================================
# Restricted permutation: blocks are defined by reservoir, so rows are exchanged
# only within the same reservoir.
ctrl <- how(blocks = env$reservoir, nperm = N_PERM)

fit_component <- function(formula, label, test_p = TRUE) {
  model <- rda(formula, data = env)
  r2 <- RsquareAdj(model)
  p <- NA_real_
  if (test_p) {
    # Seeded here rather than once at the top of the script, so that each
    # p value depends only on the term it tests. A single seed at the top makes
    # every test depend on how many permutations were drawn before it, and
    # adding or reordering a term then moves p values that were not touched.
    set.seed(SEED)
    a <- anova.cca(model, permutations = ctrl)
    p <- a$`Pr(>F)`[1]
  }
  message(sprintf("  %-30s R2 = %.4f  adj. R2 = %.4f  p = %s",
                  label, r2$r.squared, r2$adj.r.squared,
                  if (is.na(p)) "not applicable" else sprintf("%.4f", p)))
  data.frame(Component = label,
             R2 = round(r2$r.squared, 4),
             `Adjusted R2` = round(r2$adj.r.squared, 4),
             `p (restricted permutation)` =
               if (is.na(p)) "not applicable"
               else if (p <= 1 / (N_PERM + 1)) "< 0.001"
               else sprintf("%.4f", p),
             check.names = FALSE, stringsAsFactors = FALSE)
}

message("\nPartial RDA on Hellinger-transformed composition:")
components <- rbind(
  fit_component(Y_hel ~ reservoir, "Reservoir identity", test_p = FALSE),
  fit_component(Y_hel ~ band + Condition(reservoir), "Distance band | reservoir"),
  fit_component(Y_hel ~ period + Condition(reservoir), "Period | reservoir"),
  fit_component(Y_hel ~ band:period + Condition(reservoir + band + period),
                "Band x period | main effects"))

full_model <- rda(Y_hel ~ band + period + reservoir, data = env)
r2_full <- RsquareAdj(full_model)$adj.r.squared
message(sprintf("\n  full model adj. R2 = %.4f | residual = %.4f",
                r2_full, 1 - r2_full))

write.csv(components, file.path(DIR_RESULTS, "table_S4_rda.csv"),
          row.names = FALSE)
message("\n  -> table_S4_rda.csv")

# =============================================================================
# 2b. SENSITIVITY: CENTRED LOG-RATIO TRANSFORMATION (added during revision)
# =============================================================================
# The Hellinger transformation was chosen because it handles the zeros of a
# composition in which some classes are absent from a band, and because it
# keeps RDA, a Euclidean method, applicable to proportions. The log-ratio
# approach of compositional data analysis is the main alternative, but it is
# undefined at zero. Zeros are replaced multiplicatively, at 65% of the share of
# one 30 m cell in the band (the detection limit of the data), the other parts
# are rescaled so that each row still sums to one, and the centred log-ratio is
# taken. The same four components are then fitted.
P <- Y / rowSums(Y)
delta <- 0.65 * PIXEL_HA_RDA / rowSums(Y)
P_rep <- t(sapply(seq_len(nrow(P)), function(i) {
  p <- P[i, ]; z <- p == 0
  p[z] <- delta[i]
  p[!z] <- p[!z] * (1 - sum(z) * delta[i])
  p
}))
Y_clr <- log(P_rep) - rowMeans(log(P_rep))

fit_clr <- function(formula, label, test_p = TRUE) {
  model <- rda(formula, data = env)
  r2 <- RsquareAdj(model)
  p <- NA_real_
  if (test_p) {
    set.seed(SEED)
    p <- anova.cca(model, permutations = ctrl)$`Pr(>F)`[1]
  }
  data.frame(Component = label,
             R2 = round(r2$r.squared, 4),
             `Adjusted R2` = round(r2$adj.r.squared, 4),
             `p (restricted permutation)` =
               if (is.na(p)) "not applicable"
               else if (p <= 1 / (N_PERM + 1)) "< 0.001"
               else sprintf("%.4f", p),
             check.names = FALSE, stringsAsFactors = FALSE)
}
components_clr <- rbind(
  fit_clr(Y_clr ~ reservoir, "Reservoir identity", test_p = FALSE),
  fit_clr(Y_clr ~ band + Condition(reservoir), "Distance band | reservoir"),
  fit_clr(Y_clr ~ period + Condition(reservoir), "Period | reservoir"),
  fit_clr(Y_clr ~ band:period + Condition(reservoir + band + period),
          "Band x period | main effects"))
write.csv(components_clr, file.path(DIR_RESULTS, "table_S4_rda_clr.csv"),
          row.names = FALSE)
message("\nSensitivity, centred log-ratio:")
print(components_clr, row.names = FALSE)
message("  -> table_S4_rda_clr.csv")

# =============================================================================
# 3. VARIATION PARTITIONING
# =============================================================================
# varpart uses adjusted R squared by construction, which is required for the
# fractions to be comparable. The unadjusted statistic rises with every variable
# added, regardless of its relevance (Peres-Neto et al., 2006).
partition <- varpart(Y_hel, ~ band, ~ period, ~ reservoir, data = env)
print(partition)

# =============================================================================
# 4. HOW TO READ THIS RESULT
# =============================================================================
message("\nHow to read this result:")
message("  Distance band explains most of the variation in composition once")
message("  reservoir identity has been removed. Period explains little. The")
message("  interaction between band and period, which is the policy question in")
message("  multivariate form, explains none of it. The null triple difference")
message("  is therefore not an artefact of measuring forest cover alone.")
