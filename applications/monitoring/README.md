# Confluent Cloud → Dynatrace monitoring

## Scope
DEV only. TEST/PROD remain disabled. No infrastructure is provisioned by this repository CI pipeline.

## Local setup (Git Bash / Windows)
1. Log in with `az login` using an identity authorized to read the three existing secrets in Azure Key Vault `kv-confluent-example`.
2. Install dependencies: `py -m pip install -r monitoring/requirements.txt`.
3. Run tests: `py -m unittest discover -s monitoring -p "test_collector.py" -v`.
4. Start manually: `py monitoring/confluent_dynatrace_multi.py`.
5. Stop with Ctrl+C. The local checkpoint file is intentionally Git-ignored.

## Recovery and limitations
- Each poll requests 15-minute chronological windows, starting two minutes before the latest acknowledged sample, up to a maximum of 24 hours of history. Initial runs query the latest 20 minutes.
- Only samples strictly newer than the last checkpoint are forwarded; checkpoints advance only after all Dynatrace lines are accepted.
- Recovery depends on source metric retention and whether the Confluent Metrics API returns historical samples. More than 24 hours of downtime can leave a gap. A window returning no data is not proof that historical data will never arrive.
- This is **at-least-once**, not exactly-once delivery. A crash after Dynatrace accepts samples but before saving a checkpoint can produce duplicates.
- A local checkpoint must be kept on persistent storage for any future always-on deployment. Do not run multiple collector instances against the same checkpoint.
- Key Vault secrets are read at startup; restart the process after rotation. The local collector authenticates via Azure CLI; managed identity for future hosting requires a separate implementation.
- No automatic deployment, hosting, or cloud resources are configured here.

## Troubleshooting
- HTTP 401/403: check Confluent Metrics API key scope or Dynatrace token permissions; confirm Azure Key Vault access.
- HTTP 429/5xx: built-in retry with backoff.
- No new samples: produce test traffic on DEV, allow for telemetry ingestion delay, then check the Dynatrace dashboard.
- Missing checkpoint: the collector starts with a 20-minute lookback. Back up the checkpoint before changing hosts.
