param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$InputTtlFile,
    
    [Parameter(Mandatory=$true, Position=1)]
    [string]$OutputShaclFile
)

# usage: .\buildShacl.ps1 <input-ttl-file> <output-shacl-file>
# need to specify the folder paths for the ttl and shacl files relative to the current directory

# Display usage information
if ($InputTtlFile -eq "" -or $OutputShaclFile -eq "") {
    Write-Host "Usage: .\buildShacl.ps1 <input-ttl-file> <output-shacl-file>"
    Write-Host "Example: .\buildShacl.ps1 models/cids.ttl cids.basic.shacl.ttl"
    exit 1
}

# Verify input file exists
if (-not (Test-Path $InputTtlFile)) {
    Write-Error "Input file '$InputTtlFile' does not exist."
    exit 1
}

# Create output directory if it doesn't exist
$outputDir = Split-Path $OutputShaclFile -Parent
if ($outputDir -and -not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

Write-Host "Processing: $InputTtlFile -> $OutputShaclFile"

try {
    sparql --data $InputTtlFile --query sparql/sparql-owl-to-shacl.sparql | Set-Content -Path $OutputShaclFile -Encoding UTF8
    Write-Host "Successfully created SHACL file: $OutputShaclFile"
} catch {
    Write-Error "Failed to process file: $_"
    exit 1
}