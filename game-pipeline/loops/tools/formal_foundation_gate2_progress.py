#!/usr/bin/env python3
"""Apply reviewed GATE-2 successor inputs to the append-only Loop Registry."""

from __future__ import annotations

import argparse
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
REGISTRY_DIR = PROJECT_ROOT / "game-pipeline/loops/registry/formal-foundation-gate2"
SNAPSHOT_PATH = REGISTRY_DIR / "snapshot.yaml"
HISTORY_PATH = REGISTRY_DIR / "event-history.yaml"
SUCCESSOR_PATH = PROJECT_ROOT / "docs/architecture/gate1-to-formal-migration-successor-v2.yaml"
TECH_REVIEW_PATH = PROJECT_ROOT / "evidence/gate2/headquarters-buffer-successor-technical-approval-v3.md"
QA_REVIEW_PATH = PROJECT_ROOT / "evidence/gate2/headquarters-buffer-successor-independent-qa-approval-v3.md"
REMEDIATION_PATH = PROJECT_ROOT / "evidence/gate2/headquarters-buffer-successor-channel-mapping-remediation-v2.md"

LOOP_ID = "83c995ff-37b9-4df8-9e84-8417d6632187"
INPUT_SLOT_ID = "INPUT-RULES-001"
PM_ACTOR = {
    "actor_id": "inst:01M02M6X3Q8YWJXHY52K3V5AR2",
    "role": "pos:veilfront-xiangqi-siege:root:project-manager",
    "authority_id": "AUTH-VEILFRONT-PROJECT-MANAGER",
}


def load_yaml(path: Path) -> Any:
    return yaml.safe_load(path.read_text(encoding="utf-8"))


def file_sha(path: Path) -> str:
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


def require_reviewed_successor() -> tuple[str, dict[str, Any]]:
    for path in (SUCCESSOR_PATH, TECH_REVIEW_PATH, QA_REVIEW_PATH, REMEDIATION_PATH):
        if not path.is_file():
            raise RuntimeError(f"required reviewed successor artifact missing: {path}")
    successor = load_yaml(SUCCESSOR_PATH)
    mapping = successor["formal_migration_delta"]["channel_mapping"]
    if mapping["state"]["formal_contract"] != "full_state":
        raise RuntimeError("successor state mapping mismatch")
    if mapping["event"]["formal_contract"] != "domain_event":
        raise RuntimeError("successor event mapping mismatch")
    if mapping["replay"]["formal_contracts"] != ["authoritative_replay", "observer_replay"]:
        raise RuntimeError("successor replay mapping mismatch")
    if successor["formal_migration_delta"]["full_equivalence_rerun_required"] is not True:
        raise RuntimeError("successor must retain full equivalence rerun")
    return file_sha(SUCCESSOR_PATH), successor


def bind_rules_successor() -> None:
    successor_sha, _successor = require_reviewed_successor()
    snapshot_doc = load_yaml(SNAPSHOT_PATH)
    history_doc = load_yaml(HISTORY_PATH)
    history = history_doc.get("event_history", [])
    snapshot = snapshot_doc["registry_snapshot"]
    if not isinstance(history, list) or not history:
        raise RuntimeError("event history must be a non-empty list")
    if snapshot["identity"]["loop_instance_id"] != LOOP_ID:
        raise RuntimeError("loop identity mismatch")
    if snapshot["runtime"]["current_state"] != "active":
        raise RuntimeError("rules successor can only be rebound while loop is active")
    last_event = history[-1]
    runtime = snapshot["runtime"]
    if runtime["last_event_digest"] != last_event["integrity"]["event_digest"]:
        raise RuntimeError("snapshot/history last digest mismatch")
    if runtime["last_event_sequence"] != last_event["sequence"]:
        raise RuntimeError("snapshot/history sequence mismatch")

    inputs = snapshot["resources"]["inputs"]
    slot_index = next(
        (index for index, item in enumerate(inputs) if item["input_slot_id"] == INPUT_SLOT_ID),
        None,
    )
    if slot_index is None:
        raise RuntimeError(f"missing input slot: {INPUT_SLOT_ID}")
    before = copy.deepcopy(inputs[slot_index])
    if before["artifact"]["digest"]["value"] == successor_sha:
        print(f"ALREADY_BOUND {INPUT_SLOT_ID} {successor_sha}")
        return

    occurred_at = now_china()
    event_id = str(uuid.uuid4())
    after = {
        "input_slot_id": INPUT_SLOT_ID,
        "artifact": {
            "artifact_id": "artifact:veilfront-xiangqi-siege:gate1-behavior-baseline@headquarters-staging-successor-v2",
            "artifact_type": "gate1-behavior-baseline-successor",
            "version": "owner-rule-revision-5-headquarters-staging-successor-v2",
            "uri": "docs/architecture/gate1-to-formal-migration-successor-v2.yaml",
            "digest": {"algorithm": "sha256", "value": successor_sha},
            "manifest_paths": [
                "docs/prototype/rules-spec-v1.md",
                "docs/prototype/settlement-order-v1.md",
                "docs/prototype/information-boundary-v1.md",
                "docs/prototype/rules-test-coverage-matrix-v1.md",
                "evidence/gate2/headquarters-buffer-staging-remediation-v1.md",
                "evidence/gate2/headquarters-buffer-successor-technical-approval-v3.md",
                "evidence/gate2/headquarters-buffer-successor-independent-qa-approval-v3.md",
            ],
        },
        "source_loop_id": None,
        "bound_by_event_id": event_id,
        "bound_at": occurred_at,
    }
    expected_revision = int(runtime["record_revision"])
    event = {
        "schema_version": "0.1",
        "event_id": event_id,
        "mutation_id": str(uuid.uuid4()),
        "loop_instance_id": LOOP_ID,
        "sequence": int(runtime["last_event_sequence"]) + 1,
        "event_type": "core.input_bound",
        "occurred_at": occurred_at,
        "recorded_at": occurred_at,
        "actor": PM_ACTOR,
        "causality": {
            "correlation_id": str(uuid.uuid4()),
            "causation_event_id": last_event["event_id"],
            "request_id": "bind-reviewed-headquarters-buffer-successor-v2",
        },
        "concurrency": {
            "expected_record_revision": expected_revision,
            "resulting_record_revision": expected_revision + 1,
        },
        "binding_snapshot": {
            "contract_digest": snapshot["contract_binding"]["contract_digest"],
            "state_machine_digest": snapshot["state_machine_binding"]["state_machine_digest"],
        },
        "payload": {"input_slot_id": INPUT_SLOT_ID, "before": before, "after": after},
        "evidence_refs": [
            "docs/architecture/gate1-to-formal-migration-successor-v2.yaml",
            f"evidence/gate2/headquarters-buffer-successor-technical-approval-v3.md@sha256:{file_sha(TECH_REVIEW_PATH)}",
            f"evidence/gate2/headquarters-buffer-successor-independent-qa-approval-v3.md@sha256:{file_sha(QA_REVIEW_PATH)}",
        ],
        "integrity": {
            "canonicalization": "registry-event-canonical-json-v1",
            "digest_algorithm": "sha256",
            "previous_event_digest": last_event["integrity"]["event_digest"],
            "event_digest": None,
        },
    }
    event["integrity"]["event_digest"] = event_digest(event)
    history.append(event)
    inputs[slot_index] = after
    runtime.update({
        "last_event_id": event_id,
        "last_event_digest": event["integrity"]["event_digest"],
        "last_event_sequence": event["sequence"],
        "record_revision": expected_revision + 1,
    })
    history_doc["event_history"] = history
    _write_pair(snapshot_doc, history_doc)
    print(f"BOUND {INPUT_SLOT_ID} {successor_sha} event={event_id} sequence={event['sequence']}")


def _write_pair(snapshot_doc: dict[str, Any], history_doc: dict[str, Any]) -> None:
    snapshot_bytes = yaml.safe_dump(
        snapshot_doc, allow_unicode=True, sort_keys=False, width=120
    ).encode("utf-8")
    history_bytes = yaml.safe_dump(
        history_doc, allow_unicode=True, sort_keys=False, width=120
    ).encode("utf-8")
    temp_paths: list[Path] = []
    try:
        for target, payload in ((SNAPSHOT_PATH, snapshot_bytes), (HISTORY_PATH, history_bytes)):
            handle, name = tempfile.mkstemp(prefix=f".{target.name}.", dir=REGISTRY_DIR)
            with os.fdopen(handle, "wb") as stream:
                stream.write(payload)
                stream.flush()
                os.fsync(stream.fileno())
            temp_paths.append(Path(name))
        os.replace(temp_paths[1], HISTORY_PATH)
        os.replace(temp_paths[0], SNAPSHOT_PATH)
    finally:
        for path in temp_paths:
            if path.exists():
                path.unlink()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["bind-rules-successor"])
    args = parser.parse_args()
    if args.command == "bind-rules-successor":
        bind_rules_successor()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
