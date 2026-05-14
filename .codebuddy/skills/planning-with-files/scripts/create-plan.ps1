# create-plan.ps1
# PowerShell equivalent of create-plan.sh
# Creates a new plan file with the specified name and optional description

param(
    [Parameter(Mandatory=$false)]
    [string]$PlanName,

    [Parameter(Mandatory=$false)]
    [string]$Description = "",

    [Parameter(Mandatory=$false)]
    [string]$PlansDir = "plans"
)

# ── helpers ──────────────────────────────────────────────────────────────────

function Write-Info  { param([string]$msg) Write-Host "[INFO]  $msg" -ForegroundColor Cyan }
function Write-Ok    { param([string]$msg) Write-Host "[OK]    $msg" -ForegroundColor Green }
function Write-Warn  { param([string]$msg) Write-Host "[WARN]  $msg" -ForegroundColor Yellow }
function Write-Err   { param([string]$msg) Write-Host "[ERROR] $msg" -ForegroundColor Red }

function Show-Usage {
    Write-Host ""
    Write-Host "Usage: create-plan.ps1 -PlanName <name> [-Description <text>] [-PlansDir <dir>]"
    Write-Host ""
    Write-Host "  -PlanName     Name of the plan (used as filename, spaces become hyphens)"
    Write-Host "  -Description  Optional short description written into the plan header"
    Write-Host "  -PlansDir     Directory where plan files are stored (default: plans)"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\create-plan.ps1 -PlanName 'Add login page'"
    Write-Host "  .\create-plan.ps1 -PlanName 'Refactor auth' -Description 'Clean up JWT logic'"
    Write-Host ""
}

# ── validate input ────────────────────────────────────────────────────────────

if (-not $PlanName) {
    Write-Err "Plan name is required."
    Show-Usage
    exit 1
}

# Sanitise: lowercase, replace spaces/special chars with hyphens
$SafeName = $PlanName.ToLower() -replace '[^a-z0-9]+', '-' -replace '^-+|-+$', ''

if (-not $SafeName) {
    Write-Err "Plan name '$PlanName' produced an empty slug after sanitisation."
    exit 1
}

# ── ensure plans directory exists ─────────────────────────────────────────────

if (-not (Test-Path $PlansDir)) {
    Write-Info "Creating plans directory: $PlansDir"
    New-Item -ItemType Directory -Path $PlansDir | Out-Null
}

# ── determine file path ───────────────────────────────────────────────────────

$PlanFile = Join-Path $PlansDir "$SafeName.md"

if (Test-Path $PlanFile) {
    Write-Warn "Plan file already exists: $PlanFile"
    Write-Warn "Delete or rename it before creating a new plan with the same name."
    exit 1
}

# ── build plan content ────────────────────────────────────────────────────────

$Timestamp = Get-Date -Format "yyyy-MM-dd"
$DescLine  = if ($Description) { $Description } else { "<!-- Add a short description of this plan -->" }

$Content = @"
# Plan: $PlanName

> **Created:** $Timestamp
> **Status:** in-progress
> **Description:** $DescLine

---

## Steps

<!-- Add plan steps below. Use the following format for each step:

- [ ] Step description  <!-- step-id: 1 -->

Rules:
  * Each step MUST have a unique `step-id` comment.
  * Keep descriptions concise and actionable.
  * Mark a step complete by changing `[ ]` to `[x]`.
-->

- [ ] Define scope and acceptance criteria  <!-- step-id: 1 -->
- [ ] Break work into sub-tasks             <!-- step-id: 2 -->
- [ ] Implement changes                     <!-- step-id: 3 -->
- [ ] Write / update tests                  <!-- step-id: 4 -->
- [ ] Review and merge                      <!-- step-id: 5 -->

---

## Notes

<!-- Optional: background context, links, decisions, risks -->

"@

# ── write file ────────────────────────────────────────────────────────────────

try {
    Set-Content -Path $PlanFile -Value $Content -Encoding UTF8
    Write-Ok "Plan created: $PlanFile"
} catch {
    Write-Err "Failed to write plan file: $_"
    exit 1
}

# ── summary ───────────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "Next steps:" -ForegroundColor White
Write-Host "  1. Open '$PlanFile' and customise the steps."
Write-Host "  2. Run attest-plan.ps1 to validate the plan structure."
Write-Host "  3. Run check-complete.ps1 to track progress."
Write-Host ""
