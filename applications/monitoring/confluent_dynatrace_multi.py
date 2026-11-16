
import base64
import json
import logging
import os
import random
import re
import sys
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

from azure.identity import AzureCliCredential
from azure.keyvault.secrets import SecretClient

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s"
)
logging.getLogger("azure").setLevel(logging.WARNING)
logging.getLogger("azure.identity").setLevel(logging.WARNING)
logging.getLogger("azure.core.pipeline.policies.http_logging_policy").setLevel(logging.WARNING)
log = logging.getLogger("kafka-monitor")

BASE_DIR = Path(__file__).resolve().parent
CONFIG_FILE = BASE_DIR / "collector-config.json"
CHECKPOINT_FILE = BASE_DIR / "collector-checkpoints.json"

KEY_VAULT_URL = "https://kv-confluent-example.vault.azure.net/"
DYNATRACE_URL = (
    "https://abc12345.live.dynatrace.com/api/v2/metrics/ingest"
)

MAX_RETRIES = 3
BASE_RETRY_DELAY = 2
MAX_RETRY_DELAY = 30
RECOVERY_WINDOW_MINUTES = 15
MAX_RECOVERY_HOURS = 24
METRIC_DELAY_MINUTES = 2


def post(url, body, headers):
    for attempt in range(MAX_RETRIES + 1):
        request = Request(
            url,
            data=body,
            headers=headers,
            method="POST"
        )

        try:
            with urlopen(request, timeout=30) as response:
                return response.status, response.read().decode()

        except HTTPError as error:
            status = error.code

            if status != 429 and not 500 <= status <= 599:
                raise RuntimeError(
                    f"API returned HTTP {status}"
                ) from None

            reason = f"HTTP {status}"

        except (URLError, TimeoutError, ConnectionError, OSError):
            reason = "temporary network failure"

        if attempt >= MAX_RETRIES:
            raise RuntimeError(
                f"API request failed after "
                f"{MAX_RETRIES + 1} attempts: {reason}"
            )

        delay = min(
            MAX_RETRY_DELAY,
            BASE_RETRY_DELAY * (2 ** attempt)
        ) + random.uniform(0, 1)

        log.warning(
            "API request failed (%s); retry %s/%s in %.1fs",
            reason,
            attempt + 1,
            MAX_RETRIES,
            delay
        )

        time.sleep(delay)

    raise RuntimeError("API retry limit exceeded")


def load_checkpoints():
    if not CHECKPOINT_FILE.exists():
        return {}

    try:
        data = json.loads(
            CHECKPOINT_FILE.read_text(encoding="utf-8")
        )

        if not isinstance(data, dict):
            raise ValueError("Checkpoint must be a JSON object")

        for name, timestamp in data.items():
            if timestamp is not None and not isinstance(timestamp, str):
                raise ValueError(f"Invalid checkpoint for {name}")

        return data

    except (json.JSONDecodeError, ValueError) as error:
        raise RuntimeError(
            f"Invalid checkpoint file: {error}"
        ) from error


def save_checkpoints(checkpoints):
    temporary_file = CHECKPOINT_FILE.with_suffix(".json.tmp")

    temporary_file.write_text(
        json.dumps(checkpoints, indent=2),
        encoding="utf-8"
    )

    os.replace(temporary_file, CHECKPOINT_FILE)


def load_keyvault_credentials():
    log.info("Authenticating with Azure Key Vault")

    credential = AzureCliCredential()

    client = SecretClient(
        vault_url=KEY_VAULT_URL,
        credential=credential
    )

    secret_names = {
        "confluent_key": "dev-monitoring-confluent-api-key",
        "confluent_secret": "dev-monitoring-confluent-api-secret",
        "dynatrace_token": "dynatrace-metrics-api-token"
    }

    credentials = {}

    for field, secret_name in secret_names.items():
        value = client.get_secret(secret_name).value

        if not value:
            raise RuntimeError(
                f"Azure Key Vault secret is empty: {secret_name}"
            )

        credentials[field] = value

        log.info(
            "Key Vault credential loaded: %s",
            secret_name
        )

    log.info("Azure Key Vault credentials loaded successfully")

    return credentials


def parse_timestamp(value):
    timestamp = datetime.fromisoformat(value.replace("Z", "+00:00"))
    if timestamp.tzinfo is None:
        raise ValueError("Metric timestamp must contain a timezone")
    return timestamp.astimezone(timezone.utc)


LEGACY_METRIC_SPEC = {
    "name": "received_bytes",
    "metric": "io.confluent.kafka.server/received_bytes",
    "dynatrace_key": "custom.confluent.dev.received_bytes",
    "agg": "SUM",
    "group_by": {},
}
DYNATRACE_KEY_PATTERN = re.compile(r"^[A-Za-z_][A-Za-z0-9_.-]*$")


def metric_specs(config):
    """Metrics to collect. Falls back to the original single metric."""
    specs = config.get("metrics")
    if not specs:
        legacy = dict(LEGACY_METRIC_SPEC)
        legacy["metric"] = config.get("metric", legacy["metric"])
        return [legacy]
    names = set()
    for spec in specs:
        for field in ("name", "metric", "dynatrace_key"):
            if not spec.get(field):
                raise ValueError(f"Metric entry is missing '{field}'")
        if not DYNATRACE_KEY_PATTERN.match(spec["dynatrace_key"]):
            raise ValueError(f"Invalid Dynatrace metric key: {spec['dynatrace_key']}")
        if spec["name"] in names:
            raise ValueError(f"Duplicate metric name: {spec['name']}")
        names.add(spec["name"])
    return specs


def checkpoint_key(env_name, spec):
    """received_bytes keeps the plain environment key so existing checkpoints stay valid."""
    if spec["name"] == "received_bytes":
        return env_name
    return f"{env_name}:{spec['name']}"


def metric_windows(checkpoint, now=None, lookback_minutes=20):
    """Return bounded chronological windows; retain overlap for late samples."""
    now = now or datetime.now(timezone.utc)
    end = now.replace(second=0, microsecond=0) - timedelta(minutes=METRIC_DELAY_MINUTES)
    earliest = end - timedelta(hours=MAX_RECOVERY_HOURS)
    if checkpoint:
        start = max(earliest, parse_timestamp(checkpoint) - timedelta(minutes=2))
    else:
        start = max(earliest, end - timedelta(minutes=lookback_minutes))
    if start >= end:
        return []
    windows = []
    while start < end:
        next_end = min(start + timedelta(minutes=RECOVERY_WINDOW_MINUTES), end)
        windows.append((start, next_end))
        start = next_end
    return windows


def fresh_samples(samples, checkpoint):
    """Keep only unseen timestamps, sorted and deduplicated."""
    seen = {}
    cutoff = parse_timestamp(checkpoint) if checkpoint else None
    for sample in samples:
        timestamp = parse_timestamp(sample["timestamp"])
        if cutoff is None or timestamp > cutoff:
            labels = tuple(sorted(
                (key, str(value)) for key, value in sample.items()
                if key.startswith(("metric.", "resource."))
            ))
            seen[(timestamp, labels)] = sample
    return [seen[key] for key in sorted(seen)]


def query_metrics(env, config, credentials, start=None, end=None):
    if start is None or end is None:
        end = datetime.now(timezone.utc).replace(second=0, microsecond=0) - timedelta(minutes=METRIC_DELAY_MINUTES)
        start = end - timedelta(minutes=20)

    fmt = "%Y-%m-%dT%H:%M:%SZ"

    aggregation = {"metric": config["metric"]}
    aggregation_type = config.get("agg", "SUM")
    if aggregation_type:
        aggregation["agg"] = aggregation_type

    payload = {
        "aggregations": [aggregation],
        "filter": {
            "field": "resource.kafka.id",
            "op": "EQ",
            "value": env["cluster_id"]
        },
        "granularity": "PT1M",
        "intervals": [
            f"{start.strftime(fmt)}/{end.strftime(fmt)}"
        ],
        "limit": 1000
    }
    if config.get("group_by"):
        payload["group_by"] = list(config["group_by"])

    auth = base64.b64encode(
        (
            f"{credentials['confluent_key']}:"
            f"{credentials['confluent_secret']}"
        ).encode()
    ).decode()

    status, response = post(
        config["confluent_metrics_url"],
        json.dumps(payload).encode(),
        {
            "Authorization": f"Basic {auth}",
            "Content-Type": "application/json"
        }
    )

    result = json.loads(response)
    samples = result.get("data", [])

    if not isinstance(samples, list):
        raise ValueError("Invalid Metrics API response")

    if result.get("meta", {}).get("pagination", {}).get("next"):
        raise RuntimeError("Metrics response was paginated; refusing to advance checkpoint")
    if len(samples) >= payload["limit"]:
        raise RuntimeError("Metrics response reached query limit; refusing to advance checkpoint")
    return status, sorted(samples, key=lambda sample: parse_timestamp(sample["timestamp"]))


def escape_dimension(value):
    """Escape characters that are special in the Dynatrace line protocol."""
    return re.sub(r'([\\,= "])', r"\\\1", str(value))


def send_to_dynatrace(env, samples, credentials, spec=None):
    spec = spec or LEGACY_METRIC_SPEC
    lines = []

    for sample in samples:
        timestamp = datetime.fromisoformat(
            sample["timestamp"].replace("Z", "+00:00")
        )

        timestamp_ms = int(timestamp.timestamp() * 1000)

        dimensions = [
            f"environment={escape_dimension(env['name'])}",
            f"cluster={escape_dimension(env['cluster_name'])}",
        ]
        for label, dimension in spec.get("group_by", {}).items():
            if sample.get(label) is not None:
                dimensions.append(
                    f"{dimension}={escape_dimension(sample[label])}"
                )

        lines.append(
            f"{spec['dynatrace_key']},"
            f"{','.join(dimensions)} "
            f"gauge,{sample['value']} {timestamp_ms}"
        )

    status, response = post(
        DYNATRACE_URL,
        "\n".join(lines).encode(),
        {
            "Authorization": (
                f"Api-Token {credentials['dynatrace_token']}"
            ),
            "Content-Type": "text/plain"
        }
    )

    if status != 202:
        raise RuntimeError(
            f"Unexpected Dynatrace HTTP {status}"
        )

    result = json.loads(response)

    if (
        result.get("linesInvalid", 0) != 0
        or result.get("linesOk") != len(lines)
    ):
        raise RuntimeError(
            "Dynatrace rejected one or more metric samples"
        )

    return status


def poll_environment(env, specs, config, credentials, last_sent, errors=None):
    """Poll every configured metric once; a failing metric never blocks the others."""
    for spec in specs:
        key = checkpoint_key(env["name"], spec)
        try:
            windows = metric_windows(
                last_sent.get(key),
                lookback_minutes=int(config.get("lookback_minutes", 20)),
            )
            metric_config = dict(
                config,
                metric=spec["metric"],
                agg=spec.get("agg", "SUM"),
                group_by=spec.get("group_by", {}),
            )
            for start, end in windows:
                status, samples = query_metrics(
                    env, metric_config, credentials, start, end
                )
                fresh = fresh_samples(samples, last_sent.get(key))
                if not fresh:
                    continue
                dt_status = send_to_dynatrace(env, fresh, credentials, spec)
                updated = dict(last_sent)
                updated[key] = fresh[-1]["timestamp"]
                save_checkpoints(updated)
                last_sent = updated
                log.info(
                    "%s/%s: forwarded %s sample(s); Dynatrace HTTP %s; latest %s",
                    env["name"], spec["name"], len(fresh), dt_status, last_sent[key]
                )
            if not windows:
                log.info("%s/%s: no query window currently available",
                         env["name"], spec["name"])
        except (RuntimeError, ValueError, KeyError, TypeError, OSError,
                json.JSONDecodeError) as error:
            log.error("%s/%s: %s", env["name"], spec["name"], error)
            if errors is not None:
                errors.append(f'{env["name"]}/{spec["name"]}')
    return last_sent


def main():
    config = json.loads(
        CONFIG_FILE.read_text(encoding="utf-8")
    )

    environments = [
        env for env in config["environments"]
        if env["enabled"]
    ]

    if not environments:
        raise ValueError("No monitoring environments enabled")

    # One read-only metrics credential is used for every enabled environment.
    # Each query is filtered by the environment's cluster_id, and every sample
    # carries environment= and cluster= dimensions.
    for env in environments:
        if not str(env.get("cluster_id", "")).strip():
            raise ValueError(
                f"Environment {env['name']} is enabled without a cluster_id"
            )

    specs = metric_specs(config)
    credentials = load_keyvault_credentials()
    run_once = "--once" in sys.argv[1:]
    # --once is stateless: it ignores saved checkpoints and relies on lookback_minutes.
    # Re-sent samples carry identical timestamps, so Dynatrace overwrites them.
    last_sent = {} if run_once else load_checkpoints()

    for env in environments:
        for spec in specs:
            last_sent.setdefault(checkpoint_key(env["name"], spec), None)

    if run_once:
        errors = []
        for env in environments:
            last_sent = poll_environment(
                env, specs, config, credentials, last_sent, errors
            )
        if errors:
            log.error("Run failed for: %s", ", ".join(errors))
            raise SystemExit(1)
        log.info("Run-once collection finished")
        return

    interval = max(
        60,
        int(config["poll_interval_seconds"])
    )

    log.info(
        "Starting collector: %s; metrics: %s; poll interval %ss",
        ", ".join(env["name"] for env in environments),
        ", ".join(spec["name"] for spec in specs),
        interval
    )

    while True:
        for env in environments:
            last_sent = poll_environment(
                env, specs, config, credentials, last_sent
            )
        time.sleep(interval)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        log.info("Collector stopped")
    except Exception as error:
        log.error(
            "Collector startup failed: %s",
            type(error).__name__
        )
        raise SystemExit(1)
