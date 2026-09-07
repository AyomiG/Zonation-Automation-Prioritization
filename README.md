# Zonation-Automation-Prioritization

Automated multi-species conservation planning and spatial prioritization using Zonation 5

## Overview

This repository demonstrates a reproducible spatial conservation-planning workflow combining R-based spatial analysis with Windows Batch automation and Zonation 5 (CAZ1).

The workflow uses species-specific suitability information to:

- assess suitability within existing Protected Areas;
- generate species-specific Protected Area masks;
- identify ecological hotspots from overlapping suitability layers; and
- automate repeated Zonation 5 prioritization runs.

## Workflow

### Main Zonation workflow

```text
Species-specific SDM rasters
            │
            ▼
01_PA_Suitability_and_Mask_Generation.R
            │
            ├── AI_75/
            │
            └── AI_avg/
            │
            ▼
03_Zonation_Automation.bat
            │
            ▼
       Zonation 5 (CAZ1)
            │
            ▼
         Output/
Ecological hotspot workflow
Binary top-third suitability rasters
            │
            ▼
02_Ecological_Hotspot_Synthesis.R
            │
            ▼
Ecological hotspot outputs
Scripts
01_PA_Suitability_and_Mask_Generation.R

Evaluates species-specific suitability within existing Protected Areas and generates raster masks using:

75th-percentile suitability threshold
mean suitability threshold

Outputs are written to AI_75/ and AI_avg/.

02_Ecological_Hotspot_Synthesis.R

Calculates the overlap of binary suitability rasters and classifies areas according to the number of overlapping layers.

03_Zonation_Automation.bat

Automates Zonation 5 runs by:

reading feature lists from bin_file/;
selecting the appropriate PA mask;
generating Zonation settings files; and
running Zonation 5 automatically.
Scenarios

Global — uses the complete Protected Area network.

75th Percentile — uses Protected Areas with mean suitability above the 75th percentile.

Average — uses Protected Areas with mean suitability above the overall mean.

Directory Structure
Zonation-Automation-Prioritization/
│
├── README.md
├── 01_PA_Suitability_and_Mask_Generation.R
├── 02_Ecological_Hotspot_Synthesis.R
├── 03_Zonation_Automation.bat
│
├── bin_file/
├── AI_75/
├── AI_avg/
├── Output/
└── Final/
    └── Comp_F/
        └── masked/
            └── top_third_binary/

Project-specific datasets are not included.

Requirements
R 4.1+
R package: terra
Windows
Zonation 5

The Zonation executable path is configured in 03_Zonation_Automation.bat.

How to Use
Run 01_PA_Suitability_and_Mask_Generation.R.
Set MODE in 03_Zonation_Automation.bat to global, local, or local_avg.
Run the batch script to execute the Zonation workflow.
Run 02_Ecological_Hotspot_Synthesis.R separately for the hotspot analysis.
Reproducibility

The repository uses project-relative paths, explicit suitability thresholds, consistent raster processing, and automated Zonation execution to support reproducible spatial prioritization workflows.
