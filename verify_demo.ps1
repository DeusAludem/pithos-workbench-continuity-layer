[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$router = Join-Path $root 'pithos_router.ps1'
$raw = & $router -NoWrite -Repeat 2 -Compact
$result = $raw | ConvertFrom-Json
$failures = [System.Collections.Generic.List[string]]::new()

function Assert-Demo {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) {
        $script:failures.Add($Message)
    }
}

Assert-Demo -Condition ($result.runs.Count -eq 2) -Message 'Expected exactly two runs.'
$first = $result.runs[0]
$second = $result.runs[1]

Assert-Demo -Condition ($first.cache_status -eq 'fresh_mount') -Message 'First run must create a fresh mount.'
Assert-Demo -Condition ($second.cache_status -eq 'reused_existing_mount') -Message 'Second run must reuse the existing mount.'
Assert-Demo -Condition (($first.selected_records -join ',') -eq 'NORTHSTAR-DECISION-004,NORTHSTAR-TEST-018') -Message 'Smallest-sufficient selection is incorrect.'
Assert-Demo -Condition (($first.states -join ',') -eq 'received,dedupe_checked,route_selected,retrieval_completed,bound,reflected,answered') -Message 'Fresh state sequence is incorrect.'
Assert-Demo -Condition (($second.states -join ',') -eq 'received,dedupe_checked,reused_existing_mount,bound,reflected,answered') -Message 'Reuse state sequence is incorrect.'
Assert-Demo -Condition (@($first.provenance).Count -eq 2) -Message 'Expected provenance for exactly two selected records.'
Assert-Demo -Condition ($first.answer -match 'GO') -Message 'Answer is missing the current GO decision.'
Assert-Demo -Condition ($first.answer -match '18 of 18') -Message 'Answer is missing the latest test result.'

$excluded = @{}
foreach ($item in @($first.excluded_records)) {
    $excluded[$item.record_id] = $item.reason
}
Assert-Demo -Condition ($excluded['NORTHSTAR-DECISION-003'] -eq 'status_stale') -Message 'Stale record was not excluded correctly.'
Assert-Demo -Condition ($excluded['NORTHSTAR-INCIDENT-PRIVATE'] -eq 'scope_denied') -Message 'Restricted record was not excluded correctly.'
Assert-Demo -Condition ($excluded['ORBIT-BUDGET-009'] -eq 'route_mismatch') -Message 'Unrelated record was not excluded correctly.'

if ($failures.Count -gt 0) {
    throw ('Demo verification failed: ' + ($failures -join '; '))
}

[pscustomobject]@{
    status = 'PASS'
    assertions = 11
    selected_records = @($first.selected_records)
    excluded_records = @($first.excluded_records)
    fresh_states = @($first.states)
    reuse_states = @($second.states)
    provenance_count = @($first.provenance).Count
} | ConvertTo-Json -Depth 8
