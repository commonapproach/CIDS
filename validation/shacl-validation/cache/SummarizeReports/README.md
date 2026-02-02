# SHACL Violations Summary Script

## Overview
This script summarizes SHACL validation violations from Apache Jena validation reports. It groups violations by property, error message, and node type, and provides counts and lists of affected focus nodes.

## Requirements
- Python 3.6+
- rdflib library

Install rdflib:
```bash
pip3 install rdflib
```

## Usage
```bash
python3 summarize_shacl_violations.py <validation_report.ttl> [output.txt]
```

### Arguments
- `validation_report.ttl`: Path to the SHACL validation report file (Turtle format)
- `output.txt`: (Optional) Path for the output summary file. If not provided, defaults to `<input_file>_summary.txt`

### Example
```bash
python3 summarize_shacl_violations.py amplify-sff-report.ttl amplify-sff-summary.txt
```

## Output Format
The script generates a plain text summary with:

1. **Total Violations**: Total count of all violations
2. **Violations by Constraint Component Type**: Breakdown by constraint type (DatatypeConstraint, ClassConstraint, MinCountConstraint, etc.)
3. **Detailed Violation Breakdown**: Grouped by:
   - Property (resultPath)
   - Error Message (resultMessage)
   - Node Type (extracted from sourceShape)
   - Count and list of affected focus nodes

## How It Works
- Parses the Turtle format validation report using RDFLib
- Extracts node types from `sh:sourceShape` using the pattern: `prefix:NodeType_property_PropertyShape`
- Groups violations hierarchically: Property → Error Message → Node Type
- Counts violations by constraint component type
- Lists all unique focus nodes affected by each violation type

