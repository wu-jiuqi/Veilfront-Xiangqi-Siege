#!/usr/bin/env python3
"""Apply and verify the owner-directed GATE-1 Iteration 2 playtest revision."""

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

LOOP_INSTANCE_ID = "4cbb03b6-dd5a-41c5-a624-895c4b884bcb"
CONTRACT_DIGEST = "7b7fcf36920109d379aa0e230cf70a378ed7ec228ff6a88bccf35cf481fcf09c"
STATE_MACHINE_DIGEST = "810f414928b370a869b3a36a17cb504f290d17fa07c9ce5db9001136bfdb160c"
REV36_TAIL_DIGEST = "b6439553ec00daf4284ccaa33067af2058e8f8b2806763ed02bc557c74acc328"
REV36_GATE_PACKAGE_DIGEST = "d24207e5e53509d09374e3870df744c21090554f77ad819f0e61a4aa6f2d54fd"
OWNER_SOURCE_REF = (
    "codex-thread://01a008aa-c77f-7060-9e11-1a6d95e41441"
    "#owner-gate1-revision-iteration2-50-round-graybox"
)


def load_migration_module():
    spec = importlib.util.spec_from_file_location("qa_p1_003_migration", MIGRATION_TOOL)
    if spec is None or spec.loader is None:
        raise RuntimeError("无法加载 QA-P1-003 Registry 工具")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


MIGRATION = load_migration_module()


def revision_subject() -> dict[str, Any]:
    return {
        "subject": "GATE-1-revision-request-iteration-2",
        "gate_id": "GATE-1",
        "loop_instance_id": LOOP_INSTANCE_ID,
        "decision": "revise",
        "baseline": {
            "record_revision": 36,
            "last_event_sequence": 36,
            "last_event_digest": REV36_TAIL_DIGEST,
            "contract_digest": CONTRACT_DIGEST,
            "gate_1_package_digest": REV36_GATE_PACKAGE_DIGEST,
        },
        "revision_requirements": {
            "default_full_round_limit_hypothesis": 50,
            "round_limit_status": "hypothesis_cli_overridable",
            "playable_graybox": {
                "required": True,
                "classification": "disposable_playtest_harness",
                "human_information_source": "PlayerView_only",
            },
            "required_revalidation": [
                "Godot 4.7.1 import/main/playable graybox",
                "rules/fog/AI fairness/replay regression",
                "1000 fixed seeds at 50 full rounds",
                "determinism mismatch count equals 0",
                "independent QA",
                "Registry and QA-P1-003 compatibility recheck",
            ],
        },
        "formal_production": "forbidden_until_separate_gate_1_approval",
    }


def revision_digest() -> str:
    return MIGRATION.canonical_digest(revision_subject())


def approval_path() -> Path:
    return APPROVALS_DIR / f"gate-1-revision-{revision_digest()[:12]}.yaml"


def build_decision_record(decided_at: str) -> dict[str, Any]:
    digest = revision_digest()
    return {
        "approval": {
            "schema_version": "game-production-approval/v1",
            "approval_id": f"approval:veilfront-xiangqi-siege:gate-1-revision:{digest[:12]}",
            "subject_kind": "human-gate-decision",
            "subject_id": "GATE-1@iteration-1-review",
            "subject_digest": digest,
            "decision": "revise",
            "decided_by": "project-owner",
            "decided_at": decided_at,
            "evidence": {
                "source_refs": [
                    OWNER_SOURCE_REF,
                    "game-pipeline/loops/evidence/GATE-1-decision-package.md"
                    f"@sha256:{REV36_GATE_PACKAGE_DIGEST}",
                ],
                "immutable_subject": revision_subject(),
            },
            "authorized_action": {
                "summary": "返回同一 Loop 的 Iteration 2，补齐 50 回合假设与可丢弃灰盒试玩证据。",
                "allowed": [
                    "追加 GATE-1 revise 验收记录和 TR-REVIEW-ACTIVE 状态事件。",
                    "把默认完整回合上限临时调整为 50，并保留 CLI 覆盖能力。",
                    "实现仅供 GATE-1 人工试玩的可丢弃灰盒入口。",
                    "完成全量回归和独立 QA 后重新进入 review 并重建 GATE-1 决策包。",
                ],
                "forbidden": [
                    "把 50 回合冻结为正式平衡规则。",
                    "开始正式 UI、美术、音频、动画或资产生产。",
                    "把官方 Loop CLI 记录为通过。",
                    "自动批准 GATE-1。",
                ],
            },
            "application": {
                "from_state": "review",
                "to_state": "active",
                "iteration_before": 1,
                "iteration_after": 2,
                "application_event_sequence": 38,
            },
        }
    }


def decision_ref() -> str:
    return approval_path().relative_to(PROJECT_ROOT).as_posix() + "@subject-digest:" + revision_digest()


def make_minimal_snapshot_bytes(
    original_bytes: bytes,
    original_snapshot: dict[str, Any],
    updated_doc: dict[str, Any],
) -> bytes:
    updated = updated_doc["registry_snapshot"]
    before_runtime = original_snapshot["runtime"]
    after_runtime = updated["runtime"]
    text = original_bytes.decode("utf-8")
    replacements = [
        (f"    current_state: {before_runtime['current_state']}\n", f"    current_state: {after_runtime['current_state']}\n"),
        (
            f"    state_entered_at: '{before_runtime['state_entered_at']}'\n",
            f"    state_entered_at: '{after_runtime['state_entered_at']}'\n",
        ),
        (
            f"    current_iteration: {before_runtime['current_iteration']}\n",
            f"    current_iteration: {after_runtime['current_iteration']}\n",
        ),
        (
            f"    last_transition_id: {before_runtime['last_transition_id']}\n",
            f"    last_transition_id: {after_runtime['last_transition_id']}\n",
        ),
        (f"    last_event_id: {before_runtime['last_event_id']}\n", f"    last_event_id: {after_runtime['last_event_id']}\n"),
        (
            f"    last_event_digest: {before_runtime['last_event_digest']}\n",
            f"    last_event_digest: {after_runtime['last_event_digest']}\n",
        ),
        (
            f"    last_event_sequence: {before_runtime['last_event_sequence']}\n",
            f"    last_event_sequence: {after_runtime['last_event_sequence']}\n",
        ),
        (
            f"    record_revision: {before_runtime['record_revision']}\n",
            f"    record_revision: {after_runtime['record_revision']}\n",
        ),
    ]
    for before, after in replacements:
        if text.count(before) != 1:
            raise RuntimeError(f"Snapshot 最小替换目标不是唯一项: {before!r}")
        text = text.replace(before, after, 1)

    human_gate_dump = yaml.safe_dump(
        {"human_gates": updated["acceptance_snapshot"]["human_gates"]},
        allow_unicode=True,
        sort_keys=False,
        width=120,
    ).rstrip("\n")
    human_gate_block = "\n".join("    " + line for line in human_gate_dump.splitlines()) + "\n"
    if text.count("    human_gates: []\n") != 1:
        raise RuntimeError("Snapshot human_gates 基线不匹配")
    text = text.replace("    human_gates: []\n", human_gate_block, 1)
    result = text.encode("utf-8")
    if yaml.safe_load(result) != updated_doc:
        raise RuntimeError("最小格式 Snapshot 与 Iteration 2 语义不一致")
    return result


def record_revision() -> None:
    MIGRATION.verify_final_review()
    snapshot_doc = MIGRATION.load_yaml(SNAPSHOT_PATH)
    snapshot = snapshot_doc["registry_snapshot"]
    original_snapshot = copy.deepcopy(snapshot)
    history_bytes = HISTORY_PATH.read_bytes()
    history = MIGRATION.load_yaml(HISTORY_PATH)["event_history"]
    previous = history[-1]
    occurred_at = MIGRATION.now_china()

    record = build_decision_record(occurred_at)
    target = approval_path()
    if target.exists():
        if MIGRATION.load_yaml(target)["approval"]["subject_digest"] != revision_digest():
            raise RuntimeError("现有 GATE-1 修订记录摘要不匹配")
    else:
        MIGRATION.write_new(target, MIGRATION.dump_yaml(record))

    correlation_id = str(MIGRATION.uuid.uuid4())
    gate_record_id = str(MIGRATION.uuid.uuid4())
    gate_record = {
        "gate_record_id": gate_record_id,
        "gate_id": "GATE-1",
        "decision": "revise",
        "decided_by": "project-owner",
        "decision_ref": decision_ref(),
        "subject_digest": revision_digest(),
        "evidence_state": "revision_required",
        "iteration_reviewed": 1,
        "revision_iteration": 2,
        "full_gate1": False,
        "formal_production": "forbidden_until_separate_gate_1_approval",
    }
    owner_event = MIGRATION.make_event(
        sequence=37,
        event_type="core.acceptance_recorded",
        actor={"actor_id": "project-owner", "role": "project-owner", "authority_id": "GATE-1"},
        payload={
            "acceptance_kind": "human_gate",
            "record_id": gate_record_id,
            "subject_digest": revision_digest(),
            "record": gate_record,
        },
        evidence_refs=[decision_ref()],
        previous_digest=previous["integrity"]["event_digest"],
        causation_event_id=previous["event_id"],
        correlation_id=correlation_id,
        request_id="owner-gate-1-revision-iteration-2",
        occurred_at=occurred_at,
    )
    transition = MIGRATION.make_event(
        sequence=38,
        event_type="core.state_transitioned",
        actor={
            "actor_id": "inst:01M02M6X3Q8YWJXHY52K3V5AR2",
            "role": "pos:veilfront-xiangqi-siege:root:project-manager",
            "authority_id": "AUTH-VEILFRONT-PROJECT-MANAGER",
        },
        payload={
            "transition_id": "TR-REVIEW-ACTIVE",
            "from_state": "review",
            "to_state": "active",
            "iteration": {"before": 1, "after": 2},
            "reason": "project_owner_revision_required_round_limit_50_and_disposable_playable_graybox",
            "subject_digest": revision_digest(),
        },
        evidence_refs=[
            decision_ref(),
            f"event:{owner_event['event_id']}@digest:{owner_event['integrity']['event_digest']}",
        ],
        previous_digest=owner_event["integrity"]["event_digest"],
        causation_event_id=owner_event["event_id"],
        correlation_id=correlation_id,
        request_id="owner-gate-1-revision-iteration-2",
        occurred_at=occurred_at,
    )
    history_bytes = MIGRATION.append_event_bytes(history_bytes, owner_event)
    history_bytes = MIGRATION.append_event_bytes(history_bytes, transition)

    snapshot["acceptance_snapshot"]["human_gates"].append(gate_record)
    runtime = snapshot["runtime"]
    runtime["current_state"] = "active"
    runtime["state_entered_at"] = occurred_at
    runtime["current_iteration"] = 2
    runtime["last_transition_id"] = "TR-REVIEW-ACTIVE"
    runtime["last_event_id"] = transition["event_id"]
    runtime["last_event_digest"] = transition["integrity"]["event_digest"]
    runtime["last_event_sequence"] = 38
    runtime["record_revision"] = 38
    snapshot_bytes = make_minimal_snapshot_bytes(
        SNAPSHOT_PATH.read_bytes(), original_snapshot, snapshot_doc
    )
    MIGRATION.replace_registry_pair(history_bytes, snapshot_bytes)
    verify_active()
    print(json.dumps({
        "result": "active",
        "current_iteration": 2,
        "decision": "revise",
        "decision_subject_digest": revision_digest(),
        "decision_record": target.relative_to(PROJECT_ROOT).as_posix(),
        "events": [
            {"sequence": owner_event["sequence"], "event_type": owner_event["event_type"], "event_id": owner_event["event_id"], "event_digest": owner_event["integrity"]["event_digest"]},
            {"sequence": transition["sequence"], "event_type": transition["event_type"], "event_id": transition["event_id"], "event_digest": transition["integrity"]["event_digest"]},
        ],
        "formal_production": "forbidden",
    }, ensure_ascii=False, indent=2))


def verify_active() -> None:
    history_bytes = HISTORY_PATH.read_bytes()
    if MIGRATION.hashlib.sha256(history_bytes[:MIGRATION.REV30_HISTORY_SIZE]).hexdigest() != MIGRATION.REV30_HISTORY_DIGEST:
        raise RuntimeError("rev30 Event History 字节前缀摘要不匹配")
    history = MIGRATION.load_yaml(HISTORY_PATH)["event_history"]
    snapshot = MIGRATION.load_yaml(SNAPSHOT_PATH)["registry_snapshot"]
    if len(history) != 38:
        raise RuntimeError(f"Iteration 2 Event History 预期 38 条，实际 {len(history)}")
    for index, event in enumerate(history, start=1):
        if event["sequence"] != index:
            raise RuntimeError(f"事件 sequence 不连续: index={index}")
        if event["integrity"]["event_digest"] != MIGRATION.canonical_event_digest(event):
            raise RuntimeError(f"事件摘要不匹配: sequence={index}")
        if index > 1 and event["integrity"]["previous_event_digest"] != history[index - 2]["integrity"]["event_digest"]:
            raise RuntimeError(f"事件摘要断链: sequence={index}")
    if [event["event_type"] for event in history[-2:]] != ["core.acceptance_recorded", "core.state_transitioned"]:
        raise RuntimeError("Iteration 2 修订事件类型序列不匹配")
    transition = history[-1]
    runtime = snapshot["runtime"]
    checks = [
        (snapshot["contract_binding"]["contract_digest"], CONTRACT_DIGEST, "Contract digest"),
        (runtime["current_state"], "active", "state"),
        (runtime["current_iteration"], 2, "iteration"),
        (runtime["record_revision"], 38, "revision"),
        (runtime["last_event_sequence"], 38, "sequence"),
        (runtime["last_event_id"], transition["event_id"], "last_event_id"),
        (runtime["last_event_digest"], transition["integrity"]["event_digest"], "last_event_digest"),
        (runtime["last_transition_id"], "TR-REVIEW-ACTIVE", "last_transition_id"),
        (snapshot["budget"]["usage"]["completed_iterations"], 1, "completed_iterations"),
    ]
    for actual, expected, label in checks:
        if actual != expected:
            raise RuntimeError(f"Iteration 2 Snapshot {label} 不匹配: expected={expected} actual={actual}")
    gate_record = snapshot["acceptance_snapshot"]["human_gates"][-1]
    if gate_record["decision"] != "revise" or gate_record["subject_digest"] != revision_digest():
        raise RuntimeError("GATE-1 revise 记录不匹配")
    decision = MIGRATION.load_yaml(approval_path())["approval"]
    if decision["decision"] != "revise" or decision["subject_digest"] != revision_digest():
        raise RuntimeError("不可变 GATE-1 修订记录不匹配")
    print(json.dumps({
        "result": "OK",
        "record_revision": 38,
        "last_event_sequence": 38,
        "last_event_digest": transition["integrity"]["event_digest"],
        "current_state": "active",
        "current_iteration": 2,
        "gate_1_decision": "revise",
        "revision_subject_digest": revision_digest(),
        "default_full_round_limit_hypothesis": 50,
        "playable_graybox": "required",
        "formal_production": "forbidden",
    }, ensure_ascii=False, indent=2))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["record-revision", "verify-active"])
    args = parser.parse_args()
    if args.action == "record-revision":
        record_revision()
    else:
        verify_active()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
