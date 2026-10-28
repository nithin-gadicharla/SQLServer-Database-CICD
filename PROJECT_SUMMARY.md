# SQL Server Database CI/CD — Highlights

This repository implements a database delivery path built around Microsoft MSBuild, DACPAC artifacts and SqlPackage. The sample schema is deployable code, not just a pipeline diagram.

## Strongest features

- **Build once, promote the same bytes:** source commit and DACPAC SHA-256 are checked against a successful main CI run.
- **Plan before publish:** XML report and SQL script support review; a receipt binds artifact, target, environment and planned operations/alerts.
- **Recheck after approval:** the plan is regenerated and compared immediately before SqlPackage Publish.
- **Explicit target protection:** validated TLS, exact server/database matching and system-database rejection.
- **Conservative change policy:** possible data loss blocks deployment; automatic drops and smart defaults are disabled.
- **Actual lifecycle tests:** CI exercises initial and repeat deployment, an additive upgrade preserving rows, and unsafe-change rejection in a disposable SQL Server lab.
- **Operator guidance:** environment setup, permissions, network choices, recovery and partial-failure handling are documented.

Windows publishing invokes sqlpackage.exe. The default SQL project uses the MSBuild engine supplied by the .NET SDK (`dotnet msbuild`); a compatible standalone MSBuild executable can be selected with -MSBuildPath.

Actual hosted evidence is recorded in [docs/VALIDATION.md](docs/VALIDATION.md). Dev/Test/Prod need user-specific targets, credentials and configured approvals before deployment can run. No production result, independent adoption or performance improvement is invented. AI assistance is disclosed.
