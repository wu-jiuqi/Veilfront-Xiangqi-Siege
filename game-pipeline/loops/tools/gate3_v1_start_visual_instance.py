#!/usr/bin/env python3
"""Register the approved visual-production position instance for GATE-3.

The mutation is deliberately narrow: it starts the already-approved formal
position, then refreshes the active GATE-3 loop's organization input digest.
It does not create or modify long-lived organization structure.
"""

from __future__ import annotations

import copy
import hashlib
import importlib.util
import json
import os
import secrets
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any

import yaml


PROJECT_ROOT = Path(__file__).resolve().parents[3]
PLUGIN_ROOT = Path.home() / ".codex/plugins/cache/personal/game-production-pipeline/0.4.0-alpha.2"
ORG_SNAPSHOT_PATH = PROJECT_ROOT / "game-pipeline/organization/snapshot.yaml"
ORG_HISTORY_PATH = PROJECT_ROOT / "game-pipeline/organization/event-history.yaml"
LOOP_SNAPSHOT_PATH = PROJECT_ROOT / "game-pipeline/loops/registry/content-integration-gate3/snapshot.yaml"
LOOP_HISTORY_PATH = PROJECT_ROOT / "game-pipeline/loops/registry/content-integration-gate3/event-history.yaml"
ORG_VALIDATOR_PATH = PLUGIN_ROOT / "scripts/validate_organization_registry.py"

POSITION_ID = "pos:veilfront-xiangqi-siege:design-experience:visual-production-lead"
PRESET_ID = "preset:veilfront-xiangqi-siege:visual-production-lead"
PRESET_DIGEST = "42156e275853b6a73611af1ec436e676c21b99f936130fb951ca75e23787daa5"
POSITION_DEFINITION_DIGEST = "cc502a9feae5b7f38827d5fd8c85e75ad237cb147d2c40404b75b652b0022240"
INSTANCE_ID = "inst:01M0QY1VFX7SFXVFXGATE3VFX1"

PM_ACTOR_ORG = {
    "actor_kind": "instance",
    "actor_id": "inst:01M02M6X3Q8YWJXHY52K3V5AR2",
    "acting_position_id": "pos:veilfront-xiangqi-siege:root:project-manager",
    "role": "project-manager",
}
PM_ACTOR_LOOP = {
    "actor_id": "inst:01M02M6X3Q8YWJXHY52K3V5AR2",
    "role": "pos:veilfront-xiangqi-siege:root:project-manager",
    "authority_id": "AUTH-VEILFRONT-PROJECT-MANAGER",
}
PM_AUTHORITY = {
    "id": "AUTH-VEILFRONT-PROJECT-MANAGER",
    "version": "0.1.0",
    "digest": "713953e9f58fff95b9f7b56e5eb0a856a1538e4c443c9dcb88cbc541ac75e54c",
}
APPROVAL_REFS = [
    "approval:veilfront-xiangqi-siege:loop-contract:7c735748becb",
    "approval:veilfront-xiangqi-siege:organization-change-set:fdd6fec0a5f4",
]


def load_yaml(path: Path) -> dict[str, Any]:
    value = yaml.safe_load(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise RuntimeError(f"YAML root must be a mapping: {path}")
    return value


def dump_yaml(value: Any) -> bytes:
    return yaml.safe_dump(value, allow_unicode=True, sort_keys=False, width=120).encode("utf-8")


def canonical_digest(value: Any) -> str:
    encoded = json.dumps(
        value,
        ensure_ascii=False,
        allow_nan=False,
        separators=(",", ":"),
        sort_keys=True,
    ).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()


def event_digest(event: dict[str, Any]) -> str:
    normalized = copy.deepcopy(event)
    normalized["integrity"]["event_digest"] = None
    return canonical_digest(normalized)


def now_china() -> str:
    return datetime.now(timezone(timedelta(hours=8))).isoformat(timespec="microseconds")


def new_ulid() -> str:
    alphabet = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"
    value = ((time.time_ns() // 1_000_000) << 80) | int.from_bytes(secrets.token_bytes(10), "big")
    chars: list[str] = []
    for _ in range(26):
        chars.append(alphabet[value & 31])
        value >>= 5
    return "".join(reversed(chars))


def import_org_validator():
    spec = importlib.util.spec_from_file_location("organization_registry_validator", ORG_VALIDATOR_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError("cannot load organization registry validator")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def make_org_event(
    snapshot_doc: dict[str, Any],
    history: list[dict[str, Any]],
    event_type: str,
    payload: dict[str, Any],
    occurred_at: str,
    correlation_id: str,
    causation_event_id: str | None,
    request_id: str,
    evidence_refs: list[str],
) -> dict[str, Any]:
    validator = import_org_validator()
    snapshot = snapshot_doc["organization_snapshot"]
    sequence = len(history) + 1
    event = {
        "schema_version": "0.2-alpha",
        "event_id": f"evt:{new_ulid()}",
        "mutation_id": f"mut:{new_ulid()}",
        "project_id": "veilfront-xiangqi-siege",
        "sequence": sequence,
        "event_type": event_type,
        "occurred_at": occurred_at,
        "recorded_at": occurred_at,
        "actor": PM_ACTOR_ORG,
        "authorization": {
            "authority_ref": PM_AUTHORITY,
            "approval_refs": APPROVAL_REFS,
            "change_set_ref": None,
        },
        "causality": {
            "correlation_id": correlation_id,
            "causation_event_id": causation_event_id,
            "request_id": request_id,
        },
        "concurrency": {
            "expected_organization_revision": snapshot["identity"]["organization_revision"],
            "expected_snapshot_digest": validator.canonical_snapshot_digest(snapshot_doc),
            "resulting_organization_revision": snapshot["identity"]["organization_revision"] + 1,
        },
        "binding_snapshot": copy.deepcopy(snapshot["governance_bindings"]),
        "payload": payload,
        "evidence_refs": evidence_refs,
        "integrity": {
            "canonicalization": "registry-event-canonical-json-v1",
            "digest_algorithm": "sha256",
            "previous_event_digest": history[-1]["integrity"]["event_digest"],
            "event_digest": None,
        },
    }
    event["integrity"]["event_digest"] = event_digest(event)
    return event


def register_visual_instance() -> tuple[dict[str, Any], dict[str, Any], str]:
    validator = import_org_validator()
    snapshot_doc = load_yaml(ORG_SNAPSHOT_PATH)
    history_doc = load_yaml(ORG_HISTORY_PATH)
    snapshot = snapshot_doc["organization_snapshot"]
    history = history_doc["organization_event_history"]

    if any(item["instance_id"] == INSTANCE_ID for item in snapshot["runtime"]["instances"]):
        return snapshot_doc, history_doc, INSTANCE_ID
    if any(item["position_binding"]["position_id"] == POSITION_ID for item in snapshot["runtime"]["instances"] if item["instance_kind"] == "position"):
        raise RuntimeError("visual-production position already has an active instance")

    position = next(item for item in snapshot["formal_structure"]["positions"] if item["position_id"] == POSITION_ID)
    if position["lifecycle"]["state"] != "active":
        raise RuntimeError("visual-production position is not active")
    if position["preset_binding"]["preset_id"] != PRESET_ID or position["preset_binding"]["digest"] != PRESET_DIGEST:
        raise RuntimeError("visual-production preset binding mismatch")

    occurred_at = now_china()
    correlation_id = f"gate3-vfx-start:{new_ulid()}"
    registration_id = f"evt:{new_ulid()}"
    instance = {
        "instance_id": INSTANCE_ID,
        "instance_kind": "position",
        "preset_binding": copy.deepcopy(position["preset_binding"]),
        "position_binding": {
            "position_id": POSITION_ID,
            "definition_digest": POSITION_DEFINITION_DIGEST,
        },
        "temporary_binding": None,
        "lifecycle": {
            "state": "starting",
            "state_entered_at": occurred_at,
            "transition_ref": registration_id,
        },
        "started_at": occurred_at,
        "expires_at": None,
        "audit": {
            "registered_by_event_id": registration_id,
            "last_changed_by_event_id": registration_id,
        },
    }
    registration = make_org_event(
        snapshot_doc,
        history,
        "core.instance_registered",
        {"instance": instance, "reservation": None},
        occurred_at,
        correlation_id,
        history[-1]["event_id"],
        "start-gate3-vfx-formal-position-instance",
        [
            "game-pipeline/loops/contracts/loop-contract-content-integration-gate3-v1.yaml",
            ".codex/agents/visual-production-lead.toml",
        ],
    )
    registration["event_id"] = registration_id
    registration["payload"]["instance"]["lifecycle"]["transition_ref"] = registration_id
    registration["payload"]["instance"]["audit"]["registered_by_event_id"] = registration_id
    registration["payload"]["instance"]["audit"]["last_changed_by_event_id"] = registration_id
    registration["integrity"]["event_digest"] = event_digest(registration)
    history.append(registration)
    replayed, errors = validator.replay_history(history_doc)
    if errors or replayed is None:
        raise RuntimeError("organization registration replay failed: " + "; ".join(errors))
    snapshot_doc = replayed

    activation = make_org_event(
        snapshot_doc,
        history,
        "core.instance_lifecycle_transitioned",
        {
            "instance_id": INSTANCE_ID,
            "from_state": "starting",
            "to_state": "active",
            "reason": {
                "code": "startup-validation-passed",
                "checks": [
                    "Position active",
                    "Preset id/version/digest matches approved binding",
                    "maximum_active_instances=1 not exceeded",
                    "generated Codex adapter digest-matched",
                    "scope limited to TASK-VFX-G3-001",
                ],
            },
            "release_reservation": None,
        },
        occurred_at,
        correlation_id,
        registration_id,
        "activate-gate3-vfx-formal-position-instance",
        [
            ".codex/agents/visual-production-lead.toml",
            "validate_project_instance.py:state=normal",
            "contract:LOOP-CTR-CONTENT-INTEGRATION-GATE3-001@v1:TASK-VFX-G3-001",
        ],
    )
    history.append(activation)
    replayed, errors = validator.replay_history(history_doc)
    if errors or replayed is None:
        raise RuntimeError("organization activation replay failed: " + "; ".join(errors))
    return replayed, history_doc, INSTANCE_ID


def rebind_loop_organization_input(org_snapshot_doc: dict[str, Any]) -> tuple[dict[str, Any], dict[str, Any]]:
    loop_snapshot_doc = load_yaml(LOOP_SNAPSHOT_PATH)
    loop_history_doc = load_yaml(LOOP_HISTORY_PATH)
    loop_snapshot = loop_snapshot_doc["registry_snapshot"]
    loop_history = loop_history_doc["event_history"]
    runtime = loop_snapshot["runtime"]
    input_index = next(
        index
        for index, item in enumerate(loop_snapshot["resources"]["inputs"])
        if item["input_slot_id"] == "INPUT-ORG-G3-001"
    )
    before = copy.deepcopy(loop_snapshot["resources"]["inputs"][input_index])
    org_digest = hashlib.sha256(dump_yaml(org_snapshot_doc)).hexdigest()
    if before["artifact"]["digest"]["value"] == org_digest:
        return loop_snapshot_doc, loop_history_doc

    occurred_at = now_china()
    event_id = str(__import__("uuid").uuid4())
    after = copy.deepcopy(before)
    after["artifact"]["version"] = "current-approved-snapshot-plus-gate3-vfx-position-instance"
    after["artifact"]["digest"]["value"] = org_digest
    after["bound_by_event_id"] = event_id
    after["bound_at"] = occurred_at
    event = {
        "schema_version": "0.1",
        "event_id": event_id,
        "mutation_id": str(__import__("uuid").uuid4()),
        "loop_instance_id": loop_snapshot["identity"]["loop_instance_id"],
        "sequence": len(loop_history) + 1,
        "event_type": "core.input_bound",
        "occurred_at": occurred_at,
        "recorded_at": occurred_at,
        "actor": PM_ACTOR_LOOP,
        "causality": {
            "correlation_id": str(__import__("uuid").uuid4()),
            "causation_event_id": loop_history[-1]["event_id"],
            "request_id": "refresh-gate3-organization-input-after-vfx-instance-start",
        },
        "concurrency": {
            "expected_record_revision": runtime["record_revision"],
            "resulting_record_revision": runtime["record_revision"] + 1,
        },
        "binding_snapshot": {
            "contract_digest": loop_snapshot["contract_binding"]["contract_digest"],
            "state_machine_digest": loop_snapshot["state_machine_binding"]["state_machine_digest"],
        },
        "payload": {
            "input_slot_id": "INPUT-ORG-G3-001",
            "before": before,
            "after": after,
        },
        "evidence_refs": [
            "game-pipeline/organization/snapshot.yaml",
            ".codex/agents/visual-production-lead.toml",
        ],
        "integrity": {
            "canonicalization": "registry-event-canonical-json-v1",
            "digest_algorithm": "sha256",
            "previous_event_digest": loop_history[-1]["integrity"]["event_digest"],
            "event_digest": None,
        },
    }
    event["integrity"]["event_digest"] = event_digest(event)
    loop_history.append(event)
    loop_snapshot["resources"]["inputs"][input_index] = after
    runtime["last_event_id"] = event_id
    runtime["last_event_digest"] = event["integrity"]["event_digest"]
    runtime["last_event_sequence"] = len(loop_history)
    runtime["record_revision"] += 1
    return loop_snapshot_doc, loop_history_doc


def atomic_write(files: dict[Path, bytes]) -> None:
    pending: dict[Path, Path] = {}
    try:
        for path, data in files.items():
            temp = path.with_name(path.name + ".gate3-vfx-instance.tmp")
            temp.write_bytes(data)
            pending[path] = temp
        for path, temp in pending.items():
            os.replace(temp, path)
    finally:
        for temp in pending.values():
            temp.unlink(missing_ok=True)


def main() -> None:
    org_snapshot, org_history, instance_id = register_visual_instance()
    loop_snapshot, loop_history = rebind_loop_organization_input(org_snapshot)
    atomic_write(
        {
            ORG_SNAPSHOT_PATH: dump_yaml(org_snapshot),
            ORG_HISTORY_PATH: dump_yaml(org_history),
            LOOP_SNAPSHOT_PATH: dump_yaml(loop_snapshot),
            LOOP_HISTORY_PATH: dump_yaml(loop_history),
        }
    )
    print(f"GATE3_VISUAL_INSTANCE_ACTIVE instance_id={instance_id}")


if __name__ == "__main__":
    main()
