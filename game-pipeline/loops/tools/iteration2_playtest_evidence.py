#!/usr/bin/env python3
"""Register and verify Iteration 2 owner-playtest evidence without entering review."""

from __future__ import annotations

import argparse
import copy
import importlib.util
import json
from pathlib import Path
from typing import Any

import yaml


PROJECT_ROOT = Path(__file__).resolve().parents[3]
MIGRATION_TOOL = PROJECT_ROOT / "game-pipeline/loops/tools/qa_p1_003_migration.py"
SNAPSHOT_PATH = PROJECT_ROOT / "game-pipeline/loops/registry/first-production-loop/snapshot.yaml"
HISTORY_PATH = PROJECT_ROOT / "game-pipeline/loops/registry/first-production-loop/event-history.yaml"
APPROVALS_DIR = PROJECT_ROOT / "game-pipeline/approvals"

CONTRACT_DIGEST = "7b7fcf36920109d379aa0e230cf70a378ed7ec228ff6a88bccf35cf481fcf09c"
REV38_TAIL_DIGEST = "fbc96e54b834e9c1188a513a5fe29c76fb89c7ff1b9187b7870018566546af97"
CODE_COMMIT = "e5963e229c05557d668316531779e406cc9e801d"
SPEC_COMMIT = "002bff459c0d13135d9be8d0a68d2f6ac2193f5a"
QA_EVIDENCE_COMMIT = "5bbb38a"
QA_ADDENDUM_COMMIT = "910a525"
OWNER_SOURCE_REF = (
    "codex-thread://01a008aa-c77f-7060-9e11-1a6d95e41441"
    "#owner-iteration2-playtest-100-seeds-three-ai"
)

SPEC_PATH = Path("docs/prototype/iteration2-playtest-graybox-spec.md")
GODOT_PATHS = [
    Path("docs/prototype/godot-artifact-map-v1.md"),
    Path("scenes/prototype/board_shell.tscn"),
    Path("scenes/prototype/gate1_logic_lab.tscn"),
    Path("scenes/prototype/match_controller.tscn"),
    Path("scenes/prototype/status_shell.tscn"),
    Path("scripts/prototype/gate1_logic_lab.gd"),
    Path("scripts/prototype/match_controller.gd"),
    Path("scripts/prototype/view/player_view_projector.gd"),
    Path("tests/prototype/run_all.gd"),
    Path("tests/prototype/run_playtest_graybox.gd"),
]
AI_PATHS = [
    Path("resources/prototype/ai/prototype_low_budget_hypothesis.tres"),
    Path("resources/prototype/ai/prototype_default_hypothesis.tres"),
    Path("resources/prototype/ai/prototype_high_budget_hypothesis.tres"),
    Path("scripts/prototype/ai/ai_decision_engine.gd"),
    Path("scripts/prototype/match_controller.gd"),
    Path("tests/prototype/test_ai_difficulty_profiles.gd"),
    Path("tests/prototype/run_ai_difficulty_seed_matrix.gd"),
]
QA_PATHS = [
    Path("evidence/prototype/qa/iteration-2-independent-review.md"),
    Path("evidence/prototype/qa/iteration-2-command-output.txt"),
    Path("evidence/prototype/qa/iteration-2-ai-difficulty-seed-matrix-100x3.jsonl"),
    Path("evidence/prototype/qa/iteration-2-ai-difficulty-seed-matrix-summary.json"),
    Path("evidence/prototype/qa/iteration-2-rules-stress-100-seeds-round50.jsonl"),
    Path("evidence/prototype/qa/iteration-2-rules-stress-100-seeds-round50-summary.json"),
    Path("evidence/prototype/qa/iteration-2-spec-clarification-addendum.md"),
]
CONTRACT_ARTIFACT_TYPES = {
    "DELIVERABLE-INFO-001": "information-boundary-contract",
    "DELIVERABLE-GODOT-001": "disposable-godot-prototype",
    "DELIVERABLE-AI-001": "auditable-baseline-ai",
    "DELIVERABLE-QA-001": "independent-gate-evidence",
}


def load_migration_module():
    spec = importlib.util.spec_from_file_location("qa_p1_003_migration", MIGRATION_TOOL)
    if spec is None or spec.loader is None:
        raise RuntimeError("无法加载 QA-P1-003 Registry 工具")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


MIGRATION = load_migration_module()


def owner_scope_subject() -> dict[str, Any]:
    return {
        "subject": "iteration-2-owner-playtest-scope-100-seeds-three-ai",
        "loop_instance_id": "4cbb03b6-dd5a-41c5-a624-895c4b884bcb",
        "baseline": {
            "record_revision": 38,
            "last_event_sequence": 38,
            "last_event_digest": REV38_TAIL_DIGEST,
            "contract_digest": CONTRACT_DIGEST,
        },
        "owner_direction": {
            "default_full_round_limit_hypothesis": 50,
            "fixed_seed_count_for_owner_playtest_build": 100,
            "ai_difficulties": ["easy", "medium", "hard"],
            "playtest_build": "disposable_graybox",
        },
        "evidence_scope": {
            "player_view_ai": "100 fixed seeds x 3 profiles, one decision per record",
            "rules_stress": "100 fixed seeds, full matches at 50 full rounds",
            "manual_playtest": "owner plays complete human-vs-AI sessions per difficulty",
        },
        "contract_effect": "none",
        "review_transition": "blocked_until_contract_v2_1000_or_separate_contract_revision",
        "gate_1_decision": "not_made",
        "formal_production": "forbidden",
    }


def owner_scope_digest() -> str:
    return MIGRATION.canonical_digest(owner_scope_subject())


def approval_path() -> Path:
    return APPROVALS_DIR / f"iteration-2-playtest-scope-{owner_scope_digest()[:12]}.yaml"


def approval_ref() -> str:
    return (
        approval_path().relative_to(PROJECT_ROOT).as_posix()
        + "@subject-digest:"
        + owner_scope_digest()
    )


def build_approval_record(decided_at: str) -> dict[str, Any]:
    digest = owner_scope_digest()
    return {
        "approval": {
            "schema_version": "game-production-approval/v1",
            "approval_id": f"approval:veilfront-xiangqi-siege:iteration-2-playtest-scope:{digest[:12]}",
            "subject_kind": "iteration-execution-scope",
            "subject_id": "LOOP-GATE1-001@iteration-2-owner-playtest",
            "subject_digest": digest,
            "decision": "approved",
            "decided_by": "project-owner",
            "decided_at": decided_at,
            "evidence": {
                "source_refs": [OWNER_SOURCE_REF],
                "immutable_subject": owner_scope_subject(),
            },
            "authorized_action": {
                "summary": "交付含三档公平 AI 的 50 回合可丢弃灰盒，并以 100 固定种子形成试玩版证据。",
                "allowed": [
                    "运行并登记 100 固定种子的试玩版回归与独立 QA。",
                    "交付简单、中等、困难三档 PlayerView 公平 AI 供项目所有者人工试玩。",
                    "在 Iteration 2 active 状态下登记试玩版产物和受限 QA 结论。",
                ],
                "forbidden": [
                    "把 100 固定种子记录为满足 Contract v2 的 1000/1000。",
                    "执行或推荐 active -> review。",
                    "把官方 Loop CLI 记录为通过。",
                    "批准 GATE-1 或开始正式生产。",
                ],
            },
        }
    }


def artifact_manifest(commit: str, paths: list[Path]) -> dict[str, Any]:
    files = []
    for relative in paths:
        absolute = PROJECT_ROOT / relative
        if not absolute.is_file():
            raise RuntimeError(f"产物文件不存在: {relative.as_posix()}")
        files.append({
            "path": relative.as_posix(),
            "sha256": MIGRATION.file_digest(absolute),
        })
    return {"commit": commit, "files": files}


def build_outputs(event_ids: dict[str, str]) -> dict[str, dict[str, Any]]:
    manifests = {
        "DELIVERABLE-INFO-001": artifact_manifest(SPEC_COMMIT, [SPEC_PATH]),
        "DELIVERABLE-GODOT-001": artifact_manifest(CODE_COMMIT, GODOT_PATHS),
        "DELIVERABLE-AI-001": artifact_manifest(CODE_COMMIT, AI_PATHS),
        "DELIVERABLE-QA-001": artifact_manifest(QA_ADDENDUM_COMMIT, QA_PATHS),
    }
    definitions = {
        "DELIVERABLE-INFO-001": (
            "artifact:veilfront-xiangqi-siege:iteration2-playtest-spec@v1",
            "playtest-graybox-specification",
            f"iteration-2-scope-clarified@{SPEC_COMMIT}",
            f"git:veilfront-xiangqi-siege:{SPEC_COMMIT}#{SPEC_PATH.as_posix()}",
        ),
        "DELIVERABLE-GODOT-001": (
            "source:veilfront-xiangqi-siege:godot-prototype@gate1-iteration2",
            "disposable-playable-godot-prototype",
            f"iteration-2-three-ai-graybox@{CODE_COMMIT}",
            f"git:veilfront-xiangqi-siege:{CODE_COMMIT}#disposable-playable-graybox",
        ),
        "DELIVERABLE-AI-001": (
            "source:veilfront-xiangqi-siege:ai-prototype@gate1-iteration2",
            "auditable-three-difficulty-player-view-ai",
            f"iteration-2-easy-medium-hard@{CODE_COMMIT}",
            f"git:veilfront-xiangqi-siege:{CODE_COMMIT}#three-difficulty-player-view-ai",
        ),
        "DELIVERABLE-QA-001": (
            "artifact:veilfront-xiangqi-siege:gate1-evidence@iteration2-playtest",
            "independent-owner-playtest-evidence",
            f"iteration-2-100-seed-scope@{QA_ADDENDUM_COMMIT}",
            f"git:veilfront-xiangqi-siege:{QA_ADDENDUM_COMMIT}#iteration-2-independent-qa",
        ),
    }
    outputs: dict[str, dict[str, Any]] = {}
    for deliverable_id, definition in definitions.items():
        artifact_id, artifact_type, version, uri = definition
        manifest = manifests[deliverable_id]
        outputs[deliverable_id] = {
            "deliverable_id": deliverable_id,
            "artifact": {
                "artifact_id": artifact_id,
                "artifact_type": artifact_type,
                "version": version,
                "uri": uri,
                "manifest_paths": [item["path"] for item in manifest["files"]],
                "digest": {
                    "algorithm": "sha256",
                    "value": MIGRATION.canonical_digest(manifest),
                },
            },
            "produced_in_iteration": 2,
            "lifecycle_status": "submitted_for_owner_playtest",
            "registered_by_event_id": event_ids[deliverable_id],
        }
    return outputs


def acceptance_subject(outputs: dict[str, dict[str, Any]]) -> dict[str, Any]:
    return {
        "subject": "iteration-2-owner-playtest-build-independent-qa",
        "contract_digest": CONTRACT_DIGEST,
        "owner_scope_digest": owner_scope_digest(),
        "tested_code_commit": CODE_COMMIT,
        "spec_commit": SPEC_COMMIT,
        "qa_evidence_commit": QA_EVIDENCE_COMMIT,
        "qa_addendum_commit": QA_ADDENDUM_COMMIT,
        "deliverable_digests": {
            key: value["artifact"]["digest"]["value"] for key, value in outputs.items()
        },
        "official_cli": {
            "result": "failed",
            "exit_code": 1,
            "errors": MIGRATION.EXPECTED_CLI_ERRORS,
        },
        "validate_history": {"exit_code": 0, "error_count": 0},
        "ai_difficulty_matrix": {
            "fixed_seeds": 100,
            "records": 300,
            "failure_count": 0,
            "determinism_mismatch_count": 0,
            "hidden_equivalence_mismatch_count": 0,
            "mapping_failure_count": 0,
            "submit_failure_count": 0,
            "records_digest": "a5d4f6235a8652cd86eb7d303f568a50409a8b83f07e600fc4da275073f9e02a",
        },
        "rules_stress": {
            "fixed_seeds": 100,
            "completed": 100,
            "failure_count": 0,
            "determinism_mismatch_count": 0,
            "replay_verified": "10/10",
            "records_digest": "68c6a92f7fad4091b0e5353a04fa08b3617950dad3958cdcbff754546f85b2e8",
        },
        "contract_1000_seeds_satisfied": False,
        "review_transition_allowed": False,
    }


def replace_output_block(text: str, deliverable_id: str, output: dict[str, Any]) -> str:
    marker = f"      - deliverable_id: {deliverable_id}\n"
    start = text.index(marker)
    next_output = text.find("      - deliverable_id:", start + len(marker))
    acceptance = text.index("  acceptance_snapshot:\n", start)
    end = acceptance if next_output == -1 or next_output > acceptance else next_output
    dumped = yaml.safe_dump([output], allow_unicode=True, sort_keys=False, width=120).rstrip("\n")
    block = "\n".join("      " + line for line in dumped.splitlines()) + "\n"
    return text[:start] + block + text[end:]


def make_snapshot_bytes(
    original_bytes: bytes,
    original_snapshot: dict[str, Any],
    updated_doc: dict[str, Any],
    outputs: dict[str, dict[str, Any]],
) -> bytes:
    updated = updated_doc["registry_snapshot"]
    before_runtime = original_snapshot["runtime"]
    after_runtime = updated["runtime"]
    text = original_bytes.decode("utf-8")
    replacements = [
        (f"    last_event_id: {before_runtime['last_event_id']}\n", f"    last_event_id: {after_runtime['last_event_id']}\n"),
        (f"    last_event_digest: {before_runtime['last_event_digest']}\n", f"    last_event_digest: {after_runtime['last_event_digest']}\n"),
        (f"    last_event_sequence: {before_runtime['last_event_sequence']}\n", f"    last_event_sequence: {after_runtime['last_event_sequence']}\n"),
        (f"    record_revision: {before_runtime['record_revision']}\n", f"    record_revision: {after_runtime['record_revision']}\n"),
    ]
    for before, after in replacements:
        if text.count(before) != 1:
            raise RuntimeError(f"Snapshot runtime 最小替换目标不是唯一项: {before!r}")
        text = text.replace(before, after, 1)
    for deliverable_id, output in outputs.items():
        text = replace_output_block(text, deliverable_id, output)
    acceptance_dump = yaml.safe_dump(
        {"acceptance_snapshot": updated["acceptance_snapshot"]},
        allow_unicode=True,
        sort_keys=False,
        width=120,
    ).rstrip("\n")
    acceptance_block = "\n".join("  " + line for line in acceptance_dump.splitlines()) + "\n"
    acceptance_start = text.index("  acceptance_snapshot:\n")
    acceptance_end = text.index("  interruption: null\n", acceptance_start)
    text = text[:acceptance_start] + acceptance_block + text[acceptance_end:]
    result = text.encode("utf-8")
    if yaml.safe_load(result) != updated_doc:
        raise RuntimeError("最小格式 Snapshot 与 Iteration 2 证据语义不一致")
    return result


def register_evidence() -> None:
    verify_baseline()
    snapshot_doc = MIGRATION.load_yaml(SNAPSHOT_PATH)
    snapshot = snapshot_doc["registry_snapshot"]
    original_snapshot = copy.deepcopy(snapshot)
    history_bytes = HISTORY_PATH.read_bytes()
    history = MIGRATION.load_yaml(HISTORY_PATH)["event_history"]
    previous = history[-1]
    occurred_at = MIGRATION.now_china()

    record = build_approval_record(occurred_at)
    target = approval_path()
    if target.exists():
        existing = MIGRATION.load_yaml(target)["approval"]
        if existing["subject_digest"] != owner_scope_digest():
            raise RuntimeError("现有 Iteration 2 试玩范围批准记录摘要不匹配")
    else:
        MIGRATION.write_new(target, MIGRATION.dump_yaml(record))

    project_manager = {
        "actor_id": "inst:01M02M6X3Q8YWJXHY52K3V5AR2",
        "role": "pos:veilfront-xiangqi-siege:root:project-manager",
        "authority_id": "AUTH-VEILFRONT-PROJECT-MANAGER",
    }
    qa_actor = {
        "actor_id": "inst:01M02NJ3JFHVZ5C4SP5MTJFJR6",
        "role": "pos:veilfront-xiangqi-siege:quality:qa-release-lead",
        "authority_id": "AUTH-VEILFRONT-QA-RELEASE",
    }
    correlation_id = str(MIGRATION.uuid.uuid4())
    request_id = "iteration-2-owner-playtest-100-seeds-three-ai"
    deliverable_ids = [
        "DELIVERABLE-INFO-001",
        "DELIVERABLE-GODOT-001",
        "DELIVERABLE-AI-001",
        "DELIVERABLE-QA-001",
    ]
    event_ids = {key: str(MIGRATION.uuid.uuid4()) for key in deliverable_ids}
    outputs = build_outputs(event_ids)
    current_outputs = {item["deliverable_id"]: item for item in snapshot["resources"]["outputs"]}
    events = []
    for offset, deliverable_id in enumerate(deliverable_ids, start=1):
        output = outputs[deliverable_id]
        event = MIGRATION.make_event(
            sequence=38 + offset,
            event_type="core.output_registered",
            actor=project_manager,
            payload={
                "deliverable_id": deliverable_id,
                "before": copy.deepcopy(current_outputs[deliverable_id]),
                "after": copy.deepcopy(output),
            },
            evidence_refs=[approval_ref(), output["artifact"]["uri"]],
            previous_digest=previous["integrity"]["event_digest"],
            causation_event_id=previous["event_id"],
            correlation_id=correlation_id,
            request_id=request_id,
            occurred_at=occurred_at,
        )
        event["event_id"] = event_ids[deliverable_id]
        event["payload"]["after"]["registered_by_event_id"] = event["event_id"]
        event["integrity"]["event_digest"] = MIGRATION.canonical_event_digest(event)
        events.append(event)
        previous = event

    subject = acceptance_subject(outputs)
    subject_digest = MIGRATION.canonical_digest(subject)
    qa_ref = (
        f"git:veilfront-xiangqi-siege:{QA_ADDENDUM_COMMIT}#"
        "evidence/prototype/qa/iteration-2-spec-clarification-addendum.md"
    )
    automated_id = str(MIGRATION.uuid.uuid4())
    automated_record = {
        "check_set_id": automated_id,
        "result": "pass_for_owner_playtest_contract_review_blocked",
        "evidence_ref": qa_ref,
        "subject_digest": subject_digest,
        "project_instance": {"exit_code": 0, "state": "normal"},
        "pipeline_contract": {"exit_code": 0, "result": "pass"},
        "organization_history": {"exit_code": 0, "result": "pass"},
        "official_cli": {
            "exit_code": 1,
            "result": "failed",
            "error_count": 6,
            "errors": MIGRATION.EXPECTED_CLI_ERRORS,
        },
        "validate_history": {"exit_code": 0, "error_count": 0, "result": "pass_limited_scope"},
        "registry_consistency": {"result": "pass", "revision": 38, "sequence": 38},
        "godot_regression": {"result": "pass", "version": "4.7.1"},
        "ai_difficulty_matrix": subject["ai_difficulty_matrix"],
        "rules_stress": subject["rules_stress"],
        "contract_simulation_gate": {
            "result": "not_satisfied",
            "required_fixed_seeds": 1000,
            "executed_fixed_seeds": 100,
        },
        "new_defects": [],
    }
    automated_event = MIGRATION.make_event(
        sequence=43,
        event_type="core.acceptance_recorded",
        actor=qa_actor,
        payload={
            "acceptance_kind": "automated_check",
            "record_id": automated_id,
            "subject_digest": subject_digest,
            "record": automated_record,
        },
        evidence_refs=[approval_ref(), qa_ref],
        previous_digest=previous["integrity"]["event_digest"],
        causation_event_id=previous["event_id"],
        correlation_id=correlation_id,
        request_id=request_id,
        occurred_at=occurred_at,
    )
    events.append(automated_event)
    previous = automated_event

    review_id = str(MIGRATION.uuid.uuid4())
    professional_record = {
        "review_id": review_id,
        "reviewer_assignment_id": "9589489a-be2a-436f-bde4-8488d684c0bb",
        "reviewer_instance_id": "inst:01M02NJ3JFHVZ5C4SP5MTJFJR6",
        "verdict": "ready_for_owner_playtest_with_scope_limit",
        "technical_regression": "pass",
        "professional_result": "playable_graybox_ready_for_owner_playtest",
        "evidence_state": "sufficient_for_owner_playtest_only",
        "current_submission_accepted": False,
        "full_gate1": False,
        "gate_decision": "not_made",
        "transition_to_review_allowed": False,
        "evidence_ref": qa_ref,
        "subject_digest": subject_digest,
        "defect_regression": [
            {"defect_id": "QA-P1-001", "status": "closed"},
            {"defect_id": "QA-P1-002", "status": "closed"},
            {
                "defect_id": "QA-P1-003",
                "status": "controlled_temporary_exception_not_requalified_for_review",
                "classification": "owner-approved tooling exception",
                "official_cli": "failed",
                "reason": "Contract v2 1000/1000 not executed in Iteration 2",
            },
        ],
        "new_defects": [],
        "formal_production": "forbidden_until_separate_gate_1_approval",
        "legal_next_action": "project_owner_manual_playtest_while_loop_remains_active",
    }
    professional_event = MIGRATION.make_event(
        sequence=44,
        event_type="core.acceptance_recorded",
        actor=qa_actor,
        payload={
            "acceptance_kind": "professional_review",
            "record_id": review_id,
            "subject_digest": subject_digest,
            "record": professional_record,
        },
        evidence_refs=[approval_ref(), qa_ref],
        previous_digest=previous["integrity"]["event_digest"],
        causation_event_id=previous["event_id"],
        correlation_id=correlation_id,
        request_id=request_id,
        occurred_at=occurred_at,
    )
    events.append(professional_event)

    for event in events:
        history_bytes = MIGRATION.append_event_bytes(history_bytes, event)
    for deliverable_id, output in outputs.items():
        current_outputs[deliverable_id].clear()
        current_outputs[deliverable_id].update(copy.deepcopy(output))
    acceptance = snapshot["acceptance_snapshot"]
    acceptance["subject_digest"] = subject_digest
    acceptance["automated_checks"].append(automated_record)
    acceptance["professional_reviews"].append(professional_record)
    runtime = snapshot["runtime"]
    runtime["last_event_id"] = professional_event["event_id"]
    runtime["last_event_digest"] = professional_event["integrity"]["event_digest"]
    runtime["last_event_sequence"] = 44
    runtime["record_revision"] = 44
    snapshot_bytes = make_snapshot_bytes(
        SNAPSHOT_PATH.read_bytes(), original_snapshot, snapshot_doc, outputs
    )
    MIGRATION.replace_registry_pair(history_bytes, snapshot_bytes)
    verify_registered()
    print(json.dumps({
        "result": "owner_playtest_ready_contract_review_blocked",
        "owner_scope_subject_digest": owner_scope_digest(),
        "owner_scope_record": target.relative_to(PROJECT_ROOT).as_posix(),
        "acceptance_subject_digest": subject_digest,
        "events": [
            {
                "sequence": event["sequence"],
                "event_type": event["event_type"],
                "event_id": event["event_id"],
                "event_digest": event["integrity"]["event_digest"],
            }
            for event in events
        ],
        "snapshot_revision": 44,
        "current_state": "active",
        "current_iteration": 2,
        "transition_to_review_allowed": False,
        "gate_1_decision": "not_made",
        "formal_production": "forbidden",
    }, ensure_ascii=False, indent=2))


def correct_output_types() -> None:
    verify_registered()
    snapshot_doc = MIGRATION.load_yaml(SNAPSHOT_PATH)
    snapshot = snapshot_doc["registry_snapshot"]
    original_snapshot = copy.deepcopy(snapshot)
    history_bytes = HISTORY_PATH.read_bytes()
    history = MIGRATION.load_yaml(HISTORY_PATH)["event_history"]
    previous = history[-1]
    occurred_at = MIGRATION.now_china()
    actor = {
        "actor_id": "inst:01M02M6X3Q8YWJXHY52K3V5AR2",
        "role": "pos:veilfront-xiangqi-siege:root:project-manager",
        "authority_id": "AUTH-VEILFRONT-PROJECT-MANAGER",
    }
    correlation_id = str(MIGRATION.uuid.uuid4())
    request_id = "iteration-2-output-contract-type-correction"
    materialized = {item["deliverable_id"]: item for item in snapshot["resources"]["outputs"]}
    corrected: dict[str, dict[str, Any]] = {}
    events = []
    for offset, deliverable_id in enumerate(CONTRACT_ARTIFACT_TYPES, start=1):
        before = copy.deepcopy(materialized[deliverable_id])
        after = copy.deepcopy(before)
        after["artifact"]["artifact_type"] = CONTRACT_ARTIFACT_TYPES[deliverable_id]
        event = MIGRATION.make_event(
            sequence=44 + offset,
            event_type="core.output_registered",
            actor=actor,
            payload={
                "deliverable_id": deliverable_id,
                "before": before,
                "after": after,
                "correction_reason": "preserve_exact_contract_artifact_type",
            },
            evidence_refs=[
                approval_ref(),
                f"event:{previous['event_id']}@digest:{previous['integrity']['event_digest']}",
            ],
            previous_digest=previous["integrity"]["event_digest"],
            causation_event_id=previous["event_id"],
            correlation_id=correlation_id,
            request_id=request_id,
            occurred_at=occurred_at,
        )
        event["payload"]["after"]["registered_by_event_id"] = event["event_id"]
        event["integrity"]["event_digest"] = MIGRATION.canonical_event_digest(event)
        corrected[deliverable_id] = copy.deepcopy(event["payload"]["after"])
        events.append(event)
        previous = event
    for event in events:
        history_bytes = MIGRATION.append_event_bytes(history_bytes, event)
    for deliverable_id, output in corrected.items():
        materialized[deliverable_id].clear()
        materialized[deliverable_id].update(copy.deepcopy(output))
    runtime = snapshot["runtime"]
    runtime["last_event_id"] = events[-1]["event_id"]
    runtime["last_event_digest"] = events[-1]["integrity"]["event_digest"]
    runtime["last_event_sequence"] = 48
    runtime["record_revision"] = 48
    snapshot_bytes = make_snapshot_bytes(
        SNAPSHOT_PATH.read_bytes(), original_snapshot, snapshot_doc, corrected
    )
    MIGRATION.replace_registry_pair(history_bytes, snapshot_bytes)
    verify_final()
    print(json.dumps({
        "result": "contract_artifact_types_corrected_append_only",
        "events": [
            {
                "sequence": event["sequence"],
                "event_type": event["event_type"],
                "event_id": event["event_id"],
                "event_digest": event["integrity"]["event_digest"],
                "deliverable_id": event["payload"]["deliverable_id"],
                "artifact_type": event["payload"]["after"]["artifact"]["artifact_type"],
            }
            for event in events
        ],
        "snapshot_revision": 48,
        "current_state": "active",
        "transition_to_review_allowed": False,
    }, ensure_ascii=False, indent=2))


def verify_baseline() -> None:
    history_bytes = HISTORY_PATH.read_bytes()
    if MIGRATION.hashlib.sha256(history_bytes[:MIGRATION.REV30_HISTORY_SIZE]).hexdigest() != MIGRATION.REV30_HISTORY_DIGEST:
        raise RuntimeError("rev30 Event History 字节前缀摘要不匹配")
    history = MIGRATION.load_yaml(HISTORY_PATH)["event_history"]
    snapshot = MIGRATION.load_yaml(SNAPSHOT_PATH)["registry_snapshot"]
    runtime = snapshot["runtime"]
    checks = [
        (len(history), 38, "history length"),
        (history[-1]["integrity"]["event_digest"], REV38_TAIL_DIGEST, "rev38 tail"),
        (snapshot["contract_binding"]["contract_digest"], CONTRACT_DIGEST, "Contract digest"),
        (runtime["current_state"], "active", "state"),
        (runtime["current_iteration"], 2, "iteration"),
        (runtime["record_revision"], 38, "revision"),
        (runtime["last_event_sequence"], 38, "sequence"),
        (runtime["last_event_digest"], REV38_TAIL_DIGEST, "Snapshot tail"),
    ]
    for actual, expected, label in checks:
        if actual != expected:
            raise RuntimeError(f"Iteration 2 证据登记基线 {label} 不匹配: expected={expected} actual={actual}")
    for index, event in enumerate(history, start=1):
        if event["sequence"] != index:
            raise RuntimeError(f"事件 sequence 不连续: index={index}")
        if event["integrity"]["event_digest"] != MIGRATION.canonical_event_digest(event):
            raise RuntimeError(f"事件摘要不匹配: sequence={index}")
        if index > 1 and event["integrity"]["previous_event_digest"] != history[index - 2]["integrity"]["event_digest"]:
            raise RuntimeError(f"事件摘要断链: sequence={index}")


def verify_registered() -> None:
    history_bytes = HISTORY_PATH.read_bytes()
    if MIGRATION.hashlib.sha256(history_bytes[:MIGRATION.REV30_HISTORY_SIZE]).hexdigest() != MIGRATION.REV30_HISTORY_DIGEST:
        raise RuntimeError("rev30 Event History 字节前缀摘要不匹配")
    history = MIGRATION.load_yaml(HISTORY_PATH)["event_history"]
    snapshot = MIGRATION.load_yaml(SNAPSHOT_PATH)["registry_snapshot"]
    if len(history) != 44:
        raise RuntimeError(f"最终 Event History 预期 44 条，实际 {len(history)}")
    expected_types = [
        "core.output_registered",
        "core.output_registered",
        "core.output_registered",
        "core.output_registered",
        "core.acceptance_recorded",
        "core.acceptance_recorded",
    ]
    if [event["event_type"] for event in history[38:44]] != expected_types:
        raise RuntimeError("seq39-44 事件类型序列不匹配")
    for index, event in enumerate(history, start=1):
        if event["sequence"] != index:
            raise RuntimeError(f"事件 sequence 不连续: index={index}")
        if event["integrity"]["event_digest"] != MIGRATION.canonical_event_digest(event):
            raise RuntimeError(f"事件摘要不匹配: sequence={index}")
        if index > 1 and event["integrity"]["previous_event_digest"] != history[index - 2]["integrity"]["event_digest"]:
            raise RuntimeError(f"事件摘要断链: sequence={index}")
        if index >= 32 and event["binding_snapshot"]["contract_digest"] != CONTRACT_DIGEST:
            raise RuntimeError(f"Contract v2 绑定不匹配: sequence={index}")
    runtime = snapshot["runtime"]
    checks = [
        (runtime["current_state"], "active", "state"),
        (runtime["current_iteration"], 2, "iteration"),
        (runtime["record_revision"], 44, "revision"),
        (runtime["last_event_sequence"], 44, "sequence"),
        (runtime["last_event_id"], history[-1]["event_id"], "last_event_id"),
        (runtime["last_event_digest"], history[-1]["integrity"]["event_digest"], "last_event_digest"),
        (runtime["last_transition_id"], "TR-REVIEW-ACTIVE", "last_transition_id"),
        (snapshot["budget"]["usage"]["completed_iterations"], 1, "completed_iterations"),
        (len(snapshot["acceptance_snapshot"]["human_gates"]), 1, "human gate count"),
    ]
    for actual, expected, label in checks:
        if actual != expected:
            raise RuntimeError(f"最终 Snapshot {label} 不匹配: expected={expected} actual={actual}")
    outputs = build_outputs({
        event["payload"]["deliverable_id"]: event["event_id"] for event in history[38:42]
    })
    materialized = {item["deliverable_id"]: item for item in snapshot["resources"]["outputs"]}
    for deliverable_id, expected in outputs.items():
        if materialized[deliverable_id] != expected:
            raise RuntimeError(f"Snapshot 产物登记不匹配: {deliverable_id}")
    automated = snapshot["acceptance_snapshot"]["automated_checks"][-1]
    professional = snapshot["acceptance_snapshot"]["professional_reviews"][-1]
    if automated["official_cli"] != {
        "exit_code": 1,
        "result": "failed",
        "error_count": 6,
        "errors": MIGRATION.EXPECTED_CLI_ERRORS,
    }:
        raise RuntimeError("自动检查没有如实记录官方 CLI failed/exit1/六项错误")
    if automated["contract_simulation_gate"]["result"] != "not_satisfied":
        raise RuntimeError("Contract 1000 seeds 未被记录为不满足")
    if professional["transition_to_review_allowed"] is not False:
        raise RuntimeError("专业复核错误允许进入 review")
    if professional["gate_decision"] != "not_made":
        raise RuntimeError("GATE-1 决定记录不正确")
    decision = MIGRATION.load_yaml(approval_path())["approval"]
    if decision["decision"] != "approved" or decision["subject_digest"] != owner_scope_digest():
        raise RuntimeError("Iteration 2 试玩范围批准摘要不匹配")
    print(json.dumps({
        "result": "OK",
        "rev30_prefix_sha256": MIGRATION.REV30_HISTORY_DIGEST,
        "record_revision": 44,
        "last_event_sequence": 44,
        "last_event_digest": history[-1]["integrity"]["event_digest"],
        "current_state": "active",
        "current_iteration": 2,
        "owner_scope_subject_digest": owner_scope_digest(),
        "official_cli": "failed",
        "owner_playtest": "ready_with_scope_limit",
        "contract_1000_seeds_satisfied": False,
        "transition_to_review_allowed": False,
        "gate_1_decision": "not_made",
        "formal_production": "forbidden",
    }, ensure_ascii=False, indent=2))


def verify_final() -> None:
    history_bytes = HISTORY_PATH.read_bytes()
    if MIGRATION.hashlib.sha256(history_bytes[:MIGRATION.REV30_HISTORY_SIZE]).hexdigest() != MIGRATION.REV30_HISTORY_DIGEST:
        raise RuntimeError("rev30 Event History 字节前缀摘要不匹配")
    history = MIGRATION.load_yaml(HISTORY_PATH)["event_history"]
    snapshot = MIGRATION.load_yaml(SNAPSHOT_PATH)["registry_snapshot"]
    if len(history) != 48:
        raise RuntimeError(f"最终 Event History 预期 48 条，实际 {len(history)}")
    expected_types = [
        "core.output_registered",
        "core.output_registered",
        "core.output_registered",
        "core.output_registered",
        "core.acceptance_recorded",
        "core.acceptance_recorded",
        "core.output_registered",
        "core.output_registered",
        "core.output_registered",
        "core.output_registered",
    ]
    if [event["event_type"] for event in history[38:48]] != expected_types:
        raise RuntimeError("seq39-48 事件类型序列不匹配")
    for index, event in enumerate(history, start=1):
        if event["sequence"] != index:
            raise RuntimeError(f"事件 sequence 不连续: index={index}")
        if event["integrity"]["event_digest"] != MIGRATION.canonical_event_digest(event):
            raise RuntimeError(f"事件摘要不匹配: sequence={index}")
        if index > 1 and event["integrity"]["previous_event_digest"] != history[index - 2]["integrity"]["event_digest"]:
            raise RuntimeError(f"事件摘要断链: sequence={index}")
        if index >= 32 and event["binding_snapshot"]["contract_digest"] != CONTRACT_DIGEST:
            raise RuntimeError(f"Contract v2 绑定不匹配: sequence={index}")
    runtime = snapshot["runtime"]
    checks = [
        (runtime["current_state"], "active", "state"),
        (runtime["current_iteration"], 2, "iteration"),
        (runtime["record_revision"], 48, "revision"),
        (runtime["last_event_sequence"], 48, "sequence"),
        (runtime["last_event_id"], history[-1]["event_id"], "last_event_id"),
        (runtime["last_event_digest"], history[-1]["integrity"]["event_digest"], "last_event_digest"),
        (runtime["last_transition_id"], "TR-REVIEW-ACTIVE", "last_transition_id"),
        (snapshot["budget"]["usage"]["completed_iterations"], 1, "completed_iterations"),
        (len(snapshot["acceptance_snapshot"]["human_gates"]), 1, "human gate count"),
    ]
    for actual, expected, label in checks:
        if actual != expected:
            raise RuntimeError(f"最终 Snapshot {label} 不匹配: expected={expected} actual={actual}")
    materialized = {item["deliverable_id"]: item for item in snapshot["resources"]["outputs"]}
    for offset, (deliverable_id, artifact_type) in enumerate(CONTRACT_ARTIFACT_TYPES.items(), start=44):
        event = history[offset]
        if event["payload"]["deliverable_id"] != deliverable_id:
            raise RuntimeError(f"纠正事件 deliverable 顺序不匹配: sequence={event['sequence']}")
        if event["payload"]["after"]["artifact"]["artifact_type"] != artifact_type:
            raise RuntimeError(f"纠正事件 artifact_type 不匹配: {deliverable_id}")
        if materialized[deliverable_id] != event["payload"]["after"]:
            raise RuntimeError(f"Snapshot 纠正产物不匹配: {deliverable_id}")
    automated = snapshot["acceptance_snapshot"]["automated_checks"][-1]
    professional = snapshot["acceptance_snapshot"]["professional_reviews"][-1]
    if automated["official_cli"] != {
        "exit_code": 1,
        "result": "failed",
        "error_count": 6,
        "errors": MIGRATION.EXPECTED_CLI_ERRORS,
    }:
        raise RuntimeError("自动检查没有如实记录官方 CLI failed/exit1/六项错误")
    if automated["contract_simulation_gate"]["result"] != "not_satisfied":
        raise RuntimeError("Contract 1000 seeds 未被记录为不满足")
    if professional["transition_to_review_allowed"] is not False:
        raise RuntimeError("专业复核错误允许进入 review")
    decision = MIGRATION.load_yaml(approval_path())["approval"]
    if decision["decision"] != "approved" or decision["subject_digest"] != owner_scope_digest():
        raise RuntimeError("Iteration 2 试玩范围批准摘要不匹配")
    print(json.dumps({
        "result": "OK",
        "rev30_prefix_sha256": MIGRATION.REV30_HISTORY_DIGEST,
        "record_revision": 48,
        "last_event_sequence": 48,
        "last_event_digest": history[-1]["integrity"]["event_digest"],
        "current_state": "active",
        "current_iteration": 2,
        "owner_scope_subject_digest": owner_scope_digest(),
        "official_cli": "failed",
        "owner_playtest": "ready_with_scope_limit",
        "contract_1000_seeds_satisfied": False,
        "transition_to_review_allowed": False,
        "gate_1_decision": "not_made",
        "formal_production": "forbidden",
    }, ensure_ascii=False, indent=2))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "action",
        choices=[
            "register-evidence",
            "correct-output-types",
            "verify-baseline",
            "verify-registered",
            "verify-final",
        ],
    )
    args = parser.parse_args()
    if args.action == "register-evidence":
        register_evidence()
    elif args.action == "correct-output-types":
        correct_output_types()
    elif args.action == "verify-baseline":
        verify_baseline()
        print("OK: Iteration 2 rev38/seq38 证据登记基线一致")
    elif args.action == "verify-registered":
        verify_registered()
    else:
        verify_final()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
