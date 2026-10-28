#Requires -Version 7.2
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
if ($env:DISPOSABLE_DATABASE_LAB -ne 'true') { throw 'This test requires a disposable SQL Server container.' }
$commit=$env:GITHUB_SHA
$package=Join-Path $root 'artifacts/package'
function Deploy-Lab([string]$Package,[string]$Name) {
    $plan=Join-Path $root "artifacts/lab/$Name-plan"
    & (Join-Path $root 'scripts/Deploy-Database.ps1') -Action Plan -PackageDirectory $Package -Environment dev -ExpectedServer 'localhost,1433' -ExpectedDatabase DatabaseCiLab -ExpectedCommit $commit -OutputDirectory $plan -Confirm:$false
    & (Join-Path $root 'scripts/Deploy-Database.ps1') -Action Publish -PackageDirectory $Package -Environment dev -ExpectedServer 'localhost,1433' -ExpectedDatabase DatabaseCiLab -ExpectedCommit $commit -OutputDirectory (Join-Path $root "artifacts/lab/$Name-publish") -ApprovedReceipt (Join-Path $plan 'receipt.json') -Confirm:$false
    & (Join-Path $root 'scripts/Test-Database.ps1') -SqlFile (Join-Path $root 'tests/sql/Smoke.sql')
}
# Create only an explicitly reserved database in the ephemeral localhost lab.
$master=[System.Data.SqlClient.SqlConnectionStringBuilder]::new($env:DB_CONNECTION_STRING)
$master['Initial Catalog']='master'
$connection=[System.Data.SqlClient.SqlConnection]::new($master.get_ConnectionString())
$command=$connection.CreateCommand()
$command.CommandText="IF DB_ID(N'DatabaseCiLab') IS NOT NULL THROW 51000, 'Lab database already exists.', 1; CREATE DATABASE DatabaseCiLab;"
try { $connection.Open();[void]$command.ExecuteNonQuery() } finally { $command.Dispose();$connection.Dispose() }
Deploy-Lab $package 'initial'
& (Join-Path $root 'scripts/Test-Database.ps1') -SqlFile (Join-Path $root 'tests/sql/SeedExistingData.sql')
# A receipt for a different target must not authorize publishing, even with a valid DACPAC.
$badReceipt=Join-Path $root 'artifacts/lab/wrong-target-receipt.json'
$changed=Get-Content (Join-Path $root 'artifacts/lab/initial-plan/receipt.json') -Raw | ConvertFrom-Json
$changed.target_sha256='0'*64
$changed | ConvertTo-Json | Set-Content $badReceipt
$receiptBlocked=$false
try {
    & (Join-Path $root 'scripts/Deploy-Database.ps1') -Action Publish -PackageDirectory $package -Environment dev -ExpectedServer 'localhost,1433' -ExpectedDatabase DatabaseCiLab -ExpectedCommit $commit -OutputDirectory (Join-Path $root 'artifacts/lab/wrong-receipt') -ApprovedReceipt $badReceipt -Confirm:$false
} catch {
    if ($_.Exception.Message -notlike 'Approved plan no longer matches:*') { throw }
    $receiptBlocked=$true
}
if (-not $receiptBlocked) { throw 'A changed approval receipt was accepted.' }
Deploy-Lab $package 'repeat' 
# Build an additive schema version in an isolated source copy, keeping the original CI artifact unchanged.
$fixture=Join-Path $root 'artifacts/fixture'
[void](New-Item $fixture -ItemType Directory -Force)
Copy-Item (Join-Path $root 'src/ApplicationDb') $fixture -Recurse
$table=Join-Path $fixture 'ApplicationDb/Tables/Customer.sql'
$text=Get-Content $table -Raw
$text=$text.Replace('[DisplayName] nvarchar(200) NOT NULL,',"[DisplayName] nvarchar(200) NOT NULL,`n    [Notes] nvarchar(400) NULL,")
Set-Content $table $text
$upgrade=Join-Path $root 'artifacts/upgrade'
& (Join-Path $root 'scripts/Build-Database.ps1') -Project (Join-Path $fixture 'ApplicationDb/ApplicationDb.sqlproj') -OutputDirectory $upgrade -Commit $commit
Deploy-Lab $upgrade 'upgrade'
& (Join-Path $root 'scripts/Test-Database.ps1') -SqlFile (Join-Path $root 'tests/sql/AssertUpgrade.sql')
# Existing text will not fit: Publish must fail and leave both schema and data intact.
$text=$text.Replace('[DisplayName] nvarchar(200)', '[DisplayName] nvarchar(10)')
Set-Content $table $text
$unsafe=Join-Path $root 'artifacts/unsafe'
& (Join-Path $root 'scripts/Build-Database.ps1') -Project (Join-Path $fixture 'ApplicationDb/ApplicationDb.sqlproj') -OutputDirectory $unsafe -Commit $commit
$blocked=$false
try { Deploy-Lab $unsafe 'unsafe' } catch { $blocked=$true }
if (-not $blocked) { throw 'Unsafe narrowing was not blocked.' }
& (Join-Path $root 'scripts/Test-Database.ps1') -SqlFile (Join-Path $root 'tests/sql/AssertUpgrade.sql')
[ordered]@{commit=$commit;initial_publish='passed';repeat_publish='passed';additive_upgrade='passed';data_preserved='passed';unsafe_narrowing='blocked';changed_receipt='blocked';tls='validated';finished_utc=[datetime]::UtcNow.ToString('o')} |
    ConvertTo-Json | Set-Content (Join-Path $root 'artifacts/lab/integration-evidence.json')
Write-Output 'Live database deployment integration tests passed.'
