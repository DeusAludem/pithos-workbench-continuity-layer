[CmdletBinding()]
param(
    [string]$Prompt = 'Prepare the Northstar release review using the current decision, the latest test result, and only records approved for this task.',
    [string]$RouteId = 'northstar-release-review',
    [string]$Scope = 'demo_public',
    [ValidateRange(1, 2)]
    [int]$Repeat = 2,
    [switch]$NoWrite,
    [switch]$Compact
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$routesPath = Join-Path $root 'data\routes.json'
$recordsPath = Join-Path $root 'data\records.json'

$routes = @((Get-Content -LiteralPath $routesPath -Raw | ConvertFrom-Json).routes)
$records = @((Get-Content -LiteralPath $recordsPath -Raw | ConvertFrom-Json).records)
$route = $routes | Where-Object { $_.route_id -eq $RouteId } | Select-Object -First 1

if ($null -eq $route) {
    throw "Unknown route: $RouteId"
}

function Get-DedupeKey {
    param([string]$Value)

    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Value)
        return ([System.BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant()
    }
    finally {
        $sha.Dispose()
    }
}

function Test-ContainsEveryTag {
    param($Record, [string[]]$RequiredTags)

    $recordTags = @($Record.tags)
    foreach ($tag in $RequiredTags) {
        if ($recordTags -notcontains $tag) {
            return $false
        }
    }
    return $true
}

function New-Answer {
    param([array]$Selected)

    $decision = $Selected | Where-Object { $_.record_type -eq 'decision' } | Select-Object -First 1
    $test = $Selected | Where-Object { $_.record_type -eq 'test' } | Select-Object -First 1

    return "Northstar release review: $($decision.content.decision). $($decision.content.condition) Latest verification: $($test.content.summary) Environment: $($test.content.environment)."
}

function Invoke-ContinuityRequest {
    param(
        [string]$RequestPrompt,
        [string]$RequestScope,
        $SelectedRoute,
        [array]$AllRecords,
        [hashtable]$MountCache,
        [int]$RunNumber
    )

    $dedupeKey = Get-DedupeKey -Value "$($SelectedRoute.route_id)|$RequestScope|$RequestPrompt"
    $requestId = 'DEMO-{0:D3}' -f $RunNumber
    $states = [System.Collections.Generic.List[string]]::new()
    $states.Add('received')
    $states.Add('dedupe_checked')

    if ($MountCache.ContainsKey($dedupeKey)) {
        $cached = $MountCache[$dedupeKey]
        $states.Add('reused_existing_mount')
        $states.Add('bound')
        $states.Add('reflected')
        $states.Add('answered')

        return [pscustomobject]@{
            request_id = $requestId
            dedupe_key = $dedupeKey
            route_id = $SelectedRoute.route_id
            cache_status = 'reused_existing_mount'
            states = @($states)
            selected_records = @($cached.selected_records)
            excluded_records = @($cached.excluded_records)
            answer = $cached.answer
            provenance = @($cached.provenance)
        }
    }

    $states.Add('route_selected')
    $allowedScopes = @($SelectedRoute.allowed_scopes)
    $contextTags = @($SelectedRoute.context_tags)
    $eligible = @()
    $excluded = @()

    foreach ($record in $AllRecords) {
        $reason = $null
        if ($record.status -ne 'current') {
            $reason = 'status_stale'
        }
        elseif ($allowedScopes -notcontains $record.scope -or $record.scope -ne $RequestScope) {
            $reason = 'scope_denied'
        }
        elseif (-not (Test-ContainsEveryTag -Record $record -RequiredTags $contextTags)) {
            $reason = 'route_mismatch'
        }

        if ($null -eq $reason) {
            $eligible += $record
        }
        else {
            $excluded += [pscustomobject]@{
                record_id = $record.record_id
                reason = $reason
            }
        }
    }

    $selected = @()
    foreach ($recordType in @($SelectedRoute.required_record_types)) {
        $match = $eligible |
            Where-Object { $_.record_type -eq $recordType } |
            Sort-Object { [DateTimeOffset]$_.effective_at } -Descending |
            Select-Object -First 1

        if ($null -eq $match) {
            throw "No eligible '$recordType' record is available for route '$($SelectedRoute.route_id)'."
        }
        $selected += $match
    }

    foreach ($record in $eligible) {
        if (@($selected.record_id) -notcontains $record.record_id) {
            $excluded += [pscustomobject]@{
                record_id = $record.record_id
                reason = 'superseded'
            }
        }
    }

    $states.Add('retrieval_completed')
    $states.Add('bound')
    $answer = New-Answer -Selected $selected
    $states.Add('reflected')
    $states.Add('answered')

    $provenance = @($selected | ForEach-Object {
        [pscustomobject]@{
            record_id = $_.record_id
            title = $_.title
            source_path = $_.source_path
            effective_at = $_.effective_at
        }
    })

    $receipt = [pscustomobject]@{
        request_id = $requestId
        dedupe_key = $dedupeKey
        route_id = $SelectedRoute.route_id
        cache_status = 'fresh_mount'
        states = @($states)
        selected_records = @($selected.record_id)
        excluded_records = @($excluded)
        answer = $answer
        provenance = $provenance
    }

    $MountCache[$dedupeKey] = $receipt
    return $receipt
}

$cache = @{}
$runs = @()
for ($run = 1; $run -le $Repeat; $run++) {
    $runs += Invoke-ContinuityRequest -RequestPrompt $Prompt -RequestScope $Scope -SelectedRoute $route -AllRecords $records -MountCache $cache -RunNumber $run
}

$result = [pscustomobject]@{
    schema_version = '1.0'
    project = 'PITHOS Workbench Continuity Layer - portable synthetic demo'
    generated_at = [DateTimeOffset]::Now.ToString('o')
    request = [pscustomobject]@{
        prompt = $Prompt
        route_id = $RouteId
        scope = $Scope
        repeat = $Repeat
    }
    runs = $runs
}

if (-not $NoWrite) {
    $outputDir = Join-Path $root 'output'
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    $jsonPath = Join-Path $outputDir 'receipt_latest.json'
    $answerPath = Join-Path $outputDir 'answer_latest.md'
    $result | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $jsonPath -Encoding UTF8

    $answerLines = @(
        '# Northstar Release Review',
        '',
        $runs[0].answer,
        '',
        '## Provenance',
        ''
    )
    foreach ($item in @($runs[0].provenance)) {
        $answerLines += "- $($item.record_id): $($item.title) ($($item.source_path))"
    }
    $answerLines | Set-Content -LiteralPath $answerPath -Encoding UTF8
}

if ($Compact) {
    $result | ConvertTo-Json -Depth 10 -Compress
}
else {
    $result | ConvertTo-Json -Depth 10
}
