
# Confluent Cloud — DEV, TEST and PROD Readiness

## Project objective

Demonstrate an enterprise-style Confluent Cloud platform managed through Azure DevOps, Terraform, and Dynatrace.

## Environment architecture

| Component | DEV | TEST | PROD |
|---|---|---|---|
| Terraform root | environments/dev | environments/test | environments/prod |
| State key | platform-dev.tfstate | platform-test.tfstate | platform-prod.tfstate |
| Kafka cluster | kafka-dev | kafka-test | kafka-prod |
| Cloud | Azure | Azure | Azure |
| Kafka tier | Basic | Basic (demo) | Basic (demo) |
| Provisioned | Existing | No | No |
| CI validation | Enabled | Enabled | Enabled |

## Infrastructure management

Terraform uses reusable modules and separate environment configurations.

Azure DevOps Platform CI validates:

- Terraform formatting
- Terraform configuration
- Provider and module configuration
- Environment separation
- Deployment safety

The Platform CD pipeline remains approval-controlled and plan-only.

## Security requirements

The final platform demonstration should verify:

- Network-level security
- Authentication and authorization
- Service accounts and API keys
- Kafka ACLs and RBAC
- Audit logging
- Secure Terraform state
- Environment-specific credentials

These controls must be verified individually before claiming completion.

## Platform services

The original project requires:

- Kafka clusters
- Schema Registry
- ksqlDB
- Kafka topics and schemas
- Application identities and permissions

The presence of Terraform configuration does not prove a service is deployed.

## Monitoring

Dynatrace integration has been implemented for DEV.

The monitoring demonstration should include:

- Broker throughput
- Kafka resource usage
- Consumer lag
- Other available Kafka metrics

The collector can run locally for demonstration purposes.

## Important deployment limitations

TEST and PROD clusters have not been provisioned.

The Basic Kafka tier used in the demonstration is not equivalent to a highly available production architecture.

The current CD workflow does not perform TEST/PROD apply operations.

The repository contains older DEV apply pipelines. Review them separately before running them.

Terraform-managed credentials may be stored in state and must be protected.

## Known Terraform concerns

Before future deployment:

1. Review DEV API-key module references to conditional Kafka resources.
2. Verify existing Terraform state before enabling or disabling resource flags.
3. Ensure RBAC and service-account flags are configured consistently.
4. Review plans for unexpected resource deletion.
5. Confirm costs before creating TEST/PROD resources.

## Portfolio validation

1. Show the enterprise repository structure.
2. Show DEV Kafka resources in Confluent Cloud.
3. Demonstrate Terraform validation for DEV, TEST and PROD.
4. Show Azure DevOps pipeline execution.
5. Demonstrate the application pipeline and Kafka messaging.
6. Show security and access controls.
7. Verify Schema Registry, ksqlDB and auditing.
8. Display available Dynatrace metrics.
9. Explain TEST/PROD deployment approvals and state separation.

## Completion criteria

The project is complete when the original platform,
application, security, monitoring, and deployment
requirements have been demonstrated and verified.

No additional Kafka clusters should be created without
explicit authorization and cost review.
