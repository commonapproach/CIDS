@echo off
setlocal enabledelayedexpansion

:: Multi-Tier SHACL Generation Batch Script
:: Usage: generate-shacl.bat "cids:BasicTier+cids:EssentialTier" ontology.ttl query.sparql [output_dir]

echo Multi-Tier SHACL Generation Script
echo ==================================

:: Check command line arguments
if "%~3"=="" (
    echo Usage: %0 "tier1+tier2+..." ontology.ttl query.sparql [output_dir]
    echo Example: %0 "cids:BasicTier+cids:EssentialTier" cids.ttl multi-tier-query.sparql
    exit /b 1
)

set "MODE=%~1"
set "ONTOLOGY_FILE=%~2"
set "SPARQL_FILE=%~3"
set "OUTPUT_DIR=%~4"

:: Set default output directory if not provided
if "%OUTPUT_DIR%"=="" set "OUTPUT_DIR=.\output"

echo Processing tiers: %MODE%
echo Ontology file: %ONTOLOGY_FILE%
echo SPARQL file: %SPARQL_FILE%
echo Output directory: %OUTPUT_DIR%

:: Validate input files
if not exist "%ONTOLOGY_FILE%" (
    echo ERROR: Ontology file not found: %ONTOLOGY_FILE%
    exit /b 1
)

if not exist "%SPARQL_FILE%" (
    echo ERROR: SPARQL file not found: %SPARQL_FILE%
    exit /b 1
)

:: Create output directory
if not exist "%OUTPUT_DIR%" (
    mkdir "%OUTPUT_DIR%"
    echo Created output directory: %OUTPUT_DIR%
)

:: Parse tiers and create VALUES clause
set "TIER_LIST="
set "TIER_NAMES="
set "VALUES_CLAUSE=VALUES ?activeTier { "

:: Split the MODE string by + and process each tier
set "TEMP_MODE=%MODE%"
:parse_loop
for /f "tokens=1* delims=+" %%a in ("%TEMP_MODE%") do (
    set "CURRENT_TIER=%%a"
    set "TEMP_MODE=%%b"
    
    :: Add to VALUES clause
    set "VALUES_CLAUSE=!VALUES_CLAUSE!!CURRENT_TIER! "
    
    :: Add to tier list for FILTER clauses
    if "!TIER_LIST!"=="" (
        set "TIER_LIST=!CURRENT_TIER!"
    ) else (
        set "TIER_LIST=!TIER_LIST!, !CURRENT_TIER!"
    )
    
    :: Extract local name for filename
    for /f "tokens=2 delims=:" %%c in ("!CURRENT_TIER!") do (
        if "!TIER_NAMES!"=="" (
            set "TIER_NAMES=%%c"
        ) else (
            set "TIER_NAMES=!TIER_NAMES!-%%c"
        )
    )
)

if not "!TEMP_MODE!"=="" goto parse_loop

set "VALUES_CLAUSE=!VALUES_CLAUSE!}"

echo VALUES clause: !VALUES_CLAUSE!
echo Tier list: !TIER_LIST!

:: Generate safe filename
set "BASE_FILENAME=cids-shacl-!TIER_NAMES!"
set "SAFE_FILENAME=!BASE_FILENAME!"

:: Replace problematic characters for filename
set "SAFE_FILENAME=!SAFE_FILENAME::=_!"
set "SAFE_FILENAME=!SAFE_FILENAME:+=_!"
set "SAFE_FILENAME=!SAFE_FILENAME: =_!"

set "OUTPUT_FILE=%OUTPUT_DIR%\!SAFE_FILENAME!.ttl"
set "TEMP_SPARQL=%OUTPUT_DIR%\temp-query.sparql"

echo Output file: !OUTPUT_FILE!

:: Read SPARQL template and replace placeholders
echo Processing SPARQL template...

:: Create temporary SPARQL file with replacements
(
    for /f "usebackq delims=" %%i in ("%SPARQL_FILE%") do (
        set "LINE=%%i"
        set "LINE=!LINE:$TIERS=!VALUES_CLAUSE!!"
        set "LINE=!LINE:$TIER_LIST=!TIER_LIST!!"
        echo !LINE!
    )
) > "%TEMP_SPARQL%"

:: Execute SPARQL query using ARQ
echo Executing SPARQL query...
arq --data="%ONTOLOGY_FILE%" --query="%TEMP_SPARQL%" --results=TTL > "!OUTPUT_FILE!" 2>&1

if !errorlevel! neq 0 (
    echo ERROR: SPARQL execution failed
    type "!OUTPUT_FILE!"
    goto cleanup
)

:: Check if output file was created and has content
if not exist "!OUTPUT_FILE!" (
    echo ERROR: Output file was not created
    goto cleanup
)

:: Check if output file has content
for %%F in ("!OUTPUT_FILE!") do set "FILESIZE=%%~zF"
if !FILESIZE! equ 0 (
    echo WARNING: Output file is empty. Check if the specified tiers exist in the ontology.
) else (
    echo SUCCESS: Generated SHACL shapes in !OUTPUT_FILE!
    echo File size: !FILESIZE! bytes
)

echo.
echo Processing Summary:
echo   Input ontology: %ONTOLOGY_FILE%
echo   Processed tiers: %MODE%
echo   Output SHACL: !OUTPUT_FILE!
echo   Status: Complete

:cleanup
:: Clean up temporary files
if exist "%TEMP_SPARQL%" del "%TEMP_SPARQL%"

echo.
pause