#!/usr/bin/env python3
"""Replace the stale GATE-2 request with the frozen RC5 owner review request."""

from __future__ import annotations

import copy
import hashlib
import json
import os
import subprocess
import tempfile
import uuid
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any

import yaml


class NoAliasSafeDumper(yaml.SafeDumper):
	def ignore_aliases(self, data: Any) -> bool:
		return True


PROJECT_ROOT = Path(__file__).resolve().parents[3]
REGISTRY_DIR = PROJECT_ROOT / "game-pipeline/loops/registry/formal-foundation-gate2"
SNAPSHOT_PATH = REGISTRY_DIR / "snapshot.yaml"
HISTORY_PATH = REGISTRY_DIR / "event-history.yaml"
PACKAGE_PATH = PROJECT_ROOT / "game-pipeline/loops/evidence/GATE-2-v3-decision-package.md"
QA_REPORT_REF = "evidence/gate2/gate2-v3-independent-qa-rc5.md"
QA_SUMMARY_REF = "evidence/gate2/v3-candidate-05ada98/qa-evidence-summary.json"
QA_SUMMARY_PATH = PROJECT_ROOT / QA_SUMMARY_REF

LOOP_ID = "83c995ff-37b9-4df8-9e84-8417d6632187"
CONTRACT_DIGEST = "9ea1fbab25b1a560b83896194099bd9b0131552d7321223622161615c1a2a205"
STATE_MACHINE_DIGEST = "810f414928b370a869b3a36a17cb504f290d17fa07c9ce5db9001136bfdb160c"
PRODUCT_CANDIDATE = "05ada9848c20c41b6d6cc92ce552df643c31438c"
QA_EVIDENCE_COMMIT = "d1f5482f058ec66db20087ab27b6c12539c0d176"
OLD_DECISION_DIGEST = "36efd026dd33a1caab9bd9d72e4a593c6853850e92904e865d29f434c4317a84"
OLD_REQUEST_ID = "approval:veilfront-xiangqi-siege:gate-2:36efd026dd33"
BASELINE_SEQUENCE = 79

PM_ACTOR = {
	"actor_id": "inst:01M02M6X3Q8YWJXHY52K3V5AR2",
	"role": "pos:veilfront-xiangqi-siege:root:project-manager",
	"authority_id": "AUTH-VEILFRONT-PROJECT-MANAGER",
}
QA_ACTOR = {
	"actor_id": "inst:01M02NJ3JFHVZ5C4SP5MTJFJR6",
	"role": "pos:veilfront-xiangqi-siege:quality:qa-release-lead",
	"authority_id": "AUTH-VEILFRONT-QA-RELEASE",
}


def canonical_digest(value: Any) -> str:
	return hashlib.sha256(
		json.dumps(
			value,
			ensure_ascii=False,
			allow_nan=False,
			separators=(",", ":"),
			sort_keys=True,
		).encode("utf-8")
	).hexdigest()


def file_digest(path: Path) -> str:
	return hashlib.sha256(path.read_bytes()).hexdigest()


def event_digest(event: dict[str, Any]) -> str:
	normalized = copy.deepcopy(event)
	normalized["integrity"]["event_digest"] = None
	return canonical_digest(normalized)


def now_china() -> str:
	return datetime.now(timezone(timedelta(hours=8))).isoformat(timespec="microseconds")


def append_event_bytes(history_bytes: bytes, event: dict[str, Any]) -> bytes:
	dumped = yaml.dump(
		event,
		Dumper=NoAliasSafeDumper,
		allow_unicode=True,
		sort_keys=False,
		width=120,
	).rstrip("\n")
	lines = dumped.splitlines()
	event_text = "- " + lines[0] + "\n" + "\n".join("  " + line for line in lines[1:]) + "\n"
	if not history_bytes.endswith(b"\n"):
		history_bytes += b"\n"
	return history_bytes + event_text.encode("utf-8")


def make_event(
	previous_event: dict[str, Any],
	event_type: str,
	actor: dict[str, str],
	payload: dict[str, Any],
	evidence_refs: list[str],
	request_id: str,
	correlation_id: str,
	occurred_at: str,
) -> dict[str, Any]:
	sequence = int(previous_event["sequence"]) + 1
	event = {
		"schema_version": "0.1",
		"event_id": str(uuid.uuid4()),
		"mutation_id": str(uuid.uuid4()),
		"loop_instance_id": LOOP_ID,
		"sequence": sequence,
		"event_type": event_type,
		"occurred_at": occurred_at,
		"recorded_at": occurred_at,
		"actor": actor,
		"causality": {
			"correlation_id": correlation_id,
			"causation_event_id": previous_event["event_id"],
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
			"previous_event_digest": previous_event["integrity"]["event_digest"],
			"event_digest": None,
		},
	}
	event["integrity"]["event_digest"] = event_digest(event)
	return event


def update_runtime(snapshot: dict[str, Any], event: dict[str, Any]) -> None:
	runtime = snapshot["runtime"]
	runtime["last_event_id"] = event["event_id"]
	runtime["last_event_digest"] = event["integrity"]["event_digest"]
	runtime["last_event_sequence"] = event["sequence"]
	runtime["record_revision"] = event["concurrency"]["resulting_record_revision"]


def load_package_decision() -> tuple[dict[str, Any], str, str]:
	text = PACKAGE_PATH.read_text(encoding="utf-8")
	start = text.index("```json\n") + len("```json\n")
	end = text.index("\n```", start)
	decision = json.loads(text[start:end])
	digest = canonical_digest(decision)
	request_id = f"approval:veilfront-xiangqi-siege:gate-2:{digest[:12]}"
	if f"当前 GATE-2 决策摘要：`{digest}`" not in text or f"审批请求：`{request_id}`" not in text:
		raise RuntimeError("Decision package digest or request ID mismatch")
	return decision, digest, request_id


def replace_output(snapshot: dict[str, Any], record: dict[str, Any]) -> dict[str, Any] | None:
	outputs = snapshot["resources"]["outputs"]
	for index, existing in enumerate(outputs):
		if existing["deliverable_id"] == record["deliverable_id"]:
			before = copy.deepcopy(existing)
			outputs[index] = record
			return before
	outputs.append(record)
	return None


def atomic_write(path: Path, data: bytes) -> None:
	fd, temp_name = tempfile.mkstemp(prefix=f".{path.name}.", suffix=".tmp", dir=path.parent)
	try:
		with os.fdopen(fd, "wb") as handle:
			handle.write(data)
			handle.flush()
			os.fsync(handle.fileno())
		os.replace(temp_name, path)
	except Exception:
		try:
			os.unlink(temp_name)
		except FileNotFoundError:
			pass
		raise


def main() -> None:
	snapshot_doc = yaml.safe_load(SNAPSHOT_PATH.read_text(encoding="utf-8"))
	history_doc = yaml.safe_load(HISTORY_PATH.read_text(encoding="utf-8"))
	snapshot = snapshot_doc["registry_snapshot"]
	history = history_doc["event_history"]
	runtime = snapshot["runtime"]
	decision, decision_digest, new_request_id = load_package_decision()
	if runtime["last_event_sequence"] == 98 and any(
		item["request_id"] == new_request_id for item in snapshot["pending_approvals"]
	):
		for event in history:
			if event["sequence"] <= BASELINE_SEQUENCE or event["event_type"] != "core.output_registered":
				continue
			before = event["payload"].get("before")
			if isinstance(before, dict) and isinstance(before.get("artifact"), dict):
				artifact = before["artifact"]
				event["payload"]["before"] = {
					"deliverable_id": before.get("deliverable_id"),
					"artifact_id": artifact.get("artifact_id"),
					"version": artifact.get("version"),
					"digest": artifact.get("digest"),
				}
		previous_digest = next(
			event["integrity"]["event_digest"] for event in history if event["sequence"] == BASELINE_SEQUENCE
		)
		for event in history:
			if event["sequence"] <= BASELINE_SEQUENCE:
				continue
			event["integrity"]["previous_event_digest"] = previous_digest
			event["integrity"]["event_digest"] = event_digest(event)
			previous_digest = event["integrity"]["event_digest"]
		runtime["last_event_id"] = history[-1]["event_id"]
		runtime["last_event_digest"] = history[-1]["integrity"]["event_digest"]
		history_bytes = subprocess.check_output(
			[
				"git",
				"show",
				f"{QA_EVIDENCE_COMMIT}:game-pipeline/loops/registry/formal-foundation-gate2/event-history.yaml",
			],
			cwd=PROJECT_ROOT,
		)
		for event in history:
			if event["sequence"] > BASELINE_SEQUENCE:
				history_bytes = append_event_bytes(history_bytes, event)
		snapshot_bytes = yaml.safe_dump(
			{"registry_snapshot": snapshot}, allow_unicode=True, sort_keys=False, width=120
		).encode("utf-8")
		atomic_write(HISTORY_PATH, history_bytes)
		atomic_write(SNAPSHOT_PATH, snapshot_bytes)
		print(
			f"GATE2_RC5_OWNER_REVIEW_CHAIN_REPAIRED request_id={new_request_id} "
			f"digest={decision_digest} sequence=98 revision=98"
		)
		return
	if runtime["current_state"] != "waiting_approval" or runtime["last_event_sequence"] != BASELINE_SEQUENCE:
		raise RuntimeError("Registry is not at the frozen sequence 79 waiting state")
	if history[-1]["integrity"]["event_digest"] != runtime["last_event_digest"]:
		raise RuntimeError("Registry snapshot/history mismatch")

	qa = json.loads(QA_SUMMARY_PATH.read_text(encoding="utf-8"))
	if decision["candidate_commit"] != PRODUCT_CANDIDATE or decision["qa_evidence_commit"] != QA_EVIDENCE_COMMIT:
		raise RuntimeError("Decision candidate binding mismatch")
	if decision["check_results"] != qa["check_matrix"]:
		raise RuntimeError("Decision/QA check matrix mismatch")

	occurred_at = now_china()
	correlation_id = str(uuid.uuid4())
	new_events: list[dict[str, Any]] = []
	previous = history[-1]

	def add(event_type: str, actor: dict[str, str], payload: dict[str, Any], refs: list[str], req: str) -> dict[str, Any]:
		nonlocal previous
		event = make_event(previous, event_type, actor, payload, refs, req, correlation_id, occurred_at)
		new_events.append(event)
		previous = event
		update_runtime(snapshot, event)
		return event

	old_request = next(item for item in snapshot["pending_approvals"] if item["request_id"] == OLD_REQUEST_ID)
	if old_request["status"] != "pending" or old_request["subject_digest"] != OLD_DECISION_DIGEST:
		raise RuntimeError("Prior approval request is not the expected pending request")
	withdraw_ref = "game-pipeline/loops/evidence/GATE-2-v3-decision-package.md#rc5-refresh"
	add(
		"core.approval_decided",
		PM_ACTOR,
		{
			"request_id": OLD_REQUEST_ID,
			"decision": "withdrawn",
			"subject_digest": OLD_DECISION_DIGEST,
			"decision_ref": withdraw_ref,
		},
		[withdraw_ref],
		OLD_REQUEST_ID,
	)
	old_request["status"] = "withdrawn"
	old_request["decision"] = {
		"result": "withdrawn",
		"reason": "candidate_and_evidence_changed_before_owner_decision",
		"decision_ref": withdraw_ref,
		"decided_at": occurred_at,
		"decided_by": PM_ACTOR,
	}

	interruption = copy.deepcopy(snapshot["interruption"])
	revalidation = {
		"attempt_id": str(uuid.uuid4()),
		"checked_at": occurred_at,
		"overall_result": "passed",
		"checks": [
			{"check_id": check_id, "result": "passed", "evidence_refs": [QA_REPORT_REF]}
			for check_id in ["RESUME-CTR", "RESUME-INPUT", "RESUME-DEP", "RESUME-AUTH", "RESUME-BUDGET", "RESUME-EVIDENCE"]
		],
		"resulting_route": "resume",
	}
	resume_event = add(
		"core.resume_revalidation_recorded",
		PM_ACTOR,
		{
			"transition_id": "TR-INTERRUPTED-RESUME",
			"from_state": "waiting_approval",
			"to_state": "review",
			"iteration": {"before": 3, "after": 3},
			"interruption_id": interruption["interruption_id"],
			"revalidation": revalidation,
		},
		[QA_REPORT_REF, QA_SUMMARY_REF, "game-pipeline/loops/evidence/GATE-2-v3-decision-package.md"],
		"GATE-2-v3-RC5-refresh",
	)
	runtime["current_state"] = "review"
	runtime["state_entered_at"] = occurred_at
	runtime["last_transition_id"] = "TR-INTERRUPTED-RESUME"
	snapshot["interruption"] = None
	revalidation["event_id"] = resume_event["event_id"]

	acceptance = snapshot["acceptance_snapshot"]
	acceptance["subject_digest"] = decision["acceptance_subject_digest"]
	acceptance["automated_checks"] = []
	for check_id, result in decision["check_results"].items():
		record: dict[str, Any] = {
			"check_id": check_id,
			"result": result,
			"candidate_commit": PRODUCT_CANDIDATE,
			"qa_evidence_commit": QA_EVIDENCE_COMMIT,
			"evidence_ref": f"git:veilfront-xiangqi-siege:{QA_EVIDENCE_COMMIT}#{QA_REPORT_REF}",
			"subject_digest": decision["acceptance_subject_digest"],
		}
		if check_id == "CHECK-REGRESSION-001":
			record["limitation"] = decision["formal_equivalence"]
		if check_id == "CHECK-SCOPE-001":
			record["risk"] = "all_resources_export_requires_gate3_filtering"
		add(
			"core.acceptance_recorded",
			QA_ACTOR,
			{
				"acceptance_kind": "automated_check",
				"record_id": check_id,
				"subject_digest": decision["acceptance_subject_digest"],
				"record": record,
			},
			[f"git:veilfront-xiangqi-siege:{QA_EVIDENCE_COMMIT}#{QA_REPORT_REF}"],
			"GATE-2-v3-RC5-independent-review",
		)
		acceptance["automated_checks"].append(record)

	review = {
		"review_id": "GATE-2-v3-RC5-independent-review",
		"reviewer_instance_id": QA_ACTOR["actor_id"],
		"reviewer_role": QA_ACTOR["role"],
		"verdict": "pass",
		"route_recommendation": "recommend_updated_owner_approval",
		"evidence_state": "sufficient_with_disclosed_regression_and_scope_risks",
		"gate_decision": "not_made",
		"evidence_ref": f"git:veilfront-xiangqi-siege:{QA_EVIDENCE_COMMIT}#{QA_REPORT_REF}",
		"subject_digest": decision["acceptance_subject_digest"],
		"new_blocking_defects": [],
	}
	add(
		"core.acceptance_recorded",
		QA_ACTOR,
		{
			"acceptance_kind": "professional_review",
			"record_id": review["review_id"],
			"subject_digest": decision["acceptance_subject_digest"],
			"record": review,
		},
		[review["evidence_ref"]],
		review["review_id"],
	)
	acceptance["professional_reviews"].append(review)

	output_specs = [
		(
			"DELIVERABLE-PRESENTATION-2D-001",
			"preset-godot-2d-match-and-ui-shell",
			"evidence/gate2/gate2-v3-independent-qa-rc5.md",
			PRODUCT_CANDIDATE,
			decision["deliverable_digests"]["DELIVERABLE-PRESENTATION-2D-001"],
		),
		(
			"DELIVERABLE-ART-2D-001",
			"demo-2d-visual-ui-and-asset-baseline",
			"evidence/gate2/v3-candidate-05ada98/screenshots",
			QA_EVIDENCE_COMMIT,
			decision["deliverable_digests"]["DELIVERABLE-ART-2D-001"],
		),
		(
			"DELIVERABLE-QA-2D-001",
			"independent-gate2-v3-evidence",
			QA_REPORT_REF,
			QA_EVIDENCE_COMMIT,
			decision["deliverable_digests"]["DELIVERABLE-QA-2D-001"],
		),
		(
			"DELIVERABLE-GATE2-2D-001",
			"human-decision-package",
			"game-pipeline/loops/evidence/GATE-2-v3-decision-package.md",
			QA_EVIDENCE_COMMIT,
			file_digest(PACKAGE_PATH),
		),
	]
	for deliverable_id, artifact_type, uri, source_commit, digest in output_specs:
		record = {
			"deliverable_id": deliverable_id,
			"artifact": {
				"artifact_id": f"artifact:veilfront-xiangqi-siege:{deliverable_id.lower()}@rc5-{PRODUCT_CANDIDATE[:7]}",
				"artifact_type": artifact_type,
				"version": f"rc5-{PRODUCT_CANDIDATE[:7]}",
				"uri": uri,
				"manifest_paths": [uri],
				"source_commit": source_commit,
				"digest": {"algorithm": "sha256", "value": digest},
			},
			"produced_in_iteration": 3,
			"lifecycle_status": "submitted",
			"registered_by_event_id": None,
		}
		before_full = next(
			(copy.deepcopy(item) for item in snapshot["resources"]["outputs"] if item["deliverable_id"] == deliverable_id),
			None,
		)
		before = None
		if before_full is not None:
			before_artifact = before_full["artifact"]
			before = {
				"deliverable_id": before_full["deliverable_id"],
				"artifact_id": before_artifact["artifact_id"],
				"version": before_artifact["version"],
				"digest": before_artifact["digest"],
			}
		event = add(
			"core.output_registered",
			PM_ACTOR,
			{"deliverable_id": deliverable_id, "before": before, "after": record},
			[uri],
			f"GATE-2-v3-RC5-register-{deliverable_id}",
		)
		record["registered_by_event_id"] = event["event_id"]
		event["payload"]["after"]["registered_by_event_id"] = event["event_id"]
		event["integrity"]["event_digest"] = event_digest(event)
		previous = event
		update_runtime(snapshot, event)
		replace_output(snapshot, record)

	request = {
		"request_id": new_request_id,
		"requested_action": "close_gate_2_and_prepare_gate_3_contract",
		"subject_digest": decision_digest,
		"status": "pending",
		"requested_by": PM_ACTOR,
		"decision_authority": "project-owner",
		"request_ref": "game-pipeline/loops/evidence/GATE-2-v3-decision-package.md",
		"requested_at": occurred_at,
		"decision": None,
	}
	add(
		"core.approval_requested",
		PM_ACTOR,
		{
			"request_id": new_request_id,
			"requested_action": request["requested_action"],
			"subject_digest": decision_digest,
			"request": request,
		},
		["game-pipeline/loops/evidence/GATE-2-v3-decision-package.md", QA_REPORT_REF, QA_SUMMARY_REF],
		new_request_id,
	)
	snapshot["pending_approvals"].append(request)

	new_interruption = copy.deepcopy(interruption)
	new_interruption["current_interruption_state"] = "waiting_approval"
	new_interruption["current_reason"] = {
		"reason_code": "gate_2_rc5_project_owner_decision_required",
		"description": "RC5 自动检查和独立专业审查已满足；等待项目所有者对精确更新摘要批准、修订或拒绝。",
		"responsible_role": "project-owner",
		"evidence_refs": [
			"game-pipeline/loops/evidence/GATE-2-v3-decision-package.md",
			QA_REPORT_REF,
			qa["windows_artifact"]["path"],
		],
	}
	new_interruption["latest_revalidation"] = None
	add(
		"core.interruption_entered",
		PM_ACTOR,
		{
			"transition_id": "TR-OPERATIONAL-INTERRUPTED",
			"from_state": "review",
			"to_state": "waiting_approval",
			"iteration": {"before": 3, "after": 3},
			"interruption": new_interruption,
		},
		new_interruption["current_reason"]["evidence_refs"],
		new_request_id,
	)
	runtime["current_state"] = "waiting_approval"
	runtime["state_entered_at"] = occurred_at
	runtime["last_transition_id"] = "TR-OPERATIONAL-INTERRUPTED"
	snapshot["interruption"] = new_interruption

	history_bytes = HISTORY_PATH.read_bytes()
	previous_digest = history[-1]["integrity"]["event_digest"]
	for event in new_events:
		event["integrity"]["previous_event_digest"] = previous_digest
		event["integrity"]["event_digest"] = event_digest(event)
		previous_digest = event["integrity"]["event_digest"]
		history_bytes = append_event_bytes(history_bytes, event)
	runtime["last_event_digest"] = new_events[-1]["integrity"]["event_digest"]
	snapshot_bytes = yaml.safe_dump(
		{"registry_snapshot": snapshot}, allow_unicode=True, sort_keys=False, width=120
	).encode("utf-8")
	atomic_write(HISTORY_PATH, history_bytes)
	atomic_write(SNAPSHOT_PATH, snapshot_bytes)
	print(
		f"GATE2_RC5_OWNER_REVIEW_REGISTERED request_id={new_request_id} "
		f"digest={decision_digest} sequence={runtime['last_event_sequence']} revision={runtime['record_revision']}"
	)


if __name__ == "__main__":
	main()
