#!/usr/bin/env python3
"""Bind the project owner's RC3 GATE-1 approval and complete the loop."""

from __future__ import annotations

import copy
import json
import os
import uuid
from pathlib import Path
from typing import Any

from gate1_rc3_review import (
    BRIEF_DIGEST,
    CANDIDATE_COMMIT,
    CONTRACT_DIGEST,
    LOOP_ID,
    PM_ACTOR,
    PROJECT_ROOT,
    QA_EVIDENCE_COMMIT,
    RC3_PATH,
    RC3_SHA256,
    RC3_SIZE,
    STATE_MACHINE_DIGEST,
    append_event_bytes,
    canonical_digest,
    dump_yaml,
    file_digest,
    load_yaml,
    make_event,
    now_china,
)


SNAPSHOT_PATH = PROJECT_ROOT / "game-pipeline/loops/registry/first-production-loop/snapshot.yaml"
HISTORY_PATH = PROJECT_ROOT / "game-pipeline/loops/registry/first-production-loop/event-history.yaml"
DECISION_PACKAGE_PATH = PROJECT_ROOT / "game-pipeline/loops/evidence/GATE-1-decision-package.md"
HANDOFF_PATH = PROJECT_ROOT / "game-pipeline/loops/evidence/GATE-1-final-handoff.md"
APPROVAL_DIR = PROJECT_ROOT / "game-pipeline/approvals"

DECISION_PACKAGE_SUBJECT_DIGEST = (
    "3ad999746a4942e6c9cd6986cba7a7d7e819c9f3c5ffeacaab94351d1cb589a3"
)
DECISION_PACKAGE_FILE_DIGEST = (
    "3bd27f5fa6cbf1c96b002611c5c315d6295c4a3bfab8eb0ff61ef82c159d4a0b"
)
QA_ACCEPTANCE_SUBJECT_DIGEST = (
    "5be2f49678c91f3738a8be23aa4f114bb4d314a0a7b491494efdcc89738ac337"
)
EXPECTED_BASELINE_TAIL = "30193da1fca5f423d6651c7192ac883eaa8cd94b69d5647b1dd79b0b4fc04dc2"
OWNER_SOURCE_REF = "codex-thread://current#owner-gate1-approved-3ad999746a49"

HUMAN_ACTOR = {
    "actor_id": "project-owner",
    "role": "project-owner",
    "authority_id": "GATE-1",
}


def verify_baseline(snapshot: dict[str, Any], history: list[dict[str, Any]]) -> None:
    runtime = snapshot["runtime"]
    expected_binding = {
        "contract_id": "LOOP-CTR-GATE1-VERTICAL-SLICE-001",
        "contract_version": 5,
        "contract_digest": CONTRACT_DIGEST,
    }
    if snapshot["identity"]["loop_instance_id"] != LOOP_ID:
        raise RuntimeError("Loop identity mismatch")
    if snapshot["contract_binding"] != expected_binding:
        raise RuntimeError("Registry 未绑定批准的 Contract v5")
    if runtime["current_state"] != "review" or runtime["current_iteration"] != 2:
        raise RuntimeError("Registry 必须位于 review / iteration 2")
    if runtime["record_revision"] != 61 or runtime["last_event_sequence"] != 61:
        raise RuntimeError("Registry 必须位于 rev61 / seq61")
    if len(history) != 61 or history[-1]["sequence"] != 61:
        raise RuntimeError("Event History 必须精确包含 61 条事件")
    if runtime["last_event_digest"] != EXPECTED_BASELINE_TAIL:
        raise RuntimeError("Snapshot baseline tail mismatch")
    if history[-1]["integrity"]["event_digest"] != EXPECTED_BASELINE_TAIL:
        raise RuntimeError("Event History baseline tail mismatch")
    if snapshot["acceptance_snapshot"]["subject_digest"] != QA_ACCEPTANCE_SUBJECT_DIGEST:
        raise RuntimeError("QA acceptance subject mismatch")

    package_output = next(
        item
        for item in snapshot["resources"]["outputs"]
        if item["deliverable_id"] == "DELIVERABLE-GATE1-001"
    )
    if package_output["artifact"]["digest"]["value"] != DECISION_PACKAGE_FILE_DIGEST:
        raise RuntimeError("Registry decision package digest mismatch")
    if file_digest(DECISION_PACKAGE_PATH) != DECISION_PACKAGE_FILE_DIGEST:
        raise RuntimeError("Decision package file changed after submission")
    package_text = DECISION_PACKAGE_PATH.read_text(encoding="utf-8")
    for marker in [
        "awaiting_human / decision_not_made",
        DECISION_PACKAGE_SUBJECT_DIGEST,
        CANDIDATE_COMMIT,
        RC3_SHA256.upper(),
    ]:
        if marker not in package_text:
            raise RuntimeError(f"Decision package missing immutable marker: {marker}")

    latest_review = snapshot["acceptance_snapshot"]["professional_reviews"][-1]
    if not latest_review["transition_to_review_allowed"]:
        raise RuntimeError("Independent professional review did not allow review")
    if latest_review["gate_decision"] != "not_made" or latest_review["full_gate1"]:
        raise RuntimeError("GATE-1 baseline is no longer awaiting the owner")

    executable = PROJECT_ROOT / RC3_PATH
    if executable.stat().st_size != RC3_SIZE or file_digest(executable) != RC3_SHA256:
        raise RuntimeError("RC3 executable identity mismatch")
    if HANDOFF_PATH.exists():
        raise RuntimeError("Final handoff already exists; refusing duplicate approval")
    if list(APPROVAL_DIR.glob("gate-1-approval-*.yaml")):
        raise RuntimeError("A GATE-1 approval record already exists")


def approval_subject() -> dict[str, Any]:
    return {
        "subject": "GATE-1-approval-rc3-v5",
        "gate_id": "GATE-1",
        "loop_instance_id": LOOP_ID,
        "decision": "approved",
        "approved_decision_package_subject_digest": DECISION_PACKAGE_SUBJECT_DIGEST,
        "baseline": {
            "record_revision": 61,
            "last_event_sequence": 61,
            "last_event_digest": EXPECTED_BASELINE_TAIL,
            "contract_digest": CONTRACT_DIGEST,
            "project_brief_digest": BRIEF_DIGEST,
            "gate_1_package_digest": DECISION_PACKAGE_FILE_DIGEST,
            "qa_acceptance_subject_digest": QA_ACCEPTANCE_SUBJECT_DIGEST,
            "candidate_commit": CANDIDATE_COMMIT,
            "qa_evidence_commit": QA_EVIDENCE_COMMIT,
            "rc3": {
                "path": RC3_PATH,
                "size_bytes": RC3_SIZE,
                "sha256": RC3_SHA256,
            },
        },
        "accepted_residual_risks": {
            "round_limit_draws": "590/1000 at the 50-round experimental cap",
            "round_limit_status": "hypothesis_cli_overridable",
            "qa_p1_003": "owner-approved tooling exception; official CLI remains failed with exactly six errors",
            "prototype_status": "disposable vertical slice; not a formal architecture or release candidate",
            "warnings": "two UID text fallback warnings and forced-editor-exit scan warning remain nonblocking",
        },
        "scope": {
            "formal_feature_planning": "allowed through a new approved production contract",
            "formal_architecture_frozen": False,
            "high_cost_asset_production": "forbidden until GATE-2",
            "external_release": "forbidden until GATE-4",
        },
    }


def approval_document(
    subject: dict[str, Any], subject_digest: str, decided_at: str
) -> dict[str, Any]:
    return {
        "approval": {
            "schema_version": "game-production-approval/v1",
            "approval_id": f"approval:veilfront-xiangqi-siege:gate-1:{subject_digest[:12]}",
            "subject_kind": "human-gate-decision",
            "subject_id": "GATE-1@iteration-2-review",
            "subject_digest": subject_digest,
            "decision": "approved",
            "decided_by": "project-owner",
            "decided_at": decided_at,
            "evidence": {
                "source_refs": [
                    OWNER_SOURCE_REF,
                    (
                        "game-pipeline/loops/evidence/GATE-1-decision-package.md@sha256:"
                        + DECISION_PACKAGE_FILE_DIGEST
                    ),
                    (
                        "git:veilfront-xiangqi-siege:"
                        + QA_EVIDENCE_COMMIT
                        + "#evidence/prototype/qa/gate1-rc3-independent-review.md"
                    ),
                ],
                "immutable_subject": subject,
            },
            "authorized_action": {
                "summary": "批准当前 RC3 的 GATE-1 核心体验假设，并完成首个生产循环。",
                "allowed": [
                    "追加 GATE-1 approved 人工验收记录。",
                    "执行 TR-REVIEW-COMPLETED 并固化最终交接。",
                    "在新的获批 Contract 下开展正式功能规划与架构审查。",
                ],
                "forbidden": [
                    "把 RC3 或 prototype 目录直接认定为正式架构。",
                    "把 50 回合上限、AI 预算或难度参数冻结为正式平衡值。",
                    "在 GATE-2 前启动高成本最终资产批量生产。",
                    "在 GATE-4 前把 RC3 作为对外发布版本。",
                    "把官方 Loop CLI 表述为通过。",
                ],
            },
            "application": {
                "from_state": "review",
                "to_state": "completed",
                "iteration": 2,
                "gate_event_sequence": 62,
                "completion_event_sequence": 63,
                "applied_at": decided_at,
            },
        }
    }


def handoff_text(
    approval_ref: str,
    approval_subject_digest: str,
    approval_file_digest: str,
    decided_at: str,
) -> str:
    return f"""# GATE-1 最终交接（RC3 / Contract v5）

状态：`approved / loop_completion_authorized`

## 人工决定

- Gate：`GATE-1`
- 决定：`approved`
- 决定者：`project-owner`
- 决定时间：`{decided_at}`
- 获批决策包摘要：`{DECISION_PACKAGE_SUBJECT_DIGEST}`
- 审批记录：`{approval_ref}`
- 审批 subject digest：`{approval_subject_digest}`
- 审批文件 SHA-256：`{approval_file_digest}`

## 冻结证据

- Project Brief：`v4 / {BRIEF_DIGEST}`
- Loop Contract：`v5 / {CONTRACT_DIGEST}`
- RC3 候选提交：`{CANDIDATE_COMMIT}`
- RC3：`{RC3_PATH}`，`{RC3_SIZE}` bytes，SHA-256 `{RC3_SHA256}`
- 独立 QA：`{QA_EVIDENCE_COMMIT}`
- QA 验收摘要：`{QA_ACCEPTANCE_SUBJECT_DIGEST}`
- 规则压力测试：`1000/1000`，确定性差异 `0`，回放 `20/20`
- AI 公平矩阵：`400/400`，隐藏等价、确定性、映射和提交失败均为 `0`

## 保留为正式开发输入

- `docs/prototype/rules-spec-v1.md`、结算顺序、信息边界、AI 输入契约和覆盖矩阵作为行为基线。
- `tests/prototype/`、失败 seed、回放和 QA manifests 作为后续架构迁移的回归基线。
- 玩家真双机记录、LAN 限制和 RC3 构建哈希作为体验与技术成本证据。

## 必须重审或重写

- `scripts/prototype/`、`scenes/prototype/` 和原型 UI 不自动升级为正式架构；正式功能循环开始前必须完成架构审查。
- LAN 工具缺少互联网穿透、断线重连、房主迁移和发布级反作弊；若进入产品范围必须重新立项和重写。
- AI 四档预算、50 回合上限及随机性仍是实验参数，不构成正式平衡冻结。
- RC3 不是 Steam 发布候选，不能作为 GATE-4 发布证据。

## 下一阶段准入

1. 项目经理基于 GATE-1 批准结果准备新的正式功能 Contract、范围与架构审查。
2. 优先实验 50 回合下 `590/1000` 平局的节奏和胜负反馈，不静默修改已批准规则。
3. 在 GATE-2 前只允许灰盒和可逆视觉基线工作，不得批量生产最终高成本资产。
4. 任何规则、PlayerView 或随机消费顺序变化都必须执行 Contract v5 列明的受影响回归。

## 保留风险

- QA-P1-003 仍是临时工具兼容例外；官方 Loop CLI 依旧失败且只能出现获批的固定六项错误。
- clean source 加载的两个 UID 文本回退 warning 和编辑器强制退出 scan warning 仍未消除。
- GATE-1 只确认核心体验假设值得继续，不确认正式架构、最终平衡、高成本资产或对外发布。
"""


def atomic_replace(files: dict[Path, bytes]) -> None:
    originals: dict[Path, bytes | None] = {
        path: path.read_bytes() if path.exists() else None for path in files
    }
    temps: dict[Path, Path] = {}
    try:
        for path, data in files.items():
            temp = path.with_name(path.name + ".gate1-approval.tmp")
            temp.write_bytes(data)
            temps[path] = temp
        for path, temp in temps.items():
            os.replace(temp, path)
    except Exception:
        for path, data in originals.items():
            if data is None:
                path.unlink(missing_ok=True)
            else:
                path.write_bytes(data)
        raise
    finally:
        for temp in temps.values():
            temp.unlink(missing_ok=True)


def main() -> None:
    snapshot_doc = load_yaml(SNAPSHOT_PATH)
    history_doc = load_yaml(HISTORY_PATH)
    snapshot = snapshot_doc["registry_snapshot"]
    history: list[dict[str, Any]] = history_doc["event_history"]
    verify_baseline(snapshot, history)

    decided_at = now_china()
    correlation_id = str(uuid.uuid4())
    subject = approval_subject()
    approval_subject_digest = canonical_digest(subject)
    approval_path = APPROVAL_DIR / f"gate-1-approval-{approval_subject_digest[:12]}.yaml"
    approval_doc = approval_document(subject, approval_subject_digest, decided_at)
    approval_bytes = dump_yaml(approval_doc)
    approval_file_digest = file_digest_from_bytes(approval_bytes)
    approval_ref = (
        f"game-pipeline/approvals/{approval_path.name}@subject-digest:{approval_subject_digest}"
    )

    handoff = handoff_text(
        approval_ref, approval_subject_digest, approval_file_digest, decided_at
    ).encode("utf-8")
    handoff_digest = file_digest_from_bytes(handoff)
    handoff_ref = (
        "game-pipeline/loops/evidence/GATE-1-final-handoff.md@sha256:" + handoff_digest
    )

    gate_record_id = str(uuid.uuid4())
    gate_record = {
        "gate_record_id": gate_record_id,
        "gate_id": "GATE-1",
        "decision": "approved",
        "decided_by": "project-owner",
        "decision_ref": approval_ref,
        "subject_digest": approval_subject_digest,
        "approved_decision_package_subject_digest": DECISION_PACKAGE_SUBJECT_DIGEST,
        "evidence_state": "accepted_with_recorded_residual_risks",
        "iteration_reviewed": 2,
        "full_gate1": True,
        "formal_feature_development": "allowed_after_new_contract_and_architecture_review",
        "formal_architecture_frozen": False,
        "high_cost_asset_production": "forbidden_until_gate_2",
        "external_release": "forbidden_until_gate_4",
    }

    previous_event = history[-1]
    approval_event = make_event(
        snapshot,
        previous_event,
        62,
        "core.acceptance_recorded",
        HUMAN_ACTOR,
        {
            "acceptance_kind": "human_gate",
            "record_id": gate_record_id,
            "subject_digest": approval_subject_digest,
            "record": gate_record,
        },
        [
            OWNER_SOURCE_REF,
            approval_ref,
            (
                "game-pipeline/loops/evidence/GATE-1-decision-package.md@sha256:"
                + DECISION_PACKAGE_FILE_DIGEST
            ),
        ],
        "owner-gate-1-approval-rc3-v5",
        correlation_id,
        decided_at,
    )

    final_acceptance_subject = {
        "subject": "LOOP-GATE1-001-final-acceptance-rc3-v5",
        "loop_instance_id": LOOP_ID,
        "contract_digest": CONTRACT_DIGEST,
        "project_brief_digest": BRIEF_DIGEST,
        "candidate_commit": CANDIDATE_COMMIT,
        "qa_evidence_commit": QA_EVIDENCE_COMMIT,
        "qa_acceptance_subject_digest": QA_ACCEPTANCE_SUBJECT_DIGEST,
        "gate_approval_subject_digest": approval_subject_digest,
        "gate_approval_file_digest": approval_file_digest,
        "approved_decision_package_subject_digest": DECISION_PACKAGE_SUBJECT_DIGEST,
        "decision_package_file_digest": DECISION_PACKAGE_FILE_DIGEST,
        "final_handoff_digest": handoff_digest,
    }
    final_acceptance_digest = canonical_digest(final_acceptance_subject)

    completion_event = make_event(
        snapshot,
        approval_event,
        63,
        "core.loop_completed",
        PM_ACTOR,
        {
            "transition_id": "TR-REVIEW-COMPLETED",
            "from_state": "review",
            "to_state": "completed",
            "iteration": {"before": 2, "after": 2},
            "acceptance_subject_digest": final_acceptance_digest,
            "final_handoff_ref": handoff_ref,
        },
        [
            approval_ref,
            handoff_ref,
            f"game-pipeline/loops/evidence/GATE-1-decision-package.md@sha256:{DECISION_PACKAGE_FILE_DIGEST}",
            f"git:veilfront-xiangqi-siege:{QA_EVIDENCE_COMMIT}#evidence/prototype/qa/gate1-rc3-independent-review.md",
        ],
        "complete-loop-after-owner-gate-1-approval",
        correlation_id,
        decided_at,
    )

    new_snapshot = copy.deepcopy(snapshot_doc)
    registry = new_snapshot["registry_snapshot"]
    registry["acceptance_snapshot"]["human_gates"].append(gate_record)
    registry["acceptance_snapshot"]["subject_digest"] = final_acceptance_digest
    registry["acceptance_snapshot"]["final_handoff_ref"] = handoff_ref
    runtime = registry["runtime"]
    runtime.update(
        {
            "current_state": "completed",
            "state_entered_at": decided_at,
            "last_transition_id": "TR-REVIEW-COMPLETED",
            "last_event_id": completion_event["event_id"],
            "last_event_digest": completion_event["integrity"]["event_digest"],
            "last_event_sequence": 63,
            "record_revision": 63,
        }
    )
    registry["interruption"] = None
    registry["pending_approvals"] = []

    history_bytes = HISTORY_PATH.read_bytes()
    history_bytes = append_event_bytes(history_bytes, approval_event)
    history_bytes = append_event_bytes(history_bytes, completion_event)
    atomic_replace(
        {
            approval_path: approval_bytes,
            HANDOFF_PATH: handoff,
            HISTORY_PATH: history_bytes,
            SNAPSHOT_PATH: dump_yaml(new_snapshot),
        }
    )

    print(
        json.dumps(
            {
                "result": "approved",
                "current_state": "completed",
                "record_revision": 63,
                "last_event_sequence": 63,
                "last_event_digest": completion_event["integrity"]["event_digest"],
                "approval_path": approval_path.relative_to(PROJECT_ROOT).as_posix(),
                "approval_subject_digest": approval_subject_digest,
                "approval_file_sha256": approval_file_digest,
                "final_handoff_ref": handoff_ref,
                "final_acceptance_subject_digest": final_acceptance_digest,
                "high_cost_asset_production": "forbidden_until_gate_2",
            },
            ensure_ascii=False,
            indent=2,
        )
    )


def file_digest_from_bytes(data: bytes) -> str:
    import hashlib

    return hashlib.sha256(data).hexdigest()


if __name__ == "__main__":
    main()
