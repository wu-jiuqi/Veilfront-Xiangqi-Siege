#!/usr/bin/env python3
"""Bind the owner-confirmed flat wall visual amendment without rewriting history."""

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
AMENDMENT_PATH = PROJECT_ROOT / "docs/art/veilfront-wall-plane-visual-amendment-v1.md"
INVENTORY_PATH = PROJECT_ROOT / "docs/art/demo-wall-plane-asset-inventory-v1.yaml"
CONTRACT_DIGEST = "bf2d09e7117960de4b178d827dc2c123ab4b83777175e5b1b0c9cca6eabe561d"
STATE_MACHINE_DIGEST = "810f414928b370a869b3a36a17cb504f290d17fa07c9ce5db9001136bfdb160c"
LOOP_ID = "83c995ff-37b9-4df8-9e84-8417d6632187"
INPUT_SLOT_ID = "INPUT-WALL-PLANE-AMENDMENT-001"
PM_ACTOR = {
    "actor_id": "inst:01M02M6X3Q8YWJXHY52K3V5AR2",
    "role": "pos:veilfront-xiangqi-siege:root:project-manager",
    "authority_id": "AUTH-VEILFRONT-PROJECT-MANAGER",
}


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
    if snapshot["contract_binding"]["contract_digest"] != CONTRACT_DIGEST:
        raise RuntimeError("contract binding mismatch")
    if runtime["current_state"] != "active" or runtime["current_iteration"] != 3:
        raise RuntimeError("wall amendment requires active iteration 3")
    if runtime["last_event_digest"] != history[-1]["integrity"]["event_digest"]:
        raise RuntimeError("snapshot/history tail mismatch")
    if any(item["input_slot_id"] == INPUT_SLOT_ID for item in snapshot["resources"]["inputs"]):
        raise RuntimeError("wall plane amendment is already bound")

    occurred_at = now_china()
    sequence = len(history) + 1
    event_id = str(uuid.uuid4())
    amendment_digest = sha256_file(AMENDMENT_PATH)
    inventory_digest = sha256_file(INVENTORY_PATH)
    binding = {
        "input_slot_id": INPUT_SLOT_ID,
        "artifact": {
            "artifact_id": "artifact:veilfront-xiangqi-siege:wall-plane-visual-amendment@v1",
            "artifact_type": "owner-confirmed-wall-plane-visual-amendment",
            "version": "v1",
            "uri": "docs/art/veilfront-wall-plane-visual-amendment-v1.md",
            "digest": {"algorithm": "sha256", "value": amendment_digest},
            "manifest_paths": [
                "docs/art/veilfront-wall-plane-visual-amendment-v1.md",
                "docs/art/demo-wall-plane-asset-inventory-v1.yaml",
            ],
            "metadata": {
                "inventory_digest": inventory_digest,
                "supersedes_scope": "wall presentation clauses only",
                "owner_source_ref": "codex-thread://current#owner-confirm-wall-on-board-plane",
            },
        },
        "source_loop_id": None,
        "bound_by_event_id": event_id,
        "bound_at": occurred_at,
    }
    event = {
        "schema_version": "0.1",
        "event_id": event_id,
        "mutation_id": str(uuid.uuid4()),
        "loop_instance_id": LOOP_ID,
        "sequence": sequence,
        "event_type": "core.input_bound",
        "occurred_at": occurred_at,
        "recorded_at": occurred_at,
        "actor": PM_ACTOR,
        "causality": {
            "correlation_id": str(uuid.uuid4()),
            "causation_event_id": history[-1]["event_id"],
            "request_id": "bind-wall-plane-amendment-v1",
        },
        "concurrency": {
            "expected_record_revision": runtime["record_revision"],
            "resulting_record_revision": runtime["record_revision"] + 1,
        },
        "binding_snapshot": {
            "contract_digest": CONTRACT_DIGEST,
            "state_machine_digest": STATE_MACHINE_DIGEST,
        },
        "payload": {"input_slot_id": INPUT_SLOT_ID, "before": None, "after": binding},
        "evidence_refs": [
            "docs/art/veilfront-wall-plane-visual-amendment-v1.md",
            "docs/art/demo-wall-plane-asset-inventory-v1.yaml",
            "codex-thread://current#owner-confirm-wall-on-board-plane",
        ],
        "integrity": {
            "canonicalization": "registry-event-canonical-json-v1",
            "digest_algorithm": "sha256",
            "previous_event_digest": history[-1]["integrity"]["event_digest"],
            "event_digest": None,
        },
    }
    event["integrity"]["event_digest"] = event_digest(event)
    history.append(event)
    snapshot["resources"]["inputs"].append(binding)
    runtime.update(
        {
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
                "result": "wall_plane_amendment_bound",
                "record_revision": runtime["record_revision"],
                "amendment_digest": amendment_digest,
                "inventory_digest": inventory_digest,
            },
            ensure_ascii=False,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
