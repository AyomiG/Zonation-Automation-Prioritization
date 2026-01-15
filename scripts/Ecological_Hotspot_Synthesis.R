# ==========================================================================
# SCRIPT: Ecological Hotspot Synthesis & Gap Analysis
# AUTHOR: Oluwadamilola Ogundipe
# PURPOSE: Identifies conservation hotspots by stacking top-third suitability 
#          rasters and evaluating overlap against existing Protected Areas.
# ==========================================================================

library(terra)

# --- DYNAMIC PATHS ---
user_path <- Sys.getenv("USERPROFILE")
base_dir  <- file.path(user_path, "Documents", "OneDrive - Eidg. Forschungsanstalt WSL", "visua", "new_data")
input_f   <- file.path(base_dir, "Final", "Comp_F")
output_f  <- file.path(input_f, "masked")

# 1. SPATIAL SYNTHESIS
# Stack top-third binary rasters and sum them
binary_path   <- file.path(output_f, "top_third_binary")
binary_stack  <- rast(list.files(binary_path, pattern = "_top_third\\.tif$", full.names = TRUE))
overlap_count <- sum(binary_stack, na.rm = TRUE)

# Tiered Classification: 1 (Low), 2 (Moderate), 3 (High Hotspot)
hotspots <- app(overlap_count, function(x) {
    ifelse(is.na(x), NA, ifelse(x >= 15, 3, ifelse(x >= 8, 2, ifelse(x >= 1, 1, NA))))
})

# 2. ACRONYM MAPPING FUNCTION (For Portfolio Showcase)
# Maps numeric filenames (e.g., 1_1_1) to ecological labels
get_eco_label <- function(base_name) {
    parts <- unlist(strsplit(base_name, "_"))
    ph    <- c("A", "Ak", "N")[as.numeric(parts[1])]
    elev  <- c("LE", "ME")[as.numeric(parts[2])]
    moist <- c("W", "MO", "MD", "D")[as.numeric(parts[3])]
    return(paste(ph, elev, moist, sep = "/"))
}

# 3. SAVE RESULTS
writeRaster(hotspots, filename = file.path(input_f, "overlap_classified.tif"), overwrite = TRUE)
print("Synthesis complete. Results saved to OneDrive.")
