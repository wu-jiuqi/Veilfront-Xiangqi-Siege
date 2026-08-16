#!/usr/bin/env python3
"""Prepare and apply the one-shot QA-P1-003 compatibility migration.

The tool is intentionally project-specific.  It refuses to operate unless the
approved rev30 baseline is byte-for-byte intact, and it never edits Contract v1.
"""

from __future__ import annotations

import argparse
import copy
import hashlib
import importlib.util
import json
import os
from pathlib import Path
from typing import Any

import yaml


PROJECT_ROOT = Path(__file__).resolve().parents[3]
V1_PATH = PROJECT_ROOT / "game-pipeline/loops/contracts/loop-contract-gate1-vertical-slice.yaml"
V2_PATH = PROJECT_ROOT / "game-pipeline/loops/contracts/loop-contract-gate1-vertical-slice-v2.yaml"
APPROVALS_DIR = PROJECT_ROOT / "game-pipeline/approvals"
SNAPSHOT_PATH = PROJECT_ROOT / "game-pipeline/loops/registry/first-production-loop/snapshot.yaml"
HISTORY_PATH = PROJECT_ROOT / "game-pipeline/loops/registry/first-production-loop/event-history.yaml"
PLUGIN_ROOT = Path.home() / ".codex/plugins/cache/personal/game-production-pipeline/0.4.0-alpha.2"
VALIDATOR_PATH = PLUGIN_ROOT / "scripts/validate_loop_registry.py"
EVENT_CONTRACT_PATH = PLUGIN_ROOT / "contracts/loop-registry-event.template.yaml"
STATE_MACHINE_PATH = PLUGIN_ROOT / "contracts/loop-state-machine.default.yaml"

PLUGIN_VERSION = "0.4.0-alpha.2"
FRAMEWORK_DIGEST = "3589bce5cf4388f91a08f12acb5d90679256191d5085e65687d06a635bbdcd32"
VALIDATOR_DIGEST = "90804f2221af1973d099f4fc531fd39e8aaaaca7bf101922ee63c9c67f909633"
DECISION_PACKAGE_DIGEST = "b1eef2e3b99673a5070b0aa4d73c7d27eca8b5e315796f596e07757acbc1c210"
V1_SUBJECT_DIGEST = "a970c55fe068a1252251ee4d30dedff32bee9da1f8e7e7ef7dc0c501be416799"
V1_FILE_DIGEST = "a0380db5819f9651bbb2b0fab243bb3489504b11ed808506f2ecb92a589ae1ad"
REV30_SNAPSHOT_DIGEST = "4b1c2ab9d224e4e91e076a2f7f08e42dbdafed88e6f2564b01f20461be88d291"
REV30_HISTORY_DIGEST = "17a75a74da3a3314353351d22dc0fb6d7f8c4b941ae8f617b4e3b7c2f97b83e8"
REV30_TAIL_DIGEST = "1c4508c725c900959f649e6761bd0e54d3c1fcb5e14f35089b320fa43fe32e89"
STATE_MACHINE_DIGEST = "810f414928b370a869b3a36a17cb504f290d17fa07c9ce5db9001136bfdb160c"
OWNER_SOURCE_REF = "codex-thread://01a008aa-c77f-7060-9e11-1a6d95e41441#owner-approval-qa-p1-003-contract-v2"
DECIDED_AT = "2026-08-16T11:57:48.4700000+08:00"

EXPECTED_CLI_ERRORS = [
    "Snapshot 模板初始状态必须等于状态机 initial_state",
    "Snapshot 模板 current_iteration 必须从 0 开始",
    "注册后的 Snapshot 模板必须位于 sequence=1、record_revision=1",
    "draft 注册基线的 inputs 和 outputs 必须为空",
    "Snapshot input_slot_id 必须完整对应 Contract required_inputs",
    "Snapshot deliverable_id 必须完整对应 Contract required_deliverables",
]


def file_digest(path: Path) -> str:
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


def load_yaml(path: Path) -> dict[str, Any]:
    value = yaml.safe_load(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise RuntimeError(f"{path} 必须包含 YAML 映射")
    return value


def dump_yaml(value: Any) -> bytes:
    return yaml.safe_dump(
        value,
        allow_unicode=True,
        sort_keys=False,
        width=120,
    ).encode("utf-8")


def write_new(path: Path, data: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL
    descriptor = os.open(path, flags)
    try:
        with os.fdopen(descriptor, "wb") as handle:
            handle.write(data)
    except Exception:
        path.unlink(missing_ok=True)
        raise


def assert_rev30_baseline() -> tuple[dict[str, Any], dict[str, Any]]:
    checks = {
        V1_PATH: V1_FILE_DIGEST,
        SNAPSHOT_PATH: REV30_SNAPSHOT_DIGEST,
        HISTORY_PATH: REV30_HISTORY_DIGEST,
    }
    for path, expected in checks.items():
        actual = file_digest(path)
        if actual != expected:
            raise RuntimeError(f"基线摘要不匹配: {path} expected={expected} actual={actual}")

    snapshot_doc = load_yaml(SNAPSHOT_PATH)
    history_doc = load_yaml(HISTORY_PATH)
    snapshot = snapshot_doc["registry_snapshot"]
    runtime = snapshot["runtime"]
    events = history_doc["event_history"]
    if runtime["record_revision"] != 30 or runtime["last_event_sequence"] != 30 or len(events) != 30:
        raise RuntimeError("Registry 不在 rev30/seq30 基线")
    if runtime["last_event_digest"] != REV30_TAIL_DIGEST:
        raise RuntimeError("Snapshot rev30 尾摘要不匹配")
    if events[-1]["integrity"]["event_digest"] != REV30_TAIL_DIGEST:
        raise RuntimeError("Event History rev30 尾摘要不匹配")
    if snapshot["contract_binding"]["contract_digest"] != V1_SUBJECT_DIGEST:
        raise RuntimeError("Snapshot 未绑定已批准的 Contract v1")
    return snapshot_doc, history_doc


def compatibility_rule() -> dict[str, Any]:
    return {
        "exception_id": "QA-P1-003",
        "classification": "owner-approved tooling exception",
        "temporary": True,
        "scope": (
            "仅兼容锁定插件官方 Loop Registry CLI 对 active 运行态 Snapshot 误用 draft 模板校验而产生的六项已知错误；"
            "不改变玩法、质量阈值、1000 种子要求、独立 QA、GATE-1 权限或正式生产边界。"
        ),
        "immutable_baseline": {
            "plugin_version": PLUGIN_VERSION,
            "framework_digest": FRAMEWORK_DIGEST,
            "validator_digest": VALIDATOR_DIGEST,
            "decision_package_digest": DECISION_PACKAGE_DIGEST,
            "contract_v1_subject_digest": V1_SUBJECT_DIGEST,
            "contract_v1_file_digest": V1_FILE_DIGEST,
            "snapshot_rev30_file_digest": REV30_SNAPSHOT_DIGEST,
            "event_history_rev30_file_digest": REV30_HISTORY_DIGEST,
            "event_history_rev30_tail_digest": REV30_TAIL_DIGEST,
            "record_revision": 30,
            "last_event_sequence": 30,
        },
        "official_cli_observation": {
            "required_exit_code": 1,
            "required_error_count": 6,
            "required_error_set": EXPECTED_CLI_ERRORS,
            "record_result_as": "failed",
            "forbidden_claims": ["官方 CLI 通过", "official CLI passed", "等价通过表述"],
        },
        "all_conditions_required": [
            "官方 CLI 退出码恰好为 1，且错误集合恰好等于 required_error_set，不存在第七项错误。",
            "项目实例校验通过。",
            "Pipeline Contract CTR-P1-001 v1 校验通过。",
            "Organization Registry 历史重放通过。",
            "未修改的 validate_history() 退出码为 0 且 error_count=0。",
            "Snapshot、事件链、事件摘要、sequence 和 revision 一致。",
            "Godot 技术回归通过。",
            "固定 1000 个种子完成 1000/1000，且失败数为 0。",
            "确定性差异为 0。",
            "独立 QA 重新执行并确认没有 Registry 损坏或新增缺陷。",
        ],
        "recording": {
            "official_cli": "failed",
            "exception_status": "owner-approved tooling exception",
            "qa_p1_003_status": "controlled_temporary_exception_until_official_plugin_fix",
        },
        "review_transition": {
            "allowed_only_after": "独立 QA 接受本例外且 all_conditions_required 全部满足",
            "legal_transition": "active -> review",
            "gate_1_decision": "not_made",
            "post_review_scope": "仅整理并提交 GATE-1 决策包",
            "formal_production_before_gate_1": "forbidden",
        },
        "invalidation_conditions": [
            "插件版本、框架摘要或校验器摘要变化。",
            "官方 CLI 出现六项之外的任何错误，或退出码不再恰好为 1。",
            "rev30 历史前缀文件摘要或 rev30 尾事件摘要变化。",
            "Contract v2 被替换或撤销。",
            "正式修复版本可用并完成迁移。",
            "独立 QA 发现新的历史、摘要、权限或一致性问题。",
        ],
    }


def build_v2() -> tuple[dict[str, Any], str]:
    source = load_yaml(V1_PATH)
    v2 = copy.deepcopy(source)
    v2["loop_contract"]["version"] = 2
    v2["loop_contract"]["status"] = "approved"
    v2.pop("approval_binding", None)
    v2["temporary_tooling_compatibility"] = compatibility_rule()
    subject_digest = canonical_digest(v2)
    approval_id = f"approval:veilfront-xiangqi-siege:loop-contract:{subject_digest[:12]}"
    v2["approval_binding"] = {
        "approval_id": approval_id,
        "subject_digest": subject_digest,
        "approved_by": "project-owner",
        "approved_at": DECIDED_AT,
        "source_ref": OWNER_SOURCE_REF,
    }
    # Keep approval_binding in the same document position as v1 for readability.
    ordered = {
        "loop_contract": v2.pop("loop_contract"),
        "approval_binding": v2.pop("approval_binding"),
        **v2,
    }
    return ordered, subject_digest


def prepare_contract() -> None:
    assert_rev30_baseline()
    v2, subject_digest = build_v2()
    v2_bytes = dump_yaml(v2)
    materialized_digest = hashlib.sha256(v2_bytes).hexdigest()
    approval_id = v2["approval_binding"]["approval_id"]
    approval_path = APPROVALS_DIR / f"loop-contract-v2-{subject_digest[:12]}.yaml"
    approval = {
        "approval": {
            "schema_version": "game-production-approval/v1",
            "approval_id": approval_id,
            "subject_kind": "loop-contract",
            "subject_id": "LOOP-CTR-GATE1-VERTICAL-SLICE-001@v2",
            "subject_digest": subject_digest,
            "decision": "approved",
            "decided_by": "project-owner",
            "decided_at": DECIDED_AT,
            "evidence": {
                "source_refs": [
                    OWNER_SOURCE_REF,
                    "game-pipeline/loops/evidence/QA-P1-003-decision-package.md@subject-digest:"
                    + DECISION_PACKAGE_DIGEST,
                ],
                "immutable_baseline": compatibility_rule()["immutable_baseline"],
            },
            "authorized_action": {
                "summary": "为 QA-P1-003 建立一次性、精确绑定、可撤销的临时工具兼容迁移。",
                "allowed": [
                    "创建 Contract v2，不覆盖 v1。",
                    "追加 core.contract_migrated 事件并原子更新 Snapshot。",
                    "独立 QA 接受且全部条件满足后允许 active -> review。",
                    "review 后仅准备 GATE-1 决策包。",
                ],
                "forbidden": [
                    "把官方 CLI 记录为通过。",
                    "自动作出 GATE-1 决定。",
                    "在 GATE-1 单独批准前开始正式功能或资产生产。",
                    "修改锁定插件缓存、重写历史或伪造 draft Snapshot。",
                ],
                "revocation": compatibility_rule()["invalidation_conditions"],
            },
            "application": {
                "materialized_path": V2_PATH.relative_to(PROJECT_ROOT).as_posix(),
                "materialized_status": "approved",
                "materialized_digest": materialized_digest,
                "applied_at": DECIDED_AT,
            },
        }
    }
    write_new(V2_PATH, v2_bytes)
    try:
        write_new(approval_path, dump_yaml(approval))
    except Exception:
        V2_PATH.unlink(missing_ok=True)
        raise
    print(json.dumps({
        "contract_v2_path": str(V2_PATH),
        "contract_v2_subject_digest": subject_digest,
        "contract_v2_file_digest": materialized_digest,
        "approval_path": str(approval_path),
        "approval_id": approval_id,
    }, ensure_ascii=False, indent=2))


def verify_contract() -> None:
    assert_rev30_baseline()
    expected, expected_subject_digest = build_v2()
    actual = load_yaml(V2_PATH)
    if actual != expected:
        raise RuntimeError("Contract v2 与从 v1 确定性生成的授权增量不一致")
    subject = copy.deepcopy(actual)
    subject.pop("approval_binding", None)
    if canonical_digest(subject) != expected_subject_digest:
        raise RuntimeError("Contract v2 subject_digest 重算不匹配")
    approval_path = APPROVALS_DIR / f"loop-contract-v2-{expected_subject_digest[:12]}.yaml"
    approval = load_yaml(approval_path)["approval"]
    if approval["subject_digest"] != expected_subject_digest:
        raise RuntimeError("批准记录未绑定 Contract v2 subject_digest")
    if approval["application"]["materialized_digest"] != file_digest(V2_PATH):
        raise RuntimeError("批准记录未绑定 Contract v2 文件摘要")
    print(json.dumps({
        "result": "OK",
        "contract_v2_subject_digest": expected_subject_digest,
        "contract_v2_file_digest": file_digest(V2_PATH),
        "approval_id": approval["approval_id"],
        "rev30_history_unchanged": True,
        "rev30_snapshot_unchanged": True,
    }, ensure_ascii=False, indent=2))


def verify_history_unmodified() -> None:
    if file_digest(VALIDATOR_PATH) != VALIDATOR_DIGEST:
        raise RuntimeError("锁定 validate_loop_registry.py 摘要变化")
    spec = importlib.util.spec_from_file_location("locked_validate_loop_registry", VALIDATOR_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError("无法加载锁定 validate_loop_registry.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    errors = module.validate_history(
        load_yaml(SNAPSHOT_PATH),
        load_yaml(HISTORY_PATH),
        load_yaml(STATE_MACHINE_PATH),
        load_yaml(EVENT_CONTRACT_PATH),
    )
    print(json.dumps({
        "validator_sha256": VALIDATOR_DIGEST,
        "history_error_count": len(errors),
        "errors": errors,
    }, ensure_ascii=False, indent=2))
    if errors:
        raise SystemExit(1)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "action",
        choices=["prepare-contract", "verify-contract", "verify-history", "verify-rev30"],
    )
    args = parser.parse_args()
    if args.action == "verify-rev30":
        assert_rev30_baseline()
        print("OK: rev30/seq30 基线、文件摘要与尾事件摘要一致")
    elif args.action == "verify-contract":
        verify_contract()
    elif args.action == "verify-history":
        verify_history_unmodified()
    else:
        prepare_contract()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
