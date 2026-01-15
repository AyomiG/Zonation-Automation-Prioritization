# ==========================================================================
# SCRIPT: Spatial Filtering of Protected Areas (PAs) based on SDM Suitability
# AUTHOR: Oluwadamilola Ogundipe
# PURPOSE: Extracts suitability values from SDM rasters to create species-specific 
#          PA masks (75th Percentile and Average filters) for Zonation5.
# ==========================================================================

library(sf)
library(terra)

# --- CONFIGURATION ---
# Dynamically set paths to work across different machines
user_path <- Sys.getenv("USERPROFILE")
base_dir  <- file.path(user_path, "Documents", "OneDrive - Eidg. Forschungsanstalt WSL", "visua", "new_data")

# Load Protected Area (PA) Shapefile
shp_path <- file.path(base_dir, "oei_betrieb.gpkg")
shp      <- st_read(shp_path)
tshp     <- terra::vect(shp)

# --- DATA CLEANING ---
# Filter out PAs with negligible area (less than 0.0025 ha)
spatvector_sub <- tshp[tshp$ha >= 0.0025, ]

# List species SDM raster files
raster_path  <- file.path(base_dir, "bin_dv")
raster_files <- list.files(raster_path, pattern = "*.tif")

# --- PROCESSING LOOP ---
for (raster_file in raster_files) {
    
    # Read species suitability map (SDM)
    sm <- rast(file.path(raster_path, raster_file))
    crs(sm) <- crs(spatvector_sub)
    
    # Extract suitability values for each Protected Area
    suitability_score <- terra::extract(sm, spatvector_sub)
    
    # Calculate Mean Suitability Score per PA
    poly_avg <- aggregate(list(Mean_SM = suitability_score$sum),
                          by = list(ID = suitability_score$ID),
                          FUN = "mean", na.rm = TRUE)
    
    mean_sm_values_nona <- unlist(na.omit(poly_avg$Mean_SM))
    
    # Calculate Statistical Thresholds
    p75 <- quantile(mean_sm_values_nona, 0.75)
    mean_val <- mean(mean_sm_values_nona)
    
    # --- SAVE FILTERED MASKS ---
    
    # 1. 75th Percentile Filter: Top 25% most suitable PAs
    relev_pas_p75 <- spatvector_sub[mean_sm_values_nona > p75, ]
    writeVector(relev_pas_p75, filename = file.path(base_dir, "p75", paste0(basename(raster_file), ".shp")))
    
    # 2. Average Filter: PAs with above-average suitability
    relev_pas_avg <- spatvector_sub[mean_sm_values_nona > mean_val, ]
    writeVector(relev_pas_avg, filename = file.path(base_dir, "pavg", paste0(basename(raster_file), ".shp")))
}

print("Spatial filtering complete. Masks saved to p75 and pavg directories.")
