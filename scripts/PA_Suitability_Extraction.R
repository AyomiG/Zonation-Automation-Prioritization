
# SCRIPT: Spatial Filtering of Protected Areas (PAs) Based on SDM Suitability
# AUTHOR: Oluwadamilola Ogundipe
#
# PURPOSE
#   Extracts mean suitability values from species-specific SDM rasters,
#   identifies suitable Protected Areas (PAs) using two alternative
#   suitability thresholds, and rasterizes the selected PAs to the same
#   spatial grid as the SDM raster for use in Zonation 5.
#
# SCENARIOS
#   1. 75th Percentile: PAs above the 75th suitability percentile
#   2. Average: PAs above the mean suitability
#
# INPUTS
#   - oei_betrieb.gpkg
#   - SDM suitability rasters in bin_dv/
#
# OUTPUTS
#   - Filtered PA shapefiles in p75/ and pavg/
#   - Raster PA masks in p75/ and pavg/
#
# SOFTWARE
#   R >= 4.1
#
# PACKAGE
#   terra
#
# NOTE
#   The original project-specific WSL/OneDrive path has been replaced by a
#   project-relative path so the script can be reused on another machine.
# ============================================================================


# ----------------------------------------------------------------------------
# 1. PACKAGE
# ----------------------------------------------------------------------------

if (!requireNamespace("terra", quietly = TRUE)) {
  stop(
    "Package 'terra' is required but not installed.",
    call. = FALSE
  )
}

library(terra)


# ----------------------------------------------------------------------------
# 2. CONFIGURATION
# ----------------------------------------------------------------------------

# The script is expected to be stored in the project's scripts/ folder.
script_dir <- normalizePath(
  dirname(commandArgs(trailingOnly = FALSE)[
    grep("^--file=", commandArgs(trailingOnly = FALSE))
  ][1]),
  winslash = "/",
  mustWork = FALSE
)

# Project root: one level above scripts/
base_dir <- normalizePath(
  file.path(script_dir, ".."),
  winslash = "/",
  mustWork = FALSE
)

# Protected Area input
shp_path <- file.path(
  base_dir,
  "oei_betrieb.gpkg"
)

# Species SDM rasters
raster_path <- file.path(
  base_dir,
  "bin_dv"
)

# Original output folder names retained
p75_dir <- file.path(
  base_dir,
  "p75"
)

pavg_dir <- file.path(
  base_dir,
  "pavg"
)

# Analysis parameters
minimum_pa_area_ha <- 0.0025
p75 <- 0.75


# ----------------------------------------------------------------------------
# 3. VALIDATE INPUTS
# ----------------------------------------------------------------------------

if (!file.exists(shp_path)) {
  stop(
    "Protected Area dataset not found: ",
    shp_path,
    call. = FALSE
  )
}

if (!dir.exists(raster_path)) {
  stop(
    "SDM raster directory not found: ",
    raster_path,
    call. = FALSE
  )
}

raster_files <- list.files(
  raster_path,
  pattern = "\\.tif$",
  full.names = TRUE,
  ignore.case = TRUE
)

if (length(raster_files) == 0) {
  stop(
    "No SDM raster files were found in: ",
    raster_path,
    call. = FALSE
  )
}

dir.create(
  p75_dir,
  recursive = TRUE,
  showWarnings = FALSE
)

dir.create(
  pavg_dir,
  recursive = TRUE,
  showWarnings = FALSE
)


# ----------------------------------------------------------------------------
# 4. LOAD PROTECTED AREAS
# ----------------------------------------------------------------------------

message("Loading Protected Areas...")

pa <- vect(shp_path)

if (!"ha" %in% names(pa)) {
  stop(
    "The Protected Area dataset does not contain the required 'ha' field.",
    call. = FALSE
  )
}

if (is.na(crs(pa)) || crs(pa) == "") {
  stop(
    "The Protected Area dataset does not have a valid CRS.",
    call. = FALSE
  )
}


# ----------------------------------------------------------------------------
# 5. FILTER PROTECTED AREAS
# ----------------------------------------------------------------------------

pa <- pa[
  !is.na(pa$ha) &
    pa$ha >= minimum_pa_area_ha,
]

if (nrow(pa) == 0) {
  stop(
    "No Protected Areas remain after the minimum-area filter.",
    call. = FALSE
  )
}

message(
  "Protected Areas retained after area filter: ",
  nrow(pa)
)


# ----------------------------------------------------------------------------
# 6. PROCESS EACH SDM RASTER
# ----------------------------------------------------------------------------

message(
  "Processing ",
  length(raster_files),
  " SDM raster(s)..."
)

for (i in seq_along(raster_files)) {

  raster_file <- raster_files[i]

  message(
    "[", i, "/", length(raster_files), "] ",
    basename(raster_file)
  )


  # --------------------------------------------------------------------------
  # 6.1 READ SDM RASTER
  # --------------------------------------------------------------------------

  sm <- rast(raster_file)

  if (nlyr(sm) != 1) {
    warning(
      "More than one layer found in ",
      basename(raster_file),
      "; using the first layer."
    )

    sm <- sm[[1]]
  }

  if (is.na(crs(sm)) || crs(sm) == "") {
    stop(
      "SDM raster has no valid CRS: ",
      basename(raster_file),
      call. = FALSE
    )
  }


  # --------------------------------------------------------------------------
  # 6.2 MATCH PA CRS TO SDM CRS
  # --------------------------------------------------------------------------

  pa_sdm <- pa

  if (!same.crs(sm, pa_sdm)) {

    message("  Transforming Protected Areas to SDM CRS.")

    pa_sdm <- project(
      pa_sdm,
      crs(sm)
    )
  }


  # --------------------------------------------------------------------------
  # 6.3 EXTRACT MEAN SDM SUITABILITY FOR EACH PA
  # --------------------------------------------------------------------------

  suitability_score <- terra::extract(
    sm,
    pa_sdm,
    fun = mean,
    na.rm = TRUE
  )

  if (ncol(suitability_score) < 2) {

    warning(
      "No suitability values were returned for ",
      basename(raster_file),
      "; skipping."
    )

    next
  }

  suitability_column <- names(suitability_score)[2]

  suitability_score$Mean_SM <- suitability_score[[suitability_column]]

  suitability_score <- suitability_score[
    !is.na(suitability_score$Mean_SM),
    c("ID", "Mean_SM")
  ]

  if (nrow(suitability_score) == 0) {

    warning(
      "No valid suitability values found for ",
      basename(raster_file),
      "; skipping."
    )

    next
  }


  # --------------------------------------------------------------------------
  # 6.4 CALCULATE THRESHOLDS
  # --------------------------------------------------------------------------

  p75_threshold <- as.numeric(
    quantile(
      suitability_score$Mean_SM,
      probs = p75,
      na.rm = TRUE,
      names = FALSE
    )
  )

  mean_threshold <- mean(
    suitability_score$Mean_SM,
    na.rm = TRUE
  )


  # --------------------------------------------------------------------------
  # 6.5 ATTACH SUITABILITY SCORES TO PA FEATURES
  # --------------------------------------------------------------------------

  pa_scored <- pa_sdm

  pa_scored$Mean_SM <- NA_real_

  pa_scored$Mean_SM[
    suitability_score$ID
  ] <- suitability_score$Mean_SM


  # --------------------------------------------------------------------------
  # 6.6 APPLY PA SUITABILITY FILTERS
  # --------------------------------------------------------------------------

  # 75th percentile: top 25% of PA segments
  relev_pas_p75 <- pa_scored[
    !is.na(pa_scored$Mean_SM) &
      pa_scored$Mean_SM > p75_threshold,
  ]

  # Average: above-average PA segments
  relev_pas_avg <- pa_scored[
    !is.na(pa_scored$Mean_SM) &
      pa_scored$Mean_SM > mean_threshold,
  ]


  # --------------------------------------------------------------------------
  # 6.7 SAVE FILTERED VECTOR PAs
  # --------------------------------------------------------------------------

  species_name <- tools::file_path_sans_ext(
    basename(raster_file)
  )

  p75_vector <- file.path(
    p75_dir,
    paste0(species_name, ".shp")
  )

  pavg_vector <- file.path(
    pavg_dir,
    paste0(species_name, ".shp")
  )

  writeVector(
    relev_pas_p75,
    p75_vector,
    overwrite = TRUE
  )

  writeVector(
    relev_pas_avg,
    pavg_vector,
    overwrite = TRUE
  )


  # --------------------------------------------------------------------------
  # 6.8 RASTERIZE SELECTED PAs TO THE SDM GRID
  # --------------------------------------------------------------------------

  # The SDM raster is used as the reference grid so that the resulting
  # hierarchical masks have the same extent, resolution and CRS as the
  # suitability data supplied to Zonation.

  pa_p75_raster <- rasterize(
    relev_pas_p75,
    sm,
    field = 1,
    background = 0
  )

  pa_avg_raster <- rasterize(
    relev_pas_avg,
    sm,
    field = 1,
    background = 0
  )


  # --------------------------------------------------------------------------
  # 6.9 SAVE RASTER PA MASKS
  # --------------------------------------------------------------------------

  p75_raster <- file.path(
    p75_dir,
    paste0("result_", species_name, ".tif")
  )

  pavg_raster <- file.path(
    pavg_dir,
    paste0("result_", species_name, ".tif")
  )

  writeRaster(
    pa_p75_raster,
    p75_raster,
    overwrite = TRUE
  )

  writeRaster(
    pa_avg_raster,
    pavg_raster,
    overwrite = TRUE
  )


  # --------------------------------------------------------------------------
  # 6.10 REPORT RESULTS
  # --------------------------------------------------------------------------

  message(
    "  P75 threshold: ",
    round(p75_threshold, 4),
    " | PAs retained: ",
    nrow(relev_pas_p75)
  )

  message(
    "  Mean threshold: ",
    round(mean_threshold, 4),
    " | PAs retained: ",
    nrow(relev_pas_avg)
  )
}


# ----------------------------------------------------------------------------
# 7. COMPLETION
# ----------------------------------------------------------------------------

message("")
message("============================================================")
message("Spatial filtering and PA mask generation complete.")
message("")
message("75th-percentile outputs: ", p75_dir)
message("Above-mean outputs:      ", pavg_dir)
message("Processed SDM rasters:   ", length(raster_files))
message("============================================================")
