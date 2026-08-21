#!/usr/bin/env python3
"""Bind the owner-approved formal LAN scope exception to the active GATE-2 loop."""

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
REGISTRY_DIR = PROJECT_ROOT / "game-pipeline/loops/registry/formal-foundation-gate2"
SNAPSHOT_PATH = REGISTRY_DIR / "snapshot.yaml"
HISTORY_PATH = REGISTRY_DIR / "event-history.yaml"
DECISION_PATH = PROJECT_ROOT / "game-pipeline/loops/evidence/FORMAL-LAN-ASSEMBLY-OWNER-EXCEPTION-decision-package-v1.yaml"
APPROVAL_PATH = PROJECT_ROOT / "game-pipeline/approvals/production-scope-exception-formal-lan-assembly-9e65df07d193.yaml"
LOOP_ID = "83c995ff-37b9-4df8-9e84-8417d6632187"
CONTRACT_DIGEST = "9ea1fbab25b1a560b83896194099bd9b0131552d7321223622161615c1a2a205"
STATE_MACHINE_DIGEST = "810f414928b370a869b3a36a17cb504f290d17fa07c9ce5db9001136bfdb160c"
SUBJECT_DIGEST = "9e65df07d19398a083e8d024336180e37d5fc1fd998829cafc7559e7c04031b1"
RECORD_ID = "OWNER-SCOPE-EXCEPTION-FORMAL-LAN-001"
PM_ACTOR = {
    "actor_id": "inst:01M02M6X3Q8YWJXHY52K3V5AR2",
    "role": "pos:veilfront-xiangqi-siege:root:project-manager",
    "authority_id": "AUTH-VEILFRONT-PROJECT-MANAGER",
}


def load_yaml(path: Path) -> Any:
    return yaml.safe_load(path.read_text(encoding="utf-8"))


def canonical_digest(value: Any) -> str:
    payload = json.dumps(
        value,
        ensure_ascii=False,
        allow_nan=False,
        separators=(",", ":"),
        sort_keys=True,
    ).encode("utf-8")
    return hashlib.sha256(payload).hexdigest()


def sha256_file(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def event_digest(event: dict[str, Any]) -> str:
    normalized = copy.deepcopy(event)
    normalized["integrity"]["event_digest"] = None
    return canonical_digest(normalized)


def now_china() -> str:
    return datetime.now(timezone(timedelta(hours=8))).isoformat(timespec="microseconds")


def add_event(
    history: list[dict[str, Any]],
    event_type: str,
    payload: dict[str, Any],
    evidence_refs: list[str],
    correlation_id: str,
    request_id: str,
    occurred_at: str,
) -> dict[str, Any]:
    previous = history[-1]
    sequence = len(history) + 1
    event = {
        "schema_version": "0.1",
        "event_id": str(uuid.uuid4()),
        "mutation_id": str(uuid.uuid4()),
        "loop_instance_id": LOOP_ID,
        "sequence": sequence,
        "event_type": event_type,
        "occurred_at": occurred_at,
        "recorded_at": occurred_at,
        "actor": PM_ACTOR,
        "causality": {
            "correlation_id": correlation_id,
            "causation_event_id": previous["event_id"],
            "request_id": request_id,
        },
        "concurrency": {
            "expected_record_revision": sequence - 1,
            "resulting_record_revision": sequence,
        },
        "binding_snapshot": {
            "contract_digest": CONTRACT_DIGEST,
            "state_machine_digest": STATE_MACHINE_DIGEST,
        },
        "payload": payload,
        "evidence_refs": evidence_refs,
        "integrity": {
            "canonicalization": "registry-event-canonical-json-v1",
            "digest_algorithm": "sha256",
            "previous_event_digest": previous["integrity"]["event_digest"],
            "event_digest": None,
        },
    }
    event["integrity"]["event_digest"] = event_digest(event)
    history.append(event)
    return event


def write_pair(snapshot_doc: dict[str, Any], history_doc: dict[str, Any]) -> None:
    snapshot_bytes = yaml.safe_dump(snapshot_doc, allow_unicode=True, sort_keys=False, width=120).encode("utf-8")
    history_bytes = yaml.safe_dump(history_doc, allow_unicode=True, sort_keys=False, width=120).encode("utf-8")
    temp_paths: list[Path] = []
    try:
        for target, payload in ((HISTORY_PATH, history_bytes), (SNAPSHOT_PATH, snapshot_bytes)):
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


def append_unique(values: list[str], additions: list[str]) -> list[str]:
    return values + [value for value in additions if value not in values]


def apply() -> None:
    decision_doc = load_yaml(DECISION_PATH)
    approval_doc = load_yaml(APPROVAL_PATH)["approval"]
    actual_subject_digest = canonical_digest(decision_doc["exception_subject"])
    if actual_subject_digest != SUBJECT_DIGEST:
        raise RuntimeError("formal LAN exception subject digest mismatch")
    if approval_doc.get("subject_digest") != SUBJECT_DIGEST or approval_doc.get("decision") != "approved":
        raise RuntimeError("formal LAN approval is missing or invalid")

    snapshot_doc = load_yaml(SNAPSHOT_PATH)
    history_doc = load_yaml(HISTORY_PATH)
    snapshot = snapshot_doc["registry_snapshot"]
    history = history_doc["event_history"]
    runtime = snapshot["runtime"]
    if snapshot["identity"]["loop_instance_id"] != LOOP_ID:
        raise RuntimeError("loop identity mismatch")
    if snapshot["contract_binding"]["contract_digest"] != CONTRACT_DIGEST:
        raise RuntimeError("contract digest mismatch")
    if runtime["current_state"] != "active" or runtime["current_iteration"] != 3:
        raise RuntimeError("formal LAN exception requires active iteration 3")
    if runtime["last_event_digest"] != history[-1]["integrity"]["event_digest"]:
        raise RuntimeError("snapshot/history tail mismatch")
    if any(event.get("payload", {}).get("record_id") == RECORD_ID for event in history):
        print(json.dumps({"result": "already-applied", "record_revision": len(history)}, ensure_ascii=False))
        return

    occurred_at = now_china()
    correlation_id = str(uuid.uuid4())
    evidence_refs = [
        "game-pipeline/loops/evidence/FORMAL-LAN-ASSEMBLY-OWNER-EXCEPTION-decision-package-v1.yaml",
        "game-pipeline/approvals/production-scope-exception-formal-lan-assembly-9e65df07d193.yaml",
    ]
    add_event(
        history,
        "core.acceptance_recorded",
        {
            "acceptance_kind": "owner_scope_exception",
            "record_id": RECORD_ID,
            "subject_digest": SUBJECT_DIGEST,
            "record": {
                "decision": "approved",
                "scope": "formal-lan-playable",
                "release_semantics": "formal-code-path-lan-milestone-not-release",
                "approval_id": approval_doc["approval_id"],
            },
        },
        evidence_refs,
        correlation_id,
        "record-owner-formal-lan-scope-exception",
        occurred_at,
    )

    input_binding = {
        "input_slot_id": "INPUT-FORMAL-LAN-EXCEPTION-001",
        "artifact": {
            "artifact_id": "artifact:veilfront-xiangqi-siege:formal-lan-scope-exception@v1",
            "artifact_type": "owner-approved-production-scope-exception",
            "version": "v1@subject:9e65df07d193",
            "uri": "game-pipeline/loops/evidence/FORMAL-LAN-ASSEMBLY-OWNER-EXCEPTION-decision-package-v1.yaml",
            "digest": {"algorithm": "sha256", "value": SUBJECT_DIGEST},
            "manifest_paths": evidence_refs,
        },
        "source_loop_id": None,
        "bound_by_event_id": "pending",
        "bound_at": occurred_at,
    }
    input_event = add_event(
        history,
        "core.input_bound",
        {"input_slot_id": input_binding["input_slot_id"], "before": None, "after": input_binding},
        evidence_refs,
        correlation_id,
        "bind-formal-lan-scope-exception",
        occurred_at,
    )
    input_binding["bound_by_event_id"] = input_event["event_id"]
    input_event["integrity"]["event_digest"] = event_digest(input_event)

    assignment_updates = [
        (
            "executor",
            "pos:veilfront-xiangqi-siege:technology:godot-technical-lead",
            "scope",
            ["TASK-FORMAL-LAN-APPLICATION-001", "TASK-FORMAL-LAN-NETWORK-001", "TASK-FORMAL-LAN-INTEGRATION-001"],
        ),
        (
            "executor",
            "pos:veilfront-xiangqi-siege:design-experience:systems-experience-lead",
            "scope",
            ["TASK-FORMAL-LAN-UX-001"],
        ),
        (
            "reviewer",
            "pos:veilfront-xiangqi-siege:quality:qa-release-lead",
            "review_scope",
            ["CHECK-FORMAL-LAN-UX-001", "CHECK-FORMAL-LAN-AUTHORITY-001", "CHECK-FORMAL-LAN-INFORMATION-001", "CHECK-FORMAL-LAN-REGRESSION-001"],
        ),
    ]
    for assignment_kind, role, field, additions in assignment_updates:
        collection_name = "executors" if assignment_kind == "executor" else "reviewers"
        collection = snapshot["responsibility"][collection_name]
        current = next((item for item in collection if item.get("role") == role), None)
        if current is None:
            raise RuntimeError(f"registered {assignment_kind} missing: {role}")
        before = copy.deepcopy(current)
        after = copy.deepcopy(current)
        after[field] = append_unique(list(after.get(field, [])), additions)
        add_event(
            history,
            "core.assignment_changed",
            {"assignment_kind": assignment_kind, "operation": "update", "before": before, "after": after},
            evidence_refs,
            correlation_id,
            f"extend-{assignment_kind}-{role.rsplit(':', 1)[-1]}-formal-lan",
            occurred_at,
        )
        current.clear()
        current.update(after)

    snapshot["resources"]["inputs"].append(input_binding)
    snapshot["acceptance_snapshot"]["human_gates"].append({
        "gate_id": "OWNER-SCOPE-EXCEPTION-FORMAL-LAN-001",
        "decision": "approved",
        "evidence_ref": "game-pipeline/approvals/production-scope-exception-formal-lan-assembly-9e65df07d193.yaml",
        "subject_digest": SUBJECT_DIGEST,
        "release_approval": False,
    })
    snapshot["acceptance_snapshot"]["subject_digest"] = SUBJECT_DIGEST
    runtime.update({
        "last_event_id": history[-1]["event_id"],
        "last_event_digest": history[-1]["integrity"]["event_digest"],
        "last_event_sequence": len(history),
        "record_revision": len(history),
    })
    history_doc["event_history"] = history
    write_pair(snapshot_doc, history_doc)
    print(json.dumps({
        "result": "applied",
        "events_appended": 5,
        "record_revision": len(history),
        "subject_digest": SUBJECT_DIGEST,
        "approval_sha256": sha256_file(APPROVAL_PATH),
    }, ensure_ascii=False))


if __name__ == "__main__":
    apply()
