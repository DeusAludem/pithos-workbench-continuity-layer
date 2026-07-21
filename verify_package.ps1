[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$failures = [System.Collections.Generic.List[string]]::new()

function Add-Failure {
    param([string]$Message)
    $script:failures.Add($Message)
}

$required = @(
    'index.html',
    'styles.css',
    'app.js',
    'pithos_router.ps1',
    'run_demo.ps1',
    'verify_demo.ps1',
    'verify_package.ps1',
    'README.md',
    'LICENSE',
    'HOST_PORTABILITY.md',
    'MANIFEST.sha256',
    'data\routes.json',
    'data\records.json',
    'output\receipt_latest.json',
    'output\answer_latest.md',
    'output\verification_latest.json'
)

$missing = @($required | Where-Object { -not (Test-Path -LiteralPath (Join-Path $root $_)) })
foreach ($path in $missing) {
    Add-Failure -Message "Missing required artifact: $path"
}

$recordsDocument = Get-Content -LiteralPath (Join-Path $root 'data\records.json') -Raw | ConvertFrom-Json
$routesDocument = Get-Content -LiteralPath (Join-Path $root 'data\routes.json') -Raw | ConvertFrom-Json

if (@($recordsDocument.records).Count -ne 5) {
    Add-Failure -Message 'Expected five synthetic records.'
}
if (@($routesDocument.routes).Count -ne 1) {
    Add-Failure -Message 'Expected one synthetic route.'
}

$html = Get-Content -LiteralPath (Join-Path $root 'index.html') -Raw
$javascript = Get-Content -LiteralPath (Join-Path $root 'app.js') -Raw
$css = Get-Content -LiteralPath (Join-Path $root 'styles.css') -Raw

$htmlIds = @([regex]::Matches($html, 'id="([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
$javascriptIdReferences = @([regex]::Matches($javascript, 'getElementById\("([^"]+)"\)') | ForEach-Object { $_.Groups[1].Value })
$missingDomIds = @($javascriptIdReferences | Where-Object { $htmlIds -notcontains $_ })
foreach ($id in $missingDomIds) {
    Add-Failure -Message "JavaScript references missing HTML id: $id"
}

$sourceRecordIds = @($recordsDocument.records.record_id | Sort-Object)
$browserRecordIds = @([regex]::Matches($javascript, 'id: "(NORTHSTAR-[^"]+|ORBIT-[^"]+)"') | ForEach-Object { $_.Groups[1].Value } | Sort-Object)
if (($sourceRecordIds -join ',') -ne ($browserRecordIds -join ',')) {
    Add-Failure -Message 'Browser record IDs do not match data\records.json.'
}

$staticText = $html + [Environment]::NewLine + $javascript + [Environment]::NewLine + $css
$networkPattern = '(?i)https?://|fetch\s*\(|XMLHttpRequest|WebSocket|sendBeacon'
if ([regex]::IsMatch($staticText, $networkPattern)) {
    Add-Failure -Message 'Static browser surface contains a network-capable reference.'
}

$scriptText = @(
    Get-Content -LiteralPath (Join-Path $root 'pithos_router.ps1') -Raw
    Get-Content -LiteralPath (Join-Path $root 'run_demo.ps1') -Raw
    Get-Content -LiteralPath (Join-Path $root 'verify_demo.ps1') -Raw
) -join [Environment]::NewLine
$riskPattern = '(?i)\b(Start-Process|Register-ScheduledTask|New-Service|Set-Service|Invoke-WebRequest|Invoke-RestMethod|Install-Module|Install-Package|winget|choco|npm|pip)\b'
if ([regex]::IsMatch($scriptText, $riskPattern)) {
    Add-Failure -Message 'PowerShell surface contains a forbidden install, startup, service, or network command.'
}

$manifestPath = Join-Path $root 'MANIFEST.sha256'
$manifestLines = @(Get-Content -LiteralPath $manifestPath | Where-Object { $_.Trim().Length -gt 0 })
$manifestMismatches = @()
foreach ($line in $manifestLines) {
    if ($line -notmatch '^([0-9a-f]{64})  (.+)$') {
        $manifestMismatches += "Malformed manifest line: $line"
        continue
    }

    $expectedHash = $Matches[1]
    $relativePath = $Matches[2]
    $fullPath = Join-Path $root $relativePath
    if (-not (Test-Path -LiteralPath $fullPath)) {
        $manifestMismatches += "Manifest path missing: $relativePath"
        continue
    }

    $actualHash = (Get-FileHash -LiteralPath $fullPath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualHash -ne $expectedHash) {
        $manifestMismatches += "Hash mismatch: $relativePath"
    }
}
foreach ($mismatch in $manifestMismatches) {
    Add-Failure -Message $mismatch
}

$coreRaw = & (Join-Path $root 'verify_demo.ps1')
$core = $coreRaw | ConvertFrom-Json
if ($core.status -ne 'PASS' -or $core.assertions -ne 11) {
    Add-Failure -Message 'Core router verification did not pass all eleven assertions.'
}

if ($failures.Count -gt 0) {
    throw ('Package verification failed: ' + ($failures -join '; '))
}

[pscustomobject]@{
    status = 'PASS'
    core_assertions = $core.assertions
    required_artifacts = $required.Count
    manifest_entries = $manifestLines.Count
    json_documents = 2
    html_ids = $htmlIds.Count
    javascript_id_references = $javascriptIdReferences.Count
    browser_record_alignment = 'PASS'
    static_network_references = 0
    install_startup_service_network_commands = 0
    visual_render_review = 'PENDING_MANUAL'
} | ConvertTo-Json -Depth 5

