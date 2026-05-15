# reorder-steps.ps1
# Reorders steps within a plan file by reassigning step numbers
# Usage: .\reorder-steps.ps1 -PlanName <name> -StepOrder <comma-separated step numbers>

param(
    [Parameter(Mandatory=$true)]
    [string]$PlanName,

    [Parameter(Mandatory=$true)]
    [string]$StepOrder,

    [Parameter(Mandatory=$false)]
    [string]$PlansDir = ".plans"
)

$ErrorActionPreference = "Stop"

# Resolve plan file path
$planFile = Join-Path $PlansDir "$PlanName.md"

if (-not (Test-Path $planFile)) {
    Write-Error "Plan '$PlanName' not found at '$planFile'."
    exit 1
}

# Parse the desired order from comma-separated input
$desiredOrder = $StepOrder -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }

if ($desiredOrder.Count -eq 0) {
    Write-Error "StepOrder must contain at least one step number."
    exit 1
}

# Read the plan file content
$lines = Get-Content $planFile

# Extract step blocks from the plan
# Steps are expected to be formatted as: ## Step N: <title>
$stepPattern = '^## Step (\d+):(.*)$'
$steps = @{}
$stepOrder = @()
$currentStep = $null
$currentLines = @()
$headerLines = @()
$inHeader = $true

foreach ($line in $lines) {
    if ($line -match $stepPattern) {
        if ($inHeader) {
            $inHeader = $false
        } elseif ($null -ne $currentStep) {
            $steps[$currentStep] = $currentLines
        }
        $currentStep = $Matches[1]
        $stepTitle = $Matches[2].Trim()
        $stepOrder += $currentStep
        $currentLines = @("## Step $currentStep: $stepTitle")
    } elseif ($inHeader) {
        $headerLines += $line
    } else {
        $currentLines += $line
    }
}

# Save the last step
if ($null -ne $currentStep) {
    $steps[$currentStep] = $currentLines
}

# Validate that all requested step numbers exist
foreach ($stepNum in $desiredOrder) {
    if (-not $steps.ContainsKey($stepNum)) {
        Write-Error "Step '$stepNum' does not exist in plan '$PlanName'. Available steps: $($stepOrder -join ', ')"
        exit 1
    }
}

# Warn if not all steps are included
$missingSteps = $stepOrder | Where-Object { $desiredOrder -notcontains $_ }
if ($missingSteps.Count -gt 0) {
    Write-Warning "The following steps are not included in the new order and will be appended at the end: $($missingSteps -join ', ')"
    $desiredOrder = @($desiredOrder) + @($missingSteps)
}

# Rebuild the plan with reordered steps, renumbering sequentially
$newContent = @()
$newContent += $headerLines

$newStepNumber = 1
foreach ($oldStepNum in $desiredOrder) {
    $stepLines = $steps[$oldStepNum]
    # Update the step header with the new sequential number
    $firstLine = $stepLines[0]
    $firstLine = $firstLine -replace "^## Step $oldStepNum:", "## Step $newStepNumber:"
    $newContent += $firstLine
    if ($stepLines.Count -gt 1) {
        $newContent += $stepLines[1..($stepLines.Count - 1)]
    }
    $newStepNumber++
}

# Write updated content back to file
$newContent | Set-Content $planFile -Encoding UTF8

Write-Host "Steps in plan '$PlanName' have been reordered successfully."
Write-Host "New step order: $($desiredOrder -join ' -> ')"
