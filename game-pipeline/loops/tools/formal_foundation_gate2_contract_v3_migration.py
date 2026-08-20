#!/usr/bin/env python3
"""Migrate the interrupted GATE-2 loop from approved Contract v2 to approved 2D Contract v3."""

from __future__ import annotations

import copy
import hashlib
import json
import os
import tempfile
import uuid
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Callable

import yaml


PROJECT_ROOT = Path(__file__).resolve().parents[3]
REGISTRY_DIR = PROJECT_ROOT / "game-pipeline/loops/registry/formal-foundation-gate2"
SNAPSHOT_PATH = REGISTRY_DIR / "snapshot.yaml"
HISTORY_PATH = REGISTRY_DIR / "event-history.yaml"
CONTRACT_PATH = PROJECT_ROOT / "game-pipeline/loops/contracts/loop-contract-formal-foundation-gate2-v3.yaml"
APPROVAL_PATH = PROJECT_ROOT / "game-pipeline/approvals/loop-contract-formal-foundation-gate2-v3-9d9e3cfc5e92.yaml"
BRIEF_PATH = PROJECT_ROOT / "game-pipeline/project-definition/project-brief.yaml"
DIRECTION_PATH = PROJECT_ROOT / "docs/art/veilfront-2d-current-direction-v1.md"
INVENTORY_PATH = PROJECT_ROOT / "docs/art/demo-2d-asset-inventory-v1.yaml"
MIGRATION_REF = "game-pipeline/loops/evidence/GATE2-contract-v3-registry-migration-plan.md"

LOOP_ID = "83c995ff-37b9-4df8-9e84-8417d6632187"
CONTRACT_ID = "LOOP-CTR-FORMAL-FOUNDATION-GATE2-001"
OLD_CONTRACT_DIGEST = "bf2d09e7117960de4b178d827dc2c123ab4b83777175e5b1b0c9cca6eabe561d"
NEW_CONTRACT_DIGEST = "9ea1fbab25b1a560b83896194099bd9b0131552d7321223622161615c1a2a205"
CONTRACT_SUBJECT_DIGEST = "9d9e3cfc5e92d41d38eea336dbcca95040bb858706ffd8130a8b33a3594e7dd9"
BRIEF_SUBJECT_DIGEST = "8e9d4285c1c7237a22f308808e944fd8571700f896b8dd8cfb118f0fe0de3d3e"
APPROVAL_ID = "approval:veilfront-xiangqi-siege:loop-contract:9d9e3cfc5e92"
STATE_MACHINE_DIGEST = "810f414928b370a869b3a36a17cb504f290d17fa07c9ce5db9001136bfdb160c"
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


def add_event(
    history: list[dict[str, Any]],
    runtime: dict[str, Any],
    event_type: str,
    payload: dict[str, Any],
    evidence_refs: list[str],
    request_id: str,
    occurred_at: str,
    binding_digest: str,
    correlation_id: str,
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
            "expected_record_revision": runtime["record_revision"] + (sequence - runtime["last_event_sequence"] - 1),
            "resulting_record_revision": runtime["record_revision"] + (sequence - runtime["last_event_sequence"]),
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


def artifact_binding(
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


def main() -> int:
    snapshot_doc = load_yaml(SNAPSHOT_PATH)
    history_doc = load_yaml(HISTORY_PATH)
    contract_doc = load_yaml(CONTRACT_PATH)
    approval_doc = load_yaml(APPROVAL_PATH)
    brief_doc = load_yaml(BRIEF_PATH)
    snapshot = snapshot_doc["registry_snapshot"]
    history = history_doc["event_history"]
    runtime = snapshot["runtime"]

    if snapshot["identity"]["loop_instance_id"] != LOOP_ID:
        raise RuntimeError("loop identity mismatch")
    if runtime["current_state"] != "waiting_approval" or runtime["current_iteration"] != 3:
        raise RuntimeError("migration requires waiting_approval iteration 3")
    if runtime["record_revision"] != 41 or runtime["last_event_sequence"] != 41:
        raise RuntimeError("migration requires registry revision 41")
    if runtime["last_event_digest"] != history[-1]["integrity"]["event_digest"]:
        raise RuntimeError("snapshot/history tail mismatch")
    if snapshot["contract_binding"]["contract_digest"] != OLD_CONTRACT_DIGEST:
        raise RuntimeError("unexpected current contract binding")
    if snapshot.get("interruption", {}).get("resume_state") != "active":
        raise RuntimeError("interruption resume state mismatch")
    if sha256_file(CONTRACT_PATH) != NEW_CONTRACT_DIGEST:
        raise RuntimeError("materialized Contract v3 digest mismatch")

    approval = approval_doc["approval"]
    if approval["approval_id"] != APPROVAL_ID or approval["decision"] != "approved":
        raise RuntimeError("Contract v3 approval mismatch")
    if approval["subject_digest"] != CONTRACT_SUBJECT_DIGEST:
        raise RuntimeError("Contract v3 subject digest mismatch")
    if contract_doc["loop_contract"]["status"] != "approved":
        raise RuntimeError("Contract v3 is not materialized as approved")
    if contract_doc["approval_binding"]["approval_id"] != APPROVAL_ID:
        raise RuntimeError("Contract v3 approval binding mismatch")

    brief = brief_doc["project_brief"]
    if brief["review"]["status"] != "confirmed":
        raise RuntimeError("Project Brief v7 is not confirmed")
    if brief["integrity"]["subject_digest"] != BRIEF_SUBJECT_DIGEST:
        raise RuntimeError("Project Brief v7 digest mismatch")

    occurred_at = now_china()
    correlation_id = str(uuid.uuid4())
    interruption_id = snapshot["interruption"]["interruption_id"]
    pre_migration_snapshot_digest = sha256_file(SNAPSHOT_PATH)
    pre_migration_history_digest = sha256_file(HISTORY_PATH)
    preserved_outputs_digest = canonical_digest(snapshot["resources"]["outputs"])
    base_evidence = [
        MIGRATION_REF,
        "game-pipeline/loops/contracts/loop-contract-formal-foundation-gate2-v3.yaml",
        "game-pipeline/approvals/loop-contract-formal-foundation-gate2-v3-9d9e3cfc5e92.yaml",
    ]

    migration_event = add_event(
        history,
        runtime,
        "core.contract_migrated",
        {
            "contract_before": copy.deepcopy(snapshot["contract_binding"]),
            "contract_after": {
                "contract_id": CONTRACT_ID,
                "contract_version": 3,
                "contract_digest": NEW_CONTRACT_DIGEST,
            },
            "migration_check_ref": MIGRATION_REF,
            "approval_id": APPROVAL_ID,
        },
        base_evidence,
        "migrate-gate2-contract-v2-to-v3",
        occurred_at,
        OLD_CONTRACT_DIGEST,
        correlation_id,
    )
    snapshot["contract_binding"] = copy.deepcopy(migration_event["payload"]["contract_after"])
    snapshot["identity"]["title"] = contract_doc["loop_contract"]["title"]

    active_inputs = {item["input_slot_id"]: item for item in snapshot["resources"]["inputs"]}

    def retire_input(slot_id: str) -> None:
        before = active_inputs.pop(slot_id)
        add_event(
            history,
            runtime,
            "core.input_bound",
            {"input_slot_id": slot_id, "before": before, "after": None},
            [MIGRATION_REF, before["artifact"]["uri"]],
            f"retire-{slot_id.lower()}",
            occurred_at,
            NEW_CONTRACT_DIGEST,
            correlation_id,
        )

    for slot_id in (
        "INPUT-BRIEF-V6-001",
        "INPUT-REGISTRY-V1-001",
        "INPUT-VISUAL-BASELINE-001",
        "INPUT-ASSET-INVENTORY-001",
        "INPUT-WALL-PLANE-AMENDMENT-001",
    ):
        retire_input(slot_id)

    def bind_input(
        slot_id: str,
        builder: Callable[[str], dict[str, Any]],
        evidence_refs: list[str],
    ) -> None:
        before = active_inputs.get(slot_id)
        event = add_event(
            history,
            runtime,
            "core.input_bound",
            {"input_slot_id": slot_id, "before": before, "after": None},
            evidence_refs,
            f"bind-{slot_id.lower()}",
            occurred_at,
            NEW_CONTRACT_DIGEST,
            correlation_id,
        )
        after = builder(event["event_id"])
        event["payload"]["after"] = after
        event["integrity"]["event_digest"] = event_digest(event)
        active_inputs[slot_id] = after

    bind_input(
        "INPUT-BRIEF-V7-001",
        lambda event_id: artifact_binding(
            "INPUT-BRIEF-V7-001",
            "artifact:veilfront-xiangqi-siege:project-brief@v7",
            "confirmed-project-brief",
            f"7@subject:{BRIEF_SUBJECT_DIGEST}",
            "game-pipeline/project-definition/project-brief.yaml",
            BRIEF_SUBJECT_DIGEST,
            event_id,
            occurred_at,
        ),
        [
            "game-pipeline/project-definition/project-brief.yaml",
            "game-pipeline/approvals/project-brief-v7-8e9d4285c1c7.yaml",
        ],
    )
    bind_input(
        "INPUT-2D-DIRECTION-001",
        lambda event_id: artifact_binding(
            "INPUT-2D-DIRECTION-001",
            "artifact:veilfront-xiangqi-siege:current-2d-direction@v1",
            "owner-confirmed-current-2d-direction",
            "v1",
            "docs/art/veilfront-2d-current-direction-v1.md",
            sha256_file(DIRECTION_PATH),
            event_id,
            occurred_at,
        ),
        ["docs/art/veilfront-2d-current-direction-v1.md"],
    )
    bind_input(
        "INPUT-2D-ASSET-INVENTORY-001",
        lambda event_id: artifact_binding(
            "INPUT-2D-ASSET-INVENTORY-001",
            "artifact:veilfront-xiangqi-siege:demo-2d-art-asset-inventory@v1",
            "demo-2d-art-asset-inventory",
            "v1",
            "docs/art/demo-2d-asset-inventory-v1.yaml",
            sha256_file(INVENTORY_PATH),
            event_id,
            occurred_at,
        ),
        ["docs/art/demo-2d-asset-inventory-v1.yaml"],
    )
    bind_input(
        "INPUT-PREVIOUS-ACCEPTED-001",
        lambda event_id: artifact_binding(
            "INPUT-PREVIOUS-ACCEPTED-001",
            "artifact:veilfront-xiangqi-siege:gate2-v2-preserved-deliverables@revision41",
            "gate2-v2-preserved-deliverables",
            "registry-revision-41",
            "game-pipeline/loops/registry/formal-foundation-gate2/event-history.yaml",
            preserved_outputs_digest,
            event_id,
            occurred_at,
            [
                "game-pipeline/loops/registry/formal-foundation-gate2/snapshot.yaml",
                "game-pipeline/loops/registry/formal-foundation-gate2/event-history.yaml",
                *[item["artifact"]["uri"] for item in snapshot["resources"]["outputs"]],
            ],
        ),
        [
            MIGRATION_REF,
            f"sha256:snapshot:{pre_migration_snapshot_digest}",
            f"sha256:history:{pre_migration_history_digest}",
        ],
    )
    snapshot["resources"]["inputs"] = list(active_inputs.values())

    executor_scopes = {
        "pos:veilfront-xiangqi-siege:technology:godot-technical-lead": ["TASK-PRESENTATION-2D-001"],
        "pos:veilfront-xiangqi-siege:design-experience:systems-experience-lead": ["TASK-TUTORIAL-2D-COMPAT-001"],
        "pos:veilfront-xiangqi-siege:design-experience:visual-production-lead": ["TASK-ART-2D-001"],
    }
    for assignment in snapshot["responsibility"]["executors"]:
        before = copy.deepcopy(assignment)
        after = copy.deepcopy(assignment)
        after["scope"] = executor_scopes[assignment["role"]]
        add_event(
            history,
            runtime,
            "core.assignment_changed",
            {"assignment_kind": "executor", "operation": "update", "before": before, "after": after},
            base_evidence,
            f"update-executor-{assignment['role'].rsplit(':', 1)[-1]}-v3",
            occurred_at,
            NEW_CONTRACT_DIGEST,
            correlation_id,
        )
        assignment.clear()
        assignment.update(after)

    qa_assignment = next(
        item
        for item in snapshot["responsibility"]["reviewers"]
        if item["role"] == "pos:veilfront-xiangqi-siege:quality:qa-release-lead"
    )
    qa_before = copy.deepcopy(qa_assignment)
    qa_after = copy.deepcopy(qa_assignment)
    qa_after["review_scope"] = [
        "CHECK-CONTRACT-V3-001",
        "CHECK-DEPENDENCY-001",
        "CHECK-INFORMATION-2D-001",
        "CHECK-GODOT-2D-001",
        "CHECK-COORDINATE-001",
        "CHECK-RESPONSIVE-2D-001",
        "CHECK-PERFORMANCE-2D-001",
        "CHECK-ART-2D-001",
        "CHECK-REGRESSION-001",
        "CHECK-SCOPE-001",
    ]
    add_event(
        history,
        runtime,
        "core.assignment_changed",
        {"assignment_kind": "reviewer", "operation": "update", "before": qa_before, "after": qa_after},
        base_evidence,
        "update-reviewer-qa-release-lead-v3",
        occurred_at,
        NEW_CONTRACT_DIGEST,
        correlation_id,
    )
    qa_assignment.clear()
    qa_assignment.update(qa_after)

    revalidation = {
        "attempt_id": str(uuid.uuid4()),
        "checked_at": occurred_at,
        "overall_result": "passed",
        "checks": [
            {"check_id": "RESUME-CTR", "result": "passed", "evidence_refs": base_evidence},
            {
                "check_id": "RESUME-INPUT",
                "result": "passed",
                "evidence_refs": [
                    "game-pipeline/project-definition/project-brief.yaml",
                    "docs/art/veilfront-2d-current-direction-v1.md",
                    "docs/art/demo-2d-asset-inventory-v1.yaml",
                ],
            },
            {"check_id": "RESUME-DEP", "result": "passed", "evidence_refs": [MIGRATION_REF]},
            {
                "check_id": "RESUME-AUTH",
                "result": "passed",
                "evidence_refs": [
                    "game-pipeline/organization/snapshot.yaml",
                    "game-pipeline/approvals/authority-policy-initial-c68e669295be.yaml",
                ],
            },
            {"check_id": "RESUME-BUDGET", "result": "passed", "evidence_refs": ["registry://budget/status=available"]},
            {"check_id": "RESUME-EVIDENCE", "result": "passed", "evidence_refs": [MIGRATION_REF]},
        ],
        "resulting_route": "resume",
        "event_id": None,
    }
    resume_event = add_event(
        history,
        runtime,
        "core.resume_revalidation_recorded",
        {
            "transition_id": "TR-INTERRUPTED-RESUME",
            "from_state": "waiting_approval",
            "to_state": "active",
            "iteration": {"before": 3, "after": 3},
            "interruption_id": interruption_id,
            "revalidation": revalidation,
        },
        base_evidence,
        "resume-gate2-under-contract-v3",
        occurred_at,
        NEW_CONTRACT_DIGEST,
        correlation_id,
    )
    revalidation["event_id"] = resume_event["event_id"]
    resume_event["integrity"]["event_digest"] = event_digest(resume_event)

    snapshot["interruption"] = None
    runtime.update(
        {
            "current_state": "active",
            "state_entered_at": occurred_at,
            "last_transition_id": "TR-INTERRUPTED-RESUME",
            "last_event_id": history[-1]["event_id"],
            "last_event_digest": history[-1]["integrity"]["event_digest"],
            "last_event_sequence": len(history),
            "record_revision": len(history),
        }
    )
    history_doc["event_history"] = history
    write_pair(snapshot_doc, history_doc)
    print(
        json.dumps(
            {
                "result": "contract_v3_migrated_and_loop_resumed",
                "state": runtime["current_state"],
                "iteration": runtime["current_iteration"],
                "sequence": runtime["last_event_sequence"],
                "record_revision": runtime["record_revision"],
                "contract_digest": NEW_CONTRACT_DIGEST,
            },
            ensure_ascii=False,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
