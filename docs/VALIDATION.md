# Validation evidence

Status: hosted validation pending. This file will link actual build and live database deployment results after execution; tests are not marked passed merely because a workflow exists.

Defined coverage: PowerShell syntax; target/TLS guards; artifact tampering and source mismatch; XML report policy and fingerprints; real MSBuild/DACPAC compilation; Windows SqlPackage executable; SQL Server initial deployment; repeat publishing; stored procedure/view smoke assertions; additive upgrade with existing-data preservation; rejected column narrowing; and post-failure schema/data checks.

Unverified until separately executed: actual Dev/Test/Prod endpoints, private runner connectivity, environment reviewer configuration, production permissions, Entra authentication, Azure SQL variants, large-database deployment duration/locking and recovery drills.
