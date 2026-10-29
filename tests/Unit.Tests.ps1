BeforeAll {
    $root = Split-Path $PSScriptRoot -Parent
    Import-Module (Join-Path $root 'scripts/DatabaseCicd.psm1') -Force
}
Describe 'Source syntax' {
    It 'parses every PowerShell script and module' {
        foreach ($file in Get-ChildItem $root -Recurse -Include *.ps1,*.psm1) {
            $tokens=$null; $errors=$null
            [void][Management.Automation.Language.Parser]::ParseFile($file.FullName,[ref]$tokens,[ref]$errors)
            $errors.Count | Should -Be 0 -Because $file.FullName
        }
    }
}
Describe 'Target guard' {
    It 'accepts only the expected user database with validated TLS' {
        $hash=Get-TargetIdentity -ConnectionString 'Server=sql01;Database=AppDev;Integrated Security=true;Encrypt=true;TrustServerCertificate=false' -ExpectedServer sql01 -ExpectedDatabase AppDev
        $hash | Should -Match '^[0-9a-f]{64}$'
    }
    It 'rejects wrong targets, system databases and certificate bypass' {
        { Get-TargetIdentity -ConnectionString 'Server=prod;Database=AppDev;Encrypt=true' -ExpectedServer sql01 -ExpectedDatabase AppDev } | Should -Throw
        { Get-TargetIdentity -ConnectionString 'Server=sql01;Database=master;Encrypt=true' -ExpectedServer sql01 -ExpectedDatabase master } | Should -Throw
        { Get-TargetIdentity -ConnectionString 'Server=sql01;Database=AppDev;Encrypt=true;TrustServerCertificate=true' -ExpectedServer sql01 -ExpectedDatabase AppDev } | Should -Throw
        { Get-TargetIdentity -ConnectionString 'Server=sql01;Database=AppDev;Encrypt=false' -ExpectedServer sql01 -ExpectedDatabase AppDev } | Should -Throw
    }
}
Describe 'Artifact verification' {
    BeforeEach {
        $package=Join-Path $TestDrive 'package'; [void](New-Item $package -ItemType Directory -Force)
        Set-Content (Join-Path $package 'ApplicationDb.dacpac') 'fixture'
        $commit='a'*40
        @{schema_version=1;file='ApplicationDb.dacpac';commit=$commit;sha256=(Get-FileHash (Join-Path $package 'ApplicationDb.dacpac')).Hash.ToLowerInvariant()} | ConvertTo-Json | Set-Content (Join-Path $package 'manifest.json')
    }
    It 'accepts matching bytes and commit' { (Assert-Package $package -ExpectedCommit $commit).commit | Should -Be $commit }
    It 'rejects tampering' {
        Add-Content (Join-Path $package 'ApplicationDb.dacpac') 'tampered'
        { Assert-Package $package -ExpectedCommit $commit } | Should -Throw
    }
    It 'rejects a different source commit' { { Assert-Package $package -ExpectedCommit ('b'*40) } | Should -Throw }
}
Describe 'Plan policy and fingerprints' {
    It 'handles namespaced reports and ignores volatile root attributes' {
        $a=Join-Path $TestDrive 'a.xml';$b=Join-Path $TestDrive 'b.xml'
        '<DeploymentReport xmlns="http://schemas.microsoft.com/sqlserver/dac/DeployReport/2012/02" Generated="one"><Alerts/><Operations><Operation Name="Create"/></Operations></DeploymentReport>' | Set-Content $a
        '<DeploymentReport xmlns="http://schemas.microsoft.com/sqlserver/dac/DeployReport/2012/02" Generated="two"><Alerts/><Operations><Operation Name="Create"/></Operations></DeploymentReport>' | Set-Content $b
        (Get-PlanFingerprint $a) | Should -Be (Get-PlanFingerprint $b)
    }
    It 'accepts the actual no-op report emitted by SqlPackage' {
        $fixture=Join-Path $root 'tests/fixtures/SqlPackage-NoOp.xml'
        $explicit=Join-Path $TestDrive 'explicit-empty.xml'
        '<DeploymentReport xmlns="http://schemas.microsoft.com/sqlserver/dac/DeployReport/2012/02"><Alerts/><Operations/></DeploymentReport>' | Set-Content $explicit
        (Get-PlanFingerprint $fixture) | Should -Be (Get-PlanFingerprint $explicit)
    }
    It 'detects changed operations'  {
        $a=Join-Path $TestDrive 'a.xml';$b=Join-Path $TestDrive 'b.xml'
        '<DeploymentReport xmlns="http://schemas.microsoft.com/sqlserver/dac/DeployReport/2012/02"><Alerts/><Operations><Operation Name="Create"/></Operations></DeploymentReport>' | Set-Content $a
        '<DeploymentReport xmlns="http://schemas.microsoft.com/sqlserver/dac/DeployReport/2012/02"><Alerts/><Operations><Operation Name="Alter"/></Operations></DeploymentReport>' | Set-Content $b
        (Get-PlanFingerprint $a) | Should -Not -Be (Get-PlanFingerprint $b)
    }
    It 'rejects destructive plans and malformed or entity-bearing XML' {
        foreach ($text in @('<DeploymentReport xmlns="http://schemas.microsoft.com/sqlserver/dac/DeployReport/2012/02"><Alerts/><Operations><Operation Name="Drop"/></Operations></DeploymentReport>', '<DeploymentReport xmlns="http://schemas.microsoft.com/sqlserver/dac/DeployReport/2012/02"><Alerts><Alert Name="PossibleDataLoss"/></Alerts><Operations/></DeploymentReport>', '<other/>', '<!DOCTYPE x [<!ENTITY e SYSTEM "file:///etc/passwd">]><DeploymentReport xmlns="http://schemas.microsoft.com/sqlserver/dac/DeployReport/2012/02"><Operations>&e;</Operations></DeploymentReport>')) {
            $file=Join-Path $TestDrive 'bad.xml';$text | Set-Content $file
            { Get-PlanFingerprint $file } | Should -Throw
        }
    }
}
