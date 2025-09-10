#!/bin/bash

# Mac-compatible version of buildShacl.ps1
# Usage: ./buildShacl-mac.sh <input-ttl-file> <output-shacl-file>
# Example: ./buildShacl-mac.sh ../../CIDS/cids.ttl ../../CIDS/validation/shacl/cids.basic.shacl.ttl

# Check if correct number of arguments provided
if [ $# -ne 2 ]; then
    echo "Usage: $0 <input-ttl-file> <output-shacl-file>"
    echo "Example: $0 ../../CIDS/cids.ttl ../../CIDS/validation/shacl/cids.basic.shacl.ttl"
    exit 1
fi

INPUT_TTL_FILE="$1"
OUTPUT_SHACL_FILE="$2"

# Verify input file exists
if [ ! -f "$INPUT_TTL_FILE" ]; then
    echo "Error: Input file '$INPUT_TTL_FILE' does not exist."
    exit 1
fi

# Create output directory if it doesn't exist
OUTPUT_DIR=$(dirname "$OUTPUT_SHACL_FILE")
if [ ! -d "$OUTPUT_DIR" ]; then
    mkdir -p "$OUTPUT_DIR"
fi

echo "Processing: $INPUT_TTL_FILE -> $OUTPUT_SHACL_FILE"

# Run the SPARQL query and save to output file
if sparql --data "$INPUT_TTL_FILE" --query ../../CIDS/validation/sparql/aa-sparql.sparql > "$OUTPUT_SHACL_FILE"; then
# if sparql --data "$INPUT_TTL_FILE" --query ../../CIDS/validation/sparql/sparql-owl-to-shacl.sparql > "$OUTPUT_SHACL_FILE"; then
    echo "Successfully created SHACL file: $OUTPUT_SHACL_FILE"
else
    echo "Error: Failed to process file"
    exit 1
fi
