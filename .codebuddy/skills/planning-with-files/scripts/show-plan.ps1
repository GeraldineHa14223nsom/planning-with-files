# show-plan.ps1
# Displays the full contents of a specific plan file
# Usage: .\show-plan.ps1 -PlanName <name> [-PlansDir <directory>]

param(
    [Parameter(Mandatory = $true)]
    [string]$PlanName,

    [Parameter(Mandatory = $false)]
    [string]$PlansDir = ".plans"
)

# Normalize plan name - strip .md extension if provided
$PlanName = $PlanName -replace '\.md$', ''

# Resolve plans directory
$PlansPath = Join-Path (Get-Location) $PlansDir

if (-not (Test-Path $PlansPath)) {
    Write-Error "Plans directory '$PlansDir' does not exist."
    exit 1
}

# Build plan file path
$PlanFile = Join-Path $PlansPath "$PlanName.md"

if (-not (Test-Path $PlanFile)) {
    Write-Error "Plan '$PlanName' not found in '$PlansDir'."
    exit 1
}

# Read and display the plan
$Content = Get-Content -Path $PlanFile -Raw

if ([string]::IsNullOrWhiteSpace($Content)) {
    Write-Warning "Plan '$PlanName' exists but is empty."
    exit 0
}

# Parse and display header info
$Lines = $Content -split "`n"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Plan: $PlanName" -ForegroundColor Cyan
Write-Host " File: $PlanFile" -ForegroundColor DarkGray
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Count tasks by status
$TotalTasks = 0
$CompletedTasks = 0
$PendingTasks = 0
$InProgressTasks = 0

foreach ($Line in $Lines) {
    if ($Line -match '^\s*-\s*\[x\]' ) {
        $CompletedTasks++
        $TotalTasks++
    } elseif ($Line -match '^\s*-\s*\[~\]') {
        $InProgressTasks++
        $TotalTasks++
    } elseif ($Line -match '^\s*-\s*\[ \]') {
        $PendingTasks++
        $TotalTasks++
    }
}

# Display content with syntax highlighting
foreach ($Line in $Lines) {
    if ($Line -match '^#') {
        Write-Host $Line -ForegroundColor Yellow
    } elseif ($Line -match '^\s*-\s*\[x\]') {
        Write-Host $Line -ForegroundColor Green
    } elseif ($Line -match '^\s*-\s*\[~\]') {
        Write-Host $Line -ForegroundColor Blue
    } elseif ($Line -match '^\s*-\s*\[ \]') {
        Write-Host $Line -ForegroundColor White
    } elseif ($Line -match '^>') {
        Write-Host $Line -ForegroundColor DarkGray
    } else {
        Write-Host $Line
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan

# Display task summary if tasks were found
if ($TotalTasks -gt 0) {
    $PercentComplete = [math]::Round(($CompletedTasks / $TotalTasks) * 100)
    Write-Host " Summary: $CompletedTasks/$TotalTasks tasks complete ($PercentComplete%)" -ForegroundColor Cyan
    if ($InProgressTasks -gt 0) {
        Write-Host " In Progress: $InProgressTasks" -ForegroundColor Blue
    }
    if ($PendingTasks -gt 0) {
        Write-Host " Pending: $PendingTasks" -ForegroundColor DarkYellow
    }
} else {
    Write-Host " No tasks found in this plan." -ForegroundColor DarkGray
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

exit 0
