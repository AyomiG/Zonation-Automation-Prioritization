# ============================================================================
# SCRIPT 02: Ecological Hotspot Synthesis
# AUTHOR: Oluwadamilola Ogundipe
#
# PURPOSE
#   Identifies areas of concentrated ecological suitability by stacking
#   binary top-third suitability rasters and calculating the number of
#   layers contributing to each spatial cell.
#
#   Cells are subsequently classified into three hotspot levels:
#     1 = Low hotspot
#     2 = Moderate hotspot
#     3 = High hotspot
#
# INPUTS
#   - Binary top-third suitability rasters (.tif)
#
# OUTPUTS
#   - Raster showing the number of overlapping suitability layers
#   - Classified ecological hotspot raster
#   - CSV documenting hotspot classification thresholds
#
# SOFTWARE
#   R >= 4.1
#
# PACKAGE
#   terra
#
# NOTES
#   Input rasters must share the same CRS, extent, resolution and grid.
#   Set SDM_PROJECT_DIR to the project root before running.
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

# Directory containing binary top-third suitability rasters
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

# Hotspot thresholds
moderate_threshold <- 8
high_threshold <- 15


# ----------------------------------------------------------------------------
# 3. VALIDATE INPUT DIRECTORY
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
    "No top-third binary suitability rasters were found in: ",
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
  " binary suitability raster(s)."
)


# ----------------------------------------------------------------------------
# 4. LOAD RASTERS
# ----------------------------------------------------------------------------

message("Loading suitability rasters...")

binary_stack <- rast(binary_files)


# ----------------------------------------------------------------------------
# 5. CHECK SPATIAL COMPATIBILITY
# ----------------------------------------------------------------------------

message("Checking raster geometry...")

if (!compareGeom(
  binary_stack,
  stopOnError = FALSE,
  messages = FALSE
)) {
  stop(
    paste(
      "Input rasters do not have matching spatial geometry.",
      "Check CRS, extent, resolution and raster alignment."
    ),
    call. = FALSE
  )
}


# ----------------------------------------------------------------------------
# 6. CALCULATE SPATIAL OVERLAP
# ----------------------------------------------------------------------------

message("Calculating suitability-layer overlap...")

# Each cell contains the number of binary suitability rasters
# in which that cell belongs to the top-third suitability class.
overlap_count <- sum(
  binary_stack,
  na.rm = TRUE
)


# ----------------------------------------------------------------------------
# 7. CLASSIFY ECOLOGICAL HOTSPOTS
# ----------------------------------------------------------------------------

message("Classifying ecological hotspots...")

hotspots <- app(
  overlap_count,
  fun = function(x) {

    ifelse(
      is.na(x),
      NA,
      ifelse(
        x >= high_threshold,
        3,
        ifelse(
          x >= moderate_threshold,
          2,
          ifelse(
            x >= 1,
            1,
            NA
          )
        )
      )
    )
  }
)


# ----------------------------------------------------------------------------
# 8. CREATE CLASSIFICATION METADATA
# ----------------------------------------------------------------------------

hotspot_metadata <- data.frame(
  class = c(1, 2, 3),
  category = c(
    "Low hotspot",
    "Moderate hotspot",
    "High hotspot"
  ),
  overlap_range = c(
    paste0("1-", moderate_threshold - 1),
    paste0(moderate_threshold, "-", high_threshold - 1),
    paste0(high_threshold, "+")
  )
)


# ----------------------------------------------------------------------------
# 9. DEFINE OUTPUT FILES
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


# ----------------------------------------------------------------------------
# 10. SAVE OUTPUTS
# ----------------------------------------------------------------------------

message("Writing output rasters...")

writeRaster(
  overlap_count,
  filename = overlap_output,
  overwrite = TRUE
)

writeRaster(
  hotspots,
  filename = hotspot_output,
  overwrite = TRUE
)

write.csv(
  hotspot_metadata,
  file = metadata_output,
  row.names = FALSE
)


# ----------------------------------------------------------------------------
# 11. REPORT SUMMARY
# ----------------------------------------------------------------------------

message("")
message("============================================================")
message("Ecological hotspot synthesis complete.")
message("")
message("Input rasters: ", length(binary_files))
message("Overlap output: ", overlap_output)
message("Hotspot output: ", hotspot_output)
message("Metadata:       ", metadata_output)
message("")
message(
  "Classification: 1 = Low | 2 = Moderate | 3 = High"
)
message("============================================================")
