# Multi-Tier SHACL Generation for CIDS Ontology

This toolkit converts OWL class definitions and property restrictions from the CIDS (Common Impact Data Standard) ontology into SHACL (Shapes Constraint Language) validation shapes, with support for multiple tier filtering.

## Package Contents

- **`multi-tier-query.sparql`** - SPARQL CONSTRUCT query template that handles multiple tiers
- **`Generate-SHACL.ps1`** - PowerShell script for cross-platform execution
- **`generate-shacl.bat`** - Windows CMD batch script
- **`generate-shacl.sh`** - Bash script for Linux/Ubuntu
- **`README.md`** - This documentation
- **`examples/`** - Sample usage examples and tier combinations
- **`output/`** - Default output directory for generated SHACL files

## Prerequisites

1. **Apache Jena ARQ** - SPARQL query processor
   - **Ubuntu/Debian**: `sudo apt-get install jena`
   - **Other platforms**: Download from https://jena.apache.org/download/
   - Ensure `arq` command is in your system PATH
   - Test installation: `arq --version`

2. **CIDS Ontology File** - Turtle format (.ttl)

3. **Script Runtime**:
   - **Linux/macOS**: Bash shell (included by default)
   - **Windows**: PowerShell or Command Prompt
   - **Cross-platform**: PowerShell Core 6+

## Quick Start

### Linux/Ubuntu (Recommended)

```bash
# Make script executable
chmod +x generate-shacl.sh

# Generate SHACL for essential tier
./generate-shacl.sh "cids:EssentialTier" cids.ttl multi-tier-query.sparql

# Multiple tiers
./generate-shacl.sh "cids:BasicTier+cids:EssentialTier" cids.ttl multi-tier-query.sparql
```

### Windows PowerShell

```powershell
# Single tier
.\Generate-SHACL.ps1 -Mode "cids:EssentialTier" -OntologyFile "cids.ttl" -SparqlFile "multi-tier-query.sparql"

# Multiple tiers
.\Generate-SHACL.ps1 -Mode "cids:BasicTier+cids:EssentialTier" -OntologyFile "cids.ttl" -SparqlFile "multi-tier-query.sparql"
```

### Windows Command Prompt

```cmd
REM Single tier
generate-shacl.bat "cids:EssentialTier" cids.ttl multi-tier-query.sparql

REM Multiple tiers
generate-shacl.bat "cids:BasicTier+cids:EssentialTier" cids.ttl multi-tier-query.sparql
```

## Detailed Usage

### Bash Script (Linux/Ubuntu)

```bash
# Basic syntax
./generate-shacl.sh "tier1+tier2+..." ontology.ttl query.sparql [output_dir]

# Examples
./generate-shacl.sh "cids:EssentialTier" cids.ttl multi-tier-query.sparql
./generate-shacl.sh "cids:BasicTier+cids:EssentialTier+cids:FullTier" cids.ttl multi-tier-query.sparql
./generate-shacl.sh "cids:EssentialTier" cids.ttl multi-tier-query.sparql "./custom-output"

# View help
./generate-shacl.sh
```

### PowerShell Script (Cross-platform)

```powershell
# Basic syntax
.\Generate-SHACL.ps1 -Mode "tier1+tier2+..." -OntologyFile "ontology.ttl" -SparqlFile "query.sparql" [-OutputDir "output_dir"]

# Examples
.\Generate-SHACL.ps1 -Mode "cids:EssentialTier" -OntologyFile "cids.ttl" -SparqlFile "multi-tier-query.sparql"
.\Generate-SHACL.ps1 -Mode "cids:BasicTier+cids:EssentialTier+cids:FullTier+cids:SFFTier" -OntologyFile "cids.ttl" -SparqlFile "multi-tier-query.sparql"
.\Generate-SHACL.ps1 -Mode "cids:EssentialTier" -OntologyFile "cids.ttl" -SparqlFile "multi-tier-query.sparql" -OutputDir "./shacl-output"

# Get help
Get-Help .\Generate-SHACL.ps1 -Full
```

### Batch Script (Windows CMD)

```cmd
REM Basic syntax
generate-shacl.bat "tier1+tier2+..." ontology.ttl query.sparql [output_dir]

REM Examples
generate-shacl.bat "cids:EssentialTier" cids.ttl multi-tier-query.sparql
generate-shacl.bat "cids:BasicTier+cids:EssentialTier+cids:FullTier+cids:SFFTier" cids.ttl multi-tier-query.sparql
generate-shacl.bat "cids:EssentialTier" cids.ttl multi-tier-query.sparql "./output"

REM View help
generate-shacl.bat
```

## Parameters

### Mode Parameter
- **Format**: `"tier1+tier2+tier3+..."`
- **Separator**: `+` (plus sign)
- **Examples**:
  - `"cids:EssentialTier"`
  - `"cids:BasicTier+cids:EssentialTier"`
  - `"cids:BasicTier+cids:EssentialTier+cids:FullTier+cids:SFFTier"`

### Available CIDS Tiers
- **`cids:BasicTier`** - Core operational elements
- **`cids:EssentialTier`** - Fundamental validation requirements
- **`cids:FullTier`** - Complete feature set
- **`cids:SFFTier`** - Social Finance Framework specific elements

### Common Tier Combinations
```bash
# Essential only (minimal validation)
"cids:EssentialTier"

# Basic + Essential (standard validation)
"cids:BasicTier+cids:EssentialTier"

# Essential + Full (comprehensive validation)
"cids:EssentialTier+cids:FullTier"

# All tiers (complete validation)
"cids:BasicTier+cids:EssentialTier+cids:FullTier+cids:SFFTier"
```

## Output

### Generated Files
- **SHACL shapes file**: `cids-shacl-{tier-names}.ttl`
  - Example: `cids-shacl-BasicTier-EssentialTier.ttl`
- **Location**: `./output/` directory (default) or custom directory

### Filename Generation
The scripts automatically generate safe filenames by:
1. Extracting local names from CURIEs (e.g., `EssentialTier` from `cids:EssentialTier`)
2. Joining multiple tiers with hyphens
3. Replacing invalid filename characters with underscores
4. Adding `.ttl` extension

### Example Output Files
```
./output/
├── cids-shacl-EssentialTier.ttl
├── cids-shacl-BasicTier-EssentialTier.ttl
├── cids-shacl-EssentialTier-FullTier.ttl
└── cids-shacl-BasicTier-EssentialTier-FullTier-SFFTier.ttl
```

## SHACL Output Features

### Generated SHACL Elements

1. **Node Shapes** - One per OWL class in specified tiers
   ```turtle
   csh:Code_NodeShape a sh:NodeShape ;
       sh:targetClass cids:Code ;
       sh:closed false ;
       csh:activeTier cids:EssentialTier ;
       sh:property csh:Code_hasName_PropertyShape .
   ```

2. **Property Shapes** - Based on OWL property restrictions
   ```turtle
   csh:Code_hasName_PropertyShape a sh:PropertyShape ;
       sh:path org:hasName ;
       sh:datatype xsd:string ;
       sh:minCount 1 ;
       sh:maxCount 1 ;
       csh:cardinality csh:ExactlyOne .
   ```

3. **Cardinality Mappings**
   - `owl:qualifiedCardinality "1"` → `csh:ExactlyOne` + `sh:minCount 1; sh:maxCount 1`
   - `owl:minQualifiedCardinality "1"` → `csh:OneOrMore` + `sh:minCount 1`
   - `owl:maxQualifiedCardinality "1"` → `csh:Optional` + `sh:maxCount 1`
   - No constraints → `csh:ZeroOrMore`

4. **Enumerations** - From named individuals in specified tiers
   ```turtle
   cids:positive a cids:ImpactType ;
       rdfs:label "positive" ;
       csh:memberOf cids:ImpactType .
   ```

### Validation Capabilities

The generated SHACL shapes validate:
- **Required properties** (exactlyOne cardinality)
- **Optional properties** (maxCardinality constraints)
- **Datatype constraints** (string, dateTime, URI, boolean, etc.)
- **Class constraints** (object property ranges)
- **Enumeration values** (from named individuals)
- **Tier compliance** (only elements from specified tiers)

## Troubleshooting

### Common Issues

1. **"arq command not found"**
   - **Ubuntu/Debian**: `sudo apt-get install jena`
   - **Other systems**: Download from https://jena.apache.org/download/
   - Ensure Apache Jena bin directory is in your PATH
   - Test with: `arq --version`

2. **"Permission denied" (Bash script)**
   - Make script executable: `chmod +x generate-shacl.sh`
   - Ensure you have write permissions on output directory

3. **PowerShell execution policy error**
   - Check policy: `Get-ExecutionPolicy`
   - Set policy: `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser`

4. **Empty output file**
   - Check if specified tiers exist in ontology
   - Verify tier annotations: `cids:belongsToTier cids:EssentialTier`
   - Ensure ontology file is valid Turtle format

5. **Invalid CURIE format error**
   - Ensure format: `prefix:localname`
   - Use namespace prefixes defined in ontology
   - Check for typos in tier names

6. **Script not found errors**
   - Ensure you're in the correct directory
   - Use `./` prefix for bash script execution
   - Check file extensions (.ps1, .bat, .sh)

### Platform-Specific Notes

#### Linux/Ubuntu
- Scripts use standard Unix tools (sed, grep, stat)
- Requires executable permissions: `chmod +x generate-shacl.sh`
- Uses colored output for better user experience

#### Windows PowerShell
- Cross-platform compatible (Windows PowerShell 5.1+ or PowerShell Core 6+)
- Includes comprehensive error handling and validation
- Supports both absolute and relative paths

#### Windows CMD
- Uses batch file syntax and Windows-specific commands
- Handles string parsing with batch-specific methods
- Automatic pause at end for review

### Validation of Generated SHACL

To validate your generated SHACL shapes:

```bash
# Using Apache Jena shacl tool
shacl validate --shapes=output/cids-shacl-EssentialTier.ttl --data=your-impact-data.ttl

# Using other SHACL validators
# TopQuadrant SHACL API, RDF4J SHACL, pySHACL, etc.
```

## Complete Workflow Example

```bash
# 1. Setup (Ubuntu)
sudo apt-get install jena
chmod +x generate-shacl.sh

# 2. Generate SHACL for essential tier only
./generate-shacl.sh "cids:EssentialTier" cids.ttl multi-tier-query.sparql

# 3. Generate SHACL for multiple tiers
./generate-shacl.sh "cids:BasicTier+cids:EssentialTier+cids:FullTier" cids.ttl multi-tier-query.sparql

# 4. Validate your impact data against generated shapes
shacl validate --shapes=output/cids-shacl-BasicTier-EssentialTier-FullTier.ttl --data=my-impact-data.ttl

# 5. Review validation report
cat shacl-validation-report.ttl
```

## Technical Architecture

### SPARQL Query Template
The `multi-tier-query.sparql` file uses template placeholders:
- **`$TIERS`** - Replaced with VALUES clause: `VALUES ?activeTier { cids:BasicTier cids:EssentialTier }`
- **`$TIER_LIST`** - Replaced with comma-separated list: `cids:BasicTier, cids:EssentialTier`

### Processing Logic
1. **Tier Filtering**: Only processes classes and properties with `cids:belongsToTier` annotations matching specified tiers
2. **Union Processing**: Creates SPARQL VALUES clauses to handle multiple tiers simultaneously
3. **Shape Generation**: Converts OWL restrictions to SHACL property shapes with appropriate constraints
4. **Filename Sanitization**: Generates valid, descriptive filenames from CURIE specifications

### Custom CIDS Extensions
The generated SHACL includes custom properties:
- `csh:activeTier` - Tracks which tier a shape belongs to
- `csh:cardinality` - CIDS-specific cardinality semantics
- `csh:usedBy` - Tracks which class uses a property shape
- `csh:memberOf` - Groups enumeration values

## Support and Development

### Requirements for Contributing
- Understanding of OWL, SPARQL, and SHACL
- Familiarity with CIDS ontology structure
- Cross-platform scripting experience

### Known Limitations
- Only processes elements explicitly marked with tier annotations
- Does not handle complex OWL expressions beyond basic restrictions
- Generated shapes focus on structural validation, not business logic
- Requires Apache Jena ARQ for execution

### Future Enhancements
- Support for additional SHACL advanced features
- Integration with CIDS validation services
- Automated testing framework
- GUI interface for non-technical users

For issues or questions, refer to the CIDS documentation at https://www.commonapproach.org/ or the SHACL specification at https://www.w3.org/TR/shacl/.