#!/usr/bin/env python3
"""Register and start the approved formal-foundation GATE-2 production loop."""

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
CONTRACT_PATH = PROJECT_ROOT / "game-pipeline/loops/contracts/loop-contract-formal-foundation-gate2-v1.yaml"
CONTRACT_APPROVAL_PATH = PROJECT_ROOT / "game-pipeline/approvals/loop-contract-formal-foundation-gate2-v1-9beb91baa720.yaml"
STATE_MACHINE_PATH = PLUGIN_ROOT / "contracts/loop-state-machine.default.yaml"
ORG_SNAPSHOT_PATH = PROJECT_ROOT / "game-pipeline/organization/snapshot.yaml"
INPUT_BINDING_PATH = PROJECT_ROOT / "game-pipeline/loops/evidence/GATE2-architecture-input-binding.yaml"
REGISTRY_DIR = PROJECT_ROOT / "game-pipeline/loops/registry/formal-foundation-gate2"
SNAPSHOT_PATH = REGISTRY_DIR / "snapshot.yaml"
HISTORY_PATH = REGISTRY_DIR / "event-history.yaml"

CONTRACT_ID = "LOOP-CTR-FORMAL-FOUNDATION-GATE2-001"
CONTRACT_VERSION = 1
APPROVED_SOURCE_DIGEST = "9beb91baa720820d0f0985019e5a77a4e0e065a8721451eedc30e0cc22bdeaef"
ARCH_INPUT_SUBJECT_DIGEST = "0149aa0189238d7cfd9535887bf6118d540d57a9bd3fbcbee48c018f8051975f"
BRIEF_SUBJECT_DIGEST = "41bb82fae4f1a0294d17746f3b9caf063ee69d2bd07e0f7d15d26baad9ab89bb"
GATE1_SUBJECT_DIGEST = "8f93c3506192b1e286bd5f1bf631054f9fb3f0dc5337f3050716a2186a383597"
GATE1_HANDOFF_SHA = "3b186b38ea18728174100b5fc60c9785c344c2bfb22dfa0a303a944398db1753"
RULES_BASELINE_SHA = "0502e20a861a550e9845cfa1a10e4b5d94b97d1da884add2d0de70e9fa14daa4"

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
        raise RuntimeError("formal-foundation-gate2 registry already exists; refusing duplicate registration")

    contract_doc = load_yaml(CONTRACT_PATH)
    contract = contract_doc["loop_contract"]
    if contract["contract_id"] != CONTRACT_ID or contract["version"] != CONTRACT_VERSION:
        raise RuntimeError("contract identity mismatch")
    if contract["status"] != "approved":
        raise RuntimeError("contract is not approved")
    if contract_doc["approval_binding"]["subject_digest"] != APPROVED_SOURCE_DIGEST:
        raise RuntimeError("contract approval binding mismatch")

    approval = load_yaml(CONTRACT_APPROVAL_PATH)["approval"]
    contract_sha = file_sha(CONTRACT_PATH)
    if approval["subject_digest"] != APPROVED_SOURCE_DIGEST:
        raise RuntimeError("approval subject mismatch")
    if approval["application"]["materialized_digest"] != contract_sha:
        raise RuntimeError("materialized contract digest mismatch")

    input_binding = load_yaml(INPUT_BINDING_PATH)["architecture_input_binding"]
    calculated = canonical_digest(input_binding["subject"])
    if input_binding["status"] != "satisfied" or calculated != ARCH_INPUT_SUBJECT_DIGEST:
        raise RuntimeError("architecture input binding is not satisfied or digest-matched")
    if input_binding["subject_digest"] != calculated:
        raise RuntimeError("architecture input binding recorded digest mismatch")

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


def first_event(
    loop_id: str,
    occurred_at: str,
    correlation_id: str,
    contract_sha: str,
    state_machine_sha: str,
    owner_assignment: dict[str, Any],
    budget_limits: dict[str, Any],
) -> dict[str, Any]:
    event = {
        "schema_version": "0.1",
        "event_id": str(uuid.uuid4()),
        "mutation_id": str(uuid.uuid4()),
        "loop_instance_id": loop_id,
        "sequence": 1,
        "event_type": "core.loop_registered",
        "occurred_at": occurred_at,
        "recorded_at": occurred_at,
        "actor": PM_ACTOR,
        "causality": {
            "correlation_id": correlation_id,
            "causation_event_id": None,
            "request_id": "register-approved-formal-foundation-gate2-loop",
        },
        "concurrency": {"expected_record_revision": 0, "resulting_record_revision": 1},
        "binding_snapshot": {
            "contract_digest": contract_sha,
            "state_machine_digest": state_machine_sha,
        },
        "payload": {
            "project_id": "veilfront-xiangqi-siege",
            "initial_state": "draft",
            "identity": {
                "display_key": "LOOP-GATE2-001",
                "title": "第二生产循环——正式架构、教学灰盒与视觉基线",
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
        "evidence_refs": [
            f"game-pipeline/approvals/loop-contract-formal-foundation-gate2-v1-9beb91baa720.yaml@subject-digest:{APPROVED_SOURCE_DIGEST}",
        ],
        "integrity": {
            "canonicalization": "registry-event-canonical-json-v1",
            "digest_algorithm": "sha256",
            "previous_event_digest": None,
            "event_digest": None,
        },
    }
    event["integrity"]["event_digest"] = event_digest(event)
    return event


def next_event(
    history: list[dict[str, Any]],
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
    previous = history[-1]
    event = {
        "schema_version": "0.1",
        "event_id": str(uuid.uuid4()),
        "mutation_id": str(uuid.uuid4()),
        "loop_instance_id": previous["loop_instance_id"],
        "sequence": sequence,
        "event_type": event_type,
        "occurred_at": occurred_at,
        "recorded_at": occurred_at,
        "actor": actor,
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
            "contract_digest": contract_sha,
            "state_machine_digest": state_machine_sha,
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
    return event


def artifact(
    artifact_id: str,
    artifact_type: str,
    version: str,
    uri: str,
    digest: str,
    manifest_paths: list[str] | None = None,
) -> dict[str, Any]:
    value: dict[str, Any] = {
        "artifact_id": artifact_id,
        "artifact_type": artifact_type,
        "version": version,
        "uri": uri,
        "digest": {"algorithm": "sha256", "value": digest},
    }
    if manifest_paths:
        value["manifest_paths"] = manifest_paths
    return value


def atomic_write(files: dict[Path, bytes]) -> None:
    temps: dict[Path, Path] = {}
    try:
        for path, data in files.items():
            path.parent.mkdir(parents=True, exist_ok=True)
            temp = path.with_name(path.name + ".gate2-start.tmp")
            temp.write_bytes(data)
            temps[path] = temp
        for path, temp in temps.items():
            os.replace(temp, path)
    finally:
        for temp in temps.values():
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
        "iteration_limit": 4,
        "time_limit_seconds": None,
        "cost_limit": {"amount": None, "unit": None},
    }
    history = [
        first_event(
            loop_id,
            occurred_at,
            correlation_id,
            contract_sha,
            state_machine_sha,
            owner_assignment,
            budget_limits,
        )
    ]

    executors = [
        {
            "actor_id": "inst:01M02NJ3JEQXKV6PT6DPX0NKQ0",
            "role": "pos:veilfront-xiangqi-siege:technology:godot-technical-lead",
            "assignment_id": str(uuid.uuid4()),
            "authority_id": "AUTH-VEILFRONT-GODOT-TECHNOLOGY",
            "scope": ["TASK-ARCH-001", "TASK-SHELL-001", "TASK-CORE-001", "TASK-CORE-002"],
        },
        {
            "actor_id": "inst:01M02NJ3JENHD8VV7EKC9G198Q",
            "role": "pos:veilfront-xiangqi-siege:design-experience:systems-experience-lead",
            "assignment_id": str(uuid.uuid4()),
            "authority_id": "AUTH-VEILFRONT-SYSTEMS-EXPERIENCE",
            "scope": ["TASK-TUTORIAL-001", "TASK-TUTORIAL-002"],
        },
        {
            "actor_id": "pos:veilfront-xiangqi-siege:design-experience:visual-production-lead",
            "role": "pos:veilfront-xiangqi-siege:design-experience:visual-production-lead",
            "assignment_id": str(uuid.uuid4()),
            "authority_id": "AUTH-VEILFRONT-VISUAL-PRODUCTION",
            "scope": ["TASK-ART-001"],
        },
    ]
    reviewers = [
        {
            "actor_id": "inst:01M02NJ3JFHVZ5C4SP5MTJFJR6",
            "role": "pos:veilfront-xiangqi-siege:quality:qa-release-lead",
            "assignment_id": str(uuid.uuid4()),
            "review_scope": [
                "CHECK-CONTRACT-002",
                "CHECK-DEPENDENCY-001",
                "CHECK-MIGRATION-001",
                "CHECK-INFORMATION-002",
                "CHECK-TUTORIAL-001",
                "CHECK-GODOT-002",
                "CHECK-RESPONSIVE-001",
                "CHECK-ART-001",
                "CHECK-SCOPE-001",
            ],
        },
        {
            "actor_id": "project-owner",
            "role": "project-owner",
            "assignment_id": str(uuid.uuid4()),
            "review_scope": ["GATE-2"],
        },
    ]

    for assignment in executors:
        history.append(
            next_event(
                history,
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
            next_event(
                history,
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

    inputs = [
        (
            "INPUT-BRIEF-V5-001",
            artifact(
                "artifact:veilfront-xiangqi-siege:project-brief@v5",
                "confirmed-project-brief",
                f"5@subject:{BRIEF_SUBJECT_DIGEST}",
                "game-pipeline/project-definition/project-brief.yaml",
                BRIEF_SUBJECT_DIGEST,
            ),
        ),
        (
            "INPUT-GATE1-001",
            artifact(
                "artifact:veilfront-xiangqi-siege:gate1-final-handoff@rc3-v5",
                "approved-gate-handoff",
                f"approved@subject:{GATE1_SUBJECT_DIGEST}",
                "game-pipeline/loops/evidence/GATE-1-final-handoff.md",
                GATE1_HANDOFF_SHA,
            ),
        ),
        (
            "INPUT-ARCH-REVIEW-001",
            artifact(
                "artifact:veilfront-xiangqi-siege:formal-architecture-review@final-r2",
                "formal-architecture-review",
                f"v2-final-r2@subject:{ARCH_INPUT_SUBJECT_DIGEST}",
                "game-pipeline/loops/evidence/GATE2-architecture-input-binding.yaml",
                ARCH_INPUT_SUBJECT_DIGEST,
                [
                    "docs/architecture/post-gate1-formal-architecture-review-v2.md",
                    "docs/architecture/formal-dto-and-trust-boundary-v1.md",
                    "docs/architecture/gate1-to-formal-migration-manifest-v1.yaml",
                    "evidence/gate2/architecture-technical-final-rereview-v3.md",
                    "evidence/gate2/architecture-independent-qa-final-rereview-v3.md",
                ],
            ),
        ),
        (
            "INPUT-RULES-001",
            artifact(
                "artifact:veilfront-xiangqi-siege:gate1-behavior-baseline@revision5-r2",
                "gate1-behavior-baseline",
                "owner-rule-revision-5-r2",
                "docs/architecture/gate1-to-formal-migration-manifest-v1.yaml",
                RULES_BASELINE_SHA,
                [
                    "docs/prototype/rules-spec-v1.md",
                    "docs/prototype/settlement-order-v1.md",
                    "docs/prototype/information-boundary-v1.md",
                    "docs/prototype/rules-test-coverage-matrix-v1.md",
                    "evidence/prototype/qa/gate1-rc3-rules-stress-1000-seeds-round50.jsonl",
                ],
            ),
        ),
        (
            "INPUT-ORG-001",
            artifact(
                "registry:veilfront-xiangqi-siege:organization@current",
                "approved-organization-and-authority",
                "current-approved-snapshot",
                "game-pipeline/organization/snapshot.yaml",
                organization_sha,
            ),
        ),
    ]
    bound_inputs = []
    for slot_id, artifact_value in inputs:
        event = next_event(
            history,
            "core.input_bound",
            PM_ACTOR,
            {
                "input_slot_id": slot_id,
                "before": None,
                "after": {
                    "input_slot_id": slot_id,
                    "artifact": artifact_value,
                    "source_loop_id": None,
                    "bound_by_event_id": "PENDING_EVENT_ID",
                    "bound_at": occurred_at,
                },
            },
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
    ready_event = next_event(
        history,
        "core.state_transitioned",
        PM_ACTOR,
        {
            "transition_id": "TR-DRAFT-READY",
            "from_state": "draft",
            "to_state": "ready",
            "iteration": {"before": 0, "after": 0},
            "reason": "approved_contract_inputs_authority_budget_and_final_architecture_dual_review_validated",
            "subject_digest": input_set_digest,
        },
        [
            f"game-pipeline/loops/evidence/GATE2-architecture-input-binding.yaml@subject-digest:{ARCH_INPUT_SUBJECT_DIGEST}",
            "evidence/gate2/architecture-technical-final-rereview-v3.md",
            "evidence/gate2/architecture-independent-qa-final-rereview-v3.md",
        ],
        "gate2-loop-registration-validated",
        correlation_id,
        occurred_at,
        contract_sha,
        state_machine_sha,
    )
    history.append(ready_event)
    started_event = next_event(
        history,
        "core.loop_started",
        PM_ACTOR,
        {
            "transition_id": "TR-READY-ACTIVE",
            "from_state": "ready",
            "to_state": "active",
            "iteration": {"before": 0, "after": 1},
            "reason": "start_ITERATION-1-ARCHITECTURE_after_all_entry_conditions_passed",
        },
        [
            f"event:{ready_event['event_id']}@digest:{ready_event['integrity']['event_digest']}",
            f"game-pipeline/approvals/loop-contract-formal-foundation-gate2-v1-9beb91baa720.yaml@subject-digest:{APPROVED_SOURCE_DIGEST}",
        ],
        "start-formal-foundation-gate2-iteration-1",
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
                "display_key": "LOOP-GATE2-001",
                "title": "第二生产循环——正式架构、教学灰盒与视觉基线",
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
                    "cost": {"amount": 0, "unit": None},
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
