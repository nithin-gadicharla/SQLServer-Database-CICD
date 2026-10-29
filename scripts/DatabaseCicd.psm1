#Requires -Version 7.2
Set-StrictMode -Version Latest
function Get-TextSha256 {
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Text)
    [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($Text))).ToLowerInvariant()
}
function Assert-Package {
    param([Parameter(Mandatory)][string]$PackageDirectory, [string]$ExpectedCommit)
    $manifest = Get-Content (Join-Path $PackageDirectory 'manifest.json') -Raw | ConvertFrom-Json
    if ($manifest.schema_version -ne 1) { throw 'Unsupported artifact manifest version.' }
    if ($manifest.file -ne 'ApplicationDb.dacpac') { throw 'Unexpected DACPAC filename.' }
    if ($manifest.commit -notmatch '^[a-f0-9]{40}$') { throw 'A full source commit is required.' }
    if ($ExpectedCommit -and $manifest.commit -cne $ExpectedCommit) { throw 'Artifact source commit mismatch.' }
    if ((Get-FileHash (Join-Path $PackageDirectory $manifest.file) -Algorithm SHA256).Hash.ToLowerInvariant() -cne $manifest.sha256) { throw 'DACPAC checksum mismatch.' }
    return $manifest
}
function Get-TargetIdentity {
    param([Parameter(Mandatory)][string]$ConnectionString,[Parameter(Mandatory)][string]$ExpectedServer,[Parameter(Mandatory)][string]$ExpectedDatabase)
    $builder = [System.Data.SqlClient.SqlConnectionStringBuilder]::new($ConnectionString)
    if (-not $builder.get_Encrypt() -or $builder.get_TrustServerCertificate()) { throw 'Validated encrypted TLS is required.' }
    if ($builder.get_DataSource() -ine $ExpectedServer -or $builder.get_InitialCatalog() -ine $ExpectedDatabase) { throw 'Connection target mismatch.' }
    if ($ExpectedDatabase -in @('master','model','msdb','tempdb') -or [string]::IsNullOrWhiteSpace($ExpectedDatabase)) { throw 'A user database is required.' }
    return Get-TextSha256 ($ExpectedServer.ToLowerInvariant() + "`n" + $ExpectedDatabase.ToLowerInvariant())
}
function Get-PlanFingerprint {
    param([Parameter(Mandatory)][string]$ReportPath)
    $settings = [System.Xml.XmlReaderSettings]::new()
    $settings.DtdProcessing = [System.Xml.DtdProcessing]::Prohibit; $settings.XmlResolver = $null
    $reader = [System.Xml.XmlReader]::Create((Resolve-Path $ReportPath).Path, $settings)
    $doc = [System.Xml.XmlDocument]::new(); $doc.XmlResolver = $null
    try { $doc.Load($reader) } finally { $reader.Dispose() }
    $namespace='http://schemas.microsoft.com/sqlserver/dac/DeployReport/2012/02'
    if ($doc.DocumentElement.LocalName -ne 'DeploymentReport' -or $doc.DocumentElement.NamespaceURI -ne $namespace) { throw 'Invalid SqlPackage report.' }
    $alerts=$doc.SelectNodes("/*/*[local-name()='Alerts']")
    $operations=$doc.SelectNodes("//*[local-name()='Operations']")
    if ($alerts.Count -ne 1 -or $operations.Count -gt 1) { throw 'Invalid report section count.' }
    # SqlPackage omits Operations entirely for a legitimate no-change report.
    if ($operations.Count -eq 0) { [void]$doc.DocumentElement.AppendChild($doc.CreateElement('Operations',$namespace)) }
    foreach ($operation in $doc.SelectNodes("//*[local-name()='Operation']")) {
        if ($operation.GetAttribute('Name') -match '^Drop') { throw 'Drop operations are blocked.' }
    }
    foreach ($alert in $doc.SelectNodes("//*[local-name()='Alert']")) {
        if ($alert.GetAttribute('Name') -match 'DataLoss') { throw 'Possible data loss is blocked.' }
    }
    $sections = @($doc.SelectNodes("//*[local-name()='Alerts' or local-name()='Operations']") | ForEach-Object { $_.OuterXml })
    return Get-TextSha256 ($sections -join "`n")
}
function Invoke-SqlPackageCommand {
    param([Parameter(Mandatory)][string[]]$Arguments,[string]$SqlPackagePath)
    # Never print argument arrays: they can contain a secret connection string.
    if ($SqlPackagePath) { & $SqlPackagePath @Arguments }
    else { & dotnet tool run sqlpackage -- @Arguments }
    if ($LASTEXITCODE -ne 0) { throw "SqlPackage failed (exit $LASTEXITCODE)." }
}
Export-ModuleMember -Function Get-TextSha256, Assert-Package, Get-TargetIdentity, Get-PlanFingerprint, Invoke-SqlPackageCommand
