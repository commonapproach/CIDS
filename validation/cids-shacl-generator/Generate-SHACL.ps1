#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Generates SHACL shapes from CIDS ontology for specified tiers
.DESCRIPTION
    This script processes CIDS ontology tiers and generates SHACL validation shapes.
    Supports multiple tiers separated by + signs (e.g., "cids:BasicTier+cids:EssentialTier+cids:FullTier")
.PARAMETER Mode
    Tier specification as CURIEs separated by + signs
.PARAMETER OntologyFile
    Path to the CIDS ontology turtle file
.PARAMETER SparqlFile
    Path to the SPARQL query template file
.PARAMETER OutputDir
    Output directory for generated SHACL files (default: "./output")
.PARAMETER SparqlTool
    SPARQL query tool to use (default: "arq")
.EXAMPLE
    .\Generate-SHACL.ps1 -Mode "cids:EssentialTier" -OntologyFile "cids.ttl"
.EXAMPLE
    .\Generate-SHACL.ps1 -Mode "cids:BasicTier+cids:EssentialTier+cids:FullTier" -OntologyFile "cids.ttl"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$Mode,
    
    [Parameter(Mandatory=$true)]
    [string]$OntologyFile,
    
    [Parameter(Mandatory=$true)]
    [string]$SparqlFile,
    
    [string]$OutputDir = "./output",
    
    [string]$SparqlTool = "arq"
)

# Function to validate CURIE format
function Test-CurieFormat {
    param([string]$curie)
    return $curie -match '^[a-zA-Z_][a-zA-Z0-9_]*:[a-zA-Z_][a-zA-Z0-9_]*$'
}

# Function to sanitize filename
function Get-SafeFilename {
    param([string]$name)
    
    # Replace invalid filename characters
    $invalidChars = [IO.Path]::GetInvalidFileNameChars()
    $safeName = $name
    foreach ($char in $invalidChars) {
        $safeName = $safeName.Replace($char, '_')
    }
    
    # Replace additional problematic characters
    $safeName = $safeName -replace '[+:]', '_'
    $safeName = $safeName -replace '__+', '_'  # Replace multiple underscores with single
    $safeName = $safeName.Trim('_')  # Remove leading/trailing underscores
    
    return $safeName
}

# Function to extract local name from CURIE
function Get-LocalName {
    param([string]$curie)
    if ($curie -match '^[^:]+:(.+)$') {
        return $matches[1]
    }
    return $curie
}

try {
    Write-Host "Multi-Tier SHACL Generation Script" -ForegroundColor Green
    Write-Host "==================================" -ForegroundColor Green
    
    # Validate input files
    if (-not (Test-Path $OntologyFile)) {
        throw "Ontology file not found: $OntologyFile"
    }
    
    if (-not (Test-Path $SparqlFile)) {
        throw "SPARQL file not found: $SparqlFile"
    }
    
    # Create output directory
    if (-not (Test-Path $OutputDir)) {
        New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
        Write-Host "Created output directory: $OutputDir" -ForegroundColor Yellow
    }
    
    # Parse tier specifications
    $tierSpecs = $Mode -split '\+' | ForEach-Object { $_.Trim() }
    
    # Validate each tier CURIE
    foreach ($tier in $tierSpecs) {
        if (-not (Test-CurieFormat $tier)) {
            throw "Invalid CURIE format: $tier. Expected format: prefix:localname"
        }
    }
    
    Write-Host "Processing tiers: $($tierSpecs -join ', ')" -ForegroundColor Cyan
    
    # Read SPARQL template
    $sparqlTemplate = Get-Content $SparqlFile -Raw
    
    # Prepare VALUES clause for multiple tiers
    $valuesClause = "VALUES ?activeTier { " + ($tierSpecs -join ' ') + " }"
    
    # Prepare tier list for FILTER clauses
    $tierList = $tierSpecs -join ', '
    
    # Replace placeholders in SPARQL template
    $processedSparql = $sparqlTemplate
    $processedSparql = $processedSparql -replace '\$TIERS', $valuesClause
    $processedSparql = $processedSparql -replace '\$TIER_LIST', $tierList
    
    # Generate safe filename for output
    $tierNames = $tierSpecs | ForEach-Object { Get-LocalName $_ }
    $baseFilename = "cids-shacl-" + ($tierNames -join '-')
    $safeFilename = Get-SafeFilename $baseFilename
    $outputFile = Join-Path $OutputDir "$safeFilename.ttl"
    $tempSparqlFile = Join-Path $OutputDir "temp-query.sparql"
    
    Write-Host "Output file: $outputFile" -ForegroundColor Yellow
    
    # Write processed SPARQL to temporary file
    $processedSparql | Out-File -FilePath $tempSparqlFile -Encoding UTF8
    
    # Execute SPARQL query
    Write-Host "Executing SPARQL query..." -ForegroundColor Cyan
    
    $sparqlCommand = @(
        $SparqlTool
        "--data=$OntologyFile"
        "--query=$tempSparqlFile"
        "--results=TTL"
    )
    
    Write-Host "Command: $($sparqlCommand -join ' ')" -ForegroundColor Gray
    
    # Execute query and capture output
    $result = & $sparqlCommand[0] $sparqlCommand[1..($sparqlCommand.Length-1)] 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "SPARQL execution failed with exit code $LASTEXITCODE"
        Write-Error "Error output: $result"
        throw "SPARQL query execution failed"
    }
    
    # Write results to output file
    $result | Out-File -FilePath $outputFile -Encoding UTF8
    
    # Clean up temporary file
    if (Test-Path $tempSparqlFile) {
#        Remove-Item $tempSparqlFile -Force
    }
    
    # Validate output
    if (Test-Path $outputFile) {
        $outputSize = (Get-Item $outputFile).Length
        if ($outputSize -gt 0) {
            Write-Host "✓ Successfully generated SHACL shapes: $outputFile" -ForegroundColor Green
            Write-Host "  File size: $outputSize bytes" -ForegroundColor Gray
            
            # Count generated triples (approximate)
            $content = Get-Content $outputFile -Raw
            $tripleCount = ($content -split '\.' | Where-Object { $_.Trim() -and $_ -notmatch '^\s*@' }).Count
            Write-Host "  Approximate triples: $tripleCount" -ForegroundColor Gray
        } else {
            Write-Warning "Output file is empty. Check if the specified tiers exist in the ontology."
        }
    } else {
        throw "Output file was not created: $outputFile"
    }
    
    Write-Host "`nProcessing Summary:" -ForegroundColor Green
    Write-Host "  Input ontology: $OntologyFile"
    Write-Host "  Processed tiers: $($tierSpecs -join ', ')"
    Write-Host "  Output SHACL: $outputFile"
    Write-Host "  Status: Complete" -ForegroundColor Green
    
} catch {
    Write-Error "Script execution failed: $($_.Exception.Message)"
    Write-Error "At line $($_.InvocationInfo.ScriptLineNumber): $($_.InvocationInfo.Line.Trim())"
    exit 1
}

<#
.NOTES
    Example usage scenarios:

    # Single tier
    .\Generate-SHACL.ps1 -Mode "cids:EssentialTier" -OntologyFile "cids.ttl" -SparqlFile "multi-tier-query.sparql"

    # Multiple tiers
    .\Generate-SHACL.ps1 -Mode "cids:BasicTier+cids:EssentialTier" -OntologyFile "cids.ttl" -SparqlFile "multi-tier-query.sparql"

    # All tiers
    .\Generate-SHACL.ps1 -Mode "cids:BasicTier+cids:EssentialTier+cids:FullTier+cids:SFFTier" -OntologyFile "cids.ttl" -SparqlFile "multi-tier-query.sparql"

    # Custom output directory
    .\Generate-SHACL.ps1 -Mode "cids:EssentialTier" -OntologyFile "cids.ttl" -SparqlFile "multi-tier-query.sparql" -OutputDir "./shacl-output"

    Prerequisites:
    - Apache Jena ARQ tool installed and in PATH
    - PowerShell 5.1+ or PowerShell Core 6+
    - Input ontology file in Turtle format
    - SPARQL query template file
#>