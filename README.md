# Confluent Cloud Platform as Code

Three Confluent Cloud environments (DEV, TEST, PROD) provisioned entirely with Terraform and operated only through approval-gated Azure DevOps pipelines, with Dynatrace monitoring. Built and validated in November 2026, then torn down through gated destroy pipelines to avoid cost. The code, pipelines and run history were kept.

> **Reference copy.** Names, IDs, tenants and endpoints in this repository are placeholders. The pipelines target Azure DevOps, so they are documentation of the design rather than something that runs from GitHub as is.

## What this demonstrates

- **Infrastructure as code with no manual creation.** Every environment, cluster, service account, role binding, API key, topic and ACL is Terraform (`confluentinc/confluent` and `azurerm` providers, Terraform 1.17.x), with remote state in Azure Blob Storage.
- **Governed change.** A preview stage runs `terraform plan`, a Python check fails the run unless the plan contains exactly the expected changes, and a manual approval on the environment is required before apply.
- **Least privilege and secret hygiene.** Separate service accounts for platform and application, RBAC role bindings, topic and consumer-group ACLs. API keys are written to Azure Key Vault from temp files and never printed in logs. Pipelines authenticate to Azure with OIDC.
- **Observability.** A Python collector pulls Confluent Metrics API data into Dynatrace every hour. One dashboard covers throughput, retained bytes, active connections and consumer lag for all three environments, with a lag alert.
- **Cost discipline.** Basic clusters for TEST and PROD, ksqlDB and private networking written as previewed-only code, and a gated destroy path for every environment.

## Architecture

```mermaid
flowchart LR
  E["Engineer"] -->|"pull request"| R["Azure DevOps Repos<br/>platform + applications"]
  R --> P["Preview stage<br/>terraform plan + Python gate"]
  P --> A["Approval check<br/>on the environment"]
  A --> X["Re-plan, re-check,<br/>apply the saved plan"]
  X --> C["Confluent Cloud<br/>DEV / TEST / PROD"]
  X --> K["Azure Key Vault<br/>API keys"]
  X --> S["Azure Blob<br/>Terraform state"]
  C --> M["Python collector<br/>hourly, Metrics API"]
  M --> D["Dynatrace<br/>dashboard + alert"]
```

## Repositories

| Folder | Owns |
|---|---|
| `platform/` | Environment, Kafka cluster, service accounts, RBAC, API keys, Schema Registry, optional ksqlDB and private networking, plus the platform pipelines |
| `applications/` | Topics (`orders`, `payments`), Avro schemas, ACLs, the monitoring collector and dashboard, produce and consume pipelines |

Both folders were separate Azure DevOps repositories, each with its own state file per environment. The folder lists are not exhaustive.

## Environments

| Environment | Cluster | Notes |
|---|---|---|
| DEV | Standard | Built first, holds the Schema Registry and the monitoring identity |
| TEST | Basic | Deployed through `platform-apply` and `applications-apply` |
| PROD | Basic | Same pipelines, separate approval environment |

## Pipelines

| Pipeline | Purpose |
|---|---|
| `platform-apply`, `applications-apply` | Preview, approval, apply for TEST and PROD |
| `platform-destroy`, `applications-destroy` | Gated destroy for TEST and PROD, exact expected deletions, typed confirmation |
| `platform-dev-destroy`, `applications-dev-destroy` | DEV destroy, kept separate and named clearly, also needs an expected-deletion count |
| `kafka-produce-messages`, `kafka-consume-messages` | End-to-end test in any environment, prints consumer lag |
| `applications-dev-monitoring-collector` | Hourly metrics collection into Dynatrace |
| `platform-dev-private-network-apply` / `-destroy` | Enterprise cluster with Azure Private Link, previewed only, never deployed |
| `platform-dev-ksqldb-apply` / `-remove` | ksqlDB (billed hourly), written and previewed, removal is gated |

## How the safety gate works

1. The preview stage runs `terraform plan` and exports it as JSON.
2. A Python script compares the planned changes to an exact expected list and fails on anything extra.
3. Apply only runs when the apply box is ticked, and the environment's approval check pauses it.
4. After approval the plan is re-created and re-checked, then the saved plan is applied.
5. New API keys are synced to Key Vault. Values are never echoed.

## Screenshots

### Pipelines and governance
![Pipelines](docs/screenshots/01-azure-devops-pipelines.png)
*Every platform, application, destroy, produce and monitoring pipeline.*

![Approval environments](docs/screenshots/02-azure-devops-approval-environments.png)
*One approval environment per Confluent environment.*

![Preview gate](docs/screenshots/03-platform-apply-preview-gate.png)
*The preview stage passing: exactly the expected creations, nothing applied.*

![Pull request](docs/screenshots/04-pull-request-merged.png)
*Changes reach `main` through pull requests.*

![Disabled pipeline](docs/screenshots/05-pipeline-disabled-after-teardown.png)
*A pipeline disabled after teardown, with run history kept.*

### Confluent Cloud
![Environments](docs/screenshots/06-confluent-environments.png)
*DEV, TEST and PROD environments created by Terraform.*

![DEV cluster](docs/screenshots/07-confluent-dev-cluster-standard.png)
*DEV cluster (Standard).*

![TEST cluster](docs/screenshots/08-confluent-test-cluster-basic.png)
*TEST cluster (Basic).*

![PROD cluster](docs/screenshots/09-confluent-prod-cluster-basic.png)
*PROD cluster (Basic).*

![DEV messages](docs/screenshots/10-dev-orders-messages.png)
*Sample orders produced to the DEV topic by the produce pipeline.*

### Producing messages
![Produce parameters](docs/screenshots/11-produce-pipeline-parameters.png)
*Pick an environment and a message count.*

![Produce result](docs/screenshots/12-produce-pipeline-success.png)
*50 messages sent to `prod.orders`, 0 failed.*

### Secrets and state
![Key Vault](docs/screenshots/13-azure-key-vault-secrets.png)
*Secret names only. Values are never printed or committed.*

![State files](docs/screenshots/14-terraform-state-blobs.png)
*One Terraform state file per stack and environment.*

### Monitoring
![Dashboard, all environments](docs/screenshots/15-dynatrace-dashboard-all-environments.png)
*Throughput, consumer lag, connections and retained bytes across DEV, TEST and PROD.*

![Per-environment tiles](docs/screenshots/16-dynatrace-per-environment-tiles.png)
*Per-environment throughput and retained bytes.*

![First dashboard](docs/screenshots/17-dynatrace-dev-dashboard-first-version.png)
*The first, DEV-only version of the dashboard.*

![Lag alert](docs/screenshots/18-dynatrace-consumer-lag-problem.png)
*A consumer-lag problem raised and closed.*

### Code
![platform-apply.yml](docs/screenshots/19-vscode-platform-apply-yaml.png)
*The apply pipeline definition.*

![Layout](docs/screenshots/20-vscode-environments-layout.png)
*One folder per environment, shared modules.*

## Stack

Terraform, Confluent Cloud (Kafka, Schema Registry, RBAC, ACLs), Azure DevOps Repos and Pipelines, Azure Blob Storage, Azure Key Vault, OIDC, Python, Bash, Dynatrace.

## About

Built by Temitope Moses Fasooto, Confluent Certified Administrator for Apache Kafka (CCAAK). A related project deploys the full Confluent Platform on Amazon EKS with Prometheus and Grafana: [kafka-deployment-on-eks](https://github.com/Teehem2327/kafka-deployment-on-eks).
