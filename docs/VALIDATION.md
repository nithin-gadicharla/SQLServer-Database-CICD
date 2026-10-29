# Validation evidence

Hosted validation is in progress: [run 40790231396](https://github.com/nithin-gadicharla/SQLServer-Database-CICD/actions/runs/40790231396), source commit cc26f47f9d7ae80349946acba05706daafd93294.

Verified so far: Windows build job succeeded; all 9 Pester unit tests passed; MSBuild compiled ApplicationDb.dacpac; pinned Windows sqlpackage.exe ran successfully; the DACPAC and provenance manifest were uploaded as database-package. The first live job deployed the sample successfully, then the repeat-plan gate correctly blocked constraint drop/recreate churn. The status check expression was changed from IN to explicit OR comparisons; database-option scripting was also disabled. Full lifecycle validation is being rerun without weakening drop/data-loss policy.

Defined coverage: PowerShell syntax; target/TLS guards; artifact tampering and source mismatch; XML report policy and fingerprints; real MSBuild/DACPAC compilation; Windows SqlPackage executable; SQL Server initial deployment; repeat publishing; stored procedure/view smoke assertions; additive upgrade with existing-data preservation; rejected column narrowing; and post-failure schema/data checks.

Unverified until separately executed: actual Dev/Test/Prod endpoints, private runner connectivity, environment reviewer configuration, production permissions, Entra authentication, Azure SQL variants, large-database deployment duration/locking and recovery drills.

The second run (40790747008) confirmed that the revised schema no longer produced constraint churn. Its valid no-change SqlPackage report omitted the Operations element; the parser had incorrectly rejected it. The parser now accepts the observed no-op shape with a regression fixture, requires the DacFx report namespace and Alerts section, and retains destructive-operation/data-loss rejection.
