# ============================================================================
# SCRIPT: Ecological Hotspot Synthesis
# AUTHOR: Oluwadamilola Ogundipe
#
# PURPOSE
#   Synthesises species/habitat suitability layers by calculating the number
#   of layers in which each cell falls within the top-third suitability class.
#   The resulting overlap surface is classified into ecological hotspot tiers.
#
# INPUTS
#   - Binary top-third suitability rasters (.tif)
#
# OUTPUTS
#   - Raster of classified ecological hotspot levels
#
# ANALYTICAL LOGIC
#   1. Stack binary suitability rasters.
#   2. Count the number of layers contributing to each cell.
#   3. Classify cells into low, moderate and high hotspot categories.
#
# SOFTWARE
#   R >= 4.1
#
# PACKAGE
#   terra
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

# Set the project directory before running.
# For the public GitHub version, this should point to a local project copy.
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

# Input directory containing binary top-third suitability rasters
binary_dir <- file.path(
  project_dir,
  "data",
  "top_third_binary"
)

# Output directory
output_dir <- file.path(
  project_dir,
  "outputs",
  "hotspot_synthesis"
)

# Hotspot classification thresholds
moderate_hotspot_threshold <- 8
high_hotspot_threshold <- 15


# ----------------------------------------------------------------------------
# 3. VALIDATE INPUTS
# ----------------------------------------------------------------------------

if (!dir.exists(binary_dir)) {
  stop(
    "Input directory not found: ",
    binary_dir,
    call. = FALSE
  )
}

binary_files <- list.files(
  binary_dir,
  pattern = "_top_third\\.tif$",
  full.names = TRUE,
  ignore.case = TRUE
)

if (length(binary_files) == 0) {
  stop(
    "No top-third binary rasters were found in: ",
    binary_dir,
    call. = FALSE
  )
}

dir.create(
  output_dir,
  recursive = TRUE,
  showWarnings = FALSE
)

message(
  "Found ",
  length(binary_files),
  " top-third suitability raster(s)."
)


# ----------------------------------------------------------------------------
# 4. LOAD AND VALIDATE RASTERS
# ----------------------------------------------------------------------------

message("Loading binary suitability rasters...")

binary_stack <- rast(binary_files)

# Ensure all rasters are spatially compatible
if (!compareGeom(
  binary_stack,
  stopOnError = FALSE,
  messages = FALSE
)) {
  stop(
    "Input rasters do not have compatible geometry, extent, resolution or CRS.",
    call. = FALSE
  )
}


# ----------------------------------------------------------------------------
# 5. SPATIAL OVERLAP SYNTHESIS
# ----------------------------------------------------------------------------

message("Calculating suitability-layer overlap...")

# Each cell contains the number of binary rasters in which that cell
# belongs to the top-third suitability class.
overlap_count <- sum(
  binary_stack,
  na.rm = TRUE
)


# ----------------------------------------------------------------------------
# 6. HOTSPOT CLASSIFICATION
# ----------------------------------------------------------------------------

message("Classifying ecological hotspot levels...")

hotspots <- classify(
  overlap_count,
  rcl = matrix(
    c(
      0,  0,  NA,
      1,  7,  1,
      8, 14, 2,
      15, Inf, 3
    ),
    ncol = 3,
    byrow = TRUE
  ),
  include.lowest = TRUE
)


# ----------------------------------------------------------------------------
# 7. OUTPUT METADATA
# ----------------------------------------------------------------------------

hotspot_levels <- data.frame(
  class = c(1, 2, 3),
  category = c(
    "Low hotspot",
    "Moderate hotspot",
    "High hotspot"
  ),
  minimum_overlap = c(
    1,
    moderate_hotspot_threshold,
    high_hotspot_threshold
  )
)


# ----------------------------------------------------------------------------
# 8. SAVE RESULTS
# ----------------------------------------------------------------------------

overlap_output <- file.path(
  output_dir,
  "suitability_overlap_count.tif"
)

hotspot_output <- file.path(
  output_dir,
  "ecological_hotspots.tif"
)

metadata_output <- file.path(
  output_dir,
  "hotspot_classification.csv"
)

writeRaster(
  overlap_count,
  overlap_output,
  overwrite = TRUE
)

writeRaster(
  hotspots,
  hotspot_output,
  overwrite = TRUE
)

write.csv(
  hotspot_levels,
  metadata_output,
  row.names = FALSE
)


# ----------------------------------------------------------------------------
# 9. REPORT
# ----------------------------------------------------------------------------

message("")
message("============================================================")
message("Ecological hotspot synthesis complete.")
message("Input rasters: ", length(binary_files))
message("Overlap raster: ", overlap_output)
message("Hotspot raster: ", hotspot_output)
message("Classification metadata: ", metadata_output)
message("============================================================")
