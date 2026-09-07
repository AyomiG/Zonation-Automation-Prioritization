 ============================================================================
# SCRIPT 01: PA Suitability Filtering and Mask Generation
# AUTHOR: Oluwadamilola Ogundipe
#
# PURPOSE
#   Extracts mean suitability values from species-specific SDM rasters for
#   existing Protected Areas (PAs), identifies suitable PAs using alternative
#   suitability thresholds, and rasterizes the selected PAs to the analysis
#   grid for use in spatial conservation prioritisation.
#
# SCENARIOS
#   1. 75th percentile: PAs with suitability above the 75th percentile
#   2. Mean suitability: PAs with suitability above the mean
#
# INPUTS
#   - Protected Area vector dataset with an 'ha' area field
#   - Species-specific SDM suitability rasters (.tif)
#   - Reference raster defining the analysis grid
#
# OUTPUTS
#   - Species-specific vector PA selections
#   - Species-specific raster PA masks for each suitability scenario
#
# SOFTWARE
#   R >= 4.1
#
# PACKAGE
#   terra
#
# NOTE
#   Set SDM_PROJECT_DIR to the project root before running. The repository
#   should contain only example/public input data or documented placeholders;
#   WSL/project-specific data should not be committed.
# ============================================================================


# ----------------------------------------------------------------------------
# 1. PACKAGE CHECK
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

# Example:
# Sys.setenv(SDM_PROJECT_DIR = "C:/path/to/your/project")

project_dir <- Sys.getenv("SDM_PROJECT_DIR")

if (project_dir == "") {
  stop(
    paste(
      "Project directory not set.",
      "Set the 'SDM_PROJECT_DIR' environment variable",
      "or replace project_dir with your local project directory."
    ),
    call. = FALSE
  )
}

# Input data
pa_file <- file.path(
  project_dir,
  "data",
  "protected_areas.gpkg"
)

sdm_dir <- file.path(
  project_dir,
  "data",
  "sdm_rasters"
)

# Reference raster used to define resolution, extent and CRS
reference_raster_file <- file.path(
  project_dir,
  "data",
  "reference_grid.tif"
)

# Output directories
vector_p75_dir <- file.path(
  project_dir,
  "outputs",
  "pa_vectors_p75"
)

vector_mean_dir <- file.path(
  project_dir,
  "outputs",
  "pa_vectors_mean"
)

raster_p75_dir <- file.path(
  project_dir,
  "outputs",
  "pa_masks_p75"
)

raster_mean_dir <- file.path(
  project_dir,
  "outputs",
  "pa_masks_mean"
)

# Analysis parameters
minimum_pa_area_ha <- 0.0025
suitability_quantile <- 0.75

# Background value for rasterized PA masks
mask_background <- 0


# ----------------------------------------------------------------------------
# 3. VALIDATE INPUTS
# ----------------------------------------------------------------------------

if (!file.exists(pa_file)) {
  stop(
    "Protected Area input not found: ",
    pa_file,
    call. = FALSE
  )
}

if (!dir.exists(sdm_dir)) {
  stop(
    "SDM raster directory not found: ",
    sdm_dir,
    call. = FALSE
  )
}

if (!file.exists(reference_raster_file)) {
  stop(
    "Reference raster not found: ",
    reference_raster_file,
    call. = FALSE
  )
}

raster_files <- list.files(
  sdm_dir,
  pattern = "\\.tif$",
  full.names = TRUE,
  ignore.case = TRUE
)

if (length(raster_files) == 0) {
  stop(
    "No SDM raster files (.tif) were found in: ",
    sdm_dir,
    call. = FALSE
  )
}

# Create output directories
output_dirs <- c(
  vector_p75_dir,
  vector_mean_dir,
  raster_p75_dir,
  raster_mean_dir
)

for (dir_path in output_dirs) {
  dir.create(
    dir_path,
    recursive = TRUE,
    showWarnings = FALSE
  )
}


# ----------------------------------------------------------------------------
# 4. LOAD PROTECTED AREAS AND REFERENCE GRID
# ----------------------------------------------------------------------------

message("Loading Protected Areas...")

pa <- vect(pa_file)

if (!"ha" %in% names(pa)) {
  stop(
    "The Protected Area dataset must contain an 'ha' field ",
    "containing area in hectares.",
    call. = FALSE
  )
}

if (is.na(crs(pa)) || crs(pa) == "") {
  stop(
    "The Protected Area dataset does not have a valid CRS.",
    call. = FALSE
  )
}

reference_raster <- rast(reference_raster_file)

if (is.na(crs(reference_raster)) || crs(reference_raster) == "") {
  stop(
    "The reference raster does not have a valid CRS.",
    call. = FALSE
  )
}


# ----------------------------------------------------------------------------
# 5. FILTER PROTECTED AREAS
# ----------------------------------------------------------------------------

message(
  "Filtering Protected Areas smaller than ",
  minimum_pa_area_ha,
  " ha..."
)

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

message("Protected Areas retained: ", nrow(pa))


# ----------------------------------------------------------------------------
# 6. PROCESS SPECIES SDM RASTERS
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
  # 6.1 LOAD SDM RASTER
  # --------------------------------------------------------------------------

  sdm <- rast(raster_file)

  if (nlyr(sdm) != 1) {
    warning(
      "Raster contains more than one layer: ",
      basename(raster_file),
      ". Only the first layer will be used."
    )
    sdm <- sdm[[1]]
  }

  if (is.na(crs(sdm)) || crs(sdm) == "") {
    stop(
      "SDM raster has no CRS: ",
      basename(raster_file),
      call. = FALSE
    )
  }


  # --------------------------------------------------------------------------
  # 6.2 TRANSFORM PA GEOMETRY TO SDM CRS
  # --------------------------------------------------------------------------

  pa_sdm <- pa

  if (!same.crs(sdm, pa_sdm)) {
    message(
      "  Transforming Protected Areas to SDM CRS."
    )

    pa_sdm <- project(
      pa_sdm,
      crs(sdm)
    )
  }


  # --------------------------------------------------------------------------
  # 6.3 EXTRACT MEAN SDM SUITABILITY BY PA
  # --------------------------------------------------------------------------

  extracted <- terra::extract(
    sdm,
    pa_sdm,
    fun = mean,
    na.rm = TRUE
  )

  if (ncol(extracted) < 2) {

    warning(
      "No suitability values were returned for: ",
      basename(raster_file),
      ". Skipping."
    )

    next
  }

  suitability_column <- names(extracted)[2]

  extracted$mean_suitability <- extracted[[suitability_column]]

  extracted <- extracted[
    !is.na(extracted$mean_suitability),
    c("ID", "mean_suitability")
  ]

  if (nrow(extracted) == 0) {

    warning(
      "No valid suitability values found for: ",
      basename(raster_file),
      ". Skipping."
    )

    next
  }


  # --------------------------------------------------------------------------
  # 6.4 CALCULATE THRESHOLDS
  # --------------------------------------------------------------------------

  p75_threshold <- as.numeric(
    quantile(
      extracted$mean_suitability,
      probs = suitability_quantile,
      na.rm = TRUE,
      names = FALSE
    )
  )

  mean_threshold <- mean(
    extracted$mean_suitability,
    na.rm = TRUE
  )


  # --------------------------------------------------------------------------
  # 6.5 MATCH SUITABILITY VALUES BACK TO PA FEATURES
  # --------------------------------------------------------------------------

  pa_with_scores <- pa_sdm

  pa_with_scores$mean_suitability <- NA_real_

  pa_with_scores$mean_suitability[
    extracted$ID
  ] <- extracted$mean_suitability


  # --------------------------------------------------------------------------
  # 6.6 SELECT SUITABLE PAs
  # --------------------------------------------------------------------------

  pa_p75 <- pa_with_scores[
    !is.na(pa_with_scores$mean_suitability) &
      pa_with_scores$mean_suitability > p75_threshold,
  ]

  pa_mean <- pa_with_scores[
    !is.na(pa_with_scores$mean_suitability) &
      pa_with_scores$mean_suitability > mean_threshold,
  ]


  # --------------------------------------------------------------------------
  # 6.7 REPROJECT SELECTED PAs TO ANALYSIS GRID CRS
  # --------------------------------------------------------------------------

  pa_p75_grid <- pa_p75
  pa_mean_grid <- pa_mean

  if (!same.crs(reference_raster, pa_p75_grid)) {

    pa_p75_grid <- project(
      pa_p75_grid,
      crs(reference_raster)
    )

    pa_mean_grid <- project(
      pa_mean_grid,
      crs(reference_raster)
    )
  }


  # --------------------------------------------------------------------------
  # 6.8 CREATE RASTER PA MASKS
  # --------------------------------------------------------------------------

  pa_p75_raster <- rasterize(
    pa_p75_grid,
    reference_raster,
    field = 1,
    background = mask_background
  )

  pa_mean_raster <- rasterize(
    pa_mean_grid,
    reference_raster,
    field = 1,
    background = mask_background
  )


  # --------------------------------------------------------------------------
  # 6.9 CREATE OUTPUT NAMES
  # --------------------------------------------------------------------------

  species_name <- tools::file_path_sans_ext(
    basename(raster_file)
  )

  p75_vector_output <- file.path(
    vector_p75_dir,
    paste0(species_name, ".gpkg")
  )

  mean_vector_output <- file.path(
    vector_mean_dir,
    paste0(species_name, ".gpkg")
  )

  p75_raster_output <- file.path(
    raster_p75_dir,
    paste0("result_", species_name, ".tif")
  )

  mean_raster_output <- file.path(
    raster_mean_dir,
    paste0("result_", species_name, ".tif")
  )


  # --------------------------------------------------------------------------
  # 6.10 SAVE VECTOR AND RASTER OUTPUTS
  # --------------------------------------------------------------------------

  writeVector(
    pa_p75,
    p75_vector_output,
    overwrite = TRUE
  )

  writeVector(
    pa_mean,
    mean_vector_output,
    overwrite = TRUE
  )

  writeRaster(
    pa_p75_raster,
    p75_raster_output,
    overwrite = TRUE
  )

  writeRaster(
    pa_mean_raster,
    mean_raster_output,
    overwrite = TRUE
  )


  # --------------------------------------------------------------------------
  # 6.11 REPORT RESULTS
  # --------------------------------------------------------------------------

  message(
    "  Valid PAs: ", nrow(extracted),
    " | P75 threshold: ", round(p75_threshold, 4),
    " | Mean threshold: ", round(mean_threshold, 4)
  )

  message(
    "  P75 PAs retained: ", nrow(pa_p75),
    " | Above-mean PAs retained: ", nrow(pa_mean)
  )
}


# ----------------------------------------------------------------------------
# 7. COMPLETION MESSAGE
# ----------------------------------------------------------------------------

message("")
message("============================================================")
message("PA suitability filtering and mask generation complete.")
message("")
message("75th-percentile vector masks: ", vector_p75_dir)
message("Above-mean vector masks:      ", vector_mean_dir)
message("75th-percentile raster masks: ", raster_p75_dir)
message("Above-mean raster masks:      ", raster_mean_dir)
message("============================================================")
