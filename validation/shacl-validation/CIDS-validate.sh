#!/bin/zsh

# Validate CIDS data using Apache Jena SHACL and generate violation summaries
# 
# This script validates JSON-LD data files against SHACL shapes and generates
# detailed violation reports. Validation results are saved in timestamped folders
# within the JenaValidator/validations/ directory.
#
# Requirements:
# 1. Apache Jena installed with 'shacl' command available in your PATH
# 2. Python 3.7+ installed on your system
# 3. Python packages: rdflib (for summarization script)
#
# Setup steps:
# 1. Install Apache Jena: https://jena.apache.org/download/
# 2. Ensure 'shacl' command is in your PATH
# 3. Install Python dependencies: pip install rdflib
#
# Alternative: If you don't have Python/pip, you can install via Homebrew:
# brew install python3 && pip3 install rdflib

# Make this script executable (you only need to do this once):
# chmod +x CIDS-validate.sh

# Usage:
#   ./CIDS-validate.sh [--basic] [--sff] [--codelists] [--code-violations] [--no-summary] [--rebuild-cache] <data_file>
#
# Arguments:
#   --basic            Validate against CIDS basic tier SHACL shapes
#   --sff              Validate against SFF SHACL shapes (includes Basic Tier)
#   --codelists        Include all .ttl files from CodeLists directory in validation
#   --code-violations  Include violations from imported codelists in summary (default: excluded)
#   --no-summary       Skip generation of violation summary reports
#   --rebuild-cache    Force rebuild of cached merged codelists file
#   <data_file>        Path to the JSON-LD data file to validate (required)
#
# Examples:
#   ./CIDS-validate.sh --basic CRGbasic.jsonld
#   ./CIDS-validate.sh --basic --sff --codelists mydata.jsonld
#   ./CIDS-validate.sh --basic --code-violations CRGbasic.jsonld
#   ./CIDS-validate.sh --basic --no-summary data.jsonld
#   ./CIDS-validate.sh --sff --codelists --rebuild-cache mydata.jsonld
#
# Output:
#   Validation results are saved in: JenaValidator/validations/[filename][timestamp]/
#   Each validation run creates a new timestamped folder containing:
#   - Copy of the source data file
#   - Validation report files (*.ttl)
#   - Warning files (*_warnings.txt)
#   - Summary files (*_summary.txt) - unless --no-summary is used
#   - Merged file (merged-file-[filename].ttl) - when --codelists is used
#     (contains codelists and data merged with formatted Turtle output and prefix definitions)
#
# Basic usage of Jena's shacl validate (without this script):
#   shacl validate -s cids.shacl.ttl -d my-data.jsonld > report.ttl

# Capture the original command line for inclusion in the summary
original_command="$0 $*"

# Parse command-line arguments
skip_summary=false
use_basic=false
use_sff=false
use_codelists=false
include_code_violations=false
rebuild_cache=false
data_file=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --no-summary)
      skip_summary=true
      shift
      ;;
    --basic)
      use_basic=true
      shift
      ;;
    --sff)
      use_sff=true
      shift
      ;;
    --codelists)
      use_codelists=true
      shift
      ;;
    --code-violations)
      include_code_violations=true
      shift
      ;;
    --rebuild-cache)
      rebuild_cache=true
      shift
      ;;
    *)
      # Assume this is the data file path
      if [ -z "$data_file" ]; then
        data_file="$1"
      else
        echo "Error: Multiple data files specified. Only one data file is allowed."
        exit 1
      fi
      shift
      ;;
  esac
done

# Validate that at least one shapes file flag is provided
if [ "$use_basic" = false ] && [ "$use_sff" = false ]; then
  echo "Error: At least one shapes file flag must be specified (--basic or --sff)"
  echo "Usage: $0 [--basic] [--sff] [--codelists] [--code-violations] [--no-summary] <data_file>"
  exit 1
fi

# Validate that a data file was provided
if [ -z "$data_file" ]; then
  echo "Error: Data file path is required"
  echo "Usage: $0 [--basic] [--sff] [--codelists] [--code-violations] [--no-summary] <data_file>"
  exit 1
fi

# Validate that the data file exists
if [ ! -f "$data_file" ]; then
  echo "Error: Data file not found: '$data_file'"
  exit 1
fi

# Get the script's directory early (needed for cache setup)
# Works in both zsh and bash
if [ -n "$ZSH_VERSION" ]; then
  script_dir="$(cd "$(dirname "${(%):-%x}")" && pwd)"
else
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

# Set up cache directory
cache_dir="${script_dir}/cache"
mkdir -p "$cache_dir"

# Move prefixes.ttl and cids-codes-and-orgs.ttl to cache if they exist in script directory
if [ -f "${script_dir}/prefixes.ttl" ] && [ ! -f "${cache_dir}/prefixes.ttl" ]; then
  echo "Moving prefixes.ttl to cache directory..."
  mv "${script_dir}/prefixes.ttl" "${cache_dir}/prefixes.ttl"
fi

if [ -f "${script_dir}/cids-codes-and-orgs.ttl" ] && [ ! -f "${cache_dir}/cids-codes-and-orgs.ttl" ]; then
  echo "Moving cids-codes-and-orgs.ttl to cache directory..."
  mv "${script_dir}/cids-codes-and-orgs.ttl" "${cache_dir}/cids-codes-and-orgs.ttl"
fi

# Function to download a file from URL to cache directory
download_file() {
  local url="$1"
  local cache_file="$2"
  local file_name="$3"
  
  # Check if curl is available
  if ! command -v curl &> /dev/null; then
    echo "Error: curl is required to download files but is not installed"
    return 1
  fi
  
  # Download the file
  if curl -sSfL -o "$cache_file" "$url" 2>/dev/null; then
    # Verify the file was downloaded and has content
    if [ -f "$cache_file" ] && [ -s "$cache_file" ]; then
      return 0
    else
      echo "Error: Downloaded file is empty: $file_name"
      rm -f "$cache_file"
      return 1
    fi
  else
    echo "Error: Failed to download $file_name from $url"
    rm -f "$cache_file"
    return 1
  fi
}

# Function to download a codelist file from URL to cache directory
download_codelist() {
  local url="$1"
  local cache_file="$2"
  local codelist_name="$3"
  download_file "$url" "$cache_file" "$codelist_name"
}

# Function to get SHACL filename from URL
get_shacl_filename() {
  local url="$1"
  case "$url" in
    "https://ontology.commonapproach.org/validation/shacl/cids.basictier.shacl.ttl")
      echo "cids.basictier.shacl.ttl"
      ;;
    "https://ontology.commonapproach.org/validation/shacl/sff.shacl.ttl")
      echo "sff.shacl.ttl"
      ;;
    *)
      echo ""
      ;;
  esac
}

# Function to ensure SHACL shape files are cached locally
ensure_shacl_files_cached() {
  local cache_dir="$1"
  local rebuild="$2"
  
  # SHACL file URLs
  local shacl_urls=(
    "https://ontology.commonapproach.org/validation/shacl/cids.basictier.shacl.ttl"
    "https://ontology.commonapproach.org/validation/shacl/sff.shacl.ttl"
  )
  
  # Create shacl cache subdirectory
  mkdir -p "${cache_dir}/shacl"
  
  local needs_download=false
  
  # Check which files need to be downloaded
  for url in "${shacl_urls[@]}"; do
    local filename=$(get_shacl_filename "$url")
    if [ -z "$filename" ]; then
      continue
    fi
    local cached_file="${cache_dir}/shacl/${filename}"
    
    if [ "$rebuild" = true ] || [ ! -f "$cached_file" ]; then
      needs_download=true
      break
    fi
  done
  
  if [ "$needs_download" = true ]; then
    if [ "$rebuild" = true ]; then
      echo "Downloading SHACL shape files (--rebuild-cache flag set)..."
    else
      echo "Downloading SHACL shape files..."
    fi
    
    local download_failed=false
    for url in "${shacl_urls[@]}"; do
      local filename=$(get_shacl_filename "$url")
      if [ -z "$filename" ]; then
        continue
      fi
      local cached_file="${cache_dir}/shacl/${filename}"
      
      if ! download_file "$url" "$cached_file" "$filename"; then
        download_failed=true
      fi
    done
    
    if [ "$download_failed" = true ]; then
      echo "Error: Some SHACL shape files failed to download"
      return 1
    fi
    
    echo "SHACL shape files cached successfully"
  fi
  
  return 0
}

# Function to get cached SHACL file path from URL
get_cached_shacl_file() {
  local url="$1"
  local cache_dir="$2"
  
  local filename=$(get_shacl_filename "$url")
  if [ -n "$filename" ]; then
    echo "${cache_dir}/shacl/${filename}"
  else
    # If URL not recognized, return original URL (fallback)
    echo "$url"
  fi
}

# Ensure SHACL shape files are cached locally
if ! ensure_shacl_files_cached "$cache_dir" "$rebuild_cache"; then
  echo "Warning: Failed to cache SHACL shape files, will attempt to use URLs directly"
fi

# Build the shapes_files array based on selected flags (using cached files)
shapes_files=()
if [ "$use_basic" = true ]; then
  shacl_url="https://ontology.commonapproach.org/validation/shacl/cids.basictier.shacl.ttl"
  cached_shacl_file=$(get_cached_shacl_file "$shacl_url" "$cache_dir")
  # Use cached file if it exists, otherwise fall back to URL
  if [ -f "$cached_shacl_file" ]; then
    shapes_files+=("$cached_shacl_file")
  else
    shapes_files+=("$shacl_url")
  fi
fi
if [ "$use_sff" = true ]; then
  shacl_url="https://ontology.commonapproach.org/validation/shacl/sff.shacl.ttl"
  cached_shacl_file=$(get_cached_shacl_file "$shacl_url" "$cache_dir")
  # Use cached file if it exists, otherwise fall back to URL
  if [ -f "$cached_shacl_file" ]; then
    shapes_files+=("$cached_shacl_file")
  else
    shapes_files+=("$shacl_url")
  fi
fi

# Function to create or update cached merged codelists file
create_cached_codelists() {
  local cache_file="$1"
  local rebuild="$2"
  local cache_dir="$3"
  
  # Base URL for codelist files
  local codelist_base_url="https://codelist.commonapproach.org"
  
  # Specific list of codelist files to include
  local codelist_names=(
    "CanadianCorporateRegistries.ttl"
    "EquityDeservingGroupsESDC.ttl"
    "ESDCSector.ttl"
    "FundingState.ttl"
    "IRISImpactCategory.ttl"
    "IRISImpactTheme.ttl"
    "LocalityStatsCan.ttl"
    "OrgTypeGOC.ttl"
    "PopulationServed.ttl"
    "ProvinceTerritory.ttl"
    "RallyImpactArea.ttl"
    "SDGImpacts.ttl"
    "SELI-GLI.ttl"
    "UnitsOfMeasureList.ttl"
  )
  
  # Check if cache needs to be rebuilt
  local needs_rebuild=false
  
  if [ "$rebuild" = true ]; then
    needs_rebuild=true
    echo "Rebuilding cached codelists file (--rebuild-cache flag set)..."
  elif [ ! -f "$cache_file" ]; then
    needs_rebuild=true
    echo "Cached codelists file not found. Creating cache..."
  else
    # Check if any cached codelist file is missing or if cids-codes-and-orgs.ttl is newer
    local cache_mtime=$(stat -f %m "$cache_file" 2>/dev/null || stat -c %Y "$cache_file" 2>/dev/null)
    
    # Check individual codelist cache files
    for codelist_name in "${codelist_names[@]}"; do
      local cached_codelist_file="${cache_dir}/codelists/${codelist_name}"
      if [ ! -f "$cached_codelist_file" ]; then
        needs_rebuild=true
        echo "Cached codelist file missing: ${codelist_name}. Rebuilding cache..."
        break
      fi
    done
    
    # Also check cids-codes-and-orgs.ttl
    if [ "$needs_rebuild" = false ]; then
      local cids_codes_file="${cache_dir}/cids-codes-and-orgs.ttl"
      if [ -f "$cids_codes_file" ]; then
        local cids_mtime=$(stat -f %m "$cids_codes_file" 2>/dev/null || stat -c %Y "$cids_codes_file" 2>/dev/null)
        if [ "$cids_mtime" -gt "$cache_mtime" ]; then
          needs_rebuild=true
          echo "Cached codelists file is stale (cids-codes-and-orgs.ttl is newer). Rebuilding cache..."
        fi
      fi
    fi
  fi
  
  if [ "$needs_rebuild" = true ]; then
    # Create codelists cache subdirectory
    mkdir -p "${cache_dir}/codelists"
    
    # Download codelist files from URLs
    echo "Downloading codelist files from ${codelist_base_url}..."
    local download_failed=false
    for codelist_name in "${codelist_names[@]}"; do
      local url="${codelist_base_url}/${codelist_name}"
      local cached_codelist_file="${cache_dir}/codelists/${codelist_name}"
      
      if ! download_codelist "$url" "$cached_codelist_file" "$codelist_name"; then
        download_failed=true
      fi
    done
    
    if [ "$download_failed" = true ]; then
      echo "Error: Some codelist files failed to download"
      return 1
    fi
    
    # Collect source files (now from cache directory)
    local source_files=()
    for codelist_name in "${codelist_names[@]}"; do
      local cached_codelist_file="${cache_dir}/codelists/${codelist_name}"
      if [ -f "$cached_codelist_file" ]; then
        source_files+=("$cached_codelist_file")
      else
        echo "Warning: Cached codelist file not found: '$codelist_name'"
      fi
    done
    
    # Add cids-codes-and-orgs.ttl
    local cids_codes_file="${cache_dir}/cids-codes-and-orgs.ttl"
    if [ -f "$cids_codes_file" ]; then
      source_files+=("$cids_codes_file")
    fi
    
    if [ ${#source_files[@]} -eq 0 ]; then
      echo "Error: No codelist files found to create cache"
      return 1
    fi
    
    # Create temporary files for two-step conversion
    local temp_nt_file="${cache_dir}/.temp_codelists_cache.nt"
    local temp_stderr_file="${cache_dir}/.temp_codelists_cache.stderr"
    local prefixes_file="${cache_dir}/prefixes.ttl"
    
    # Step 1: Convert codelist files to N-Triples
    local step1_args=("riot" "--output=N-Triples")
    for source_file in "${source_files[@]}"; do
      step1_args+=("$source_file")
    done
    
    "${step1_args[@]}" > "$temp_nt_file" 2> "$temp_stderr_file"
    local step1_exit_code=$?
    
    if [ $step1_exit_code -ne 0 ] || [ ! -f "$temp_nt_file" ] || [ ! -s "$temp_nt_file" ]; then
      echo "Error: Failed to create N-Triples from codelist files"
      if [ -s "$temp_stderr_file" ]; then
        cat "$temp_stderr_file"
      fi
      rm -f "$temp_nt_file" "$temp_stderr_file"
      return 1
    fi
    
    # Step 2: Convert N-Triples to formatted Turtle with prefix definitions
    local step2_args=("riot" "--formatted=TURTLE")
    if [ -f "$prefixes_file" ]; then
      step2_args+=("$prefixes_file")
    fi
    step2_args+=("$temp_nt_file")
    
    "${step2_args[@]}" > "$cache_file" 2> "$temp_stderr_file"
    local step2_exit_code=$?
    
    # Clean up temporary files
    rm -f "$temp_nt_file" "$temp_stderr_file"
    
    if [ $step2_exit_code -ne 0 ] || [ ! -f "$cache_file" ] || [ ! -s "$cache_file" ]; then
      echo "Error: Failed to create cached codelists file"
      if [ -s "$temp_stderr_file" ]; then
        cat "$temp_stderr_file"
      fi
      rm -f "$cache_file"
      return 1
    fi
    
    echo "Cached codelists file created successfully: $cache_file"
  else
    echo "Using cached codelists file: $cache_file"
  fi
  
  return 0
}

# Collect codelist files if --codelists flag is set
codelist_files=()
cached_codelists_file="${cache_dir}/merged-codelists.ttl"

if [ "$use_codelists" = true ]; then
  # Create or update cached merged codelists file (downloads from URLs if needed)
  if create_cached_codelists "$cached_codelists_file" "$rebuild_cache" "$cache_dir"; then
    # Use the cached file instead of individual files
    codelist_files=("$cached_codelists_file")
    echo "Using cached merged codelists (${#codelist_files[@]} file(s))"
  else
    echo "Error: Failed to create cached codelists"
    echo "  Continuing without codelist files."
  fi
fi

echo "Starting SHACL validation process for '$data_file'..."

# Check if the data file has a .json extension and create a temporary .jsonld file if needed
if [[ "$data_file" == *.json ]]; then
  echo "Converting .json file to .jsonld for Jena compatibility..."
  temp_data_file="${data_file%.json}.jsonld"
  cp "$data_file" "$temp_data_file"
  echo "Created temporary file: $temp_data_file"
  data_file_for_validation="$temp_data_file"
else
  data_file_for_validation="$data_file"
fi

# Get the data file's name without its extension (e.g., "my-data")
# Handle filenames with multiple dots by removing only the last extension
data_file_prefix=${data_file:r}

# Get the original filename (basename) for the folder name
data_file_basename=$(basename "$data_file")
data_file_basename_no_ext=${data_file_basename%.*}

# Sanitize the basename for use in report filenames
# Replace dots and other potentially problematic characters with underscores
safe_data_file_prefix=$(echo "$data_file_basename_no_ext" | sed 's/[^a-zA-Z0-9_-]/_/g')

# Generate date-time stamp (format: YYYYMMDD-HHMMSS)
date_time_stamp=$(date +"%Y%m%d-%H%M%S")

# Create validation folder name: [original file name][date-time]
validation_folder_name="${data_file_basename_no_ext}${date_time_stamp}"

# script_dir is already defined earlier, just set validations_base_dir
validations_base_dir="${script_dir}/validations"

# Locate prefixes file for formatted Turtle output (now in cache directory)
prefixes_file="${cache_dir}/prefixes.ttl"

# Create the validations base directory if it doesn't exist
mkdir -p "$validations_base_dir"

# Full path to validation folder
validation_folder="${validations_base_dir}/${validation_folder_name}"

echo "Creating validation results folder: '$validation_folder'"
mkdir -p "$validation_folder"

# Copy the source file to the validation folder
echo "Copying source file to validation folder..."
cp "$data_file" "$validation_folder/"
echo "  Source file copied: $(basename "$data_file")"

echo "Data file: '$data_file'"
echo "Validation results will be saved in: '$validation_folder/'"
echo "==================================="

# Cross-shell yes/no prompt helper (works in zsh and bash)
ask_yes_no() {
  local prompt_msg="$1"
  local reply
  if [ -n "$ZSH_VERSION" ]; then
    read -q "reply?${prompt_msg} "
    echo ""
    [[ $reply == [Yy] ]]
  else
    read -r -n 1 -p "${prompt_msg} " reply
    echo ""
    [[ $reply == [Yy] ]]
  fi
}

# Create empty arrays to hold the list of report files and warning files
report_files_list=()
warning_files_list=()

# Loop through each file in the shapes_files array
for current_shapes_file in "${shapes_files[@]}"; do
  # First, get just the filename from the full path (e.g., "cids.shacl.ttl")
  filename_only=${current_shapes_file:t}

  # Then, get the prefix from the filename only (e.g., "cids")
  shacl_prefix=${filename_only%%.*}

  # Dynamically generate the report filename using the specified format
          report_file="${validation_folder}/report-${shacl_prefix}-${safe_data_file_prefix}.ttl"

  echo "Validating with '$current_shapes_file'..."
  
  # Generate warning file name (replace .ttl with _warnings.txt)
  warning_file="${report_file%.ttl}_warnings.txt"
  
  # Check if report file already exists and prompt user
  if [ -f "$report_file" ]; then
    echo "⚠️  Report file '$report_file' already exists."
    if ! ask_yes_no "Overwrite existing file? (y/N):"; then
      echo "  Skipping validation for '$current_shapes_file' (using existing report)"
      report_files_list+=("$report_file") # Add existing report to the list
      warning_files_list+=("$warning_file") # Add warning file to the list (may not exist)
      echo "" # Add a blank line for readability
      continue
    fi
    echo "  Proceeding with validation (will overwrite existing file)"
  fi
  
  # Build the shacl validate command with primary data file and any codelist files
  # Use non-verbose output for cleaner LLM analysis
  # Capture stderr (warnings) separately from stdout (TTL report)
  
  # If codelist files are included, we need to merge them with the main data file
  # because Jena's shacl validate appears to only use the last --data file when multiple are provided
  if [ ${#codelist_files[@]} -gt 0 ]; then
    # Create merged file in validation folder
    merged_file="${validation_folder}/merged-file-${safe_data_file_prefix}.ttl"
    
    # Create temporary files for two-step conversion
    temp_codelists_nt="${validation_folder}/.temp_codelists_${shacl_prefix}_${safe_data_file_prefix}.nt"
    temp_merged_nt="${validation_folder}/.temp_merged_${shacl_prefix}_${safe_data_file_prefix}.nt"
    temp_stderr_file="${validation_folder}/.temp_merged_${shacl_prefix}_${safe_data_file_prefix}.stderr"
    
    # Step 1a: Convert codelist files to N-Triples (static reference data - should always work)
    echo "  Merging ${#codelist_files[@]} codelist file(s)..."
    echo "  Step 1a: Converting codelists to N-Triples..."
    step1a_args=("riot" "--output=N-Triples")
    for codelist_file in "${codelist_files[@]}"; do
      step1a_args+=("$codelist_file")
    done
    
    "${step1a_args[@]}" > "$temp_codelists_nt" 2> "$temp_stderr_file"
    step1a_exit_code=$?
    
    if [ $step1a_exit_code -ne 0 ] || [ ! -f "$temp_codelists_nt" ] || [ ! -s "$temp_codelists_nt" ]; then
      echo "  ⚠️  Error: Failed to convert codelists to N-Triples"
      if [ -s "$temp_stderr_file" ]; then
        echo "  Error details:"
        head -20 "$temp_stderr_file"
      fi
    else
      echo "  ✓ Codelists converted to N-Triples ($(wc -l < "$temp_codelists_nt" | tr -d ' ') lines)"
    fi
    
    # Check for errors from codelist merge (these are static files, so errors are unexpected)
    if [ -s "$temp_stderr_file" ]; then
      # Filter out just warnings - codelists should not have errors
      if grep -q "ERROR" "$temp_stderr_file"; then
        echo "  ⚠️  Warning: Errors found in codelist files (unexpected for static reference data)"
        cat "$temp_stderr_file" >> "$warning_file"
      else
        # Just warnings/info - capture but don't worry
        cat "$temp_stderr_file" >> "$warning_file"
      fi
    fi
    
    # Step 1b: Merge codelists N-Triples with data file
    if [ -f "$temp_codelists_nt" ] && [ -s "$temp_codelists_nt" ]; then
      echo "  Step 1b: Merging codelists with data file..."
      step1b_args=("riot" "--output=N-Triples" "$temp_codelists_nt" "$data_file_for_validation")
      "${step1b_args[@]}" > "$temp_merged_nt" 2> "$temp_stderr_file"
      step1b_exit_code=$?
      
      if [ $step1b_exit_code -ne 0 ] || [ ! -f "$temp_merged_nt" ] || [ ! -s "$temp_merged_nt" ]; then
        echo "  ⚠️  Error: Failed to merge codelists with data file"
        if [ -s "$temp_stderr_file" ]; then
          echo "  Error details:"
          head -20 "$temp_stderr_file"
        fi
      else
        echo "  ✓ Merged file created ($(wc -l < "$temp_merged_nt" | tr -d ' ') lines)"
      fi
      
      # Check for errors from data file merge (warnings are expected, errors are not)
      if [ -s "$temp_stderr_file" ]; then
        cat "$temp_stderr_file" >> "$warning_file"
      fi
      
      # Use the merged file for step 2
      temp_nt_file="$temp_merged_nt"
      step1_exit_code=$step1b_exit_code
    else
      echo "  ⚠️  Warning: Failed to merge codelist files, validating main file only"
      rm -f "$temp_codelists_nt" "$temp_merged_nt" "$temp_stderr_file"
      # Fallback: validate just the main file
      validate_args=("shacl" "validate" "--shapes" "$current_shapes_file" "--data" "$data_file_for_validation")
      "${validate_args[@]}" > "$report_file" 2>> "$warning_file"
      # Skip to next shapes file
      report_files_list+=("$report_file")
      warning_files_list+=("$warning_file")
      echo "" # Add a blank line for readability
      continue
    fi
    
    # Step 2: Build command to convert N-Triples to formatted Turtle with prefix definitions
    step2_args=("riot" "--formatted=TURTLE")
    if [ -f "$prefixes_file" ]; then
      step2_args+=("$prefixes_file")
    fi
    step2_args+=("$temp_nt_file")
    
    # Only fail if file doesn't exist or is empty (warnings from data file are expected)
    if [ ! -f "$temp_nt_file" ] || [ ! -s "$temp_nt_file" ]; then
      echo "  ⚠️  Warning: Failed to merge codelist files with data file, validating main file only"
      # Clean up temporary files
      rm -f "$temp_codelists_nt" "$temp_merged_nt" "$temp_nt_file" "$temp_stderr_file"
      # Fallback: validate just the main file
      validate_args=("shacl" "validate" "--shapes" "$current_shapes_file" "--data" "$data_file_for_validation")
      "${validate_args[@]}" > "$report_file" 2>> "$warning_file"
    else
      # Step 2: Convert N-Triples to formatted Turtle
      "${step2_args[@]}" > "$merged_file" 2> "$temp_stderr_file"
      step2_exit_code=$?
      
      # Check for errors from step 2
      if [ -s "$temp_stderr_file" ]; then
        cat "$temp_stderr_file" >> "$warning_file"
      fi
      
      # Clean up temporary files
      rm -f "$temp_codelists_nt" "$temp_merged_nt" "$temp_nt_file" "$temp_stderr_file"
      
      # Proceed if merged file exists and has content (warnings are acceptable)
      if [ ! -f "$merged_file" ] || [ ! -s "$merged_file" ]; then
        echo "  ⚠️  Warning: Failed to convert merged file to Turtle, validating main file only"
        # Fallback: validate just the main file
        validate_args=("shacl" "validate" "--shapes" "$current_shapes_file" "--data" "$data_file_for_validation")
        "${validate_args[@]}" > "$report_file" 2>> "$warning_file"
      else
        # Validate the merged file
        validate_args=("shacl" "validate" "--shapes" "$current_shapes_file" "--data" "$merged_file")
        "${validate_args[@]}" > "$report_file" 2>> "$warning_file"
        merge_exit_code=$?
        
        if [ $merge_exit_code -ne 0 ]; then
          echo "  ⚠️  Warning: Error during validation with merged codelist files"
        fi
      fi
    fi
  else
    # No codelist files, just validate the main data file
    validate_args=("shacl" "validate" "--shapes" "$current_shapes_file" "--data" "$data_file_for_validation")
    "${validate_args[@]}" > "$report_file" 2> "$warning_file"
  fi
  
  echo "--> Success: Report saved to '$report_file'."
  echo "--> Warnings saved to '$warning_file'."
  report_files_list+=("$report_file") # Add the report file to the list
  warning_files_list+=("$warning_file") # Add the warning file to the list
  echo "" # Add a blank line for readability
done

echo "==================================="
echo "All validations complete. ✅"

# Function to count node types in the source data file
count_node_types() {
  local data_file="$1"
  local temp_nt_file="${validation_folder}/.temp_node_types_${safe_data_file_prefix}.nt"
  local temp_stderr_file="${validation_folder}/.temp_node_types_${safe_data_file_prefix}.stderr"
  
  # Convert data file to N-Triples to extract rdf:type statements
  riot --output=N-Triples "$data_file" > "$temp_nt_file" 2> "$temp_stderr_file"
  
  if [ ! -f "$temp_nt_file" ] || [ ! -s "$temp_nt_file" ]; then
    rm -f "$temp_nt_file" "$temp_stderr_file"
    echo "{}"
    return 1
  fi
  
  # Extract rdf:type statements and count node types using Python for better JSON handling
  python3 <<PYTHON_SCRIPT
import sys
import json
from collections import defaultdict

rdf_type_uri = 'http://www.w3.org/1999/02/22-rdf-syntax-ns#type'
counts = defaultdict(int)

try:
    with open('$temp_nt_file', 'r') as f:
        for line in f:
            # Pattern: <subject> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <type> .
            if rdf_type_uri in line:
                # Extract the type (third URI in the line)
                parts = line.strip().split()
                if len(parts) >= 3:
                    type_uri = parts[2].strip('<>')
                    # Extract local name (part after # or last part after /)
                    if '#' in type_uri:
                        local_name = type_uri.split('#')[-1]
                    elif '/' in type_uri:
                        local_name = type_uri.split('/')[-1]
                    else:
                        local_name = type_uri
                    counts[local_name] += 1
    print(json.dumps(dict(counts)))
except Exception as e:
    print("{}")
PYTHON_SCRIPT
  
  # Clean up
  rm -f "$temp_nt_file" "$temp_stderr_file"
}

# Generate summaries unless --no-summary flag is set
if [ "$skip_summary" = false ]; then
  echo ""
  echo "Generating violation summaries..."
  echo "==================================="
  
  # Count node types in source data file
  echo "Counting node types in source data file..."
  node_type_counts=$(count_node_types "$data_file_for_validation")
  
  # Path to the summarization script (now in cache directory)
  summarize_script="${cache_dir}/SummarizeReports/summarize_shacl_violations.py"
  
  # Check if the script exists
  if [ ! -f "$summarize_script" ]; then
    echo "⚠️  Warning: Summarization script not found at '$summarize_script'"
    echo "   Skipping summary generation."
  else
    # Loop through each report file and generate a summary
    for report_file in "${report_files_list[@]}"; do
      if [ -f "$report_file" ]; then
        # Generate summary filename: replace .ttl with _summary.txt
        summary_file="${report_file%.ttl}_summary.txt"
        echo "Generating summary for '$report_file'..."
        # Pass --code-violations flag, original command, and node type counts to Python script
        if [ "$include_code_violations" = true ]; then
          python3 "$summarize_script" --code-violations --command "$original_command" --node-types "$node_type_counts" "$report_file" "$summary_file"
        else
          python3 "$summarize_script" --command "$original_command" --node-types "$node_type_counts" "$report_file" "$summary_file"
        fi
      fi
    done
    echo ""
    echo "Summary generation complete. ✅"
  fi
  echo "==================================="
fi

# Clean up temporary .jsonld file if it was created
if [[ -n "$temp_data_file" && -f "$temp_data_file" ]]; then
  echo "Cleaning up temporary file: $temp_data_file"
  rm "$temp_data_file"
fi

echo "All validation results are organized in the '$validation_folder' folder"

### Additional Notes on Jena SHACL Command Options
# The 'shacl validate' command comes with a variety of options to customize its behavior.
# You can view all available options by running:
# shacl validate --help
# or
# shacl validate -h

# Here is a brief description of the most common options you'll find in the help documentation. Most flags have a long version (e.g., --shapes) and a short version (e.g., -s).

# Input Files
# --shapes FILE or -s FILE
# This is the most important flag. It specifies the SHACL file that contains the validation rules. FILE can be a local file path or a remote URL.

# --data FILE or -d FILE
# This flag specifies the data graph you want to validate. Like the shapes file, FILE can be a local path or a URL.

# Output Control
# --output=FORMAT or -o FORMAT
# Controls the syntax of the validation report. This is very useful for piping the output to other tools. Common formats include text (the default, human-readable), ttl, json-ld, rdf/xml, and nt.

# Validation Behavior
# --validateShapes
# A useful flag that validates the shapes file itself against the core SHACL specification. This helps you catch errors in your own SHACL rules.

# --strict
# Enables strict mode. In this mode, any invalid SHACL constructs in your shapes file will cause the validation to fail.

# General Flags
# --verbose or -v
# Enables verbose logging, which can provide more detailed information during the validation process, especially useful for debugging.

# --version
# Prints the version of the Apache Jena tool being used.

