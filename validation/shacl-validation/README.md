# CIDS Validation Script

A comprehensive validation tool for CIDS (Common Impact Data Standard) data files using Apache Jena SHACL validation. This script validates JSON-LD data files against SHACL shapes and generates detailed violation reports with summaries.

## Overview

The `CIDS-validate.sh` script provides an automated workflow for:
- Validating CIDS data files against SHACL shapes (Basic Tier and/or SFF)
- Merging codelist reference data with your data files
- Generating detailed violation reports and summaries
- Caching merged codelists for improved performance

## Requirements

### Software Dependencies

1. **Apache Jena** - Required for SHACL validation and RDF processing
   - Download: https://jena.apache.org/download/
   - Ensure `shacl` and `riot` commands are in your PATH
   - Test installation: `shacl validate --help` and `riot --help`

2. **Python 3.7+** - Required for violation summarization
   - Python 3.7 or higher
   - Test installation: `python3 --version`

3. **Python Packages**
   - `rdflib` - For parsing RDF and generating summaries
   - Install: `pip3 install rdflib`
   - Or via Homebrew: `brew install python3 && pip3 install rdflib`

### File Structure

The script expects the following directory structure:
```
JenaValidator/
├── CIDS-validate.sh
├── cache/
│   ├── merged-codelists.ttl          # Cached merged codelists (auto-generated)
│   ├── prefixes.ttl                   # Prefix definitions
│   ├── cids-codes-and-orgs.ttl        # CIDS code classes and organizations
│   └── SummarizeReports/
│       └── summarize_shacl_violations.py
└── validations/                       # Output directory (auto-created)
    └── [filename][timestamp]/        # Timestamped validation results
```

## Installation

1. **Make the script executable:**
   ```bash
   chmod +x CIDS-validate.sh
   ```

2. **Verify Apache Jena is installed:**
   ```bash
   shacl validate --help
   riot --help
   ```

3. **Install Python dependencies:**
   ```bash
   pip3 install rdflib
   ```

4. **First run setup:**
   - On first run with `--codelists`, the script will:
     - Create the `cache/` directory
     - Move `prefixes.ttl` and `cids-codes-and-orgs.ttl` to cache (if present)
     - Generate the cached merged codelists file

## Usage

### Basic Syntax

```bash
./CIDS-validate.sh [OPTIONS] <data_file>
```

### Arguments

| Flag | Description |
|------|-------------|
| `--basic` | Validate against CIDS Basic Tier SHACL shapes |
| `--sff` | Validate against SFF SHACL shapes (includes Basic Tier) |
| `--codelists` | Include codelist reference data in validation |
| `--code-violations` | Include violations from imported codelists in summary (default: excluded) |
| `--no-summary` | Skip generation of violation summary reports |
| `--rebuild-cache` | Force rebuild of cached merged codelists file |
| `<data_file>` | Path to JSON-LD or JSON data file to validate (required) |

**Note:** At least one of `--basic` or `--sff` must be specified.

### Examples

**Basic validation:**
```bash
./CIDS-validate.sh --basic mydata.jsonld
```

**SFF validation with codelists:**
```bash
./CIDS-validate.sh --sff --codelists mydata.jsonld
```

**Both Basic and SFF validation:**
```bash
./CIDS-validate.sh --basic --sff --codelists mydata.jsonld
```

**Include codelist violations in summary:**
```bash
./CIDS-validate.sh --sff --codelists --code-violations mydata.jsonld
```

**Force cache rebuild:**
```bash
./CIDS-validate.sh --sff --codelists --rebuild-cache mydata.jsonld
```

**Validate JSON file (auto-converted to JSON-LD):**
```bash
./CIDS-validate.sh --basic mydata.json
```

**Skip summary generation:**
```bash
./CIDS-validate.sh --basic --no-summary mydata.jsonld
```

## Output Structure

Validation results are saved in timestamped folders within `JenaValidator/validations/`:

```
validations/
└── [filename][YYYYMMDD-HHMMSS]/
    ├── [filename].jsonld                    # Copy of source data file
    ├── report-[shapes]-[filename].ttl       # SHACL validation report (Turtle)
    ├── report-[shapes]-[filename]_warnings.txt  # Warnings/errors from validation
    ├── report-[shapes]-[filename]_summary.txt   # Human-readable violation summary
    └── merged-file-[filename].ttl            # Merged codelists + data (if --codelists used)
```

### Summary Report Contents

The summary report includes:

1. **Command** - The exact command used to run validation
2. **Node Types in Source Data File** - Count of each node type found in your data
3. **Total Violations** - Total count of violations (with codelist exclusion note if applicable)
4. **Violations by Constraint Component Type** - Breakdown by constraint type with property subtotals
5. **Detailed Violation Breakdown** - Grouped by:
   - Property (resultPath)
   - Error Message (normalized)
   - Node Type
   - Affected focus nodes and values

## Codelist Caching System

The script includes an intelligent caching system for improved performance:

### How It Works

1. **First Run:** When `--codelists` is used for the first time, the script:
   - Merges all 14 specified codelist files + `cids-codes-and-orgs.ttl`
   - Converts to N-Triples, then to formatted Turtle with prefixes
   - Saves to `cache/merged-codelists.ttl`

2. **Subsequent Runs:** The script:
   - Checks if cached file exists
   - Compares modification times of source files vs cache
   - Rebuilds cache only if source files are newer
   - Uses cached file for faster validation

### Cache Management

- **Automatic:** Cache is automatically maintained and rebuilt when needed
- **Manual Rebuild:** Use `--rebuild-cache` flag to force rebuild
- **Cache Location:** `JenaValidator/cache/merged-codelists.ttl`
- **Cache Size:** Typically ~188KB (merged from 14+ files)

### Included Codelists

The following codelist files are included when using `--codelists`:

- CanadianCorporateRegistries.ttl
- EquityDeservingGroupsESDC.ttl
- ESDCSector.ttl
- FundingState.ttl
- IRISImpactCategory.ttl
- IRISImpactTheme.ttl
- LocalityStatsCan.ttl
- OrgTypeGOC.ttl
- PopulationServed.ttl
- ProvinceTerritory.ttl
- RallyImpactArea.ttl
- SDGImpacts.ttl
- SELI-GLI.ttl
- UnitsOfMeasureList.ttl
- cids-codes-and-orgs.ttl (CIDS code classes and organizations)

## Two-Step Merge Process

When merging codelists with data files, the script uses a two-step process:

1. **Step 1a:** Convert cached codelists to N-Triples (resolves relative IRIs)
2. **Step 1b:** Merge codelists N-Triples with data file to N-Triples
3. **Step 2:** Convert merged N-Triples to formatted Turtle with prefix definitions

This ensures:
- All relative IRIs are resolved to absolute URIs
- Clean, formatted output with proper prefix usage
- Consistent merging regardless of input format

## Troubleshooting

### Script Hangs During Merge

**Symptom:** Script appears to hang at "Merging 1 codelist file(s)..."

**Cause:** Large data files can take several minutes to process. The script is working, but processing is slow.

**Solution:**
- Wait for completion (can take 5-10+ minutes for very large files)
- Check progress messages - the script now shows which step is running
- For extremely large files, consider processing in smaller chunks

### Cache Not Updating

**Symptom:** Changes to codelist files aren't reflected in validation

**Solution:**
- Use `--rebuild-cache` flag to force cache rebuild
- Check that codelist files are in the expected directory: `/Users/garthyule/Documents/Common_Approach/CodeLists`

### Python Script Not Found

**Symptom:** "Summarization script not found" warning

**Solution:**
- Ensure `cache/SummarizeReports/summarize_shacl_violations.py` exists
- Check file permissions: `chmod +x cache/SummarizeReports/summarize_shacl_violations.py`

### Invalid Literal Errors

**Symptom:** Python errors about invalid literals (empty strings with xsd:dateTime, etc.)

**Solution:**
- These are warnings from your data file, not script errors
- The script handles these gracefully and continues processing
- Fix invalid literals in your source data file for cleaner validation

### Missing Codelist Files

**Symptom:** "Warning: Codelist file not found" messages

**Solution:**
- Verify codelist files exist in `/Users/garthyule/Documents/Common_Approach/CodeLists`
- Check file names match exactly (case-sensitive)
- Script will continue with available files

## Performance Tips

1. **Use Caching:** Always use `--codelists` - the cache system makes it fast
2. **Skip Summary:** Use `--no-summary` for faster validation if you only need the TTL report
3. **Large Files:** Be patient with large JSON-LD files - processing can take time
4. **Cache Rebuild:** Only use `--rebuild-cache` when codelist files actually change

## Advanced Usage

### Validating Multiple Files

The script validates one file at a time. To validate multiple files:

```bash
for file in *.jsonld; do
  ./CIDS-validate.sh --sff --codelists "$file"
done
```

### Custom Output Location

Validation results are always saved in `validations/` subdirectory. To change this, modify the `validations_base_dir` variable in the script.

### Integration with CI/CD

The script is suitable for automated validation in CI/CD pipelines:

```bash
#!/bin/bash
./CIDS-validate.sh --sff --codelists data.jsonld
if [ $? -ne 0 ]; then
  echo "Validation failed"
  exit 1
fi
```

## File Formats

### Input Files

- **JSON-LD** (`.jsonld`) - Preferred format, used directly
- **JSON** (`.json`) - Automatically converted to `.jsonld` for Jena compatibility

### Output Files

- **Validation Report** (`.ttl`) - SHACL validation report in Turtle format
- **Summary** (`.txt`) - Human-readable violation summary
- **Warnings** (`.txt`) - Warnings and errors from validation process
- **Merged File** (`.ttl`) - Merged codelists + data (when `--codelists` used)

## See Also

- [Apache Jena Documentation](https://jena.apache.org/documentation/)
- [SHACL Specification](https://www.w3.org/TR/shacl/)
- [CIDS Ontology](https://ontology.commonapproach.org/cids)

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review validation warnings in `*_warnings.txt` files
3. Check that all dependencies are properly installed
4. Verify file paths and permissions

