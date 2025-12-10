#!/bin/bash
# Convert sff2.ttl to sff2.owl using ROBOT
# This script converts sff2.ttl to OWL format without loading imported ontologies.
# Only the content defined in sff2.ttl (sff: namespace) will be included.
# Usage: ./convert-sff2-to-owl.sh

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

# Run ROBOT conversion (no catalog needed since we're not loading imports)
java -jar "$SCRIPT_DIR/robot.jar" convert \
    -i "$PROJECT_ROOT/sff2.ttl" \
    -f owl \
    -o "$PROJECT_ROOT/sff2.owl"

echo "Conversion complete: sff2.owl created (contains only sff: namespace content, no imports)"
