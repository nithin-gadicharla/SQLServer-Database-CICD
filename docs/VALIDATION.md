# Validation evidence

[Hosted run 40791422323](https://github.com/nithin-gadicharla/SQLServer-Database-CICD/actions/runs/40791422323) passed on commit 5f8b9a51d33b3e4dc3f01d9409925583e215c881.

- All 11 Windows Pester tests passed.
- MSBuild compiled the SQL project into ApplicationDb.dacpac.
- Pinned Windows sqlpackage.exe 170.5.96 ran successfully.
- Live SQL Server 2022 tests passed: initial deployment, repeat deployment, stored procedure/view smoke checks, additive upgrade preserving existing rows, modified approval receipt rejection, unsafe column narrowing rejection, and post-failure schema/data checks.
- Deployment testing used certificate-validated TLS and a disposable Linux SQL Server container. The Windows executable was checked separately; actual user environments were not connected.

Corrections discovered through execution: the original IN status constraint caused drop/recreate churn and was replaced with an equivalent explicit OR expression; no-op SqlPackage reports omit Operations, so the parser now normalizes that shape with a captured regression fixture. Database-option scripting is disabled, physical column order is ignored, and exact database-name case is preserved. Drop/data-loss guards remain enabled.

Unverified: your Dev/Test/Prod endpoints, private runner connectivity, environment reviewer configuration, production permissions, Entra authentication, Azure SQL variants, large-database locking/duration and recovery drills. Configure these using ENVIRONMENT_SETUP.md before enabling promotion.
