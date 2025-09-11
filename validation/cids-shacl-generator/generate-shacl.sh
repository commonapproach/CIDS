#!/bin/bash

# Multi-Tier SHACL Generation Bash Script for Ubuntu/Linux
# Generates SHACL shapes from CIDS ontology for specified tiers
# Usage: ./generate-shacl.sh "tier1+tier2+..." ontology.ttl query.sparql [output_dir]

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color

# Function to print colored output
print_color() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to validate CURIE format
validate_curie() {
    local curie=$1
    if [[ $curie =~ ^[a-zA-Z_][a-zA-Z0-9_]*:[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
        return 0
    else
        return 1
    fi
}

# Function to sanitize filename
sanitize_filename() {
    local name=$1
    # Replace problematic characters with underscores
    name=$(echo "$name" | tr ':+' '_')
    # Replace multiple underscores with single underscore
    name=$(echo "$name" | sed 's/__\+/_/g')
    # Remove leading/trailing underscores
    name=$(echo "$name" | sed 's/^_\+\|_\+$//g')
    echo "$name"
}

# Function to extract local name from CURIE
get_local_name() {
    local curie=$1
    echo "${curie#*:}"
}

# Function to show usage
show_usage() {
    cat << EOF
Multi-Tier SHACL Generation Script for CIDS Ontology

Usage: $0 "tier1+tier2+..." ontology.ttl query.sparql [output_dir]

Parameters:
  tier1+tier2+...  Tier specifications as CURIEs separated by + signs
  ontology.ttl     Path to the CIDS ontology turtle file
  query.sparql     Path to the SPARQL query template file
  output_dir       Output directory (default: ./output)

Examples:
  $0 "cids:EssentialTier" cids.ttl multi-tier-query.sparql
  $0 "cids:BasicTier+cids:EssentialTier" cids.ttl multi-tier-query.sparql
  $0 "cids:BasicTier+cids:EssentialTier+cids:FullTier+cids:SFFTier" cids.ttl multi-tier-query.sparql ./output

Available CIDS Tiers:
  cids:BasicTier     - Core operational elements
  cids:EssentialTier - Fundamental validation requirements  
  cids:FullTier      - Complete feature set
  cids:SFFTier       - Social Finance Framework specific elements

Prerequisites:
  - Apache Jena ARQ tool installed and in PATH
  - Input ontology file in Turtle format
  - SPARQL query template file

EOF
}

# Function to check prerequisites
check_prerequisites() {
    # Check if arq is available
    if ! command -v arq &> /dev/null; then
        print_color $RED "ERROR: Apache Jena ARQ tool not found in PATH"
        print_color $YELLOW "Please install Apache Jena from: https://jena.apache.org/download/"
        print_color $YELLOW "And ensure 'arq' command is available in your PATH"
        exit 1
    fi
    
    # Check ARQ version
    local arq_version=$(arq --version 2>&1 | head -n 1)
    print_color $GRAY "Found ARQ: $arq_version"
}

# Main script starts here
main() {
    print_color $GREEN "Multi-Tier SHACL Generation Script"
    print_color $GREEN "=================================="
    
    # Check command line arguments
    if [ $# -lt 3 ]; then
        show_usage
        exit 1
    fi
    
    local MODE="$1"
    local ONTOLOGY_FILE="$2"
    local SPARQL_FILE="$3"
    local OUTPUT_DIR="${4:-./output}"
    
    print_color $CYAN "Processing tiers: $MODE"
    print_color $GRAY "Ontology file: $ONTOLOGY_FILE"
    print_color $GRAY "SPARQL file: $SPARQL_FILE"
    print_color $GRAY "Output directory: $OUTPUT_DIR"
    
    # Check prerequisites
    check_prerequisites
    
    # Validate input files
    if [ ! -f "$ONTOLOGY_FILE" ]; then
        print_color $RED "ERROR: Ontology file not found: $ONTOLOGY_FILE"
        exit 1
    fi
    
    if [ ! -f "$SPARQL_FILE" ]; then
        print_color $RED "ERROR: SPARQL file not found: $SPARQL_FILE"
        exit 1
    fi
    
    # Create output directory
    if [ ! -d "$OUTPUT_DIR" ]; then
        mkdir -p "$OUTPUT_DIR"
        print_color $YELLOW "Created output directory: $OUTPUT_DIR"
    fi
    
    # Parse tier specifications
    IFS='+' read -ra TIER_SPECS <<< "$MODE"
    
    # Validate each tier CURIE
    for tier in "${TIER_SPECS[@]}"; do
        tier=$(echo "$tier" | xargs)  # Trim whitespace
        if ! validate_curie "$tier"; then
            print_color $RED "ERROR: Invalid CURIE format: $tier"
            print_color $YELLOW "Expected format: prefix:localname"
            exit 1
        fi
    done
    
    # Prepare VALUES clause for multiple tiers
    local values_clause="VALUES ?activeTier { "
    local tier_list=""
    local tier_names=""
    
    for i in "${!TIER_SPECS[@]}"; do
        local tier=$(echo "${TIER_SPECS[$i]}" | xargs)
        values_clause+="$tier "
        
        if [ $i -eq 0 ]; then
            tier_list="$tier"
        else
            tier_list="$tier_list, $tier"
        fi
        
        local local_name=$(get_local_name "$tier")
        if [ $i -eq 0 ]; then
            tier_names="$local_name"
        else
            tier_names="$tier_names-$local_name"
        fi
    done
    
    values_clause+="}"
    
    print_color $GRAY "VALUES clause: $values_clause"
    print_color $GRAY "Tier list: $tier_list"
    
    # Generate safe filename
    local base_filename="cids-shacl-$tier_names"
    local safe_filename=$(sanitize_filename "$base_filename")
    local output_file="$OUTPUT_DIR/$safe_filename.ttl"
    local temp_sparql="$OUTPUT_DIR/temp-query.sparql"
    
    print_color $YELLOW "Output file: $output_file"
    
    # Read SPARQL template and replace placeholders
    print_color $CYAN "Processing SPARQL template..."
    
    # Use sed to replace placeholders in SPARQL template
    sed -e "s|\$TIERS|$values_clause|g" \
        -e "s|\$TIER_LIST|$tier_list|g" \
        "$SPARQL_FILE" > "$temp_sparql"
    
    # Execute SPARQL query
    print_color $CYAN "Executing SPARQL query..."
    
    local sparql_command="arq --data=\"$ONTOLOGY_FILE\" --query=\"$temp_sparql\" --results=TTL"
    print_color $GRAY "Command: $sparql_command"
    
    # Execute query and capture output
    if ! arq --data="$ONTOLOGY_FILE" --query="$temp_sparql" --results=TTL > "$output_file" 2>&1; then
        print_color $RED "ERROR: SPARQL execution failed"
        if [ -f "$output_file" ]; then
            print_color $RED "Error output:"
            cat "$output_file"
        fi
        cleanup_and_exit 1
    fi
    
    # Clean up temporary file
    rm -f "$temp_sparql"
    
    # Validate output
    if [ -f "$output_file" ]; then
        local file_size=$(stat -f%z "$output_file" 2>/dev/null || stat -c%s "$output_file" 2>/dev/null || echo "unknown")
        
        if [ "$file_size" != "unknown" ] && [ "$file_size" -gt 0 ]; then
            print_color $GREEN "✓ Successfully generated SHACL shapes: $output_file"
            print_color $GRAY "  File size: $file_size bytes"
            
            # Count generated triples (approximate)
            local triple_count=$(grep -c '\.' "$output_file" 2>/dev/null || echo "unknown")
            if [ "$triple_count" != "unknown" ]; then
                print_color $GRAY "  Approximate triples: $triple_count"
            fi
        else
            print_color $YELLOW "WARNING: Output file is empty. Check if the specified tiers exist in the ontology."
        fi
    else
        print_color $RED "ERROR: Output file was not created: $output_file"
        exit 1
    fi
    
    # Processing summary
    print_color $GREEN ""
    print_color $GREEN "Processing Summary:"
    print_color $GRAY "  Input ontology: $ONTOLOGY_FILE"
    print_color $GRAY "  Processed tiers: $MODE"
    print_color $GRAY "  Output SHACL: $output_file"
    print_color $GREEN "  Status: Complete"
}

# Function to cleanup and exit
cleanup_and_exit() {
    local exit_code=${1:-0}
    # Clean up any temporary files
    if [ -f "$OUTPUT_DIR/temp-query.sparql" ]; then
        rm -f "$OUTPUT_DIR/temp-query.sparql"
    fi
    exit $exit_code
}

# Trap to ensure cleanup on script exit
trap 'cleanup_and_exit 1' ERR INT TERM

# Run main function with all arguments
main "$@"