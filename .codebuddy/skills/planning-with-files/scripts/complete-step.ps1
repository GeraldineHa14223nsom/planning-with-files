# complete-step.ps1
# Marks a specific step in a plan as complete
# Usage: .\complete-step.ps1 -PlanName <name> -StepNumber <number> [[-PlansDir] <path>]

param(
    [Parameter(Mandatory=$true)]
    [string]$PlanName,

    [Parameter(Mandatory=$true)]
    [int]$StepNumber,

    [Parameter(Mandatory=$false)]
    [string]$PlansDir = ".plans"
)

# Resolve the plans directory
$PlansDir = $PlansDir.TrimEnd('\\')
if (-not (Test-Path $PlansDir)) {
    Write-Error "Plans directory '$PlansDir' does not exist."
    exit 1
}

# Build the plan file path
$PlanFile = Join-Path $PlansDir "$PlanName.md"
if (-not (Test-Path $PlanFile)) {
    Write-Error "Plan '$PlanName' not found at '$PlanFile'."
    exit 1
}

# Read the plan content
$lines = Get-Content $PlanFile -Encoding UTF8

# Track state
$stepFound = $false
$stepCompleted = $false
$currentStep = 0
$updatedLines = @()

foreach ($line in $lines) {
    # Match unchecked step: '- [ ] Step N:' or '- [ ] N.' patterns
    if ($line -match '^(\s*- \[) \] (.*)$') {
        $currentStep++
        if ($currentStep -eq $StepNumber) {
            $stepFound = $true
            # Replace '- [ ]' with '- [x]'
            $updatedLine = $line -replace '^(\s*- \[) \]', '$1x]'
            $updatedLines += $updatedLine
            $stepCompleted = $true
            continue
        }
    }
    # Match already-checked step: '- [x] ...' — still count it
    elseif ($line -match '^(\s*- \[x\]) (.*)$') {
        $currentStep++
        if ($currentStep -eq $StepNumber) {
            $stepFound = $true
            Write-Warning "Step $StepNumber in plan '$PlanName' is already marked complete."
            $updatedLines += $line
            $stepCompleted = $false
            continue
        }
    }
    $updatedLines += $line
}

if (-not $stepFound) {
    Write-Error "Step $StepNumber not found in plan '$PlanName'. The plan has $currentStep step(s)."
    exit 1
}

if ($stepCompleted) {
    # Write updated content back to file
    $updatedLines | Set-Content $PlanFile -Encoding UTF8
    Write-Host "Step $StepNumber in plan '$PlanName' marked as complete." -ForegroundColor Green

    # Check if all steps are now complete
    $remainingUnchecked = $updatedLines | Where-Object { $_ -match '^\s*- \[ \]' }
    if ($remainingUnchecked.Count -eq 0) {
        Write-Host "All steps in plan '$PlanName' are now complete!" -ForegroundColor Cyan

        # Update the status header if present
        $finalLines = @()
        foreach ($line in $updatedLines) {
            if ($line -match '^\*\*Status:\*\*') {
                $finalLines += '**Status:** Complete'
            } else {
                $finalLines += $line
            }
        }
        $finalLines | Set-Content $PlanFile -Encoding UTF8
        Write-Host "Plan status updated to 'Complete'." -ForegroundColor Cyan
    } else {
        $remaining = $remainingUnchecked.Count
        Write-Host "$remaining step(s) remaining in plan '$PlanName'." -ForegroundColor Yellow
    }
} else {
    exit 0
}
