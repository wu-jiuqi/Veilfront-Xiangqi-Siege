#!/usr/bin/env python3
"""Append the owner-authorized GATE-2 iteration catch-up to the Loop Registry."""

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
LOOP_ID = "83c995ff-37b9-4df8-9e84-8417d6632187"
CONTRACT_DIGEST = "a26a9b3fdb0d8d06e42a06833a84455d911fea8f72bcedec59d0ae5e620cc205"
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


def output_binding(deliverable_id: str, artifact_type: str, uri: str, digest: str, event_id: str, version: str) -> dict[str, Any]:
    return {
        "deliverable_id": deliverable_id,
        "artifact": {
            "artifact_id": f"artifact:veilfront-xiangqi-siege:{deliverable_id.lower()}@{version}",
            "artifact_type": artifact_type,
            "version": version,
            "uri": uri,
            "digest": {"algorithm": "sha256", "value": digest},
            "manifest_paths": [uri],
        },
        "status": "accepted_for_iteration_progression",
        "registered_by_event_id": event_id,
        "registered_at": None,
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


def advance(args: argparse.Namespace) -> None:
    snapshot_doc = load_yaml(SNAPSHOT_PATH)
    history_doc = load_yaml(HISTORY_PATH)
    snapshot = snapshot_doc["registry_snapshot"]
    history = history_doc["event_history"]
    runtime = snapshot["runtime"]
    if snapshot["identity"]["loop_instance_id"] != LOOP_ID:
        raise RuntimeError("loop identity mismatch")
    if runtime["current_state"] != "active" or runtime["current_iteration"] != 1:
        raise RuntimeError("advance-to-iteration3 requires active iteration 1")
    if runtime["last_event_digest"] != history[-1]["integrity"]["event_digest"]:
        raise RuntimeError("snapshot/history tail mismatch")
    if args.candidate_commit != "245f5c9e" and not args.candidate_commit.startswith("245f5c9"):
        raise RuntimeError("candidate commit must be the R3 commit 245f5c9")
    owner_decision = Path(args.owner_decision)
    if not owner_decision.is_absolute():
        owner_decision = PROJECT_ROOT / owner_decision
    if not owner_decision.is_file():
        raise RuntimeError(f"owner decision missing: {owner_decision}")
    handoff = PROJECT_ROOT / args.iteration1_handoff
    if not handoff.is_file():
        raise RuntimeError(f"iteration 1 handoff missing: {handoff}")
    if any(event.get("payload", {}).get("transition_id") == "TR-ITERATION3-STARTED" for event in history):
        raise RuntimeError("iteration 3 transition already applied")

    occurred_at = now_china()
    correlation_id = str(uuid.uuid4())
    owner_sha = sha256_file(owner_decision)
    handoff_sha = sha256_file(handoff)
    r3_evidence = PROJECT_ROOT / "evidence/gate2/iteration2-core-migration-remediation-r3-v1.md"
    r3_sha = sha256_file(r3_evidence)

    add_event(
        history,
        "core.acceptance_recorded",
        {
            "acceptance_kind": "owner_iteration_exception",
            "record_id": "OWNER-DECISION-ITERATION2-R4",
            "subject_digest": owner_sha,
            "record": {
                "decision": "accepted_with_sampling_exception",
                "independent_review_status": "deferred_not_approved",
                "1000_seed_status": "cancelled_by_project_owner_not_passed",
                "scope": "iteration-2-r3",
            },
        },
        ["evidence/gate2/iteration2-owner-decision-r4.md", "evidence/gate2/iteration2-core-migration-remediation-r3-v1.md"],
        correlation_id,
        "record-owner-iteration2-r4-decision",
        occurred_at,
    )

    for deliverable_id, artifact_type, uri, digest, version in (
        ("DELIVERABLE-ARCH-001", "approved-formal-architecture-baseline", "docs/godot-prompter/specs/formal-godot-scene-composition-v1.md", sha256_file(PROJECT_ROOT / "docs/godot-prompter/specs/formal-godot-scene-composition-v1.md"), "iteration1"),
        ("DELIVERABLE-PRESENTATION-001", "preset-godot-match-shell", "scenes/game/app/game_app.tscn", sha256_file(PROJECT_ROOT / "scenes/game/app/game_app.tscn"), "iteration1"),
    ):
        event = add_event(
            history,
            "core.output_registered",
            {
                "deliverable_id": deliverable_id,
                "before": None,
                "after": output_binding(deliverable_id, artifact_type, uri, digest, "pending", version),
            },
            [uri, "evidence/gate2/iteration1-completion-handoff-v1.md"],
            correlation_id,
            f"register-{deliverable_id}-iteration1",
            occurred_at,
        )
        event["payload"]["after"]["registered_by_event_id"] = event["event_id"]
        event["payload"]["after"]["registered_at"] = occurred_at
        event["integrity"]["event_digest"] = event_digest(event)

    add_event(
        history,
        "core.state_transitioned",
        {
            "transition_id": "TR-ACTIVE-REVIEW",
            "from_state": "active",
            "to_state": "review",
            "iteration": {"before": 1, "after": 1},
            "reason": "iteration_1_architecture_and_shell_owner_accepted",
            "subject_digest": handoff_sha,
        },
        [args.iteration1_handoff],
        correlation_id,
        "complete-iteration-1-architecture",
        occurred_at,
    )
    add_event(
        history,
        "core.state_transitioned",
        {
            "transition_id": "TR-REVIEW-ACTIVE",
            "from_state": "review",
            "to_state": "active",
            "iteration": {"before": 1, "after": 2},
            "reason": "start_iteration_2_core_migration_owner_authorized",
            "subject_digest": r3_sha,
        },
        ["evidence/gate2/iteration2-core-migration-remediation-r3-v1.md", args.owner_decision],
        correlation_id,
        "start-iteration-2-core-migration",
        occurred_at,
    )
    for deliverable_id, artifact_type, uri, digest, version in (
        ("DELIVERABLE-MIGRATION-001", "behavior-preserving-formal-core", "evidence/gate2/iteration2-core-migration-remediation-r3-v1.md", r3_sha, "r3-owner-exception"),
        ("DELIVERABLE-QA-002", "iteration2-regression-evidence", "evidence/gate2/iteration2-core-migration-remediation-r3-v1.md", r3_sha, "r3-producer-evidence"),
    ):
        event = add_event(
            history,
            "core.output_registered",
            {
                "deliverable_id": deliverable_id,
                "before": None,
                "after": output_binding(deliverable_id, artifact_type, uri, digest, "pending", version),
            },
            ["evidence/gate2/iteration2-core-migration-remediation-r3-v1.md", args.owner_decision],
            correlation_id,
            f"register-{deliverable_id}-iteration2-r3",
            occurred_at,
        )
        event["payload"]["after"]["registered_by_event_id"] = event["event_id"]
        event["payload"]["after"]["registered_at"] = occurred_at
        event["integrity"]["event_digest"] = event_digest(event)

    add_event(
        history,
        "core.state_transitioned",
        {
            "transition_id": "TR-ACTIVE-REVIEW",
            "from_state": "active",
            "to_state": "review",
            "iteration": {"before": 2, "after": 2},
            "reason": "iteration_2_core_migration_owner_accepted_with_1000_seed_exception",
            "subject_digest": r3_sha,
        },
        ["evidence/gate2/iteration2-core-migration-remediation-r3-v1.md", args.owner_decision],
        correlation_id,
        "complete-iteration-2-core-migration-owner-decision",
        occurred_at,
    )
    add_event(
        history,
        "core.state_transitioned",
        {
            "transition_id": "TR-REVIEW-ACTIVE",
            "from_state": "review",
            "to_state": "active",
            "iteration": {"before": 2, "after": 3},
            "reason": "start_iteration_3_tutorial_visual_owner_authorized",
            "subject_digest": sha256_file(PROJECT_ROOT / "docs/godot-prompter/specs/2026-08-19-main-menu-and-level-mode-design.md"),
        },
        ["docs/godot-prompter/specs/2026-08-19-main-menu-and-level-mode-design.md", args.owner_decision],
        correlation_id,
        "start-iteration-3-tutorial-visual",
        occurred_at,
    )

    runtime.update({
        "current_state": "active",
        "current_iteration": 3,
        "last_transition_id": "TR-REVIEW-ACTIVE",
        "last_event_id": history[-1]["event_id"],
        "last_event_digest": history[-1]["integrity"]["event_digest"],
        "last_event_sequence": len(history),
        "record_revision": len(history),
        "state_entered_at": occurred_at,
    })
    snapshot["resources"]["outputs"] = [
        event["payload"]["after"]
        for event in history
        if event["event_type"] == "core.output_registered"
    ]
    snapshot["acceptance_snapshot"]["subject_digest"] = owner_sha
    snapshot["acceptance_snapshot"]["human_gates"] = [{
        "gate_id": "OWNER-ITERATION2-R4",
        "decision": "accepted_with_sampling_exception",
        "evidence_ref": "evidence/gate2/iteration2-owner-decision-r4.md",
        "1000_seed": "cancelled_not_passed",
        "independent_reviews": "deferred",
    }]
    history_doc["event_history"] = history
    write_pair(snapshot_doc, history_doc)
    print(json.dumps({"result": "advanced", "iteration": 3, "state": "active", "events_appended": len(history) - 14, "record_revision": len(history)}, ensure_ascii=False))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)
    advance_parser = subparsers.add_parser("advance-to-iteration3")
    advance_parser.add_argument("--iteration1-handoff", required=True)
    advance_parser.add_argument("--owner-decision", required=True)
    advance_parser.add_argument("--candidate-commit", required=True)
    args = parser.parse_args()
    if args.command == "advance-to-iteration3":
        advance(args)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
