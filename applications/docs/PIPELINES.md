# Applications pipelines (confluent-applications)

Only the two CI pipelines run automatically, and they only validate. Everything that changes Confluent Cloud
is started by hand and waits at the `confluent-dev` approval gate.

## How to add or change a topic, ACL or schema

1. Edit the Terraform in `environments/dev` (topics and ACLs in `main.tf`, schemas in `schemas.tf` and
   `schemas/*.avsc`) and open a pull request.
2. After the merge, run **`applications-dev-drift-check`**. It plans only; a pending change shows as a failure
   with the planned action listed.
3. Run the gated apply that matches the change and approve it. The apply pipelines accept only an exact, expected change.
4. Run the drift-check again; it must end with `Changes: []`.

Topics are created through this process and not in the Confluent console. A topic created by hand is not managed
and not reviewed.

## Active pipelines

| File | Azure DevOps name | Runs | Purpose |
|---|---|---|---|
| `applications-ci.yml` | `applications-ci` | Automatically on pull requests | Terraform validation for the applications code. |
| `monitoring-ci.yml` | `monitoring-ci` | Automatically on pull requests | Runs the collector unit tests. |
| `applications-dev-drift-check.yml` | `applications-dev-drift-check` | By hand | Read-only plan of topics, ACLs and the schema. Must report zero changes. |
| `applications-dev-resources-apply.yml` | `applications-dev-resources-apply` | By hand | Approved apply of the DEV topics, ACLs and schema registration. |
| `applications-dev-monitoring-collector.yml` | `confluent-applications-dev-monitoring-collector` | Hourly (minute 5, UTC) and by hand | Reads Kafka metrics from Confluent and sends them to Dynatrace. Read-only. Disable it when the Dynatrace trial ends. |

## Archived (in the `archive` folder)

| File | Why |
|---|---|
| `applications-dev-resources-preview.yml` | One-time preview that expects exactly six creations. Would fail now that they exist. |
| `applications-dev-schema-credentials.yml` | One-time refresh of the stored Schema Registry credentials after the key swap. |
| `applications-cd.yml` | Older plan stage that forces the deploy switches to `false`, so it would plan deleting everything. **Disabled; do not run.** Replaced by the drift-check. |

## Monitoring

`monitoring/` holds the collector, its config and the Dynatrace dashboard JSON. It sends received bytes, sent bytes,
retained bytes by topic, active connections and consumer lag. It authenticates with the read-only
`sa-dev-monitoring` key stored in Key Vault. Consumer lag appears only while a consumer group is active.
