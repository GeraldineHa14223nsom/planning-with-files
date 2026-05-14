# update-plan.ps1
# Updates an existing plan file with new step statuses, notes, or additional steps.
# Usage: .\update-plan.ps1 -PlanFile <path> [-StepNumber <n>] [-Status <status>] [-Note <text>] [-AddStep <description>]

param(
    [Parameter(Mandatory = $true)]
    [string]$PlanFile,

    [Parameter(Mandatory = $false)]
    [int]$StepNumber = 0,

    [Parameter(Mandatory = $false)]
    [ValidateSet("pending", "in-progress", "complete", "blocked", "skipped")]
    [string]$Status = "",

    [Parameter(Mandatory = $false)]
    [string]$Note = "",

    [Parameter(Mandatory = $false)]
    [string]$AddStep = "",

    [Parameter(Mandatory = $false)]
    [switch]$ListSteps
)

# Verify the plan file exists
if (-not (Test-Path $PlanFile)) {
    Write-Error "Plan file not found: $PlanFile"
    exit 1
}

$content = Get-Content $PlanFile -Raw
$lines = Get-Content $PlanFile

# List steps mode
if ($ListSteps) {
    Write-Host "Steps in plan: $PlanFile" -ForegroundColor Cyan
    Write-Host ("─" * 50)
    $stepIndex = 0
    foreach ($line in $lines) {
        if ($line -match '^\s*-\s*\[( |x|X|~|!)\]\s*(.+)$') {
            $stepIndex++
            $statusChar = $Matches[1]
            $description = $Matches[2]
            $statusLabel = switch ($statusChar) {
                ' '  { "pending" }
                'x'  { "complete" }
                'X'  { "complete" }
                '~'  { "in-progress" }
                '!'  { "blocked" }
                default { "unknown" }
            }
            $color = switch ($statusLabel) {
                "complete"    { "Green" }
                "in-progress" { "Yellow" }
                "blocked"     { "Red" }
                default       { "White" }
            }
            Write-Host ("  [{0,2}] [{1}] {2}" -f $stepIndex, $statusLabel.PadRight(11), $description) -ForegroundColor $color
        }
    }
    exit 0
}

# Add a new step to the plan
if ($AddStep -ne "") {
    # Find the last checklist item and append after it
    $lastStepLine = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^\s*-\s*\[[ xX~!]\]') {
            $lastStepLine = $i
        }
    }

    $newStep = "- [ ] $AddStep"
    if ($lastStepLine -ge 0) {
        $updatedLines = @()
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $updatedLines += $lines[$i]
            if ($i -eq $lastStepLine) {
                $updatedLines += $newStep
            }
        }
    } else {
        # No existing steps found, append to end
        $updatedLines = $lines + $newStep
    }

    $updatedLines | Set-Content $PlanFile -Encoding UTF8
    Write-Host "Added new step: $AddStep" -ForegroundColor Green
    exit 0
}

# Update a specific step's status
if ($StepNumber -gt 0 -and $Status -ne "") {
    $statusChar = switch ($Status) {
        "pending"     { " " }
        "in-progress" { "~" }
        "complete"    { "x" }
        "blocked"     { "!" }
        "skipped"     { "x" }
        default       { " " }
    }

    $stepIndex = 0
    $updatedLines = @()
    $updated = $false

    foreach ($line in $lines) {
        if ($line -match '^(\s*-\s*\[)[ xX~!](\]\s*.+)$') {
            $stepIndex++
            if ($stepIndex -eq $StepNumber) {
                $updatedLine = $Matches[1] + $statusChar + $Matches[2]
                # Append note inline if provided
                if ($Note -ne "") {
                    $updatedLine = $updatedLine.TrimEnd() + " <!-- $Note -->"
                }
                $updatedLines += $updatedLine
                $updated = $true
                continue
            }
        }
        $updatedLines += $line
    }

    if (-not $updated) {
        Write-Error "Step number $StepNumber not found in plan."
        exit 1
    }

    $updatedLines | Set-Content $PlanFile -Encoding UTF8
    Write-Host "Updated step $StepNumber to '$Status'" -ForegroundColor Green
    if ($Note -ne "") {
        Write-Host "Note added: $Note" -ForegroundColor Cyan
    }
    exit 0
}

# If only a note is provided without a step number, append it to the plan footer
if ($Note -ne "" -and $StepNumber -eq 0) {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm"
    $noteEntry = "`n<!-- Note ($timestamp): $Note -->"
    Add-Content -Path $PlanFile -Value $noteEntry -Encoding UTF8
    Write-Host "Note appended to plan: $Note" -ForegroundColor Cyan
    exit 0
}

Write-Host "No action taken. Use -ListSteps, -AddStep, or provide -StepNumber with -Status." -ForegroundColor Yellow
exit 0
