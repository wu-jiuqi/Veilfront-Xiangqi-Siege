#!/usr/bin/env python3
"""Apply the approved GATE-2 Contract v2 migration without rewriting prior events."""

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
CONTRACT_PATH = PROJECT_ROOT / "game-pipeline/loops/contracts/loop-contract-formal-foundation-gate2-v2.yaml"
APPROVAL_PATH = PROJECT_ROOT / "game-pipeline/approvals/loop-contract-formal-foundation-gate2-v2-ce2d6174f82a.yaml"
MIGRATION_REF = "game-pipeline/loops/evidence/GATE2-visual-direction-contract-v2-migration-plan.md"
LOOP_ID = "83c995ff-37b9-4df8-9e84-8417d6632187"
OLD_CONTRACT_DIGEST = "a26a9b3fdb0d8d06e42a06833a84455d911fea8f72bcedec59d0ae5e620cc205"
NEW_CONTRACT_DIGEST = "bf2d09e7117960de4b178d827dc2c123ab4b83777175e5b1b0c9cca6eabe561d"
STATE_MACHINE_DIGEST = "810f414928b370a869b3a36a17cb504f290d17fa07c9ce5db9001136bfdb160c"
APPROVAL_ID = "approval:veilfront-xiangqi-siege:loop-contract:ce2d6174f82a"
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


def add_event(
    history: list[dict[str, Any]],
    event_type: str,
    payload: dict[str, Any],
    evidence_refs: list[str],
    correlation_id: str,
    request_id: str,
    occurred_at: str,
    binding_digest: str,
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
            "contract_digest": binding_digest,
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


def input_binding(
    slot_id: str,
    artifact_id: str,
    artifact_type: str,
    version: str,
    uri: str,
    digest: str,
    event_id: str,
    bound_at: str,
    manifest_paths: list[str] | None = None,
) -> dict[str, Any]:
    artifact: dict[str, Any] = {
        "artifact_id": artifact_id,
        "artifact_type": artifact_type,
        "version": version,
        "uri": uri,
        "digest": {"algorithm": "sha256", "value": digest},
    }
    if manifest_paths:
        artifact["manifest_paths"] = manifest_paths
    return {
        "input_slot_id": slot_id,
        "artifact": artifact,
        "source_loop_id": None,
        "bound_by_event_id": event_id,
        "bound_at": bound_at,
    }


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


def main() -> int:
    snapshot_doc = load_yaml(SNAPSHOT_PATH)
    history_doc = load_yaml(HISTORY_PATH)
    contract_doc = load_yaml(CONTRACT_PATH)
    approval_doc = load_yaml(APPROVAL_PATH)
    snapshot = snapshot_doc["registry_snapshot"]
    history = history_doc["event_history"]
    runtime = snapshot["runtime"]

    if snapshot["identity"]["loop_instance_id"] != LOOP_ID:
        raise RuntimeError("loop identity mismatch")
    if runtime["record_revision"] != 23 or runtime["last_event_sequence"] != 23:
        raise RuntimeError("migration requires registry revision 23")
    if runtime["current_state"] != "active" or runtime["current_iteration"] != 3:
        raise RuntimeError("migration requires active iteration 3")
    if runtime["last_event_digest"] != history[-1]["integrity"]["event_digest"]:
        raise RuntimeError("snapshot/history tail mismatch")
    if snapshot["contract_binding"]["contract_digest"] != OLD_CONTRACT_DIGEST:
        raise RuntimeError("unexpected current contract binding")
    if sha256_file(CONTRACT_PATH) != NEW_CONTRACT_DIGEST:
        raise RuntimeError("materialized Contract v2 digest mismatch")
    approval = approval_doc["approval"]
    if approval["approval_id"] != APPROVAL_ID or approval["decision"] != "approved":
        raise RuntimeError("Contract v2 approval mismatch")
    if approval["subject_digest"] != "ce2d6174f82af003b023f80e2ae3676510df541f4a6ac129bfcf69847361b20d":
        raise RuntimeError("Contract v2 subject digest mismatch")
    if contract_doc["loop_contract"]["status"] != "approved":
        raise RuntimeError("Contract v2 is not materialized as approved")
    if any(event.get("event_type") == "core.contract_migrated" for event in history):
        raise RuntimeError("Contract v2 migration already applied")

    occurred_at = now_china()
    correlation_id = str(uuid.uuid4())
    pre_migration_snapshot_digest = sha256_file(SNAPSHOT_PATH)
    preserved_outputs_digest = canonical_digest(snapshot["resources"]["outputs"])

    migration_event = add_event(
        history,
        "core.contract_migrated",
        {
            "contract_before": copy.deepcopy(snapshot["contract_binding"]),
            "contract_after": {
                "contract_id": "LOOP-CTR-FORMAL-FOUNDATION-GATE2-001",
                "contract_version": 2,
                "contract_digest": NEW_CONTRACT_DIGEST,
            },
            "migration_check_ref": MIGRATION_REF,
            "approval_id": APPROVAL_ID,
        },
        [
            "game-pipeline/approvals/loop-contract-formal-foundation-gate2-v2-ce2d6174f82a.yaml",
            MIGRATION_REF,
        ],
        correlation_id,
        "migrate-gate2-contract-v1-to-v2",
        occurred_at,
        OLD_CONTRACT_DIGEST,
    )
    snapshot["contract_binding"] = copy.deepcopy(migration_event["payload"]["contract_after"])
    snapshot["identity"]["title"] = contract_doc["loop_contract"]["title"]

    old_inputs = {item["input_slot_id"]: item for item in snapshot["resources"]["inputs"]}
    active_inputs: dict[str, dict[str, Any]] = {}

    for slot_id, before in old_inputs.items():
        add_event(
            history,
            "core.input_bound",
            {"input_slot_id": slot_id, "before": before, "after": None},
            [MIGRATION_REF],
            correlation_id,
            f"retire-{slot_id.lower()}",
            occurred_at,
            NEW_CONTRACT_DIGEST,
        )

    def bind_input(slot_id: str, builder: Any, evidence_refs: list[str]) -> None:
        event = add_event(
            history,
            "core.input_bound",
            {"input_slot_id": slot_id, "before": None, "after": None},
            evidence_refs,
            correlation_id,
            f"bind-{slot_id.lower()}",
            occurred_at,
            NEW_CONTRACT_DIGEST,
        )
        after = builder(event["event_id"])
        event["payload"]["after"] = after
        event["integrity"]["event_digest"] = event_digest(event)
        active_inputs[slot_id] = after

    bind_input(
        "INPUT-BRIEF-V6-001",
        lambda event_id: input_binding(
            "INPUT-BRIEF-V6-001",
            "artifact:veilfront-xiangqi-siege:project-brief@v6",
            "confirmed-project-brief",
            "6@subject:54520517ac26859c24459accb2d7672d12d0224ef69a766f883eda7b2b523289",
            "game-pipeline/project-definition/project-brief.yaml",
            "54520517ac26859c24459accb2d7672d12d0224ef69a766f883eda7b2b523289",
            event_id,
            occurred_at,
        ),
        [
            "game-pipeline/project-definition/project-brief.yaml",
            "game-pipeline/approvals/project-brief-v6-54520517ac26.yaml",
        ],
    )
    bind_input(
        "INPUT-REGISTRY-V1-001",
        lambda event_id: input_binding(
            "INPUT-REGISTRY-V1-001",
            "artifact:veilfront-xiangqi-siege:gate2-registry@revision23",
            "active-loop-registry-snapshot",
            "revision-23-pre-contract-v2",
            "game-pipeline/loops/registry/formal-foundation-gate2/snapshot.yaml",
            pre_migration_snapshot_digest,
            event_id,
            occurred_at,
            [
                "game-pipeline/loops/registry/formal-foundation-gate2/snapshot.yaml",
                "game-pipeline/loops/registry/formal-foundation-gate2/event-history.yaml",
            ],
        ),
        [MIGRATION_REF],
    )
    bind_input(
        "INPUT-VISUAL-BASELINE-001",
        lambda event_id: input_binding(
            "INPUT-VISUAL-BASELINE-001",
            "artifact:veilfront-xiangqi-siege:visual-baseline@v1",
            "owner-frozen-oblique-3d-visual-baseline",
            "v1",
            "docs/art/veilfront-visual-baseline-v1.md",
            sha256_file(PROJECT_ROOT / "docs/art/veilfront-visual-baseline-v1.md"),
            event_id,
            occurred_at,
        ),
        ["docs/art/veilfront-visual-baseline-v1.md", "evidence/gate2/visual-direction-change-impact-v1.md"],
    )
    bind_input(
        "INPUT-ASSET-INVENTORY-001",
        lambda event_id: input_binding(
            "INPUT-ASSET-INVENTORY-001",
            "artifact:veilfront-xiangqi-siege:demo-art-asset-inventory@v1",
            "demo-art-asset-inventory",
            "v1",
            "docs/art/demo-asset-inventory-v1.yaml",
            sha256_file(PROJECT_ROOT / "docs/art/demo-asset-inventory-v1.yaml"),
            event_id,
            occurred_at,
        ),
        ["docs/art/demo-asset-inventory-v1.yaml", "docs/art/vertical-art-slice-brief-v1.md"],
    )
    bind_input(
        "INPUT-PREVIOUS-ACCEPTED-001",
        lambda event_id: input_binding(
            "INPUT-PREVIOUS-ACCEPTED-001",
            "artifact:veilfront-xiangqi-siege:gate2-v1-accepted-deliverables@revision23",
            "gate2-v1-accepted-deliverables",
            "registry-revision-23",
            "game-pipeline/loops/registry/formal-foundation-gate2/event-history.yaml",
            preserved_outputs_digest,
            event_id,
            occurred_at,
            [item["artifact"]["uri"] for item in snapshot["resources"]["outputs"]],
        ),
        [MIGRATION_REF, "evidence/gate2/iteration2-owner-decision-r4.md"],
    )
    snapshot["resources"]["inputs"] = list(active_inputs.values())

    executor_scopes = {
        "pos:veilfront-xiangqi-siege:technology:godot-technical-lead": ["TASK-PRESENTATION-3D-001"],
        "pos:veilfront-xiangqi-siege:design-experience:systems-experience-lead": ["TASK-TUTORIAL-3D-COMPAT-001"],
        "pos:veilfront-xiangqi-siege:design-experience:visual-production-lead": ["TASK-ART-001"],
    }
    for assignment in snapshot["responsibility"]["executors"]:
        role = assignment["role"]
        before = copy.deepcopy(assignment)
        after = copy.deepcopy(assignment)
        after["scope"] = executor_scopes[role]
        event = add_event(
            history,
            "core.assignment_changed",
            {"assignment_kind": "executor", "operation": "update", "before": before, "after": after},
            [MIGRATION_REF, "game-pipeline/loops/contracts/loop-contract-formal-foundation-gate2-v2.yaml"],
            correlation_id,
            f"update-executor-{role.rsplit(':', 1)[-1]}",
            occurred_at,
            NEW_CONTRACT_DIGEST,
        )
        assignment.clear()
        assignment.update(event["payload"]["after"])

    qa_checks = [item["check_id"] for item in contract_doc["acceptance"]["automated_checks"]]
    for assignment in snapshot["responsibility"]["reviewers"]:
        before = copy.deepcopy(assignment)
        after = copy.deepcopy(assignment)
        after["review_scope"] = ["GATE-2"] if assignment["role"] == "project-owner" else qa_checks
        event = add_event(
            history,
            "core.assignment_changed",
            {"assignment_kind": "reviewer", "operation": "update", "before": before, "after": after},
            [MIGRATION_REF, "game-pipeline/loops/contracts/loop-contract-formal-foundation-gate2-v2.yaml"],
            correlation_id,
            f"update-reviewer-{assignment['role'].rsplit(':', 1)[-1]}",
            occurred_at,
            NEW_CONTRACT_DIGEST,
        )
        assignment.clear()
        assignment.update(event["payload"]["after"])

    runtime.update({
        "last_event_id": history[-1]["event_id"],
        "last_event_digest": history[-1]["integrity"]["event_digest"],
        "last_event_sequence": len(history),
        "record_revision": len(history),
    })
    history_doc["event_history"] = history
    write_pair(snapshot_doc, history_doc)
    print(json.dumps({
        "result": "contract_v2_migrated",
        "events_appended": len(history) - 23,
        "record_revision": len(history),
        "contract_digest": NEW_CONTRACT_DIGEST,
    }, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
