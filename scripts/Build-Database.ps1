#Requires -Version 7.2
[CmdletBinding()]
param(
    [string]$Project = (Join-Path $PSScriptRoot '../src/ApplicationDb/ApplicationDb.sqlproj'),
    [string]$OutputDirectory = (Join-Path $PSScriptRoot '../artifacts/package'),
    [string]$MSBuildPath,
    [Parameter(Mandatory)][ValidatePattern('^[a-f0-9]{40}$')][string]$Commit
)
$ErrorActionPreference = 'Stop'
[void](New-Item -ItemType Directory -Path $OutputDirectory -Force)
$output = (Resolve-Path $OutputDirectory).Path + [IO.Path]::DirectorySeparatorChar
$arguments = @($Project, '/restore', '/t:Rebuild', '/p:Configuration=Release', "/p:OutputPath=$output", '/verbosity:minimal', '/nologo')
if ($MSBuildPath) { & $MSBuildPath @arguments }
else { & dotnet msbuild @arguments }
if ($LASTEXITCODE -ne 0) { throw "MSBuild failed (exit $LASTEXITCODE)." }
$file = Join-Path $output 'ApplicationDb.dacpac'
if (-not (Test-Path $file)) { throw 'MSBuild did not produce ApplicationDb.dacpac.' }
[ordered]@{schema_version=1; file='ApplicationDb.dacpac'; commit=$Commit
    sha256=(Get-FileHash $file -Algorithm SHA256).Hash.ToLowerInvariant()
    build_run_id=$env:GITHUB_RUN_ID; created_utc=[datetime]::UtcNow.ToString('o')
    target='SQL Server 2022'; project_sdk='Microsoft.Build.Sql/2.3.0'
} | ConvertTo-Json | Set-Content (Join-Path $output 'manifest.json') -Encoding utf8
Write-Output "DACPAC and provenance manifest written to $output"
