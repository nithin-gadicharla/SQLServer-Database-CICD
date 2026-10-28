# Security

Do not commit credentials, production connection strings, backup files or customer data. Store secrets in environment-scoped secrets or a managed secret store. Deployment reports/scripts can expose database structure; approve their retention and use a restricted repository for confidential targets.

TLS certificate validation is required; there is no bypass option. SqlPackage needs the connection string as a process argument in this implementation, so use isolated dedicated runners and do not expose process inspection to untrusted users. Script argument arrays are never printed, but native tool logs may include schema and target details.

Never run untrusted pull requests on production-connected runners. Protect main and environment approvals before enabling promotion. Report vulnerabilities privately to the repository owner through a verified channel or GitHub private vulnerability reporting if enabled. No support SLA or production certification is claimed.
