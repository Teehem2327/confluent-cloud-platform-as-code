#!/usr/bin/env python3
"""Read-only CI and Terraform safety checks. Never invokes Terraform Apply."""
from pathlib import Path
import sys

root = Path(__file__).resolve().parents[1]
errors = []
for env in ("dev", "test", "prod"):
    folder = root / "environments" / env
    for name in ("backend.tf", "main.tf", "providers.tf", "variables.tf"):
        if not (folder / name).is_file():
            errors.append(f"Missing {folder / name}")
    backend = (folder / "backend.tf")
    if backend.exists():
        text = backend.read_text(encoding="utf-8")
        expected = ("platform" if root.name == "confluent-platform" else "applications") + f"-{env}.tfstate"
        if expected not in text:
            errors.append(f"Backend key mismatch in {backend}; expected {expected}")
for pipeline in (root / "pipelines").glob("*.yml"):
    content = pipeline.read_text(encoding="utf-8")
    # Comments are excluded; catch active shell calls in inline scripts.
    for line_no, line in enumerate(content.splitlines(), 1):
        if line.lstrip().startswith("#"):
            continue
        import re
        if re.search(r"\bterraform\s+(?:-chdir=\S+\s+)?(?:apply|destroy)\b", line):
            errors.append(f"Apply/destroy command in {pipeline}:{line_no}")
print(f"Checking {root.name}:")
if errors:
    for error in errors:
        print("ERROR:", error)
    sys.exit(1)
print("PASS: environment roots/state keys present; no Terraform Apply/Destroy commands in pipeline YAML.")
