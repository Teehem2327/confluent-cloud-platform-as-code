# Platform pipelines (confluent-platform)

All pipelines run from the YAML files in `pipelines/`. Nothing deploys on a commit: only the CI pipeline
runs automatically, and it only validates. Every pipeline that changes Confluent Cloud is started by hand
and waits at the `confluent-dev` approval gate before it applies.

## How a change reaches Confluent Cloud

1. Change the Terraform in `environments/<env>` and open a pull request. CI validates all three environments.
2. After the merge, run **`platform-plan`** for the environment. DEV must report zero changes after an
   apply; TEST and PROD show what would be created and never apply.
3. If a change is intended, run the matching gated pipeline, read its preview, then approve.

## Active pipelines

| File | Azure DevOps name | Runs | Purpose |
|---|---|---|---|
| `platform-ci.yml` | `platform-ci` | Automatically on pull requests and pushes to `main` | Terraform `fmt` and `validate` for dev, test and prod, plus offline safety checks. Never contacts Confluent. |
| `platform-plan.yml` | `confluent-platform-plan` | By hand, with an `environment` choice | Plan only. DEV fails on any difference (drift check). TEST and PROD list what would be created and fail only on deletes. |
| `platform-cd.yml` | `platform-cd` | By hand | DEV zero-change plan gate; TEST and PROD approval gate. No apply. |
| `platform-dev-private-network-plan.yml` | `platform-dev-private-network-plan` | By hand | Preview only. Plans the DEV private networking root (`environments/dev-private-network`) and fails unless it is exactly the expected creations. Costs nothing. Its apply pipeline is added for the final deployment window. |
| `platform-dev-ksqldb-apply.yml` | `confluent-platform-dev-ksqldb` | By hand | Preview, then approved creation of a DEV ksqlDB cluster. **On hold: bills hourly while it exists.** |

## Finished one-time pipelines (in the `archive` folder)

These each performed one step of the build. Re-running them fails their own exact-change check, which is the
safety design. The files and run history stay as the record of what was deployed and approved; nothing was deleted.

| File | What it did |
|---|---|
| `platform-dev-apply.yml` | Created the DEV Kafka cluster. |
| `platform-dev-identity-preview.yml`, `platform-dev-identity-apply.yml` | Created the DEV service accounts and role binding. |
| `platform-dev-api-keys-preview.yml`, `platform-dev-api-keys-apply.yml` | Created the two DEV Kafka API keys and stored them in Key Vault. |
| `platform-dev-deploy.yml` | Earlier deployment pipeline. |
| `platform-dev-drift-check.yml` (three definitions) | DEV drift check; superseded by `platform-plan` with `dev`. |
| `platform-dev-cluster-upgrade-apply.yml` | Upgraded `kafka-dev` from Basic to Standard in place. Irreversible. |
| `platform-dev-schema-registry-key.yml` | Created the Schema Registry API key and stored it in Key Vault. |
| `platform-dev-monitoring-identity.yml` | Created `sa-dev-monitoring` with the read-only MetricsViewer role and its key; stored the key in Key Vault. |

## Private networking (code ready, not deployed)

`environments/dev-private-network` is a separate Terraform root with its own state
(`platform-dev-private-network.tfstate`). It builds Azure Private Link for an Enterprise cluster: a Confluent gateway and
access point, an Azure VNet, private endpoint and private DNS, plus an optional Enterprise cluster `kafka-dev-private`.
Both switches default to `false`, and it never touches `kafka-dev`. The preview shows 9 creations with the cluster included.

The resource group `rg-confluent-private-dev` is created once by hand. The pipeline identity
(`sp-azdo-confluent-terraform`) has Contributor on that group only, not on the subscription.

## Deployed state (DEV)

Environment `dev`; cluster `kafka-dev` (Standard, Azure eastus); service accounts `sa-dev-platform`,
`sa-dev-application`, `sa-dev-monitoring`; EnvironmentAdmin for the platform account; MetricsViewer for the
monitoring account; two Kafka API keys, one Schema Registry key and one monitoring key. TEST and PROD are
code only and have never been deployed.

## Rules

- Never apply from a laptop. Use the gated pipelines.
- Terraform state holds secrets. Keep access to the state storage account restricted.
- Switches that default to `false` (`deploy_ksqldb`) are off until a gated pipeline turns them on. Switches for
  resources that already exist default to `true` so plans do not try to delete them.
