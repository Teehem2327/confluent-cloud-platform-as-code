# Operations and handover checklist

## Architecture
Two Azure DevOps Git repositories: `confluent-platform` (environment, Kafka cluster,
service accounts and security) and `confluent-applications` (topics and ACLs).
Terraform roots: `environments/dev`, `environments/test`, `environments/prod`.
Azure Blob backend state keys are separate for platform/applications and per environment.

## Day-2 operations
- Review Azure DevOps CI failures and Terraform drift before deployment decisions.
- Rotate API keys via Key Vault, then validate the affected pipeline and applications.
- Verify cluster metrics, consumer lag, connector tasks and schema compatibility.
- Maintain incident response, backup/DR objectives and access reviews.
- Record ownership of Confluent Cloud, Azure subscriptions, Key Vault, pipelines and Dynatrace.

## Acceptance criteria
[ ] Terraform fmt, init -backend=false and validate pass for all six roots
[ ] CI runs pass for both repositories
[ ] No `terraform apply` or `terraform destroy` in active pipeline steps
[ ] TEST/PROD states remain uninitialized until approved
[ ] Environment-specific credentials and access controls reviewed
[ ] Dynatrace metrics source and ingestion method selected and verified
[ ] Dashboards/alerts tested with actual data before claiming monitoring complete
[ ] Cost estimate and budgets approved before any resource provisioning
[ ] Runbook and change-control owner assigned

## Important
Configuration validation does not prove cloud connectivity, Kafka deployment,
Dynatrace ingestion or production readiness.
