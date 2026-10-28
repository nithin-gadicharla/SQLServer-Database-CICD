#Requires -Version 7.2
[CmdletBinding()]
param([Parameter(Mandatory)][ValidatePattern('^[0-9]+$')][string]$RunId,[Parameter(Mandatory)][ValidatePattern('^[a-f0-9]{40}$')][string]$Commit)
$ErrorActionPreference='Stop'
if (-not $env:GH_REPO) { throw 'GH_REPO must be the current repository.' }
$result=& gh api "repos/$env:GH_REPO/actions/runs/$RunId"
if ($LASTEXITCODE -ne 0) { throw 'Unable to verify CI run.' }
$run=$result | ConvertFrom-Json
if ($run.repository.full_name -cne $env:GH_REPO -or $run.path -ne '.github/workflows/ci.yml' -or $run.event -ne 'push' -or $run.head_branch -ne 'main' -or $run.status -ne 'completed' -or $run.conclusion -ne 'success' -or $run.head_sha -cne $Commit) { throw 'Promotion requires a successful main-branch push CI run for the exact source commit.' }
Write-Output 'CI run provenance verified.'
