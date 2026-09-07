# ============================================================================
# SCRIPT 02: Ecological Hotspot Synthesis
# AUTHOR: Oluwadamilola Ogundipe
#
# PURPOSE
#   Identifies areas of concentrated ecological suitability by stacking
#   binary top-third suitability rasters and calculating the number of
#   suitability layers overlapping at each spatial cell.
#
# INPUTS
#   - Binary top-third suitability rasters
#
# OUTPUTS
#   - Raster showing the number of overlapping suitability layers
#   - Classified ecological hotspot raster
#
# SOFTWARE
#   R >= 4.1
#
# PACKAGE
#   terra
#
# NOTE
#   This is a separate spatial-synthesis demonstration and is not required
#   for the main Zonation automation workflow.
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
script_args <- commandArgs(trailingOnly = FALSE)
script_file <- grep("^--file=", script_args, value = TRUE)

if (length(script_file) > 0) {
  script_dir <- dirname(
    normalizePath(
      sub("^--file=", "", script_file[1]),
      winslash = "/",
      mustWork = FALSE
    )
  )
} else {
  # Fallback for interactive execution in RStudio.
  script_dir <- getwd()
}

# Project root: one level above scripts/
base_dir <- normalizePath(
  file.path(script_dir, ".."),
  winslash = "/",
  mustWork = FALSE
)

# Original analysis folders retained where appropriate
input_f <- file.path(
  base_dir,
  "Final",
  "Comp_F"
)

output_f <- file.path(
  input_f,
  "masked"
)

binary_path <- file.path(
  output_f,
  "top_third_binary"
)

# Output directory
hotspot_output_dir <- file.path(
  output_f,
  "hotspot_synthesis"
)

# Hotspot thresholds
moderate_threshold <- 8
high_threshold <- 15


# ----------------------------------------------------------------------------
# 3. VALIDATE INPUTS
# ----------------------------------------------------------------------------

if (!dir.exists(binary_path)) {
  stop(
    "Top-third binary raster directory not found: ",
    binary_path,
    call. = FALSE
  )
}

binary_files <- list.files(
  binary_path,
  pattern = "_top_third\\.tif$",
  full.names = TRUE,
  ignore.case = TRUE
)

if (length(binary_files) == 0) {
  stop(
    "No top-third binary rasters were found in: ",
    binary_path,
    call. = FALSE
  )
}

dir.create(
  hotspot_output_dir,
  recursive = TRUE,
  showWarnings = FALSE
)

message(
  "Found ",
  length(binary_files),
  " top-third suitability raster(s)."
)


# ----------------------------------------------------------------------------
# 4. LOAD RASTERS
# ----------------------------------------------------------------------------

message("Loading binary suitability rasters...")

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
      "Check CRS, extent, resolution and grid alignment."
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

message("Classifying ecological hotspot levels...")

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
  hotspot_output_dir,
  "suitability_overlap_count.tif"
)

hotspot_output <- file.path(
  hotspot_output_dir,
  "ecological_hotspots.tif"
)

metadata_output <- file.path(
  hotspot_output_dir,
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
# 11. REPORT
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
