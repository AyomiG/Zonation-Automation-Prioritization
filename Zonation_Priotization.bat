@echo off
setlocal enabledelayedexpansion

rem ==========================================================================
rem SCRIPT: Automated Zonation5 Prioritization
rem AUTHOR: Oluwadamilola Ogundipe
rem PURPOSE: Automates Zonation5 (CAZ1) runs using three PA suitability filters.
rem ==========================================================================

rem --- CONFIGURATION ---
rem Set MODE to: global (all PAs), local (75th percentile), or local_avg (average)
set "MODE=global"

rem Path to Zonation5 executable on the local computer
set "Z5_PATH=C:\Program Files (x86)\Zonation5\z5w.exe"

rem Project root directory
rem Assumes this BAT file is stored in the scripts folder.
set "BASE_PATH=%~dp0.."

rem Zonation feature-list files
set "BIN_FOLDER=%BASE_PATH%\data\zonation\feature_lists"

rem --- MASKING LOGIC ---
if /I "%MODE%"=="global" (
    set "MASK_PATH=%BASE_PATH%\data\zonation\masks\totalpa.tif"
) else if /I "%MODE%"=="local" (
    set "MASK_DIR=%BASE_PATH%\data\zonation\masks\p75"
) else if /I "%MODE%"=="local_avg" (
    set "MASK_DIR=%BASE_PATH%\data\zonation\masks\pavg"
)

set "OUTPUT_DIR=%BASE_PATH%\outputs\zonation\%MODE%"
mkdir "%OUTPUT_DIR%" 2>nul

echo Starting Zonation in [%MODE%] mode...

for %%F in ("%BIN_FOLDER%\*.txt") do (
    set "FILENAME=%%~nF"
    set "FILE_FOLDER=%OUTPUT_DIR%\!FILENAME!"
    mkdir "!FILE_FOLDER!" 2>nul
    mkdir "!FILE_FOLDER!\final_output" 2>nul

    copy /Y "%%F" "!FILE_FOLDER!" >nul

    (
        echo feature list file = !FILENAME!.txt
        if /I "%MODE%"=="global" (
            echo hierarchic mask layer = %MASK_PATH%
        ) else (
            echo hierarchic mask layer = "!MASK_DIR!\result_!FILENAME!.tif.tif"
        )
    ) > "!FILE_FOLDER!\setting.txt"

    "%Z5_PATH%" "--mode=CAZ1" "-h" "!FILE_FOLDER!\setting.txt" "!FILE_FOLDER!\final_output"
)

echo Process Complete.
pause
