@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem ==========================================================================
rem SCRIPT: Automated Zonation 5 Prioritization
rem AUTHOR: Oluwadamilola Ogundipe
rem
rem PURPOSE
rem   Automates repeated Zonation 5 (CAZ1) runs using three Protected Area
rem   suitability scenarios:
rem     1. global    - entire Protected Area network
rem     2. local     - 75th-percentile suitability masks
rem     3. local_avg - above-average suitability masks
rem
rem INPUTS
rem   - bin_file\*.txt      Zonation feature-list files
rem   - totalpa.tif         Complete Protected Area mask
rem   - AI_75\*.tif         75th-percentile PA masks
rem   - AI_avg\*.tif        Above-average PA masks
rem   - Zonation 5 executable
rem
rem OUTPUTS
rem   - Output\<feature>\setting.txt
rem   - Output\<feature>\final_output\
rem
rem REQUIREMENTS
rem   - Windows
rem   - Zonation 5 installed locally
rem
rem NOTES
rem   The project root is taken as the folder one level above this script.
rem   This replaces the original WSL/OneDrive-specific project path while
rem   retaining the original project folder names.
rem ==========================================================================


rem ----------------------------------------------------------------------------
rem 1. CONFIGURATION
rem ----------------------------------------------------------------------------

rem Set MODE to:
rem   global    = all PAs
rem   local     = 75th-percentile PA suitability masks
rem   local_avg = above-average PA suitability masks
set "MODE=global"

rem Zonation 5 executable
set "Z5_PATH=C:\Program Files (x86)\Zonation5\z5w.exe"

rem Project root: script is assumed to be inside a scripts folder
set "BASE_PATH=%~dp0.."

rem Original project naming conventions retained
set "BIN_FOLDER=%BASE_PATH%\bin_file"
set "MASK_PATH_GLOBAL=%BASE_PATH%\totalpa.tif"
set "MASK_DIR_75=%BASE_PATH%\AI_75"
set "MASK_DIR_AVG=%BASE_PATH%\AI_avg"
set "OUTPUT_DIR=%BASE_PATH%\Output"


rem ----------------------------------------------------------------------------
rem 2. VALIDATE CONFIGURATION
rem ----------------------------------------------------------------------------

if not exist "%Z5_PATH%" (
    echo ERROR: Zonation 5 executable not found:
    echo        %Z5_PATH%
    exit /b 1
)

if not exist "%BIN_FOLDER%" (
    echo ERROR: Feature-list directory not found:
    echo        %BIN_FOLDER%
    exit /b 1
)

if /I "%MODE%"=="global" (
    if not exist "%MASK_PATH_GLOBAL%" (
        echo ERROR: Global PA mask not found:
        echo        %MASK_PATH_GLOBAL%
        exit /b 1
    )
) else if /I "%MODE%"=="local" (
    if not exist "%MASK_DIR_75%" (
        echo ERROR: 75th-percentile PA mask directory not found:
        echo        %MASK_DIR_75%
        exit /b 1
    )
) else if /I "%MODE%"=="local_avg" (
    if not exist "%MASK_DIR_AVG%" (
        echo ERROR: Average-suitability PA mask directory not found:
        echo        %MASK_DIR_AVG%
        exit /b 1
    )
) else (
    echo ERROR: Invalid MODE: %MODE%
    echo        Use global, local, or local_avg.
    exit /b 1
)


rem ----------------------------------------------------------------------------
rem 3. CREATE OUTPUT DIRECTORY
rem ----------------------------------------------------------------------------

if not exist "%OUTPUT_DIR%" mkdir "%OUTPUT_DIR%"

echo.
echo ============================================================
echo Starting Zonation 5
echo Scenario: %MODE%
echo Project:  %BASE_PATH%
echo ============================================================
echo.


rem ----------------------------------------------------------------------------
rem 4. PROCESS FEATURE LISTS
rem ----------------------------------------------------------------------------

set "FILE_COUNT=0"

for %%F in ("%BIN_FOLDER%\*.txt") do (

    set /a FILE_COUNT+=1
    set "FILENAME=%%~nF"
    set "FILE_FOLDER=%OUTPUT_DIR%\!FILENAME!"
    set "FINAL_OUTPUT=!FILE_FOLDER!\final_output"

    echo ------------------------------------------------------------
    echo Processing: !FILENAME!
    echo ------------------------------------------------------------

    if not exist "!FILE_FOLDER!" mkdir "!FILE_FOLDER!"
    if not exist "!FINAL_OUTPUT!" mkdir "!FINAL_OUTPUT!"

    rem Copy the feature-list file into its corresponding run folder
    copy /Y "%%F" "!FILE_FOLDER!\" >nul


    rem ------------------------------------------------------------------------
    rem Determine the Protected Area mask for the selected scenario
    rem ------------------------------------------------------------------------

    set "MASK_PATH="

    if /I "%MODE%"=="global" (
        set "MASK_PATH=%MASK_PATH_GLOBAL%"
    ) else if /I "%MODE%"=="local" (
        set "MASK_PATH=%MASK_DIR_75%\result_!FILENAME!.tif.tif"
    ) else if /I "%MODE%"=="local_avg" (
        set "MASK_PATH=%MASK_DIR_AVG%\result_!FILENAME!.tif.tif"
    )


    rem Check that the required mask exists
    if not exist "!MASK_PATH!" (
        echo ERROR: Required mask not found:
        echo        !MASK_PATH!
        echo Skipping !FILENAME!.
        echo.
        goto :next_file
    )


    rem ------------------------------------------------------------------------
    rem Create Zonation settings file
    rem ------------------------------------------------------------------------

    (
        echo feature list file = !FILENAME!.txt
        echo hierarchic mask layer = !MASK_PATH!
    ) > "!FILE_FOLDER!\setting.txt"


    rem ------------------------------------------------------------------------
    rem Run Zonation 5 using CAZ1
    rem ------------------------------------------------------------------------

    "%Z5_PATH%" "--mode=CAZ1" "-h" "!FILE_FOLDER!\setting.txt" "!FINAL_OUTPUT!"

    if errorlevel 1 (
        echo ERROR: Zonation failed for !FILENAME!.
    ) else (
        echo Completed: !FILENAME!
    )

    :next_file
)


rem ----------------------------------------------------------------------------
rem 5. COMPLETION
rem ----------------------------------------------------------------------------

echo.
echo ============================================================
echo Zonation processing complete.
echo Scenario: %MODE%
echo Feature lists processed: %FILE_COUNT%
echo Results: %OUTPUT_DIR%
echo ============================================================
echo.

endlocal
exit /b 0
