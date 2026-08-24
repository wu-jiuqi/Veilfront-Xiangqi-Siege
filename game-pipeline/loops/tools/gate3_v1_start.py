#!/usr/bin/env python3
"""Register and start the approved GATE-3 content-integration loop."""

from __future__ import annotations

import copy
import hashlib
import json
import os
import uuid
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any

import yaml


PROJECT_ROOT = Path(__file__).resolve().parents[3]
PLUGIN_ROOT = Path.home() / ".codex/plugins/cache/personal/game-production-pipeline/0.4.0-alpha.2"
CONTRACT_PATH = PROJECT_ROOT / "game-pipeline/loops/contracts/loop-contract-content-integration-gate3-v1.yaml"
APPROVAL_PATH = PROJECT_ROOT / "game-pipeline/approvals/loop-contract-content-integration-gate3-v1-7c735748becb.yaml"
STATE_MACHINE_PATH = PLUGIN_ROOT / "contracts/loop-state-machine.default.yaml"
ORG_SNAPSHOT_PATH = PROJECT_ROOT / "game-pipeline/organization/snapshot.yaml"
GATE2_SNAPSHOT_PATH = PROJECT_ROOT / "game-pipeline/loops/registry/formal-foundation-gate2/snapshot.yaml"
REGISTRY_DIR = PROJECT_ROOT / "game-pipeline/loops/registry/content-integration-gate3"
SNAPSHOT_PATH = REGISTRY_DIR / "snapshot.yaml"
HISTORY_PATH = REGISTRY_DIR / "event-history.yaml"

CONTRACT_ID = "LOOP-CTR-CONTENT-INTEGRATION-GATE3-001"
CONTRACT_VERSION = 1
APPROVAL_ID = "approval:veilfront-xiangqi-siege:loop-contract:7c735748becb"
APPROVED_SOURCE_DIGEST = "7c735748becb46c0834f2935863e0576be07aa8a48868df9655c06a362f6206d"
GATE2_LOOP_ID = "83c995ff-37b9-4df8-9e84-8417d6632187"
GATE2_APPROVAL_ID = "approval:veilfront-xiangqi-siege:gate-2:0213f500a100"

PM_ACTOR = {
    "actor_id": "inst:01M02M6X3Q8YWJXHY52K3V5AR2",
    "role": "pos:veilfront-xiangqi-siege:root:project-manager",
    "authority_id": "AUTH-VEILFRONT-PROJECT-MANAGER",
}


def load_yaml(path: Path) -> dict[str, Any]:
    value = yaml.safe_load(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise RuntimeError(f"YAML root must be a mapping: {path}")
    return value


def dump_yaml(value: Any) -> bytes:
    return yaml.safe_dump(value, allow_unicode=True, sort_keys=False, width=120).encode("utf-8")


def file_sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


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


def verify_preflight() -> tuple[str, str, str]:
    if SNAPSHOT_PATH.exists() or HISTORY_PATH.exists():
        raise RuntimeError("content-integration-gate3 registry already exists; refusing duplicate registration")

    contract_doc = load_yaml(CONTRACT_PATH)
    contract = contract_doc["loop_contract"]
    if contract["contract_id"] != CONTRACT_ID or contract["version"] != CONTRACT_VERSION:
        raise RuntimeError("contract identity mismatch")
    if contract["status"] != "approved":
        raise RuntimeError("contract is not approved")
    binding = contract_doc.get("approval_binding") or {}
    if binding.get("approval_id") != APPROVAL_ID or binding.get("subject_digest") != APPROVED_SOURCE_DIGEST:
        raise RuntimeError("contract approval binding mismatch")

    approval = load_yaml(APPROVAL_PATH)["approval"]
    contract_sha = file_sha(CONTRACT_PATH)
    if approval["approval_id"] != APPROVAL_ID or approval["decision"] != "approved":
        raise RuntimeError("approval identity or decision mismatch")
    if approval["subject_digest"] != APPROVED_SOURCE_DIGEST:
        raise RuntimeError("approval subject mismatch")
    if approval["application"]["materialized_digest"] != contract_sha:
        raise RuntimeError("materialized contract digest mismatch")

    gate2 = load_yaml(GATE2_SNAPSHOT_PATH)["registry_snapshot"]
    gate2_runtime = gate2["runtime"]
    if gate2["identity"]["loop_instance_id"] != GATE2_LOOP_ID:
        raise RuntimeError("GATE-2 loop identity mismatch")
    if gate2_runtime["current_state"] != "completed" or gate2_runtime["record_revision"] != 102:
        raise RuntimeError("GATE-2 is not at the approved completed waterline")

    organization = load_yaml(ORG_SNAPSHOT_PATH)["organization_snapshot"]
    active_positions = {
        item["position_id"]
        for item in organization["formal_structure"]["positions"]
        if item["lifecycle"]["state"] == "active"
    }
    required_positions = {
        "pos:veilfront-xiangqi-siege:root:project-manager",
        "pos:veilfront-xiangqi-siege:technology:godot-technical-lead",
        "pos:veilfront-xiangqi-siege:design-experience:systems-experience-lead",
        "pos:veilfront-xiangqi-siege:design-experience:visual-production-lead",
        "pos:veilfront-xiangqi-siege:quality:qa-release-lead",
    }
    if not required_positions.issubset(active_positions):
        raise RuntimeError("required active positions are missing")

    active_instances = {
        item["instance_id"]
        for item in organization["runtime"]["instances"]
        if item["lifecycle"]["state"] == "active"
    }
    required_instances = {
        PM_ACTOR["actor_id"],
        "inst:01M02NJ3JENHD8VV7EKC9G198Q",
        "inst:01M02NJ3JEQXKV6PT6DPX0NKQ0",
        "inst:01M02NJ3JFHVZ5C4SP5MTJFJR6",
    }
    if not required_instances.issubset(active_instances):
        raise RuntimeError("required active formal instances are missing")

    return contract_sha, file_sha(STATE_MACHINE_PATH), file_sha(ORG_SNAPSHOT_PATH)


def make_event(
    history: list[dict[str, Any]],
    loop_id: str,
    event_type: str,
    actor: dict[str, str],
    payload: dict[str, Any],
    evidence_refs: list[str],
    request_id: str,
    correlation_id: str,
    occurred_at: str,
    contract_sha: str,
    state_machine_sha: str,
) -> dict[str, Any]:
    sequence = len(history) + 1
    previous = history[-1] if history else None
    event = {
        "schema_version": "0.1",
        "event_id": str(uuid.uuid4()),
        "mutation_id": str(uuid.uuid4()),
        "loop_instance_id": loop_id,
        "sequence": sequence,
        "event_type": event_type,
        "occurred_at": occurred_at,
        "recorded_at": occurred_at,
        "actor": actor,
        "causality": {
            "correlation_id": correlation_id,
            "causation_event_id": previous["event_id"] if previous else None,
            "request_id": request_id,
        },
        "concurrency": {
            "expected_record_revision": sequence - 1,
            "resulting_record_revision": sequence,
        },
        "binding_snapshot": {
            "contract_digest": contract_sha,
            "state_machine_digest": state_machine_sha,
        },
        "payload": payload,
        "evidence_refs": evidence_refs,
        "integrity": {
            "canonicalization": "registry-event-canonical-json-v1",
            "digest_algorithm": "sha256",
            "previous_event_digest": previous["integrity"]["event_digest"] if previous else None,
            "event_digest": None,
        },
    }
    event["integrity"]["event_digest"] = event_digest(event)
    return event


def artifact(artifact_id: str, artifact_type: str, version: str, uri: str, digest: str) -> dict[str, Any]:
    return {
        "artifact_id": artifact_id,
        "artifact_type": artifact_type,
        "version": version,
        "uri": uri,
        "digest": {"algorithm": "sha256", "value": digest},
    }


def atomic_write(files: dict[Path, bytes]) -> None:
    temporary: dict[Path, Path] = {}
    try:
        for path, data in files.items():
            path.parent.mkdir(parents=True, exist_ok=True)
            temp = path.with_name(path.name + ".gate3-start.tmp")
            temp.write_bytes(data)
            temporary[path] = temp
        for path, temp in temporary.items():
            os.replace(temp, path)
    finally:
        for temp in temporary.values():
            temp.unlink(missing_ok=True)


def main() -> None:
    contract_sha, state_machine_sha, organization_sha = verify_preflight()
    occurred_at = now_china()
    loop_id = str(uuid.uuid4())
    correlation_id = str(uuid.uuid4())
    owner_assignment = {
        "actor_id": PM_ACTOR["actor_id"],
        "role": PM_ACTOR["role"],
        "assignment_id": str(uuid.uuid4()),
        "authority_id": PM_ACTOR["authority_id"],
        "assigned_by": "project-owner",
        "effective_from": occurred_at,
    }
    budget_limits = {
        "iteration_limit": 5,
        "time_limit_seconds": None,
        "cost_limit": {"amount": 0, "unit": "CNY"},
    }
    history: list[dict[str, Any]] = []
    history.append(
        make_event(
            history,
            loop_id,
            "core.loop_registered",
            PM_ACTOR,
            {
                "project_id": "veilfront-xiangqi-siege",
                "initial_state": "draft",
                "identity": {
                    "display_key": "LOOP-GATE3-001",
                    "title": "第三生产循环v1——二维内容制作、交互打磨与集成冻结",
                    "created_at": occurred_at,
                    "created_by": PM_ACTOR,
                },
                "contract_binding": {
                    "contract_id": CONTRACT_ID,
                    "contract_version": CONTRACT_VERSION,
                    "contract_digest": contract_sha,
                },
                "state_machine_binding": {
                    "state_machine_id": "LOOP-SM-DEFAULT",
                    "state_machine_version": "0.2",
                    "state_machine_digest": state_machine_sha,
                },
                "parent_loop_id": None,
                "owner_assignment": owner_assignment,
                "budget_limits": budget_limits,
            },
            [f"game-pipeline/approvals/loop-contract-content-integration-gate3-v1-7c735748becb.yaml@subject-digest:{APPROVED_SOURCE_DIGEST}"],
            "register-approved-content-integration-gate3-loop",
            correlation_id,
            occurred_at,
            contract_sha,
            state_machine_sha,
        )
    )

    executors = [
        {
            "actor_id": "inst:01M02NJ3JEQXKV6PT6DPX0NKQ0",
            "role": "pos:veilfront-xiangqi-siege:technology:godot-technical-lead",
            "assignment_id": str(uuid.uuid4()),
            "authority_id": "AUTH-VEILFRONT-GODOT-TECHNOLOGY",
            "scope": ["TASK-EXPORT-G3-001", "TASK-CUE-CONTRACT-G3-001", "TASK-SFX-G3-001"],
        },
        {
            "actor_id": "inst:01M02NJ3JENHD8VV7EKC9G198Q",
            "role": "pos:veilfront-xiangqi-siege:design-experience:systems-experience-lead",
            "assignment_id": str(uuid.uuid4()),
            "authority_id": "AUTH-VEILFRONT-SYSTEMS-EXPERIENCE",
            "scope": ["TASK-UI-FOUNDATION-G3-001", "TASK-UIUX-G3-001", "TASK-CONTENT-G3-001"],
        },
        {
            "actor_id": "pos:veilfront-xiangqi-siege:design-experience:visual-production-lead",
            "role": "pos:veilfront-xiangqi-siege:design-experience:visual-production-lead",
            "assignment_id": str(uuid.uuid4()),
            "authority_id": "AUTH-VEILFRONT-VISUAL-PRODUCTION",
            "scope": ["TASK-VFX-G3-001"],
        },
    ]
    reviewers = [
        {
            "actor_id": "inst:01M02NJ3JFHVZ5C4SP5MTJFJR6",
            "role": "pos:veilfront-xiangqi-siege:quality:qa-release-lead",
            "assignment_id": str(uuid.uuid4()),
            "review_scope": [
                "CHECK-CONTRACT-G3-001",
                "CHECK-EXPORT-G3-001",
                "CHECK-INFORMATION-G3-001",
                "CHECK-AUDIO-G3-001",
                "CHECK-VFX-G3-001",
                "CHECK-UIUX-G3-001",
                "CHECK-CONTENT-G3-001",
                "CHECK-RESPONSIVE-G3-001",
                "CHECK-PERFORMANCE-G3-001",
                "CHECK-REGRESSION-G3-001",
                "CHECK-SCOPE-G3-001",
            ],
        },
        {
            "actor_id": "project-owner",
            "role": "project-owner",
            "assignment_id": str(uuid.uuid4()),
            "review_scope": ["GATE-3"],
        },
    ]
    for assignment in executors:
        history.append(
            make_event(
                history,
                loop_id,
                "core.assignment_changed",
                PM_ACTOR,
                {"assignment_kind": "executor", "operation": "add", "before": None, "after": assignment},
                ["game-pipeline/organization/snapshot.yaml", f"contract:{CONTRACT_ID}@v1"],
                f"assign-{assignment['role']}",
                correlation_id,
                occurred_at,
                contract_sha,
                state_machine_sha,
            )
        )
    for assignment in reviewers:
        history.append(
            make_event(
                history,
                loop_id,
                "core.assignment_changed",
                PM_ACTOR,
                {"assignment_kind": "reviewer", "operation": "add", "before": None, "after": assignment},
                ["game-pipeline/organization/snapshot.yaml", f"contract:{CONTRACT_ID}@v1"],
                f"assign-reviewer-{assignment['role']}",
                correlation_id,
                occurred_at,
                contract_sha,
                state_machine_sha,
            )
        )

    input_specs = [
        (
            "INPUT-GATE2-HANDOFF-001",
            artifact(
                "artifact:veilfront-xiangqi-siege:gate2-final-handoff@rc5",
                "approved-gate2-final-handoff",
                "gate2-rc5-registry-r102",
                "game-pipeline/loops/evidence/GATE-2-v3-final-handoff.md",
                file_sha(PROJECT_ROOT / "game-pipeline/loops/evidence/GATE-2-v3-final-handoff.md"),
            ),
            GATE2_LOOP_ID,
        ),
        (
            "INPUT-AUDIO-PROPOSAL-001",
            artifact(
                "artifact:veilfront-xiangqi-siege:observer-safe-audio-proposal@v1",
                "observer-safe-audio-contract-proposal",
                "v1",
                "docs/audio/veilfront-bgm-sfx-contract-proposal-v1.md",
                file_sha(PROJECT_ROOT / "docs/audio/veilfront-bgm-sfx-contract-proposal-v1.md"),
            ),
            None,
        ),
        (
            "INPUT-UI-AUDIT-001",
            artifact(
                "artifact:veilfront-xiangqi-siege:ui-ux-audit@2026-08-23",
                "ui-ux-audit",
                "2026-08-23",
                "docs/ui/ui-ux-audit-2026-08-23.md",
                file_sha(PROJECT_ROOT / "docs/ui/ui-ux-audit-2026-08-23.md"),
            ),
            None,
        ),
        (
            "INPUT-CONTENT-CATALOG-001",
            artifact(
                "artifact:veilfront-xiangqi-siege:level-catalog@gate3-entry",
                "tutorial-and-challenge-catalog",
                "T0-T10-C1-C3-entry",
                "resources/game/levels/level_catalog.tres",
                file_sha(PROJECT_ROOT / "resources/game/levels/level_catalog.tres"),
            ),
            None,
        ),
        (
            "INPUT-ORG-G3-001",
            artifact(
                "registry:veilfront-xiangqi-siege:organization@current",
                "approved-organization-and-authority",
                "current-approved-snapshot",
                "game-pipeline/organization/snapshot.yaml",
                organization_sha,
            ),
            None,
        ),
    ]
    bound_inputs: list[dict[str, Any]] = []
    for slot_id, artifact_value, source_loop_id in input_specs:
        after = {
            "input_slot_id": slot_id,
            "artifact": artifact_value,
            "source_loop_id": source_loop_id,
            "bound_by_event_id": "PENDING_EVENT_ID",
            "bound_at": occurred_at,
        }
        event = make_event(
            history,
            loop_id,
            "core.input_bound",
            PM_ACTOR,
            {"input_slot_id": slot_id, "before": None, "after": after},
            [artifact_value["uri"]],
            f"bind-{slot_id}",
            correlation_id,
            occurred_at,
            contract_sha,
            state_machine_sha,
        )
        event["payload"]["after"]["bound_by_event_id"] = event["event_id"]
        event["integrity"]["event_digest"] = event_digest(event)
        history.append(event)
        bound_inputs.append(copy.deepcopy(event["payload"]["after"]))

    input_set_digest = canonical_digest(
        [{"input_slot_id": item["input_slot_id"], "digest": item["artifact"]["digest"]["value"]} for item in bound_inputs]
    )
    ready_event = make_event(
        history,
        loop_id,
        "core.state_transitioned",
        PM_ACTOR,
        {
            "transition_id": "TR-DRAFT-READY",
            "from_state": "draft",
            "to_state": "ready",
            "iteration": {"before": 0, "after": 0},
            "reason": "approved_contract_inputs_authority_budget_and_gate2_handoff_validated",
            "subject_digest": input_set_digest,
        },
        [
            f"game-pipeline/approvals/loop-contract-content-integration-gate3-v1-7c735748becb.yaml@subject-digest:{APPROVED_SOURCE_DIGEST}",
            f"game-pipeline/approvals/gate-2-approval-0213f500a100.yaml@approval-id:{GATE2_APPROVAL_ID}",
        ],
        "gate3-loop-registration-validated",
        correlation_id,
        occurred_at,
        contract_sha,
        state_machine_sha,
    )
    history.append(ready_event)
    started_event = make_event(
        history,
        loop_id,
        "core.loop_started",
        PM_ACTOR,
        {
            "transition_id": "TR-READY-ACTIVE",
            "from_state": "ready",
            "to_state": "active",
            "iteration": {"before": 0, "after": 1},
            "reason": "start_ITERATION-1-BUDGET-AND-CUE-FOUNDATION_after_all_entry_conditions_passed",
        },
        [
            f"event:{ready_event['event_id']}@digest:{ready_event['integrity']['event_digest']}",
            "game-pipeline/loops/evidence/GATE-2-v3-final-handoff.md",
        ],
        "start-content-integration-gate3-iteration-1",
        correlation_id,
        occurred_at,
        contract_sha,
        state_machine_sha,
    )
    history.append(started_event)

    snapshot = {
        "registry_snapshot": {
            "schema_version": "0.1",
            "identity": {
                "loop_instance_id": loop_id,
                "project_id": "veilfront-xiangqi-siege",
                "display_key": "LOOP-GATE3-001",
                "title": "第三生产循环v1——二维内容制作、交互打磨与集成冻结",
                "created_at": occurred_at,
                "created_by": PM_ACTOR,
            },
            "contract_binding": {
                "contract_id": CONTRACT_ID,
                "contract_version": CONTRACT_VERSION,
                "contract_digest": contract_sha,
            },
            "state_machine_binding": {
                "state_machine_id": "LOOP-SM-DEFAULT",
                "state_machine_version": "0.2",
                "state_machine_digest": state_machine_sha,
            },
            "topology": {"parent_loop_id": None, "dependencies": []},
            "responsibility": {"owner": owner_assignment, "executors": executors, "reviewers": reviewers},
            "runtime": {
                "current_state": "active",
                "state_entered_at": occurred_at,
                "current_iteration": 1,
                "last_transition_id": "TR-READY-ACTIVE",
                "last_event_id": started_event["event_id"],
                "last_event_digest": started_event["integrity"]["event_digest"],
                "last_event_sequence": len(history),
                "record_revision": len(history),
            },
            "budget": {
                "limits": budget_limits,
                "usage": {
                    "completed_iterations": 0,
                    "active_time_seconds": 0,
                    "cost": {"amount": 0, "unit": "CNY"},
                },
                "status": "available",
                "last_updated_at": occurred_at,
            },
            "resources": {"inputs": bound_inputs, "outputs": []},
            "acceptance_snapshot": {
                "subject_digest": None,
                "automated_checks": [],
                "professional_reviews": [],
                "human_gates": [],
                "final_handoff_ref": None,
            },
            "interruption": None,
            "pending_approvals": [],
        }
    }

    if [event["sequence"] for event in history] != list(range(1, len(history) + 1)):
        raise RuntimeError("event sequence is not continuous")
    if any(event["integrity"]["event_digest"] != event_digest(event) for event in history):
        raise RuntimeError("event digest verification failed before write")
    for previous, current in zip(history, history[1:]):
        if current["integrity"]["previous_event_digest"] != previous["integrity"]["event_digest"]:
            raise RuntimeError("event history chain is broken before write")

    atomic_write(
        {
            SNAPSHOT_PATH: dump_yaml(snapshot),
            HISTORY_PATH: dump_yaml({"event_history": history}),
        }
    )
    print(
        json.dumps(
            {
                "result": "started",
                "loop_instance_id": loop_id,
                "state": "active",
                "iteration": 1,
                "record_revision": len(history),
                "last_event_sequence": len(history),
                "last_event_digest": started_event["integrity"]["event_digest"],
                "input_set_digest": input_set_digest,
                "contract_digest": contract_sha,
                "state_machine_digest": state_machine_sha,
            },
            ensure_ascii=False,
            indent=2,
        )
    )


if __name__ == "__main__":
    main()
