# Dynatrace monitoring implementation guide (configuration only)

**Status:** Design and operational checklist; NO Dynatrace resources or API connections are created.

## Integration prerequisites
- Confirm Dynatrace tenant URL, environment permissions and API ingestion method.
- Confirm whether Kafka is **Confluent Cloud** or self-managed; metrics endpoints and coverage differ.
- Obtain a least-privilege Dynatrace API token through approved secret management.
- For Confluent Cloud, assess the Metrics API and integration/extension support for the
  chosen Kafka cluster type. Verify endpoint, metrics, limits, API-key scopes and costs.
- Decide whether ingestion is via Dynatrace-supported extension, OpenTelemetry collector,
  or a scheduled exporter. Do not assume all Kafka broker internals are exposed in Confluent Cloud.
- Never store token values in Git, YAML, Terraform variables, logs, or dashboards.

## Proposed dashboard sections
1. Cluster health and availability: Kafka cluster status, request errors, throughput.
2. Consumer health: consumer lag (per group/topic), stalled consumers, rebalance spikes.
3. Producer health: produce errors, retry rates, request latency.
4. Data flow: bytes/messages in and out, topic growth, connector task failures.
5. Operations: service account auth failures, quota/throttling and cost trends (where available).

## Proposed alerts (thresholds are placeholders pending baseline)
- Sustained consumer lag above an agreed per-workload SLO.
- Failed Kafka Connect tasks / connectors not running.
- Authentication/authorization failure rate spike.
- Ingestion or egress drops inconsistent with expected traffic.
- Unexpected Confluent Cloud usage/cost spike.
- Pipeline failures and unauthorized deployment attempts.

For each alert define: metric source, exact query, baseline, evaluation window,
severity, on-call owner, notification destination, and remediation runbook.
Do not enable alerts until metric names and units are verified in the tenant.

## Validation and handover
- Test telemetry with a non-production sample and verify metric timestamps.
- Confirm dashboards distinguish DEV, TEST and PROD with environment tags.
- Simulate a benign alert and verify notification routing.
- Record API token rotation, ownership, access audit and integration costs.
