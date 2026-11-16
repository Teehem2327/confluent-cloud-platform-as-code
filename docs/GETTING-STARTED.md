# Getting started

This guide builds the three environments from this repository. **TEST and PROD** use a short two-pipeline path. **DEV** was the first environment and has extras (Standard cluster, Schema Registry key, monitoring identity), so it is built in stages with its own pipelines. Every pipeline previews first and fails on any change it did not expect.

> **Cost.** Basic is the cheapest Confluent Cloud cluster type, but any cluster bills while it exists. ksqlDB and the Enterprise private-network cluster bill by the hour. Tear down when you are done (section 9).

## 1. What you need

| Need | Notes |
|---|---|
| Confluent Cloud account | A **Cloud resource management** API key and secret |
| Azure subscription | One storage account and one Key Vault |
| Azure DevOps organization and project | Repos, Pipelines, Environments |
| Pipeline agent | Microsoft-hosted `ubuntu-24.04`. The pipeline installs Terraform 1.17.x itself |

## 2. Azure one-time setup

1. **State storage.** Create a resource group, a storage account, and a container named `tfstate`. Each stack and environment gets its own state file, for example `platform-test.tfstate` and `applications-test.tfstate`.
2. **Key Vault.** Create a vault and add these two secrets by hand:

   | Secret name | Value |
   |---|---|
   | `confluent-cloud-api-key` | Your Confluent Cloud API key |
   | `confluent-cloud-api-secret` | Your Confluent Cloud API secret |

   Pipelines create the other secrets themselves (see the reference in section 10). Values are never printed in logs.
3. **Service connection.** In Azure DevOps, Project settings, Service connections, create an **Azure Resource Manager** connection using **workload identity federation (OIDC)**. Name it `azure-confluent-service-connection`, or change the name in the YAML.
4. **Permissions for that connection's identity:**
   - on the storage account: **Storage Blob Data Contributor**;
   - on the Key Vault: permission to get, list and set secrets. Use whichever model your vault uses, either an access policy or the **Key Vault Secrets Officer** role.

## 3. Azure DevOps setup

1. **Repos.** Create two repos in one project, `confluent-platform` and `confluent-applications`. Push the contents of `platform/` and `applications/` to them, so `pipelines/` and `environments/` sit at each repo root.
2. **Placeholders.** Replace the values in the table below. To list every one:
   ```bash
   grep -rn "sttfstateexample01\|kv-confluent-example\|example-org\|abc12345\|00000000-0000" .
   ```
3. **Environments.** Pipelines, Environments, create `confluent-dev`, `confluent-test` and `confluent-prod`. On each, open Approvals and checks, add **Approvals**, and add yourself as approver.
4. **Pipelines.** For each file in `pipelines/` that you plan to use, choose New pipeline, Azure Repos Git, your repo, Existing Azure Pipelines YAML file, then Save without running. Rename each pipeline to match its file, for example `platform-apply`. The first run of each may ask you to permit access to the service connection and environment. Approve it.

| Placeholder | Where | Replace with |
|---|---|---|
| `sttfstateexample01` | `backend.tf` and `platform-state.tf` in each environment folder | your storage account name |
| `storage` (`resource_group_name`) | same files | your resource group |
| `kv-confluent-example` | `keyVaultName` in the pipeline YAML, `KEY_VAULT_URL` in `monitoring/confluent_dynatrace_multi.py` | your Key Vault name |
| `azure-confluent-service-connection` | `azureServiceConnection` in the pipeline YAML | your connection name |
| `00000000-0000-0000-0000-000000000000` | wherever it appears | your own ID |
| `abc12345` | Dynatrace tenant in `monitoring/` | your tenant ID, only if you use monitoring |

## 4. Path A: TEST or PROD

Run **`platform-apply`** with `environment = test`. Leave **Apply after approval** unticked for the first run.

- **Expect in the log:** `PASS: exactly the expected creations; nothing applied.` The plan is 7 creations: 1 environment, 1 cluster, 2 service accounts, 1 role binding and 2 API keys.
- Run it again with **Apply after approval** ticked. Approve the prompt on the `confluent-test` environment. The pipeline re-plans, re-checks, applies the saved plan, and syncs the new API keys to Key Vault.
- **Check:** the Confluent console shows the environment `test` with a Basic cluster.

Then run **`applications-apply`** with `environment = test`, preview first, then apply. Expect exactly 6 creations: a guard resource, the topics `orders` and `payments`, and 3 ACLs (orders read, orders write, consumer group).

For PROD, repeat both with `environment = prod`.

## 5. Path B: DEV, built in stages

DEV applies run against the `confluent-dev` environment, so each one waits for your approval. For every stage, run the Preview pipeline or the Preview stage first, read the planned creations, and only then tick the apply option.

| Step | Pipeline | What it does |
|---|---|---|
| 1 | `platform-dev-deploy` | Plan-only preview of the DEV environment and the `kafka-dev` cluster |
| 2 | `platform-dev-apply` | Applies it after approval. Review costs first. Tick `enableApply` |
| 3 | `platform-dev-identity-preview`, then `platform-dev-identity-apply` | Two service accounts and one EnvironmentAdmin role binding |
| 4 | `platform-dev-api-keys-preview`, then `platform-dev-api-keys-apply` | Kafka API keys for the platform and application identities. Leaves the cluster, service accounts and RBAC unchanged |
| 5 | `platform-dev-schema-registry-key` | Schema Registry API key, written to Key Vault as `dev-schema-registry-api-key` and `-secret` |
| 6 | `platform-dev-monitoring-identity` | Read-only monitoring service account, MetricsViewer binding and key, written to Key Vault as `dev-monitoring-confluent-api-key` and `-secret` |
| 7 | `applications-dev-resources-preview`, then `applications-dev-resources-apply` | Topics and ACLs. The `orders-value` Avro schema is defined in `applications/environments/dev` |

Later, if you rotate the Schema Registry key, run `applications-dev-schema-credentials`. It proceeds only if the plan is one in-place update of the stored schema credentials.

**Optional DEV extras:**
- `platform-dev-cluster-upgrade-apply`: upgrades `kafka-dev` from Basic to Standard. It is **irreversible** and raises cost. It proceeds only if the saved plan is exactly one in-place update of the cluster.
- `platform-dev-ksqldb-apply` and `platform-dev-ksqldb-remove`: a ksqlDB cluster, **billed hourly**. Removal needs the confirmation `remove-ksqldb`.
- `platform-dev-private-network-plan`, `-apply`, `-destroy`: Azure Private Link and an optional Enterprise cluster. The plan costs nothing. Apply is billed about $1.75 to $2.25 per eCKU-hour, needs the confirmation `deploy-private-network`, and should be destroyed the same day.
- `platform-dev-drift-check` and `applications-dev-drift-check`: plan-only checks that nothing changed outside Terraform.

## 6. Test end to end

1. Run **`kafka-produce-messages`**, choose `dev`, `test` or `prod` and a count from 1 to 200. Expect `PASS: messages produced.` DEV messages are Avro, TEST and PROD are JSON.
2. Run **`kafka-consume-messages`** for the same environment. It reads the messages and prints lag per partition.

## 7. Monitoring (optional)

The collector pushes Confluent Metrics API data to Dynatrace every hour for DEV, TEST and PROD, without any approval, because it only reads metrics. It needs:
- the monitoring identity from DEV step 6;
- a Dynatrace API token, stored by hand as `dynatrace-metrics-api-token`;
- your cluster IDs in `monitoring/collector-config.json`;
- the pipeline `applications-dev-monitoring-collector` registered and left enabled;
- the dashboard in `monitoring/dynatrace-dashboard.json`, imported by hand in Dynatrace.

To stop it, disable the pipeline in Azure DevOps.

## 8. If something fails

| Symptom | Likely cause |
|---|---|
| Preview fails with an unexpected-change error | The plan contains more than the expected creations. Read the list and fix the cause, do not edit the gate |
| Cannot read or write state | The service connection's identity lacks Storage Blob Data Contributor |
| Cannot read or set secrets | The identity lacks Key Vault permissions, or the vault name is wrong |
| Pipeline waits forever | Approve the pending check on the environment |
| A DEV stage fails on a missing prerequisite | Run the stages in the order of the table in section 5 |

## 9. Tear down

Disable the collector pipeline first if you use it. Each preview shows the exact deletions before anything is destroyed.

**TEST or PROD**
1. `applications-destroy`: expect 6 deletions. Tick the destroy box and type `destroy-test` or `destroy-prod`.
2. `platform-destroy`: expect 7 deletions, same confirmation.

**DEV (do it last, it removes the monitoring identity and the Schema Registry key)**
1. If deployed, run `platform-dev-ksqldb-remove` and `platform-dev-private-network-destroy` first.
2. `applications-dev-destroy`: run the preview, then tick `enableDestroy`, type `destroy-dev`, and enter `expectedDeletions` equal to the count the preview showed (8 in the original build).
3. `platform-dev-destroy`: same method (11 in the original build).

Then check that the Confluent Environments page no longer lists the environments. Key Vault secrets are left in place on purpose. A redeploy overwrites them.

## 10. Key Vault secret reference

| Secret | Created by |
|---|---|
| `confluent-cloud-api-key`, `confluent-cloud-api-secret` | You, by hand (section 2) |
| `dynatrace-metrics-api-token` | You, by hand (monitoring only) |
| `<env>-platform-kafka-api-key` and `-secret` | The platform pipelines |
| `<env>-application-kafka-api-key` and `-secret` | The platform pipelines |
| `dev-schema-registry-api-key` and `-secret` | `platform-dev-schema-registry-key` |
| `dev-monitoring-confluent-api-key` and `-secret` | `platform-dev-monitoring-identity` |
