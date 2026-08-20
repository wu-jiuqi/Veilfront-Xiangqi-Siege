#!/usr/bin/env python3
"""Pause the active 3D-bound GATE-2 loop after the owner switches the current target to 2D."""

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
IMPACT_PATH = PROJECT_ROOT / "game-pipeline/loops/evidence/GATE2-current-2d-direction-change-impact-v1.md"
BRIEF_PATH = PROJECT_ROOT / "game-pipeline/project-definition/project-brief.yaml"
CONTRACT_V3_PATH = PROJECT_ROOT / "game-pipeline/loops/contracts/loop-contract-formal-foundation-gate2-v3.yaml"

LOOP_ID = "83c995ff-37b9-4df8-9e84-8417d6632187"
CONTRACT_ID = "LOOP-CTR-FORMAL-FOUNDATION-GATE2-001"
CONTRACT_VERSION = 2
CONTRACT_DIGEST = "bf2d09e7117960de4b178d827dc2c123ab4b83777175e5b1b0c9cca6eabe561d"
STATE_MACHINE_DIGEST = "810f414928b370a869b3a36a17cb504f290d17fa07c9ce5db9001136bfdb160c"
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


def event_digest(event: dict[str, Any]) -> str:
    normalized = copy.deepcopy(event)
    normalized["integrity"]["event_digest"] = None
    return canonical_digest(normalized)


def now_china() -> str:
    return datetime.now(timezone(timedelta(hours=8))).isoformat(timespec="microseconds")


def write_pair(snapshot_doc: dict[str, Any], history_doc: dict[str, Any]) -> None:
    snapshot_bytes = yaml.safe_dump(snapshot_doc, allow_unicode=True, sort_keys=False, width=120).encode("utf-8")
    history_bytes = yaml.safe_dump(history_doc, allow_unicode=True, sort_keys=False, width=120).encode("utf-8")
    temporary_paths: list[Path] = []
    try:
        for target, payload in ((HISTORY_PATH, history_bytes), (SNAPSHOT_PATH, snapshot_bytes)):
            handle, name = tempfile.mkstemp(prefix=f".{target.name}.", dir=REGISTRY_DIR)
            with os.fdopen(handle, "wb") as stream:
                stream.write(payload)
                stream.flush()
                os.fsync(stream.fileno())
            temporary_paths.append(Path(name))
        os.replace(temporary_paths[0], HISTORY_PATH)
        os.replace(temporary_paths[1], SNAPSHOT_PATH)
    finally:
        for path in temporary_paths:
            if path.exists():
                path.unlink()


def main() -> int:
    snapshot_doc = load_yaml(SNAPSHOT_PATH)
    history_doc = load_yaml(HISTORY_PATH)
    snapshot = snapshot_doc["registry_snapshot"]
    history = history_doc["event_history"]
    runtime = snapshot["runtime"]

    if snapshot["identity"]["loop_instance_id"] != LOOP_ID:
        raise RuntimeError("loop identity mismatch")
    if snapshot["contract_binding"] != {
        "contract_id": CONTRACT_ID,
        "contract_version": CONTRACT_VERSION,
        "contract_digest": CONTRACT_DIGEST,
    }:
        raise RuntimeError("contract binding mismatch")
    if runtime["current_state"] == "waiting_approval" and snapshot.get("interruption"):
        raise RuntimeError("direction-change interruption is already active")
    if runtime["current_state"] != "active" or runtime["current_iteration"] != 3:
        raise RuntimeError("direction change interruption requires active iteration 3")
    if runtime["record_revision"] != 40 or runtime["last_event_sequence"] != 40:
        raise RuntimeError("unexpected registry revision")
    if runtime["last_event_digest"] != history[-1]["integrity"]["event_digest"]:
        raise RuntimeError("snapshot/history tail mismatch")

    occurred_at = now_china()
    sequence = runtime["last_event_sequence"] + 1
    event_id = str(uuid.uuid4())
    interruption_id = str(uuid.uuid4())
    evidence_refs = [
        "game-pipeline/loops/evidence/GATE2-current-2d-direction-change-impact-v1.md",
        "game-pipeline/project-definition/project-brief.yaml",
        "game-pipeline/loops/contracts/loop-contract-formal-foundation-gate2-v3.yaml",
        "codex-thread://current#owner-current-implementation-2d-late-3d-option",
    ]
    entry_snapshot = {
        "contract_id": CONTRACT_ID,
        "contract_version": CONTRACT_VERSION,
        "contract_digest": CONTRACT_DIGEST,
        "input_set_digest": canonical_digest(snapshot["resources"]["inputs"]),
        "dependency_set_digest": canonical_digest(snapshot["topology"]["dependencies"]),
        "authority_set_digest": canonical_digest(snapshot["responsibility"]),
        "budget_usage_digest": canonical_digest(snapshot["budget"]["usage"]),
    }
    interruption = {
        "interruption_id": interruption_id,
        "current_interruption_state": "waiting_approval",
        "resume_state": "active",
        "first_entered_from_state": "active",
        "first_entered_at": occurred_at,
        "current_reason": {
            "reason_code": "owner_direction_change_requires_brief_and_contract_reapproval",
            "description": "项目所有者将现阶段正式实现由三维三渲二改为二维；旧 Contract v2 不再适合作为当前生产目标，须先确认 Project Brief v7，再单独批准并迁移 Contract v3。",
            "responsible_role": "project-owner",
            "evidence_refs": evidence_refs,
        },
        "entry_snapshot": entry_snapshot,
        "latest_revalidation": None,
    }
    event = {
        "schema_version": "0.1",
        "event_id": event_id,
        "mutation_id": str(uuid.uuid4()),
        "loop_instance_id": LOOP_ID,
        "sequence": sequence,
        "event_type": "core.interruption_entered",
        "occurred_at": occurred_at,
        "recorded_at": occurred_at,
        "actor": PM_ACTOR,
        "causality": {
            "correlation_id": str(uuid.uuid4()),
            "causation_event_id": history[-1]["event_id"],
            "request_id": "owner-current-2d-direction-change",
        },
        "concurrency": {
            "expected_record_revision": runtime["record_revision"],
            "resulting_record_revision": runtime["record_revision"] + 1,
        },
        "binding_snapshot": {
            "contract_digest": CONTRACT_DIGEST,
            "state_machine_digest": STATE_MACHINE_DIGEST,
        },
        "payload": {
            "transition_id": "TR-OPERATIONAL-INTERRUPTED",
            "from_state": "active",
            "to_state": "waiting_approval",
            "iteration": {"before": 3, "after": 3},
            "interruption": interruption,
        },
        "evidence_refs": evidence_refs,
        "integrity": {
            "canonicalization": "registry-event-canonical-json-v1",
            "digest_algorithm": "sha256",
            "previous_event_digest": history[-1]["integrity"]["event_digest"],
            "event_digest": None,
        },
    }
    event["integrity"]["event_digest"] = event_digest(event)
    history.append(event)
    snapshot["interruption"] = interruption
    runtime.update(
        {
            "current_state": "waiting_approval",
            "state_entered_at": occurred_at,
            "last_transition_id": "TR-OPERATIONAL-INTERRUPTED",
            "last_event_id": event_id,
            "last_event_digest": event["integrity"]["event_digest"],
            "last_event_sequence": sequence,
            "record_revision": runtime["record_revision"] + 1,
        }
    )
    history_doc["event_history"] = history
    write_pair(snapshot_doc, history_doc)
    print(
        json.dumps(
            {
                "result": "current_3d_loop_waiting_for_2d_direction_approval",
                "state": runtime["current_state"],
                "iteration": runtime["current_iteration"],
                "sequence": runtime["last_event_sequence"],
                "record_revision": runtime["record_revision"],
                "interruption_id": interruption_id,
            },
            ensure_ascii=False,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
