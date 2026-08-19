#!/usr/bin/env python3
"""Validate the materialized formal-foundation Loop Registry history and snapshot."""

from __future__ import annotations

import importlib.util
from pathlib import Path

import yaml


PROJECT_ROOT = Path(__file__).resolve().parents[3]
PLUGIN_ROOT = Path(r"C:/Users/30114/.codex/plugins/cache/personal/game-production-pipeline/0.4.0-alpha.2")
VALIDATOR_PATH = PLUGIN_ROOT / "scripts/validate_loop_registry.py"
REGISTRY_DIR = PROJECT_ROOT / "game-pipeline/loops/registry/formal-foundation-gate2"
EVENT_CONTRACT = PLUGIN_ROOT / "contracts/loop-registry-event.template.yaml"
STATE_MACHINE = PLUGIN_ROOT / "contracts/loop-state-machine.default.yaml"


def load_module():
    spec = importlib.util.spec_from_file_location("loop_registry_validator", VALIDATOR_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError("cannot load plugin registry validator")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main() -> int:
    validator = load_module()
    snapshot = yaml.safe_load((REGISTRY_DIR / "snapshot.yaml").read_text(encoding="utf-8"))
    history = yaml.safe_load((REGISTRY_DIR / "event-history.yaml").read_text(encoding="utf-8"))
    event_contract = yaml.safe_load(EVENT_CONTRACT.read_text(encoding="utf-8"))
    state_machine = yaml.safe_load(STATE_MACHINE.read_text(encoding="utf-8"))
    errors = validator.validate_history(snapshot, history, state_machine, event_contract)
    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        return 1
    runtime = snapshot["registry_snapshot"]["runtime"]
    print(
        "FORMAL_FOUNDATION_GATE2_REGISTRY_PASS "
        f"state={runtime['current_state']} iteration={runtime['current_iteration']} "
        f"sequence={runtime['last_event_sequence']} revision={runtime['record_revision']}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
