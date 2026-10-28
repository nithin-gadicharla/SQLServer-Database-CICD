# Database deployment recovery runbook

Before publishing: identify the approved artifact/commit, backup and restore owner, recent verified recovery evidence, application compatibility window, data migration risks, expected locks/rebuilds and abort criteria. Capture an approved plan and change record. For expand/contract changes, deploy compatible additions before changing consumers and remove obsolete objects only in a later reviewed step.

If Publish fails: stop promotions, preserve the report/script and secure logs, inspect the target using authorized diagnostics, determine which schema/data changes committed, and check application health. Do not assume a nonzero exit code means no changes occurred. Do not blindly rerun or deploy an old DACPAC.

If smoke tests fail after Publish: treat the schema as potentially applied. Select a reviewed forward fix, application rollback if still schema-compatible, or recovery from verified backup/log chains to an isolated instance. Restoring production requires a separate explicit operational decision and outage/data-loss analysis. The repository does not automate this decision.

Record actual start/end times, recovered data boundary, CHECKDB and application validation results when conducting restore drills. Do not claim RTO or RPO from pipeline duration alone.

For nondestructive changes, an earlier schema artifact may be a useful comparison input. It is not a backup, cannot recover deleted data, and can itself generate unsafe reverse changes. Generate and review a fresh plan for any follow-up action.
