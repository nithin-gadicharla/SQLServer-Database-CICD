# Configure Dev / Test / Prod

The repository code is complete; your actual targets cannot be connected without their details and authorization. Default deployment enablement is absent, so the promotion workflow fails closed before accessing a target. CI uses only its own disposable lab.

## Information needed

| Item | Example / required decision |
| --- | --- |
| Platform | SQL Server version/edition; Azure SQL/MI require separate target validation |
| Source model | Replace sample schema with reviewed SQL project objects or migrate your existing SSDT project |
| Targets | Exact server endpoint (including instance/port) and user database for each environment |
| Authentication | SQL authentication or Windows integrated authentication supported by the current wrapper |
| Network | Hosted-runner reachability, or dedicated private Windows runners |
| Approval | Who reviews plans and approves Dev/Test/Prod publishes |
| Recovery | Backup ownership, retention, restore evidence and application rollback/forward-fix procedure |

Use environment secrets to enter credentials directly in GitHub. Do not send passwords in chat. The connection-string parser currently uses System.Data.SqlClient; Entra-specific authentication/token workflows require a separately implemented and tested extension.

## GitHub environments

Create `dev-plan`, `dev`, `test-plan`, `test`, `prod-plan`, and `prod`.

For each pair configure the **same** target identity:

| Setting | Type | Purpose |
| --- | --- | --- |
| `DB_SERVER` | Environment variable | Expected server endpoint, exactly matching the connection string |
| `DB_DATABASE` | Environment variable | Expected existing user database, including exact letter case |
| `DB_CONNECTION_STRING` | Environment secret | Validated encrypted connection; authentication from your approved mechanism |
| `ALLOW_DEPLOYMENT_REPORT_UPLOAD` | Variable in `*-plan` | Set `true` only after approving storage of schema reports/scripts as Actions artifacts |

On deployment environments (`dev`, `test`, `prod`), configure required reviewers, prevent self-review when available, restrict branches to `main`, and disable approval bypass where your policy requires it. Restrict `*-plan` environments too when access to schema metadata needs approval. Protect `main` with required database CI and code review. These settings are not automatically established by the workflow files.

Only after settings, approvers and connectivity are ready, set repository variable `DATABASE_DEPLOYMENTS_ENABLED=true`. Review the generated plan artifact before approving the publish job. Without required reviewers, GitHub may run an environment job immediately: do not enable real deployment before configuring protection.

Configure a deployment identity with only the privileges required for your schema operations. Avoid granting sysadmin simply to make deployment pass. In the plan environment, a separately scoped identity may be used if it can read the needed metadata and generate a complete plan; validate its coverage.

SQL authentication connection-string shape (placeholder only):

```text
Server=sql-dev.example.com;Initial Catalog=ApplicationDb_Dev;User ID=<deployment-user>;Password=<secret>;Encrypt=True;TrustServerCertificate=False;Connect Timeout=30
```

Windows integrated authentication is appropriate on a configured domain-connected runner. The workflow defaults to GitHub-hosted Windows; switch both plan/publish `runs-on` values to your dedicated runner labels for private endpoints. Do not open a production firewall broadly to accommodate hosted runners. Do not run untrusted pull requests on production-connected self-hosted runners.

## Trigger promotion

1. Merge reviewed schema changes into `main` and wait for **database-ci** to finish successfully.
2. Open **Actions → database-promote → Run workflow** on `main`.
3. Enter the successful main `push` run ID, full 40-character source SHA, and destination environment.
4. The workflow verifies the run origin and downloads its `database-package` artifact.
5. Review `deployment-plan-<environment>`: report, script and receipt.
6. Approve the waiting environment job. It regenerates the plan and rejects a changed package, target, environment or operations/alerts fingerprint.
7. Inspect publish and smoke-test results and retain the deployment receipt with your change record.

Use the same CI run and SHA to deploy the identical artifact to another environment. This is an operator-controlled promotion process, not an automatic environment-order enforcement system. Artifacts expire under your Actions retention policy; archive approved releases in a trusted long-term artifact store when needed. Never rebuild an expired artifact and describe it as the original.

This is a public reference repository. Real deployment reports, SQL text and logs may expose your schema, and Actions artifacts in a public repository are not a confidential vault. Put sensitive application source and real deployment workflows in a suitably restricted repository before enabling them.
