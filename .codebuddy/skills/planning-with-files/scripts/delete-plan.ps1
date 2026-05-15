# delete-plan.ps1
# Deletes a plan file from the plans directory
# Usage: ./delete-plan.ps1 -PlanName <name> [-Force] [-PlansDir <path>]

param(
    [Parameter(Mandatory = $true)]
    [string]$PlanName,

    [Parameter(Mandatory = $false)]
    [switch]$Force,

    [Parameter(Mandatory = $false)]
    [string]$PlansDir = ".plans"
)

# Normalize plan name: strip .md extension if provided
$PlanName = $PlanName -replace '\.md$', ''

# Resolve plans directory relative to current working directory
$PlansPath = Join-Path (Get-Location) $PlansDir

# Check that plans directory exists
if (-not (Test-Path $PlansPath -PathType Container)) {
    Write-Error "Plans directory not found: $PlansPath"
    exit 1
}

# Build full path to the plan file
$PlanFile = Join-Path $PlansPath "$PlanName.md"

# Check that the plan file exists
if (-not (Test-Path $PlanFile -PathType Leaf)) {
    Write-Error "Plan not found: $PlanFile"
    exit 1
}

# Read plan metadata for confirmation display
$PlanContent = Get-Content $PlanFile -Raw
$TitleMatch = [regex]::Match($PlanContent, '^#\s+(.+)$', [System.Text.RegularExpressions.RegexOptions]::Multiline)
$PlanTitle = if ($TitleMatch.Success) { $TitleMatch.Groups[1].Value.Trim() } else { $PlanName }

$StatusMatch = [regex]::Match($PlanContent, '(?i)\*\*Status\*\*[:\s]+([^\n]+)')
$PlanStatus = if ($StatusMatch.Success) { $StatusMatch.Groups[1].Value.Trim() } else { 'unknown' }

# Display plan info before deletion
Write-Host ""
Write-Host "Plan to delete:"
Write-Host "  File   : $PlanFile"
Write-Host "  Title  : $PlanTitle"
Write-Host "  Status : $PlanStatus"
Write-Host ""

# Prompt for confirmation unless -Force is specified
if (-not $Force) {
    $Confirm = Read-Host "Are you sure you want to delete this plan? [y/N]"
    if ($Confirm -notmatch '^[Yy]$') {
        Write-Host "Deletion cancelled."
        exit 0
    }
}

# Attempt to delete the plan file
try {
    Remove-Item -Path $PlanFile -Force
    Write-Host "Plan '$PlanName' deleted successfully."
} catch {
    Write-Error "Failed to delete plan: $_"
    exit 1
}

# Check if plans directory is now empty and optionally report
$RemainingPlans = Get-ChildItem -Path $PlansPath -Filter '*.md' -File
$RemainingCount = ($RemainingPlans | Measure-Object).Count

if ($RemainingCount -eq 0) {
    Write-Host "No plans remaining in '$PlansDir'."
} else {
    Write-Host "$RemainingCount plan(s) remaining in '$PlansDir'."
}

exit 0
