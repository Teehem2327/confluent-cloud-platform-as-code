# DEV / TEST / PROD Terraform architecture

- Terraform module implementations are shared; each environment has a separate root and Azure Blob state key.
- DEV remote state is preserved. TEST and PROD backend keys are configured but state is **not created**.
- Run CI once to validate all three environments with `terraform init -backend=false` and `terraform validate`.
- Platform CD supports static validation of all three environments and DEV-only live plan with a zero-change gate.
- Applications CD retains its existing DEV-only zero-change plan; TEST and PROD are static-validation-only for now.
- No pipeline in this package runs `terraform apply`. No Kafka clusters, topics, ACLs or service accounts are created by these checks.
- TEST and PROD deployments need separate credentials, Azure DevOps environment approvals, a cost review, and explicit authorization before introducing any Apply workflow.
- Do not initialize remote TEST or PROD state or apply these configurations until approved.
- Review plan outputs for drift; plan-only validation does not guarantee that a future apply is safe.
- The initial Platform DEV environment already exists in Confluent Cloud. Do not import, rename, or recreate it.
