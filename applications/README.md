# Confluent Cloud Application Infrastructure

This repository defines Kafka topics and ACLs separately from the platform infrastructure.

## Layout
- `modules/topics`: reusable topic definitions
- `modules/acls`: reusable Kafka ACL definitions
- `environments/dev`: DEV application configuration
- `pipelines/applications-ci.yml`: validation pipeline
- `pipelines/applications-cd.yml`: deployment-disabled placeholder

## State
Azure Blob backend: `sttfstateexample01/tfstate/applications-dev.tfstate`.
The platform state uses a separate key.

## Safety
- `deploy_application_resources` defaults to `false`.
- The CD pipeline has **no Terraform Apply step** yet.
- Do not commit API credentials, state, or Terraform plan files.
- Do not enable application deployment until a Kafka cluster, appropriately scoped credentials, and an approval-controlled plan/apply pipeline exist.

## Local validation
```bash
terraform fmt -recursive
terraform -chdir=environments/dev init -backend=false -input=false
terraform -chdir=environments/dev providers lock -platform=windows_amd64 -platform=linux_amd64
terraform -chdir=environments/dev validate
```

Terraform validation does not verify cloud authorization or live resource compatibility.
