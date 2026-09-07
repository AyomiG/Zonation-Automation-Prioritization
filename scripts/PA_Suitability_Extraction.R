# ============================================================================
# SCRIPT: Spatial Filtering of Protected Areas Based on SDM Suitability
# AUTHOR: Oluwadamilola Ogundipe
#
# PURPOSE
#   Extract mean suitability values from species-specific SDM rasters for
#   existing Protected Areas (PAs), then create species-specific PA masks
#   using:
#     1. 75th percentile suitability (top 25% of suitable PAs)
#     2. Mean suitability (above-average PAs)
#
# INPUTS
#   - Protected Area vector dataset
#   - Species-specific SDM suitability rasters (.tif)
#
# OUTPUTS
#   - Species-specific PA masks using the 75th percentile threshold
#   - Species-specific PA masks using the mean suitability threshold
#
# SOFTWARE
#   R >= 4.1
#
# PACKAGE
#   terra
#
# NOTES
#   Set SDM_PROJECT_DIR to the local project root before running.
#   Project-specific WSL/OneDrive paths are intentionally not hard-coded.
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

# Set this to the root directory of the project.
# Windows example:
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

# Input locations
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

# Output locations
p75_dir <- file.path(
  project_dir,
  "outputs",
  "pa_masks_p75"
)

pavg_dir <- file.path(
  project_dir,
  "outputs",
  "pa_masks_mean"
)

# Analysis parameters
minimum_pa_area_ha <- 0.0025
suitability_quantile <- 0.75


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

  if (is.na(crs(sdm)) || crs(sdm) == "") {
    stop(
      "SDM raster has no CRS: ",
      basename(raster_file),
      call. = FALSE
    )
  }


  # --------------------------------------------------------------------------
  # 6.2 MATCH PA CRS TO SDM CRS
  # --------------------------------------------------------------------------

  pa_for_extraction <- pa

  if (!same.crs(sdm, pa_for_extraction)) {

    message(
      "  CRS differs; transforming Protected Areas to SDM CRS."
    )

    pa_for_extraction <- project(
      pa_for_extraction,
      crs(sdm)
    )
  }


  # --------------------------------------------------------------------------
  # 6.3 EXTRACT MEAN SDM SUITABILITY FOR EACH PA
  # --------------------------------------------------------------------------

  extracted <- terra::extract(
    sdm,
    pa_for_extraction,
    fun = mean,
    na.rm = TRUE
  )

  suitability_column <- names(extracted)[2]

  extracted$mean_suitability <- extracted[[suitability_column]]


  # --------------------------------------------------------------------------
  # 6.4 REMOVE PAs WITHOUT VALID SUITABILITY VALUES
  # --------------------------------------------------------------------------

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
  # 6.5 CALCULATE SUITABILITY THRESHOLDS
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
  # 6.6 MATCH SUITABILITY VALUES BACK TO PA FEATURES
  # --------------------------------------------------------------------------

  pa_with_scores <- pa_for_extraction

  pa_with_scores$mean_suitability <- NA_real_

  pa_with_scores$mean_suitability[
    extracted$ID
  ] <- extracted$mean_suitability


  # --------------------------------------------------------------------------
  # 6.7 APPLY 75TH-PERCENTILE FILTER
  # --------------------------------------------------------------------------

  pa_p75 <- pa_with_scores[
    !is.na(pa_with_scores$mean_suitability) &
      pa_with_scores$mean_suitability > p75_threshold,
  ]


  # --------------------------------------------------------------------------
  # 6.8 APPLY ABOVE-MEAN FILTER
  # --------------------------------------------------------------------------

  pa_mean <- pa_with_scores[
    !is.na(pa_with_scores$mean_suitability) &
      pa_with_scores$mean_suitability > mean_threshold,
  ]


  # --------------------------------------------------------------------------
  # 6.9 CREATE CLEAN OUTPUT NAMES
  # --------------------------------------------------------------------------

  species_name <- tools::file_path_sans_ext(
    basename(raster_file)
  )

  p75_output <- file.path(
    p75_dir,
    paste0(species_name, ".gpkg")
  )

  mean_output <- file.path(
    pavg_dir,
    paste0(species_name, ".gpkg")
  )


  # --------------------------------------------------------------------------
  # 6.10 SAVE RESULTS
  # --------------------------------------------------------------------------

  writeVector(
    pa_p75,
    p75_output,
    overwrite = TRUE
  )

  writeVector(
    pa_mean,
    mean_output,
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
message("Spatial filtering complete.")
message("P75 masks:  ", p75_dir)
message("Mean masks: ", pavg_dir)
message("============================================================")
