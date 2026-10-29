# SQL Server Database CI/CD — Project Summary and Highlights

> **Main achievement:** A working SQL Server CI/CD reference implementation that builds a DACPAC with MSBuild, validates it in a disposable database, and provides a controlled SqlPackage promotion workflow for Dev, Test and Prod.

**Repository:** [SQLServer-Database-CICD](https://github.com/nithin-gadicharla/SQLServer-Database-CICD)  
**Verified CI:** [Successful build and deployment tests](https://github.com/nithin-gadicharla/SQLServer-Database-CICD/actions/runs/40791422323)  
**Tested source commit:** `5f8b9a51d33b3e4dc3f01d9409925583e215c881`  
**License:** MIT

## Most important features

| Highlight | What was implemented | Why it matters |
| --- | --- | --- |
| **Build once, promote the same artifact** | MSBuild produces a DACPAC with a source-commit and SHA-256 manifest; promotion selects a successful main-branch CI run | Prevents rebuilding different schema artifacts for each environment |
| **Plan before publishing** | SqlPackage generates an XML deployment report and SQL script | Gives reviewers concrete changes to inspect before execution |
| **Recheck the reviewed plan** | A receipt binds the source commit, DACPAC hash, target, environment and reported operations/alerts; Publish regenerates and compares the plan | Rejects mismatched artifacts, targets and changed plans |
| **Data-loss protection** | Possible data loss is blocked; automatic drops and smart defaults are disabled; reported Drop operations are rejected | Makes destructive changes an explicit separate review concern |
| **Target verification** | Certificate-validated TLS, server/database matching, exact database-name case and system-database rejection | Reduces wrong-target deployment risk, including on case-sensitive instances |
| **Live deployment tests** | Initial deployment, repeat publishing, additive upgrade, existing-data preservation and negative tests | Verifies actual database behavior beyond compiling a pipeline file |
| **Environment promotion workflow** | Dev/Test/Prod selection, environment-scoped configuration and support for reviewer approval | Provides a reusable deployment path once the actual environments are configured |

**Important:** Required reviewers and branch protection must be configured in GitHub settings. Workflow files alone do not establish approval protection.

## Technology and project structure

- **Build:** MSBuild engine through `dotnet msbuild`, with Microsoft.Build.Sql **2.3.0**.
- **Publish:** SqlPackage **170.5.96**, with Windows publishing explicitly invoking **`sqlpackage.exe`**.
- **Target model:** SQL Server **2022**.
- **Automation:** PowerShell, GitHub Actions and pinned tool/action versions.
- **Sample schema:** Customer and Order tables, constraints, an index, an upsert stored procedure and an aggregate view.

| Location | Purpose |
| --- | --- |
| [src/ApplicationDb](src/ApplicationDb) | SQL project and sample schema |
| [scripts/Build-Database.ps1](scripts/Build-Database.ps1) | Compile the DACPAC and create its provenance manifest |
| [scripts/Deploy-Database.ps1](scripts/Deploy-Database.ps1) | Generate plans/scripts, validate receipts and publish |
| [scripts/DatabaseCicd.psm1](scripts/DatabaseCicd.psm1) | Artifact, target and deployment-report checks |
| [scripts/Test-Database.ps1](scripts/Test-Database.ps1) | Execute database assertions |
| [publish](publish) | Conservative Dev/Test/Prod publish profiles |
| [.github/workflows/ci.yml](.github/workflows/ci.yml) | Build, unit tests and disposable database integration tests |
| [.github/workflows/deploy.yml](.github/workflows/deploy.yml) | Promote a verified CI artifact to a configured environment |
| [tests](tests) | Unit tests, SQL assertions and a captured no-op report fixture |
| [docs](docs) | Setup, architecture, validation and recovery guidance |

A compatible standalone MSBuild executable can be selected with `-MSBuildPath`. The default tested build uses the .NET SDK MSBuild engine; the sample is an SDK-style SQL project rather than a traditional SSDT project requiring installed Visual Studio targets.

## Verified results

**Both the Windows build job and the live SQL Server integration job passed in the linked CI run.**

| Validation | Result |
| --- | --- |
| Windows Pester unit tests | **11 passed** |
| MSBuild SQL project compilation | **Passed — ApplicationDb.dacpac produced** |
| Pinned Windows sqlpackage.exe execution | **Passed** |
| Initial database deployment | **Passed** |
| Repeat deployment | **Passed** |
| Stored procedure and aggregate-view smoke checks | **Passed** |
| Additive schema upgrade | **Passed** |
| Existing-row preservation | **Passed** |
| Modified approval receipt | **Rejected as expected** |
| Unsafe column narrowing | **Rejected as expected** |
| Schema/data checks after rejection | **Passed** |
| Live SQL connectivity | **Certificate-validated TLS** |

**Scope distinction:** Live deployment tests ran against a disposable Linux SQL Server 2022 container using the pinned SqlPackage tool. The Windows executable was checked separately. These results do not establish that your actual Dev/Test/Prod databases have been deployed or tested.

See the [validation record](docs/VALIDATION.md) for evidence and remaining boundaries.

## How delivery works

1. **Commit or open a pull request:** CI runs unit tests and compiles the SQL project.
2. **Produce the artifact:** The DACPAC and manifest are uploaded together.
3. **Test the database lifecycle:** CI deploys to an isolated SQL Server and runs positive and negative tests.
4. **Select a trusted build:** Promotion requires a successful main-branch push CI run and its exact source commit.
5. **Generate and review a plan:** Review the deployment report and SQL script.
6. **Approve the environment job:** GitHub reviewer protection must already be configured.
7. **Recheck and publish:** The workflow verifies the artifact/target, regenerates the plan, compares the receipt and invokes SqlPackage Publish.
8. **Run smoke tests and retain evidence:** Inspect the outcome and deployment receipt.

**The same CI artifact can be promoted to another environment without rebuilding.** Environment order remains operator-controlled; the workflow does not automatically prove that an earlier environment was deployed or approved.

## Important issues found and fixed

- **Constraint churn:** The original status constraint generated a drop/recreate operation on repeat comparison. Its IN expression was replaced with equivalent explicit OR comparisons, keeping the drop policy enforced.
- **Valid no-op reports:** SqlPackage omits the Operations section when there are no changes. The parser now normalizes that shape, with an actual generated report retained as a regression fixture.
- **Unrequested database-option changes:** Database-option scripting is disabled.
- **Column-order rebuilds:** Physical column order is ignored so ordinal positioning alone does not force table recreation. Applications should use explicit column lists.
- **Case-sensitive target names:** Database-name case is preserved in target checks and fingerprints.

## What is needed to deploy to your databases

**The code is published and the sample lifecycle is tested. Actual environment deployment remains disabled until configuration is supplied.**

| Required information or configuration | Details |
| --- | --- |
| **Database platform** | SQL Server version/edition and your existing schema or SQL project |
| **Environment targets** | Exact server endpoint and database name for Dev, Test and Prod |
| **Authentication** | SQL authentication or Windows integrated authentication for the current wrapper |
| **Runner/network access** | Hosted-runner reachability or a dedicated private Windows runner |
| **Approvals** | Plan reviewers, deployment approvers and protected branches/environments |
| **Recovery readiness** | Backup ownership, restore evidence and application recovery procedure |

Configure target variables and environment secrets through the [environment setup guide](docs/ENVIRONMENT_SETUP.md). **Enter credentials directly into an approved secret store; do not commit them or paste passwords into issues or chat.**

## Operational limits and recovery

- **A DACPAC is not a backup.** Publishing an earlier artifact does not restore deleted or transformed data.
- **A failed post-deployment smoke test does not undo an applied schema.** Follow the [recovery runbook](docs/RECOVERY.md).
- Plan fingerprints cover reported operations and alerts, not every target-state change. Concurrent external changes remain possible.
- Pre/post-deployment SQL can bypass model-based data-loss protection; this sample does not include production data migrations or seeding.
- The smoke test rolls back its rows but can advance identity values. Adapt it to the actual application.
- Production permissions, real reviewer settings, private connectivity, Entra authentication, Azure SQL variants, large-database locking/duration and recovery drills remain separately unverified.

This is an **AI-assisted reference implementation with inspectable test evidence**. No production deployment, independent adoption or performance improvement is claimed.
