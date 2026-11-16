# Deployment governance — DEV / TEST / PROD

## Current release posture
All environments are **plan/validation only**. There is no Terraform Apply in this release.
Do not enable provisioning flags or create TEST/PROD state without an approved change and cost estimate.

| Control | DEV | TEST | PROD |
|---|---|---|---|
| Terraform static validation | Yes | Yes | Yes |
| Live plan | Existing DEV pipeline only | Not enabled | Not enabled |
| Terraform Apply | Disabled | Disabled | Disabled |
| Deployment approval (future) | Team reviewer | Independent reviewer | Two-person approval and change ticket |
| Confluent credentials | DEV-scoped | Dedicated TEST-scoped | Dedicated PROD-scoped |

## Azure DevOps setup checklist (manual, not provisioned by this bundle)
1. Create environments named `confluent-dev`, `confluent-test`, `confluent-prod`.
2. Configure approvals/checks on the **environment resources**; use an independent reviewer for TEST and PROD.
3. Restrict service connection and variable-group pipeline permissions to the intended pipelines.
4. Use separate Confluent Cloud API keys, Kafka API keys, and Key Vault secret scopes per environment.
5. Require branch policies and pull-request reviews for `main`; restrict direct pushes.
6. Require an explicit change ticket, reviewed cost estimate, and approved plan before introducing any Apply job.
7. Apply must use the **same reviewed saved plan**, not a new unreviewed plan, after checks and approval.
8. Ensure approval checks cannot be bypassed by changing YAML in an unreviewed branch.
9. Enable Azure cost budgets and Confluent Cloud spend alerts before any paid deployment.

## Safe promotion sequence (future only)
PR -> format/validate -> DEV plan -> approval -> DEV apply -> test verification ->
TEST plan -> independent approval -> TEST apply -> integration verification ->
PROD plan -> two-person approval -> PROD apply -> smoke checks.
This is a design proposal, NOT an active deployment workflow.

## Rollback and incident rules
- Do not assume `terraform apply` or `terraform destroy` is a safe rollback.
- For Kafka topic changes, partition increases and data/schema changes may be irreversible.
- Stop pipeline execution on drift, authorization failures, unexpected plan actions, or budget concerns.
- Retain reviewed plan metadata and change ticket, never raw secrets or raw plan JSON as public artifacts.
- Validate client connectivity, producer/consumer health, consumer lag, ACLs and Schema Registry after rollout.
- Restore through an incident-specific runbook with a reviewed remediation plan.
