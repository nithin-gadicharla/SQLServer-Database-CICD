#Requires -Version 7.2
[CmdletBinding(SupportsShouldProcess, ConfirmImpact='High')]
param(
    [Parameter(Mandatory)][ValidateSet('Plan','Publish')][string]$Action,
    [Parameter(Mandatory)][string]$PackageDirectory,
    [Parameter(Mandatory)][ValidateSet('dev','test','prod')][string]$Environment,
    [Parameter(Mandatory)][string]$ExpectedServer,
    [Parameter(Mandatory)][string]$ExpectedDatabase,
    [Parameter(Mandatory)][ValidatePattern('^[a-f0-9]{40}$')][string]$ExpectedCommit,
    [string]$OutputDirectory = './artifacts/deployment',
    [string]$ApprovedReceipt,
    [string]$SqlPackagePath
)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'DatabaseCicd.psm1') -Force
if (-not $env:DB_CONNECTION_STRING) { throw 'DB_CONNECTION_STRING is required.' }
$manifest = Assert-Package -PackageDirectory $PackageDirectory -ExpectedCommit $ExpectedCommit
$target = Get-TargetIdentity -ConnectionString $env:DB_CONNECTION_STRING -ExpectedServer $ExpectedServer -ExpectedDatabase $ExpectedDatabase
if (-not $PSCmdlet.ShouldProcess($ExpectedDatabase, "Generate $Action plan; Publish also executes schema changes")) { return }
# Open the exact user database first: a mistyped/nonexistent database must fail, not be created.
$connection = [System.Data.SqlClient.SqlConnection]::new($env:DB_CONNECTION_STRING)
try { $connection.Open() } finally { $connection.Dispose() }
$profile = Join-Path (Split-Path $PSScriptRoot -Parent) "publish/$Environment.publish.xml"
[void](New-Item -ItemType Directory -Path $OutputDirectory -Force)
$output = (Resolve-Path $OutputDirectory).Path
$common = @(
    "/SourceFile:$((Resolve-Path (Join-Path $PackageDirectory $manifest.file)).Path)",
    "/Profile:$profile", "/TargetConnectionString:$env:DB_CONNECTION_STRING",
    '/p:BlockOnPossibleDataLoss=True', '/p:DropObjectsNotInSource=False',
    '/p:DropConstraintsNotInSource=False', '/p:DropIndexesNotInSource=False',
    '/p:DropDmlTriggersNotInSource=False', '/p:DropExtendedPropertiesNotInSource=False',
    '/p:GenerateSmartDefaults=False', '/p:IgnorePermissions=True', '/p:IgnoreRoleMembership=True',
    '/p:CommandTimeout=120'
)
$report = Join-Path $output 'deploy-report.xml'
Invoke-SqlPackageCommand -SqlPackagePath $SqlPackagePath -Arguments (@('/Action:DeployReport', "/OutputPath:$report") + $common)
$fingerprint = Get-PlanFingerprint -ReportPath $report
Invoke-SqlPackageCommand -SqlPackagePath $SqlPackagePath -Arguments (@('/Action:Script', "/OutputPath:$(Join-Path $output 'deploy.sql')") + $common)
$receipt = [ordered]@{schema_version=1; commit=$manifest.commit; dacpac_sha256=$manifest.sha256; target_sha256=$target; environment=$Environment; plan_sha256=$fingerprint}
if ($Action -eq 'Publish') {
    if (-not $ApprovedReceipt) { throw 'Publish requires the receipt from a reviewed Plan execution.' }
    $approved = Get-Content $ApprovedReceipt -Raw | ConvertFrom-Json
    foreach ($key in $receipt.Keys) {
        if ($approved.$key -cne $receipt[$key]) { throw "Approved plan no longer matches: $key. Generate and review a new plan." }
    }
    Invoke-SqlPackageCommand -SqlPackagePath $SqlPackagePath -Arguments (@('/Action:Publish') + $common)
}
$receipt | ConvertTo-Json | Set-Content (Join-Path $output 'receipt.json') -Encoding utf8
[ordered]@{action=$Action; commit=$manifest.commit; dacpac_sha256=$manifest.sha256; environment=$Environment; finished_utc=[datetime]::UtcNow.ToString('o'); status='succeeded'} |
    ConvertTo-Json | Set-Content (Join-Path $output 'deployment-evidence.json') -Encoding utf8
Write-Output "$Action succeeded. Review report and script in the protected output directory."
