# Zonation-Automation-Prioritization
Batch-processing for multi-species conservation planning and spatial prioritization using Zonation5

Zonation5 Automation: PA Suitability Filtering Framework
Developed by Oluwadamilola Ogundipe

Overview
This repository provides a complete end-to-end pipeline for multi-species spatial prioritization using Zonation5 (CAZ1). The workflow addresses the challenge of applying species-specific scientific filters to Protected Area (PA) networks at scale by combining R-based spatial analysis with Windows Batch automation.

Project Components
PA_Suitability_Extraction.R: This script performs the core spatial analysis. It extracts suitability values from SDM rasters and generates species-specific PA masks based on scientific thresholds.

Zonation_Automation.bat: This master script handles the high-volume processing. It iterates through species lists and automatically pairs them with the generated masks for Zonation5 runs.

Filtering Strategies (Modes)
The pipeline facilitates three distinct conservation scenarios by filtering the PA network based on species suitability scores:

Global: Analysis using the entire Protected Area network within the study region.

75th Percentile: Analysis restricted to PAs meeting the 75th suitability percentile for the specific target species.

Average: Analysis restricted to PAs meeting the average suitability threshold for the specific target species.

Directory Structure
bin_file/: Input directory for species list .txt files.

AI_75/: Directory for hierarchical masks meeting the 75th percentile criteria.

AI_avg/: Directory for hierarchical masks meeting the average suitability criteria.

Output/: Results folder automatically generated to store setting.txt files and Zonation outputs.

How to Use
Pre-processing: Run PA_Suitability_Extraction.R to generate your species-specific masks into the AI_ folders.

Setup: Ensure Zonation5 is installed at C:\Program Files (x86)\Zonation5\.

Configuration: Open Zonation_Automation.bat and set the MODE variable to global, local, or local_avg.

Execution: Run the .bat file to process all species lists in the bin_file directory.
