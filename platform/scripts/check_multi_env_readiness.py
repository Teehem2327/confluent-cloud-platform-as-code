
#!/usr/bin/env python3
"""Offline, no-credential DEV/TEST/PROD architecture readiness checks."""

from pathlib import Path
import re
import sys

root = Path(__file__).resolve().parents[1]
errors = []

for env in ("dev", "test", "prod"):
    directory = root / "environments" / env

    main = (directory / "main.tf").read_text(encoding="utf-8")
    backend = (directory / "backend.tf").read_text(encoding="utf-8")
    variables = (directory / "variables.tf").read_text(encoding="utf-8")
    providers = (directory / "providers.tf").read_text(encoding="utf-8")

    if f"platform-{env}.tfstate" not in backend:
        errors.append(f"{env}: separate backend state key missing")

    if not re.search(rf'display_name\s*=\s*"{env}"', main):
        errors.append(f"{env}: expected environment name missing")

    if f'"kafka-{env}"' not in main:
        errors.append(f"{env}: expected Kafka cluster name missing")

    for name in (
        "deploy_kafka_cluster",
        "deploy_service_accounts",
        "deploy_rbac",
    ):
        match = re.search(
            r'variable\s+"' + name + r'"\s*\{([^}]+)\}',
            variables,
            re.S,
        )

        if not match or not re.search(
            r"\bdefault\s*=\s*false\b", match.group(1)
        ):
            errors.append(f"{env}: {name} must default to false")

    if (
        "cloud_api_key" not in providers
        or "cloud_api_secret" not in providers
    ):
        errors.append(f"{env}: Confluent provider credentials missing")

    if (
        "../../modules/kafka-cluster" not in main
        or "../../modules/service-accounts" not in main
    ):
        errors.append(f"{env}: shared module wiring missing")

cd = (root / "pipelines/platform-cd.yml").read_text(encoding="utf-8")

if "trigger: none" not in cd or "pr: none" not in cd:
    errors.append("CD pipeline must not trigger automatically")

if re.search(
    r"(?m)^\s*terraform\s+(?:-chdir=\S+\s+)?(?:apply|destroy)\b",
    cd,
):
    errors.append("CD pipeline contains apply/destroy")

if "confluent-${{ parameters.environment }}" not in cd:
    errors.append("Expected approval environment naming missing")

for env in ("dev", "test", "prod"):
    print(f"{env.upper()}: static architecture checks complete")

if errors:
    for issue in errors:
        print("FAIL:", issue)
    sys.exit(1)

print(
    "PASS: offline multi-environment readiness checks "
    "(no infrastructure contacted)."
)
