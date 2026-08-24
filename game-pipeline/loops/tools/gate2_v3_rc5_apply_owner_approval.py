#!/usr/bin/env python3
"""Apply the exact project-owner GATE-2 RC5 approval and complete the loop."""

from __future__ import annotations

import copy
import hashlib
import json
import uuid
from pathlib import Path
from typing import Any

import yaml

import gate2_v3_rc5_register_owner_review as registry_tools


PROJECT_ROOT = Path(__file__).resolve().parents[3]
SNAPSHOT_PATH = PROJECT_ROOT / "game-pipeline/loops/registry/formal-foundation-gate2/snapshot.yaml"
HISTORY_PATH = PROJECT_ROOT / "game-pipeline/loops/registry/formal-foundation-gate2/event-history.yaml"
PACKAGE_PATH = PROJECT_ROOT / "game-pipeline/loops/evidence/GATE-2-v3-decision-package.md"
HANDOFF_PATH = PROJECT_ROOT / "game-pipeline/loops/evidence/GATE-2-v3-final-handoff.md"
APPROVAL_PATH = PROJECT_ROOT / "game-pipeline/approvals/gate-2-approval-0213f500a100.yaml"

REQUEST_ID = "approval:veilfront-xiangqi-siege:gate-2:0213f500a100"
DECISION_DIGEST = "0213f500a10070198ccdf1090ddcdd2ea519828233251e9896076ff0ced68525"
BASELINE_SEQUENCE = 98
DECIDED_AT = "2026-08-24T16:47:40.6589920+08:00"
OWNER_ACTOR = {"actor_id": "project-owner", "role": "project-owner", "authority_id": "GATE-2"}


def load_package_decision() -> dict[str, Any]:
	text = PACKAGE_PATH.read_text(encoding="utf-8")
	start = text.index("```json\n") + len("```json\n")
	end = text.index("\n```", start)
	decision = json.loads(text[start:end])
	if registry_tools.canonical_digest(decision) != DECISION_DIGEST:
		raise RuntimeError("Decision package no longer matches the owner-confirmed digest")
	return decision


def main() -> None:
	decision = load_package_decision()
	approval = yaml.safe_load(APPROVAL_PATH.read_text(encoding="utf-8"))["approval"]
	if approval["approval_id"] != REQUEST_ID or approval["subject_digest"] != DECISION_DIGEST:
		raise RuntimeError("Approval materialization mismatch")
	if approval["decision"] != "approved" or approval["decided_by"] != "project-owner":
		raise RuntimeError("Approval is not an explicit project-owner approval")

	snapshot_doc = yaml.safe_load(SNAPSHOT_PATH.read_text(encoding="utf-8"))
	history_doc = yaml.safe_load(HISTORY_PATH.read_text(encoding="utf-8"))
	snapshot = snapshot_doc["registry_snapshot"]
	history = history_doc["event_history"]
	runtime = snapshot["runtime"]
	if runtime["current_state"] != "waiting_approval" or runtime["last_event_sequence"] != BASELINE_SEQUENCE:
		raise RuntimeError("Registry is not at the frozen RC5 approval waterline")
	if history[-1]["integrity"]["event_digest"] != runtime["last_event_digest"]:
		raise RuntimeError("Registry snapshot/history mismatch")
	request = next(item for item in snapshot["pending_approvals"] if item["request_id"] == REQUEST_ID)
	if request["status"] != "pending" or request["subject_digest"] != DECISION_DIGEST:
		raise RuntimeError("RC5 approval request is not the expected pending request")

	correlation_id = str(uuid.uuid4())
	previous = history[-1]
	new_events: list[dict[str, Any]] = []

	def add(event_type: str, actor: dict[str, str], payload: dict[str, Any], refs: list[str], req: str) -> dict[str, Any]:
		nonlocal previous
		event = registry_tools.make_event(
			previous,
			event_type,
			actor,
			payload,
			refs,
			req,
			correlation_id,
			DECIDED_AT,
		)
		new_events.append(event)
		previous = event
		registry_tools.update_runtime(snapshot, event)
		return event

	approval_ref = (
		"game-pipeline/approvals/gate-2-approval-0213f500a100.yaml"
		f"@subject-digest:{DECISION_DIGEST}"
	)
	package_ref = (
		"game-pipeline/loops/evidence/GATE-2-v3-decision-package.md"
		f"@sha256:{hashlib.sha256(PACKAGE_PATH.read_bytes()).hexdigest()}"
	)
	qa_ref = (
		"git:veilfront-xiangqi-siege:d1f5482f058ec66db20087ab27b6c12539c0d176"
		"#evidence/gate2/gate2-v3-independent-qa-rc5.md"
	)

	add(
		"core.approval_decided",
		OWNER_ACTOR,
		{
			"request_id": REQUEST_ID,
			"decision": "approved",
			"subject_digest": DECISION_DIGEST,
			"decision_ref": approval_ref,
		},
		["codex-thread://current#owner-gate2-rc5-approved-0213f500a100", approval_ref, package_ref],
		REQUEST_ID,
	)
	request["status"] = "approved"
	request["decision"] = {
		"result": "approved",
		"decided_by": "project-owner",
		"decided_at": DECIDED_AT,
		"decision_ref": approval_ref,
	}

	gate_record = {
		"gate_record_id": str(uuid.uuid4()),
		"gate_id": "GATE-2",
		"decision": "approved",
		"decided_by": "project-owner",
		"decision_ref": approval_ref,
		"subject_digest": DECISION_DIGEST,
		"approved_decision_package_subject_digest": DECISION_DIGEST,
		"evidence_state": "accepted_with_recorded_residual_risks",
		"iteration_reviewed": 3,
		"content_and_integration_contract_required": True,
		"gate_3_production_started": False,
		"external_release": "forbidden_until_gate_4",
	}
	add(
		"core.acceptance_recorded",
		OWNER_ACTOR,
		{
			"acceptance_kind": "human_gate",
			"record_id": gate_record["gate_record_id"],
			"subject_digest": DECISION_DIGEST,
			"record": gate_record,
		},
		["codex-thread://current#owner-gate2-rc5-approved-0213f500a100", approval_ref, package_ref, qa_ref],
		REQUEST_ID,
	)
	snapshot["acceptance_snapshot"]["human_gates"].append(gate_record)

	interruption = copy.deepcopy(snapshot["interruption"])
	revalidation = {
		"attempt_id": str(uuid.uuid4()),
		"checked_at": DECIDED_AT,
		"overall_result": "passed",
		"checks": [
			{"check_id": check_id, "result": "passed", "evidence_refs": [approval_ref, package_ref]}
			for check_id in ["RESUME-CTR", "RESUME-INPUT", "RESUME-DEP", "RESUME-AUTH", "RESUME-BUDGET", "RESUME-EVIDENCE"]
		],
		"resulting_route": "resume",
	}
	add(
		"core.resume_revalidation_recorded",
		registry_tools.PM_ACTOR,
		{
			"transition_id": "TR-INTERRUPTED-RESUME",
			"from_state": "waiting_approval",
			"to_state": "review",
			"iteration": {"before": 3, "after": 3},
			"interruption_id": interruption["interruption_id"],
			"revalidation": revalidation,
		},
		[approval_ref, package_ref, qa_ref],
		"GATE-2-v3-RC5-owner-approved-resume",
	)
	runtime["current_state"] = "review"
	runtime["state_entered_at"] = DECIDED_AT
	runtime["last_transition_id"] = "TR-INTERRUPTED-RESUME"
	snapshot["interruption"] = None

	handoff_ref = (
		"game-pipeline/loops/evidence/GATE-2-v3-final-handoff.md"
		f"@sha256:{hashlib.sha256(HANDOFF_PATH.read_bytes()).hexdigest()}"
	)
	add(
		"core.loop_completed",
		registry_tools.PM_ACTOR,
		{
			"transition_id": "TR-REVIEW-COMPLETED",
			"from_state": "review",
			"to_state": "completed",
			"iteration": {"before": 3, "after": 3},
			"acceptance_subject_digest": decision["acceptance_subject_digest"],
			"final_handoff_ref": handoff_ref,
		},
		[approval_ref, handoff_ref, package_ref, qa_ref],
		"complete-gate-2-v3-after-owner-approval",
	)
	runtime["current_state"] = "completed"
	runtime["state_entered_at"] = DECIDED_AT
	runtime["last_transition_id"] = "TR-REVIEW-COMPLETED"
	snapshot["acceptance_snapshot"]["final_handoff_ref"] = handoff_ref
	snapshot["interruption"] = None

	history_bytes = HISTORY_PATH.read_bytes()
	previous_digest = history[-1]["integrity"]["event_digest"]
	for event in new_events:
		event["integrity"]["previous_event_digest"] = previous_digest
		event["integrity"]["event_digest"] = registry_tools.event_digest(event)
		previous_digest = event["integrity"]["event_digest"]
		history_bytes = registry_tools.append_event_bytes(history_bytes, event)
	runtime["last_event_digest"] = new_events[-1]["integrity"]["event_digest"]
	snapshot_bytes = yaml.safe_dump(
		{"registry_snapshot": snapshot}, allow_unicode=True, sort_keys=False, width=120
	).encode("utf-8")
	registry_tools.atomic_write(HISTORY_PATH, history_bytes)
	registry_tools.atomic_write(SNAPSHOT_PATH, snapshot_bytes)
	print(
		"GATE2_RC5_OWNER_APPROVAL_APPLIED "
		f"approval_id={REQUEST_ID} digest={DECISION_DIGEST} "
		f"sequence={runtime['last_event_sequence']} revision={runtime['record_revision']} state=completed"
	)


if __name__ == "__main__":
	main()
