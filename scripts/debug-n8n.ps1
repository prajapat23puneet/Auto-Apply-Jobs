param(
    [Parameter(Mandatory = $true)][string]$ExecutionId,
    [string]$N8nUrl = "http://localhost:5678"
)

# ── Read API key from .env ────────────────────────────────────────────────────
$rootPath = Split-Path -Parent $PSScriptRoot
$envPath = Join-Path $rootPath ".env"
if (-not (Test-Path $envPath)) { Write-Error ".env not found at $envPath"; exit 1 }

$ApiKey = ""
foreach ($line in Get-Content $envPath) {
    if ($line -match '^\s*N8N_API_KEY\s*=\s*(.+)$') { $ApiKey = $Matches[1].Trim(); break }
}
if (-not $ApiKey) { Write-Error "N8N_API_KEY not found in .env"; exit 1 }

# ── Call n8n API ──────────────────────────────────────────────────────────────
$headers = @{ "X-N8N-API-KEY" = $ApiKey }
try {
    # FIX 1: removed stray backtick before ?, used ${} to safely delimit variable
    $exec = Invoke-RestMethod `
        -Uri "$N8nUrl/api/v1/executions/${ExecutionId}?includeData=true" `
        -Headers $headers -Method GET
}
catch {
    Write-Error "API error: $($_.Exception.Message)"; exit 1
}

# ── Helpers ───────────────────────────────────────────────────────────────────
function ToJson($obj) { $obj | ConvertTo-Json -Depth 20 -Compress }

# FIX 4: reference $script:sb so the function always hits the right scope
$script:sb = [System.Text.StringBuilder]::new()
function L([string]$s) { $null = $script:sb.AppendLine($s) }

# ── Build MD ──────────────────────────────────────────────────────────────────
L "# n8n Execution Report"
L ""
L "| | |"
L "|---|---|"
L "| **ID** | $ExecutionId |"
L "| **Workflow** | $($exec.workflowData.name) |"
L "| **Status** | $($exec.status) |"
L "| **Started** | $($exec.startedAt) |"
L "| **Finished** | $($exec.stoppedAt) |"
L ""

# FIX 3: null-check runData
$runData = $exec.data.resultData.runData
if ($null -eq $runData) {
    L "> No run data found for this execution."
    $script:sb.ToString() | Out-File -FilePath (Join-Path $PSScriptRoot "execution_${ExecutionId}.md") -Encoding UTF8
    Write-Host "Done. No run data."
    exit 0
}

# ── Error summary ─────────────────────────────────────────────────────────────
if ($exec.status -eq "error") {
    L "## ❌ Error Summary"
    L ""
    foreach ($nodeName in $runData.PSObject.Properties.Name) {
        foreach ($run in $runData.$nodeName) {
            if ($run.error) {
                # FIX 2: use `` (double-backtick) for literal backtick + $() for expansion
                L "**Node:** ``$($nodeName)``"
                L ""
                L '```'
                L "Message : $($run.error.message)"
                if ($run.error.description) { L "Detail  : $($run.error.description)" }
                if ($run.error.stack) { L "$($run.error.stack)" }
                L '```'
                L ""
            }
        }
    }
}

# ── Per-node IO ───────────────────────────────────────────────────────────────
L "## Node IO"
L ""

foreach ($nodeName in $runData.PSObject.Properties.Name) {
    $runs = $runData.$nodeName
    L "---"
    L ""
    # FIX 2: same backtick fix
    L "### ``$($nodeName)``"
    L ""

    $idx = 0
    foreach ($run in $runs) {
        # FIX 2: same backtick fix for inline code
        L "**Attempt $idx** — status: ``$($run.executionStatus)`` | time: $($run.executionTime)ms"
        L ""

        L "#### Input"
        L '```json'
        if ($null -ne $run.data.main) { L (ToJson $run.data.main) } else { L "null" }
        L '```'
        L ""

        if ($null -ne $run.outputData) {
            L "#### Output"
            L '```json'
            L (ToJson $run.outputData)
            L '```'
            L ""
        }

        if ($run.error) {
            L "#### ❌ Error"
            L '```'
            L "Message : $($run.error.message)"
            if ($run.error.description) { L "Detail  : $($run.error.description)" }
            if ($run.error.stack) { L "$($run.error.stack)" }
            L '```'
            L ""
        }

        $idx++
    }
}

# ── Write file ────────────────────────────────────────────────────────────────
$outFile = Join-Path $PSScriptRoot "execution_${ExecutionId}.md"
$script:sb.ToString() | Out-File -FilePath $outFile -Encoding UTF8
Write-Host "Saved: $outFile"