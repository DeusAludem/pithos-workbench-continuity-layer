[CmdletBinding()]
param(
    [string]$Prompt = 'Prepare the Northstar release review using the current decision, the latest test result, and only records approved for this task.'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
& (Join-Path $root 'pithos_router.ps1') -Prompt $Prompt -Repeat 2
