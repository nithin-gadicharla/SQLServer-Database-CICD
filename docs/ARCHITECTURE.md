# Design and enforcement

## Build once

The Microsoft.Build.Sql SDK invokes DacFx model validation through MSBuild and emits a DACPAC. The build wrapper records its SHA-256, source commit and CI run identity. Compilation catches SQL project references and syntax issues; it cannot prove production behavior or full permission coverage.

## Artifact origin

Promotion accepts only a completed successful push CI run on main in this same repository, checks the workflow path and exact commit, then downloads the artifact by run ID. The manifest is checked again before each plan/publish. A checksum detects changed bytes; trusted CI origin and protected main provide the provenance boundary. A checksum alone is not a digital signature or independent attestation.

## Plan and publish

The connection must use encrypted TLS with certificate validation, match the configured server/database and refer to a user database. Opening that exact database before invoking SqlPackage prevents accidentally provisioning a nonexistent target through a typo. Schema create permission is outside the wrapper's responsibilities.

Plan creates a DeployReport and Script with the same pinned tool and deploy options. The receipt binds source commit, DACPAC hash, target fingerprint, environment and a hash of report Operations/Alerts. It omits connection strings. DTDs and external XML entities are rejected. Drop operations and data-loss alerts are rejected. Publish regenerates the report/script after approval, compares the receipt, then uses SqlPackage Publish so the data-loss guard runs again.

The publisher is intentionally conservative: extra target objects, indexes, constraints, DML triggers and extended properties are not automatically removed. This can preserve intentional drift and means the target is not guaranteed to equal the project. Database options, permissions and role membership are not managed by this sample. Physical column order is intentionally ignored so a nullable column added in the middle of a project definition does not force table recreation just to match ordinal positions; applications must use explicit column lists. Handle destructive/schema cleanup changes through a separate reviewed migration process.

A fingerprint detects changes in the reported operations/alerts, not every database change or concurrent data modification. There is still a time-of-check/time-of-use interval. Environment concurrency serializes this repository's promotions for one environment, not external tools, other repositories or aliases for the same physical database.

## Recovery and partial failure

A successful Publish followed by a failed smoke test does not undo the schema. Treat it as a deployment incident and follow the recovery runbook. No unattended downgrade or restore is attempted. SqlPackage transactional options are not a guarantee that every deployment action is reversible.

## Tested scope

The sample targets SQL Server 2022. CI uses a Windows MSBuild build and checks the Windows sqlpackage.exe; live deployment tests run the same pinned SqlPackage release on Linux against a disposable SQL Server container. The real Dev/Test/Prod workflow is configuration-complete but cannot be proven against undisclosed targets. See VALIDATION.md for actual runs and remaining limits.
