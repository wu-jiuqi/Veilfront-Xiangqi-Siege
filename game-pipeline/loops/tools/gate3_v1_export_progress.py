#!/usr/bin/env python3
"""Register the GATE-3 export/resource-budget producer deliverable."""

from __future__ import annotations

import copy
import hashlib
import json
import os
import tempfile
import uuid
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any

import yaml


PROJECT_ROOT = Path(__file__).resolve().parents[3]
REGISTRY_DIR = PROJECT_ROOT / "game-pipeline/loops/registry/content-integration-gate3"
SNAPSHOT_PATH = REGISTRY_DIR / "snapshot.yaml"
HISTORY_PATH = REGISTRY_DIR / "event-history.yaml"
EVIDENCE_URI = "docs/architecture/windows-runtime-resource-budget-v1.md"
LOOP_ID = "e6e0f300-2130-41d0-8020-f7f4006deb3f"
DELIVERABLE_ID = "DELIVERABLE-EXPORT-G3-001"
TECH_ACTOR = {
    "actor_id": "inst:01M02NJ3JEQXKV6PT6DPX0NKQ0",
    "role": "pos:veilfront-xiangqi-siege:technology:godot-technical-lead",
    "authority_id": "AUTH-VEILFRONT-GODOT-TECHNOLOGY",
}
MANIFEST_PATHS = [
    EVIDENCE_URI,
    "export_presets.cfg",
    "tools/release/windows_runtime_manifest.json",
    "tools/release/verify_windows_runtime_budget.ps1",
    "tools/release/build_windows_runtime_candidate.ps1",
    "tools/release/verify_windows_lan_export.ps1",
    "tests/game/performance/run_match_interaction_performance_contract.gd",
]


def load_yaml(path: Path) -> Any:
    return yaml.safe_load(path.read_text(encoding="utf-8"))


def sha256_file(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def canonical_digest(value: Any) -> str:
    payload = json.dumps(
        value,
        ensure_ascii=False,
        allow_nan=False,
        separators=(",", ":"),
        sort_keys=True,
    ).encode("utf-8")
    return hashlib.sha256(payload).hexdigest()


def event_digest(event: dict[str, Any]) -> str:
    normalized = copy.deepcopy(event)
    normalized["integrity"]["event_digest"] = None
    return canonical_digest(normalized)


def now_china() -> str:
    return datetime.now(timezone(timedelta(hours=8))).isoformat(timespec="microseconds")


def write_pair(snapshot_doc: dict[str, Any], history_doc: dict[str, Any]) -> None:
    snapshot_bytes = yaml.safe_dump(
        snapshot_doc, allow_unicode=True, sort_keys=False, width=120
    ).encode("utf-8")
    history_bytes = yaml.safe_dump(
        history_doc, allow_unicode=True, sort_keys=False, width=120
    ).encode("utf-8")
    temp_paths: list[Path] = []
    try:
        for target, payload in (
            (HISTORY_PATH, history_bytes),
            (SNAPSHOT_PATH, snapshot_bytes),
        ):
            handle, name = tempfile.mkstemp(prefix=f".{target.name}.", dir=REGISTRY_DIR)
            with os.fdopen(handle, "wb") as stream:
                stream.write(payload)
                stream.flush()
                os.fsync(stream.fileno())
            temp_paths.append(Path(name))
        os.replace(temp_paths[0], HISTORY_PATH)
        os.replace(temp_paths[1], SNAPSHOT_PATH)
    finally:
        for path in temp_paths:
            if path.exists():
                path.unlink()


def main() -> None:
    snapshot_doc = load_yaml(SNAPSHOT_PATH)
    history_doc = load_yaml(HISTORY_PATH)
    snapshot = snapshot_doc["registry_snapshot"]
    history = history_doc["event_history"]
    runtime = snapshot["runtime"]
    if snapshot["identity"]["loop_instance_id"] != LOOP_ID:
        raise RuntimeError("loop identity mismatch")
    if runtime["current_state"] != "active" or runtime["current_iteration"] != 1:
        raise RuntimeError("export progress requires active GATE-3 iteration 1")
    if runtime["last_event_digest"] != history[-1]["integrity"]["event_digest"]:
        raise RuntimeError("snapshot/history tail mismatch")
    if any(
        output.get("deliverable_id") == DELIVERABLE_ID
        for output in snapshot["resources"]["outputs"]
    ):
        raise RuntimeError("GATE-3 export deliverable is already registered")
    for manifest_path in MANIFEST_PATHS:
        if not (PROJECT_ROOT / manifest_path).is_file():
            raise RuntimeError(f"deliverable manifest path missing: {manifest_path}")

    occurred_at = now_china()
    event_id = str(uuid.uuid4())
    sequence = len(history) + 1
    evidence_digest = sha256_file(PROJECT_ROOT / EVIDENCE_URI)
    output = {
        "deliverable_id": DELIVERABLE_ID,
        "artifact": {
            "artifact_id": (
                "artifact:veilfront-xiangqi-siege:"
                "filtered-windows-export-and-budget@g3-iteration1-producer-v1"
            ),
            "artifact_type": "filtered-windows-export-and-budget",
            "version": "g3-iteration1-producer-v1",
            "uri": EVIDENCE_URI,
            "digest": {"algorithm": "sha256", "value": evidence_digest},
            "manifest_paths": MANIFEST_PATHS,
        },
        "produced_in_iteration": 1,
        "lifecycle_status": "submitted",
        "registered_by_event_id": event_id,
    }
    event = {
        "schema_version": "0.1",
        "event_id": event_id,
        "mutation_id": str(uuid.uuid4()),
        "loop_instance_id": LOOP_ID,
        "sequence": sequence,
        "event_type": "core.output_registered",
        "occurred_at": occurred_at,
        "recorded_at": occurred_at,
        "actor": TECH_ACTOR,
        "causality": {
            "correlation_id": str(uuid.uuid4()),
            "causation_event_id": history[-1]["event_id"],
            "request_id": "register-gate3-export-budget-producer-deliverable",
        },
        "concurrency": {
            "expected_record_revision": runtime["record_revision"],
            "resulting_record_revision": runtime["record_revision"] + 1,
        },
        "binding_snapshot": {
            "contract_digest": snapshot["contract_binding"]["contract_digest"],
            "state_machine_digest": snapshot["state_machine_binding"]["state_machine_digest"],
        },
        "payload": {
            "deliverable_id": DELIVERABLE_ID,
            "before": None,
            "after": output,
        },
        "evidence_refs": MANIFEST_PATHS,
        "integrity": {
            "canonicalization": "registry-event-canonical-json-v1",
            "digest_algorithm": "sha256",
            "previous_event_digest": history[-1]["integrity"]["event_digest"],
            "event_digest": None,
        },
    }
    event["integrity"]["event_digest"] = event_digest(event)
    history.append(event)
    snapshot["resources"]["outputs"].append(output)
    runtime["last_event_id"] = event_id
    runtime["last_event_digest"] = event["integrity"]["event_digest"]
    runtime["last_event_sequence"] = sequence
    runtime["record_revision"] += 1
    write_pair(snapshot_doc, history_doc)
    print(
        "GATE3_EXPORT_PROGRESS_REGISTERED "
        f"sequence={sequence} revision={runtime['record_revision']} "
        f"digest={evidence_digest}"
    )


if __name__ == "__main__":
    main()
