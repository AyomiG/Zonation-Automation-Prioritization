@echo off
setlocal enabledelayedexpansion

rem ==========================================================================
rem SCRIPT: Automated Zonation5 Prioritization
rem AUTHOR: Oluwadamilola Ogundipe
rem PURPOSE: Automates species prioritization by iterating through species lists 
rem          and applying specific hierarchical mask layers.
rem ==========================================================================

rem --- CONFIGURATION ---
rem Change "SET MODE=" to: global, local, or local_avg
set "MODE=global"

set "Z5_PATH=C:\Program Files (x86)\Zonation5\z5w.exe"
set "BASE_PATH=%USERPROFILE%\Documents\OneDrive - Eidg. Forschungsanstalt WSL\visua"
set "BIN_FOLDER=%BASE_PATH%\bin_file"

rem --- SET MASKING LOGIC BASED ON MODE ---
if /I "%MODE%"=="global" (
    set "MASK_PATH=%BASE_PATH%/totalpa.tif"
) else if /I "%MODE%"=="local" (
    set "MASK_DIR=%cd%\AI_75"
) else if /I "%MODE%"=="local_avg" (
    set "MASK_DIR=%cd%\AI_avg"
)

rem Create Output Directory
set "OUTPUT_DIR=%cd%\Output"
mkdir "%OUTPUT_DIR%" 2>nul

rem --- PROCESSING LOOP ---
echo Starting Zonation processing in [%MODE%] mode...

for %%F in ("%BIN_FOLDER%\*.txt") do (
    set "FILENAME=%%~nF"
    set "FILE_FOLDER=%OUTPUT_DIR%\!FILENAME!"
    mkdir "!FILE_FOLDER!" 2>nul
    mkdir "!FILE_FOLDER!\final_output" 2>nul
    
    copy /Y "%%F" "!FILE_FOLDER!" >nul

    rem Generate setting.txt with dynamic mask logic
    (
        echo feature list file = !FILENAME!.txt
        if /I "%MODE%"=="global" (
            echo hierarchic mask layer = %MASK_PATH%
        ) else (
            echo hierarchic mask layer = "!MASK_DIR!\result_!FILENAME!.tif.tif"
        )
    ) > "!FILE_FOLDER!\setting.txt"

    rem Run Zonation5
    "%Z5_PATH%" "--mode=CAZ1" "-h" "!FILE_FOLDER!\setting.txt" "!FILE_FOLDER!\final_output"
)

echo.
echo Process Complete. Check the Output folder for results.
pause
