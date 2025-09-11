param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$InputTtlFile,
    
    [Parameter(Mandatory=$true, Position=1)]
    [ValidateSet("cids:BasicTier", "cids:EssentialTier", "cids:FullTier")]
    [string]$Mode,
    
    [Parameter(Mandatory=$false, Position=2)]
    [string]$OutputShaclFile
)

# usage: .\buildShacl.ps1 <input-ttl-file> <mode> [output-shacl-file]
# need to specify the folder paths for the ttl and shacl files relative to the current directory
# mode can be: cids:BasicTier, cids:EssentialTier, or cids:FullTier

# Generate default output filename if not provided
if ([string]::IsNullOrEmpty($OutputShaclFile)) {
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($InputTtlFile)
    switch ($Mode) {
        "cids:BasicTier" { $OutputShaclFile = "$baseName.basic.shacl.ttl" }
        "cids:EssentialTier" { $OutputShaclFile = "$baseName.essential.shacl.ttl" }
        "cids:FullTier" { $OutputShaclFile = "$baseName.full.shacl.ttl" }
    }
}

# Display usage information
if ($InputTtlFile -eq "" -or $Mode -eq "") {
    Write-Host "Usage: .\buildShacl.ps1 <input-ttl-file> <mode> [output-shacl-file]"
    Write-Host "Modes: cids:BasicTier, cids:EssentialTier, cids:FullTier"
    Write-Host "Example: .\buildShacl.ps1 models/cids.ttl cids:BasicTier"
    Write-Host "Example: .\buildShacl.ps1 models/cids.ttl cids:BasicTier cids.basic.shacl.ttl"
    exit 1
}

# Verify input file exists
if (-not (Test-Path $InputTtlFile)) {
    Write-Error "Input file '$InputTtlFile' does not exist."
    exit 1
}

# Verify SPARQL query file exists
$sparqlQueryFile = "sparql/sparql-owl-to-shacl-revised.sparql"
if (-not (Test-Path $sparqlQueryFile)) {
    Write-Error "SPARQL query file '$sparqlQueryFile' does not exist."
    exit 1
}

# Create output directory if it doesn't exist
$outputDir = Split-Path $OutputShaclFile -Parent
if ($outputDir -and -not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

Write-Host "Processing: $InputTtlFile -> $OutputShaclFile (Mode: $Mode)"

try {
    # Read the SPARQL query template
    $sparqlTemplate = Get-Content $sparqlQueryFile -Raw
    
    # Replace the $mode parameter with the actual mode value
    $sparqlQuery = $sparqlTemplate -replace '\$mode', $Mode
    
    # Create a temporary file for the modified query
    $tempQueryFile = [System.IO.Path]::GetTempFileName() + ".sparql"
    Set-Content -Path $tempQueryFile -Value $sparqlQuery -Encoding UTF8
    
    try {
        # Execute SPARQL with the modified query
        sparql --data $InputTtlFile --query $tempQueryFile | Set-Content -Path $OutputShaclFile -Encoding UTF8
        Write-Host "Successfully created SHACL file: $OutputShaclFile"
    } finally {
        # Clean up temporary file
        if (Test-Path $tempQueryFile) {
            Remove-Item $tempQueryFile -Force
        }
    }
} catch {
    Write-Error "Failed to process file: $_"
    exit 1
}