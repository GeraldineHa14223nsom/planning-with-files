# list-plans.ps1
# Lists all planning files in the plans directory with their status and metadata
# Part of the planning-with-files skill

param(
    [string]$PlansDir = "plans",
    [switch]$ShowCompleted,
    [switch]$ShowAttested,
    [switch]$Verbose,
    [ValidateSet("table", "json", "simple")]
    [string]$Format = "table"
)

$ErrorActionPreference = "Stop"

# Resolve plans directory
$resolvedPlansDir = Join-Path (Get-Location) $PlansDir

if (-not (Test-Path $resolvedPlansDir)) {
    Write-Error "Plans directory '$resolvedPlansDir' does not exist."
    exit 1
}

# Collect plan files
$planFiles = Get-ChildItem -Path $resolvedPlansDir -Filter "*.md" -File | Sort-Object Name

if ($planFiles.Count -eq 0) {
    Write-Host "No plans found in '$PlansDir'."
    exit 0
}

# Parse plan metadata
function Get-PlanMetadata {
    param([System.IO.FileInfo]$File)

    $content = Get-Content $File.FullName -Raw
    $lines   = Get-Content $File.FullName

    $meta = [PSCustomObject]@{
        Name      = $File.BaseName
        File      = $File.Name
        Status    = "pending"
        Attested  = $false
        Steps     = 0
        Completed = 0
        Created   = $File.CreationTime.ToString("yyyy-MM-dd")
        Modified  = $File.LastWriteTime.ToString("yyyy-MM-dd")
    }

    # Detect completion marker
    if ($content -match '(?im)^#+\s*status[:\s]+complete') {
        $meta.Status = "complete"
    } elseif ($content -match '(?im)^#+\s*status[:\s]+in.?progress') {
        $meta.Status = "in-progress"
    }

    # Detect attestation block
    if ($content -match '(?im)^#+\s*attestation') {
        $meta.Attested = $true
    }

    # Count checklist items
    $totalSteps     = ($lines | Where-Object { $_ -match '^\s*-\s*\[[ x]\]' }).Count
    $completedSteps = ($lines | Where-Object { $_ -match '^\s*-\s*\[x\]' }).Count

    $meta.Steps     = $totalSteps
    $meta.Completed = $completedSteps

    if ($totalSteps -gt 0 -and $completedSteps -eq $totalSteps) {
        $meta.Status = "complete"
    } elseif ($completedSteps -gt 0) {
        $meta.Status = "in-progress"
    }

    return $meta
}

# Build plan list
$plans = foreach ($file in $planFiles) {
    Get-PlanMetadata -File $file
}

# Apply filters
if (-not $ShowCompleted) {
    $plans = $plans | Where-Object { $_.Status -ne "complete" }
}

if (-not $ShowAttested) {
    $plans = $plans | Where-Object { -not $_.Attested }
}

if ($null -eq $plans -or @($plans).Count -eq 0) {
    Write-Host "No plans match the current filters."
    Write-Host "Tip: Use -ShowCompleted and/or -ShowAttested to include filtered plans."
    exit 0
}

# Output
switch ($Format) {
    "json" {
        $plans | ConvertTo-Json -Depth 3
    }
    "simple" {
        foreach ($plan in $plans) {
            $attested = if ($plan.Attested) { " [attested]" } else { "" }
            Write-Host "[$($plan.Status.ToUpper())] $($plan.Name)$attested"
        }
    }
    default {
        # Table format
        $header = "{0,-30} {1,-12} {2,-10} {3,-10} {4,-12}" -f "Name", "Status", "Steps", "Done", "Modified"
        $divider = "-" * 78
        Write-Host $divider
        Write-Host $header
        Write-Host $divider

        foreach ($plan in $plans) {
            $attested = if ($plan.Attested) { "*" } else { " " }
            $row = "{0,-30} {1,-12} {2,-10} {3,-10} {4,-12}" -f `
                "$($plan.Name)$attested", $plan.Status, $plan.Steps, $plan.Completed, $plan.Modified
            Write-Host $row
        }

        Write-Host $divider
        Write-Host "Total: $(@($plans).Count) plan(s)  (* = attested)"

        if ($Verbose) {
            Write-Host ""
            Write-Host "Plans directory: $resolvedPlansDir"
        }
    }
}
