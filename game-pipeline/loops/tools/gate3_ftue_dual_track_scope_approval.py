#!/usr/bin/env python3
"""Bind the owner-approved dual-track FTUE addendum to the active GATE-3 loop."""

from __future__ import annotations

import copy
import json
import uuid
from typing import Any

from gate3_v1_iteration1_progress import (
    HISTORY_PATH,
    LOOP_ID,
    PM_ACTOR,
    PROJECT_ROOT,
    SNAPSHOT_PATH,
    add_event,
    canonical_digest,
    event_digest,
    load_yaml,
    now_china,
    write_pair,
)


DECISION_URI = "game-pipeline/loops/evidence/FTUE-DUAL-TRACK-OWNER-EXCEPTION-decision-package-v1.yaml"
APPROVAL_URI = "game-pipeline/approvals/production-scope-exception-ftue-dual-track-6e2d0f83914e.yaml"
PROPOSAL_URI = "docs/design/tutorial/veilfront-ftue-content-coverage-and-ux-proposal-v1.md"
SUBJECT_DIGEST = "6e2d0f83914ed58ee053f082325503f0136e672ee392b9639ba03961d42a080e"
RECORD_ID = "OWNER-SCOPE-EXCEPTION-FTUE-DUAL-TRACK-001"
INPUT_SLOT_ID = "INPUT-FTUE-DUAL-TRACK-EXCEPTION-001"


def append_unique(values: list[str], additions: list[str]) -> list[str]:
    return values + [value for value in additions if value not in values]


def find_assignment(collection: list[dict[str, Any]], role: str) -> dict[str, Any]:
    assignment = next((item for item in collection if item.get("role") == role), None)
    if assignment is None:
        raise RuntimeError(f"registered assignment missing: {role}")
    return assignment


def validate_approval() -> dict[str, Any]:
    decision_doc = load_yaml(PROJECT_ROOT / DECISION_URI)
    approval_doc = load_yaml(PROJECT_ROOT / APPROVAL_URI)["approval"]
    actual_digest = canonical_digest(decision_doc["exception_subject"])
    if actual_digest != SUBJECT_DIGEST:
        raise RuntimeError("FTUE exception subject digest mismatch")
    if approval_doc.get("subject_digest") != SUBJECT_DIGEST:
        raise RuntimeError("FTUE approval subject digest mismatch")
    if approval_doc.get("decision") != "approved":
        raise RuntimeError("FTUE approval is not approved")
    confirmation = approval_doc.get("evidence", {}).get("confirmation", {})
    if confirmation.get("received_digest") != SUBJECT_DIGEST:
        raise RuntimeError("FTUE exact digest confirmation is missing")
    if confirmation.get("matches_subject_digest") is not True:
        raise RuntimeError("FTUE exact digest confirmation is invalid")
    return approval_doc


def main() -> None:
    approval_doc = validate_approval()
    snapshot_doc = load_yaml(SNAPSHOT_PATH)
    history_doc = load_yaml(HISTORY_PATH)
    snapshot = snapshot_doc["registry_snapshot"]
    history = history_doc["event_history"]
    runtime = snapshot["runtime"]
    if snapshot["identity"]["loop_instance_id"] != LOOP_ID:
        raise RuntimeError("loop identity mismatch")
    if runtime["current_state"] != "active" or runtime["current_iteration"] != 2:
        raise RuntimeError("FTUE scope approval requires active GATE-3 iteration 2")
    if runtime["last_event_digest"] != history[-1]["integrity"]["event_digest"]:
        raise RuntimeError("snapshot/history tail mismatch")
    if any(event.get("payload", {}).get("record_id") == RECORD_ID for event in history):
        print(json.dumps({"result": "already-applied", "record_revision": len(history)}, ensure_ascii=False))
        return

    evidence_refs = [DECISION_URI, APPROVAL_URI, PROPOSAL_URI]
    for relative_path in evidence_refs:
        if not (PROJECT_ROOT / relative_path).is_file():
            raise RuntimeError(f"FTUE approval evidence missing: {relative_path}")

    occurred_at = now_china()
    correlation_id = str(uuid.uuid4())
    acceptance_record = {
        "gate_id": RECORD_ID,
        "decision": "approved",
        "evidence_ref": APPROVAL_URI,
        "subject_digest": SUBJECT_DIGEST,
        "release_approval": False,
    }
    add_event(
        snapshot,
        history,
        "core.acceptance_recorded",
        PM_ACTOR,
        {
            "acceptance_kind": "owner_scope_exception",
            "record_id": RECORD_ID,
            "subject_digest": SUBJECT_DIGEST,
            "record": acceptance_record,
        },
        evidence_refs,
        correlation_id,
        "record-owner-ftue-dual-track-scope-exception",
        occurred_at,
    )

    input_binding = {
        "input_slot_id": INPUT_SLOT_ID,
        "artifact": {
            "artifact_id": "artifact:veilfront-xiangqi-siege:ftue-dual-track-scope-exception@v1",
            "artifact_type": "owner-approved-production-scope-exception",
            "version": "v1@subject:6e2d0f83914e",
            "uri": DECISION_URI,
            "digest": {"algorithm": "sha256", "value": SUBJECT_DIGEST},
            "manifest_paths": evidence_refs,
        },
        "source_loop_id": None,
        "bound_by_event_id": "pending",
        "bound_at": occurred_at,
    }
    input_event = add_event(
        snapshot,
        history,
        "core.input_bound",
        PM_ACTOR,
        {"input_slot_id": INPUT_SLOT_ID, "before": None, "after": input_binding},
        evidence_refs,
        correlation_id,
        "bind-ftue-dual-track-scope-exception",
        occurred_at,
    )
    input_binding["bound_by_event_id"] = input_event["event_id"]
    input_event["payload"]["after"]["bound_by_event_id"] = input_event["event_id"]
    input_event["integrity"]["event_digest"] = event_digest(input_event)
    runtime["last_event_digest"] = input_event["integrity"]["event_digest"]

    assignment_updates = (
        (
            "executors",
            "executor",
            "pos:veilfront-xiangqi-siege:technology:godot-technical-lead",
            "scope",
            ["TASK-FTUE-DATA-G3-EX-001", "TASK-FTUE-RUNTIME-G3-EX-001", "TASK-FTUE-MIGRATION-G3-EX-001"],
        ),
        (
            "executors",
            "executor",
            "pos:veilfront-xiangqi-siege:design-experience:systems-experience-lead",
            "scope",
            ["TASK-FTUE-UX-G3-EX-001", "TASK-FTUE-CONTENT-G3-EX-001"],
        ),
        (
            "reviewers",
            "reviewer",
            "pos:veilfront-xiangqi-siege:quality:qa-release-lead",
            "review_scope",
            [
                "CHECK-FTUE-ROUTES-G3-EX-001",
                "CHECK-FTUE-PROGRESS-G3-EX-001",
                "CHECK-FTUE-INFORMATION-G3-EX-001",
                "CHECK-FTUE-RESPONSIVE-G3-EX-001",
                "CHECK-FTUE-REGRESSION-G3-EX-001",
            ],
        ),
    )
    for collection_name, assignment_kind, role, field, additions in assignment_updates:
        current = find_assignment(snapshot["responsibility"][collection_name], role)
        before = copy.deepcopy(current)
        after = copy.deepcopy(current)
        after[field] = append_unique(list(after.get(field, [])), additions)
        add_event(
            snapshot,
            history,
            "core.assignment_changed",
            PM_ACTOR,
            {"assignment_kind": assignment_kind, "operation": "update", "before": before, "after": after},
            evidence_refs,
            correlation_id,
            f"extend-{assignment_kind}-{role.rsplit(':', 1)[-1]}-ftue-dual-track",
            occurred_at,
        )
        current.clear()
        current.update(after)

    snapshot["resources"]["inputs"].append(copy.deepcopy(input_binding))
    snapshot["acceptance_snapshot"]["human_gates"].append(acceptance_record)
    write_pair(snapshot_doc, history_doc)
    print(
        json.dumps(
            {
                "result": "applied",
                "events_appended": 5,
                "record_revision": runtime["record_revision"],
                "subject_digest": SUBJECT_DIGEST,
                "approval_id": approval_doc["approval_id"],
            },
            ensure_ascii=False,
        )
    )


if __name__ == "__main__":
    main()
