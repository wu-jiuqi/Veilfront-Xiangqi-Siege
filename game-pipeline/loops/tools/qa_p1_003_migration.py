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
import subprocess
import uuid
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any

import yaml


PROJECT_ROOT = Path(__file__).resolve().parents[3]
V1_PATH = PROJECT_ROOT / "game-pipeline/loops/contracts/loop-contract-gate1-vertical-slice.yaml"
V2_PATH = PROJECT_ROOT / "game-pipeline/loops/contracts/loop-contract-gate1-vertical-slice-v2.yaml"
APPROVALS_DIR = PROJECT_ROOT / "game-pipeline/approvals"
SNAPSHOT_PATH = PROJECT_ROOT / "game-pipeline/loops/registry/first-production-loop/snapshot.yaml"
HISTORY_PATH = PROJECT_ROOT / "game-pipeline/loops/registry/first-production-loop/event-history.yaml"
MIGRATION_EVIDENCE_PATH = (
    PROJECT_ROOT / "game-pipeline/loops/evidence/QA-P1-003-contract-v2-migration-check.md"
)
QA_REPORT_PATH = (
    PROJECT_ROOT / "evidence/prototype/qa/iteration-1-qa-p1-003-contract-v2-recheck.md"
)
QA_REPORT_DIGEST = "62bceb167f35bd87f3b1d996dc3635689004dc99509b824d88a2c2e7674cc7b5"
QA_REPORT_COMMIT = "83616cc6cb2e56d19b3ec401ec105baf9ef49dd4"
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
REV30_HISTORY_SIZE = 68463
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


def canonical_event_digest(event: dict[str, Any]) -> str:
    normalized = copy.deepcopy(event)
    normalized["integrity"]["event_digest"] = None
    return canonical_digest(normalized)


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


def now_china() -> str:
    return datetime.now(timezone(timedelta(hours=8))).isoformat(timespec="microseconds")


def append_event_bytes(history_bytes: bytes, event: dict[str, Any]) -> bytes:
    dumped = yaml.safe_dump(event, allow_unicode=True, sort_keys=False, width=120).rstrip("\n")
    lines = dumped.splitlines()
    event_text = "  - " + lines[0] + "\n" + "\n".join("    " + line for line in lines[1:]) + "\n"
    separator = b"\n" if history_bytes.endswith(b"\n") else b"\n\n"
    return history_bytes + separator + event_text.encode("utf-8")


def make_event(
    *,
    sequence: int,
    event_type: str,
    actor: dict[str, str],
    payload: dict[str, Any],
    evidence_refs: list[str],
    previous_digest: str,
    causation_event_id: str,
    correlation_id: str,
    request_id: str,
    occurred_at: str,
) -> dict[str, Any]:
    event = {
        "schema_version": "0.1",
        "event_id": str(uuid.uuid4()),
        "mutation_id": str(uuid.uuid4()),
        "loop_instance_id": "4cbb03b6-dd5a-41c5-a624-895c4b884bcb",
        "sequence": sequence,
        "event_type": event_type,
        "occurred_at": occurred_at,
        "recorded_at": occurred_at,
        "actor": actor,
        "causality": {
            "correlation_id": correlation_id,
            "causation_event_id": causation_event_id,
            "request_id": request_id,
        },
        "concurrency": {
            "expected_record_revision": sequence - 1,
            "resulting_record_revision": sequence,
        },
        "binding_snapshot": {
            "contract_digest": build_v2()[1],
            "state_machine_digest": STATE_MACHINE_DIGEST,
        },
        "payload": payload,
        "evidence_refs": evidence_refs,
        "integrity": {
            "canonicalization": "registry-event-canonical-json-v1",
            "digest_algorithm": "sha256",
            "previous_event_digest": previous_digest,
            "event_digest": None,
        },
    }
    event["integrity"]["event_digest"] = canonical_event_digest(event)
    return event


def replace_registry_pair(history_bytes: bytes, snapshot_bytes: bytes) -> None:
    """Best-effort atomic two-file commit with rollback on the second replace."""
    old_history = HISTORY_PATH.read_bytes()
    old_snapshot = SNAPSHOT_PATH.read_bytes()
    temp_history = HISTORY_PATH.with_name(HISTORY_PATH.name + ".qa-p1-003.tmp")
    temp_snapshot = SNAPSHOT_PATH.with_name(SNAPSHOT_PATH.name + ".qa-p1-003.tmp")
    temp_history.write_bytes(history_bytes)
    temp_snapshot.write_bytes(snapshot_bytes)
    try:
        os.replace(temp_history, HISTORY_PATH)
        try:
            os.replace(temp_snapshot, SNAPSHOT_PATH)
        except Exception:
            rollback = HISTORY_PATH.with_name(HISTORY_PATH.name + ".qa-p1-003.rollback")
            rollback.write_bytes(old_history)
            os.replace(rollback, HISTORY_PATH)
            raise
    finally:
        temp_history.unlink(missing_ok=True)
        temp_snapshot.unlink(missing_ok=True)
    # Detect any unexpected partial or stale write immediately.
    if HISTORY_PATH.read_bytes() != history_bytes or SNAPSHOT_PATH.read_bytes() != snapshot_bytes:
        HISTORY_PATH.write_bytes(old_history)
        SNAPSHOT_PATH.write_bytes(old_snapshot)
        raise RuntimeError("Registry 双文件提交后校验失败，已回滚 rev30 基线")


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


def migration_evidence(subject_digest: str, approval_id: str) -> bytes:
    content = f"""# QA-P1-003 Contract v2 迁移检查

状态：`approved / ready_to_apply`

## 迁移对象

- Loop：`LOOP-GATE1-001 / Iteration 1`
- 迁移：`LOOP-CTR-GATE1-VERTICAL-SLICE-001 v1 -> v2`
- Contract v2 subject digest：`{subject_digest}`
- Contract v2 file digest：`{file_digest(V2_PATH)}`
- 批准记录：`{approval_id}`

## 精确绑定基线

- 插件：`game-production-pipeline@{PLUGIN_VERSION}`
- 框架摘要：`{FRAMEWORK_DIGEST}`
- 校验器摘要：`{VALIDATOR_DIGEST}`
- 决策包摘要：`{DECISION_PACKAGE_DIGEST}`
- v1 subject digest：`{V1_SUBJECT_DIGEST}`
- v1 file digest：`{V1_FILE_DIGEST}`
- rev30 Snapshot file digest：`{REV30_SNAPSHOT_DIGEST}`
- rev30 Event History file digest：`{REV30_HISTORY_DIGEST}`
- rev30 尾事件摘要：`{REV30_TAIL_DIGEST}`

## 兼容性结论

- v2 由 v1 确定性复制；除 `version`、新的批准绑定和新增 `temporary_tooling_compatibility` 外，原 Contract 语义未改变。
- 临时规则只处理 QA-P1-003 的六项已知官方 CLI 模板错误；官方 CLI 必须继续记录为 `failed`。
- 玩法、质量阈值、1000 种子、确定性、独立 QA、GATE-1 权限和正式生产边界保持不变。
- 迁移只允许追加 `core.contract_migrated`；前 30 条事件不得改写。
- 独立 QA 接受例外并确认全部条件前，Loop 保持 `active`。

## 失效与回退

任一 v2 `invalidation_conditions` 成立时，本例外立即失效；不得以本记录宣称官方 CLI 通过，也不得自动作出 GATE-1 决定。
"""
    return content.replace("\r\n", "\n").encode("utf-8")


def migrate_registry() -> None:
    snapshot_doc, history_doc = assert_rev30_baseline()
    v2, subject_digest = build_v2()
    if load_yaml(V2_PATH) != v2:
        raise RuntimeError("已物化 Contract v2 与确定性生成结果不一致")
    approval_id = v2["approval_binding"]["approval_id"]
    approval_path = APPROVALS_DIR / f"loop-contract-v2-{subject_digest[:12]}.yaml"
    approval = load_yaml(approval_path)["approval"]
    if approval["decision"] != "approved" or approval["subject_digest"] != subject_digest:
        raise RuntimeError("Contract v2 缺少匹配的项目所有者批准")

    evidence_bytes = migration_evidence(subject_digest, approval_id)
    write_new(MIGRATION_EVIDENCE_PATH, evidence_bytes)
    evidence_ref = (
        MIGRATION_EVIDENCE_PATH.relative_to(PROJECT_ROOT).as_posix()
        + "@sha256:"
        + hashlib.sha256(evidence_bytes).hexdigest()
    )
    occurred_at = now_china()
    previous_event = history_doc["event_history"][-1]
    event_id = str(uuid.uuid4())
    event = {
        "schema_version": "0.1",
        "event_id": event_id,
        "mutation_id": str(uuid.uuid4()),
        "loop_instance_id": snapshot_doc["registry_snapshot"]["identity"]["loop_instance_id"],
        "sequence": 31,
        "event_type": "core.contract_migrated",
        "occurred_at": occurred_at,
        "recorded_at": occurred_at,
        "actor": {
            "actor_id": "inst:01M02M6X3Q8YWJXHY52K3V5AR2",
            "role": "pos:veilfront-xiangqi-siege:root:project-manager",
            "authority_id": "AUTH-VEILFRONT-PROJECT-MANAGER",
        },
        "causality": {
            "correlation_id": str(uuid.uuid4()),
            "causation_event_id": previous_event["event_id"],
            "request_id": approval_id,
        },
        "concurrency": {"expected_record_revision": 30, "resulting_record_revision": 31},
        "binding_snapshot": {
            "contract_digest": V1_SUBJECT_DIGEST,
            "state_machine_digest": STATE_MACHINE_DIGEST,
        },
        "payload": {
            "contract_before": {
                "contract_id": "LOOP-CTR-GATE1-VERTICAL-SLICE-001",
                "contract_version": 1,
                "contract_digest": V1_SUBJECT_DIGEST,
            },
            "contract_after": {
                "contract_id": "LOOP-CTR-GATE1-VERTICAL-SLICE-001",
                "contract_version": 2,
                "contract_digest": subject_digest,
            },
            "migration_check_ref": evidence_ref,
            "approval_id": approval_id,
        },
        "evidence_refs": [
            approval_path.relative_to(PROJECT_ROOT).as_posix(),
            V2_PATH.relative_to(PROJECT_ROOT).as_posix() + "@sha256:" + file_digest(V2_PATH),
            evidence_ref,
            "game-pipeline/loops/evidence/QA-P1-003-decision-package.md@subject-digest:"
            + DECISION_PACKAGE_DIGEST,
        ],
        "integrity": {
            "canonicalization": "registry-event-canonical-json-v1",
            "digest_algorithm": "sha256",
            "previous_event_digest": REV30_TAIL_DIGEST,
            "event_digest": None,
        },
    }
    event["integrity"]["event_digest"] = canonical_event_digest(event)

    original_history_bytes = HISTORY_PATH.read_bytes()
    history_bytes = append_event_bytes(original_history_bytes, event)
    snapshot = snapshot_doc["registry_snapshot"]
    snapshot["contract_binding"] = copy.deepcopy(event["payload"]["contract_after"])
    runtime = snapshot["runtime"]
    runtime["last_event_id"] = event_id
    runtime["last_event_digest"] = event["integrity"]["event_digest"]
    runtime["last_event_sequence"] = 31
    runtime["record_revision"] = 31
    replace_registry_pair(history_bytes, dump_yaml(snapshot_doc))

    # The original bytes must remain an exact immutable prefix after append.
    current_history_bytes = HISTORY_PATH.read_bytes()
    if current_history_bytes[: len(original_history_bytes)] != original_history_bytes:
        raise RuntimeError("rev30 Event History 字节前缀在迁移后发生变化")
    if hashlib.sha256(current_history_bytes[: len(original_history_bytes)]).hexdigest() != REV30_HISTORY_DIGEST:
        raise RuntimeError("rev30 Event History 前缀摘要在迁移后发生变化")
    print(json.dumps({
        "result": "migrated",
        "event_id": event_id,
        "event_sequence": 31,
        "event_digest": event["integrity"]["event_digest"],
        "contract_v2_subject_digest": subject_digest,
        "snapshot_record_revision": 31,
        "snapshot_state": snapshot["runtime"]["current_state"],
        "migration_evidence": evidence_ref,
    }, ensure_ascii=False, indent=2))


def verify_migrated() -> None:
    history_bytes = HISTORY_PATH.read_bytes()
    if len(history_bytes) <= REV30_HISTORY_SIZE:
        raise RuntimeError("Event History 未包含 seq31 迁移事件")
    if hashlib.sha256(history_bytes[:REV30_HISTORY_SIZE]).hexdigest() != REV30_HISTORY_DIGEST:
        raise RuntimeError("rev30 Event History 字节前缀摘要不匹配")
    history_doc = load_yaml(HISTORY_PATH)
    snapshot_doc = load_yaml(SNAPSHOT_PATH)
    events = history_doc["event_history"]
    snapshot = snapshot_doc["registry_snapshot"]
    if len(events) != 31:
        raise RuntimeError(f"迁移验证预期 31 条事件，实际 {len(events)}")
    event = events[30]
    expected_subject_digest = build_v2()[1]
    checks = [
        (events[29]["integrity"]["event_digest"], REV30_TAIL_DIGEST, "rev30 尾事件摘要"),
        (event["sequence"], 31, "迁移事件 sequence"),
        (event["event_type"], "core.contract_migrated", "迁移事件类型"),
        (event["integrity"]["previous_event_digest"], REV30_TAIL_DIGEST, "迁移事件前链摘要"),
        (event["integrity"]["event_digest"], canonical_event_digest(event), "迁移事件摘要"),
        (event["binding_snapshot"]["contract_digest"], V1_SUBJECT_DIGEST, "迁移前事件绑定"),
        (event["payload"]["contract_after"]["contract_digest"], expected_subject_digest, "迁移后摘要"),
        (snapshot["contract_binding"]["contract_version"], 2, "Snapshot Contract 版本"),
        (snapshot["contract_binding"]["contract_digest"], expected_subject_digest, "Snapshot Contract 摘要"),
        (snapshot["runtime"]["record_revision"], 31, "Snapshot revision"),
        (snapshot["runtime"]["last_event_sequence"], 31, "Snapshot sequence"),
        (snapshot["runtime"]["last_event_id"], event["event_id"], "Snapshot last_event_id"),
        (snapshot["runtime"]["last_event_digest"], event["integrity"]["event_digest"], "Snapshot last_event_digest"),
        (snapshot["runtime"]["current_state"], "active", "Snapshot state"),
        (snapshot["runtime"]["current_iteration"], 1, "Snapshot iteration"),
    ]
    for actual, expected, label in checks:
        if actual != expected:
            raise RuntimeError(f"{label} 不匹配: expected={expected} actual={actual}")
    print(json.dumps({
        "result": "OK",
        "rev30_prefix_sha256": REV30_HISTORY_DIGEST,
        "rev30_tail_event_digest": REV30_TAIL_DIGEST,
        "migration_event_id": event["event_id"],
        "migration_event_digest": event["integrity"]["event_digest"],
        "snapshot_revision": 31,
        "last_event_sequence": 31,
        "contract_v2_subject_digest": expected_subject_digest,
        "state": "active",
        "iteration": 1,
    }, ensure_ascii=False, indent=2))


def minimize_snapshot_diff() -> None:
    """Restore rev30 formatting while preserving the verified rev31 semantics."""
    current_doc = load_yaml(SNAPSHOT_PATH)
    completed = subprocess.run(
        ["git", "show", "10ce887:game-pipeline/loops/registry/first-production-loop/snapshot.yaml"],
        cwd=PROJECT_ROOT,
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    base_bytes = completed.stdout
    if hashlib.sha256(base_bytes).hexdigest() != REV30_SNAPSHOT_DIGEST:
        raise RuntimeError("Git 中的 rev30 Snapshot 摘要不匹配")
    text = base_bytes.decode("utf-8")
    event = load_yaml(HISTORY_PATH)["event_history"][30]
    subject_digest = build_v2()[1]
    replacements = [
        (
            "  contract_binding:\n"
            "    contract_id: LOOP-CTR-GATE1-VERTICAL-SLICE-001\n"
            "    contract_version: 1\n"
            f"    contract_digest: {V1_SUBJECT_DIGEST}\n",
            "  contract_binding:\n"
            "    contract_id: LOOP-CTR-GATE1-VERTICAL-SLICE-001\n"
            "    contract_version: 2\n"
            f"    contract_digest: {subject_digest}\n",
        ),
        ("    last_event_id: 947ef717-8f6a-4199-8fab-de9bfe02110a\n", f"    last_event_id: {event['event_id']}\n"),
        (f"    last_event_digest: {REV30_TAIL_DIGEST}\n", f"    last_event_digest: {event['integrity']['event_digest']}\n"),
        ("    last_event_sequence: 30\n", "    last_event_sequence: 31\n"),
        ("    record_revision: 30\n", "    record_revision: 31\n"),
    ]
    for before, after in replacements:
        if text.count(before) != 1:
            raise RuntimeError(f"Snapshot 最小替换目标不是唯一项: {before!r}")
        text = text.replace(before, after, 1)
    minimized_bytes = text.encode("utf-8")
    minimized_doc = yaml.safe_load(minimized_bytes)
    if minimized_doc != current_doc:
        raise RuntimeError("最小格式 Snapshot 与已验证 rev31 语义不一致")
    temp = SNAPSHOT_PATH.with_name(SNAPSHOT_PATH.name + ".minimize.tmp")
    temp.write_bytes(minimized_bytes)
    os.replace(temp, SNAPSHOT_PATH)
    print(json.dumps({
        "result": "OK",
        "snapshot_revision": 31,
        "semantic_change": False,
        "format_churn_removed": True,
    }, ensure_ascii=False, indent=2))


def record_qa_and_enter_review() -> None:
    verify_migrated()
    if file_digest(QA_REPORT_PATH) != QA_REPORT_DIGEST:
        raise RuntimeError("独立 QA 报告摘要不匹配")
    report_text = QA_REPORT_PATH.read_text(encoding="utf-8")
    required_markers = [
        "owner-approved tooling exception",
        "官方 `validate_loop_registry` CLI：**failed**",
        "completed_matches=1000",
        "failure_count=0",
        "determinism_mismatch_count=0",
        "允许项目经理执行该转换",
        "`GATE-1`：`not_made`",
        "新增缺陷：无",
    ]
    missing = [marker for marker in required_markers if marker not in report_text]
    if missing:
        raise RuntimeError(f"独立 QA 报告缺少必要结论: {missing}")

    snapshot_doc = load_yaml(SNAPSHOT_PATH)
    snapshot = snapshot_doc["registry_snapshot"]
    history_bytes = HISTORY_PATH.read_bytes()
    history = load_yaml(HISTORY_PATH)["event_history"]
    previous_event = history[-1]
    v2_digest = build_v2()[1]
    qa_ref = (
        f"git:veilfront-xiangqi-siege:{QA_REPORT_COMMIT}#"
        + QA_REPORT_PATH.relative_to(PROJECT_ROOT).as_posix()
    )
    acceptance_subject = {
        "subject": "LOOP-GATE1-001-iteration-1-qa-p1-003-v2-recheck",
        "contract_digest": v2_digest,
        "migration_event_digest": previous_event["integrity"]["event_digest"],
        "qa_report_commit": QA_REPORT_COMMIT,
        "qa_report_sha256": QA_REPORT_DIGEST,
        "official_cli": {"result": "failed", "exit_code": 1, "errors": EXPECTED_CLI_ERRORS},
        "validate_history": {"exit_code": 0, "error_count": 0},
        "seeded_matches": {
            "completed": 1000,
            "passed": 1000,
            "failure_count": 0,
            "determinism_mismatch_count": 0,
            "records_digest": "dcc6947442ee14d05636953095d07c19ebd093ff616449598612082baa03575d",
        },
    }
    acceptance_digest = canonical_digest(acceptance_subject)
    outputs = snapshot["resources"]["outputs"]
    qa_output = next(item for item in outputs if item["deliverable_id"] == "DELIVERABLE-QA-001")
    output_event_id = str(uuid.uuid4())
    after_output = {
        "deliverable_id": "DELIVERABLE-QA-001",
        "artifact": {
            "artifact_id": "artifact:veilfront-xiangqi-siege:gate1-evidence@prototype-v1",
            "artifact_type": "independent-gate-evidence",
            "version": f"iteration-1-qa-p1-003-contract-v2-recheck@{QA_REPORT_COMMIT}",
            "uri": qa_ref,
            "manifest_paths": [QA_REPORT_PATH.relative_to(PROJECT_ROOT).as_posix()],
            "digest": {"algorithm": "sha256", "value": QA_REPORT_DIGEST},
        },
        "produced_in_iteration": 1,
        "lifecycle_status": "submitted",
        "registered_by_event_id": output_event_id,
    }
    occurred_at = now_china()
    correlation_id = str(uuid.uuid4())
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
    event32 = make_event(
        sequence=32,
        event_type="core.output_registered",
        actor=project_manager,
        payload={
            "deliverable_id": "DELIVERABLE-QA-001",
            "before": copy.deepcopy(qa_output),
            "after": after_output,
        },
        evidence_refs=[qa_ref],
        previous_digest=previous_event["integrity"]["event_digest"],
        causation_event_id=previous_event["event_id"],
        correlation_id=correlation_id,
        request_id=QA_REPORT_COMMIT,
        occurred_at=occurred_at,
    )
    # registered_by_event_id is part of the output payload and therefore must use the actual event ID.
    event32["payload"]["after"]["registered_by_event_id"] = event32["event_id"]
    event32["integrity"]["event_digest"] = canonical_event_digest(event32)

    automated_record_id = str(uuid.uuid4())
    automated_record = {
        "check_set_id": automated_record_id,
        "result": "pass_with_owner_approved_tooling_exception",
        "evidence_ref": qa_ref,
        "subject_digest": acceptance_digest,
        "project_instance": {"exit_code": 0, "state": "normal"},
        "pipeline_contract": {"exit_code": 0, "result": "pass"},
        "organization_history": {"exit_code": 0, "result": "pass"},
        "official_cli": {
            "exit_code": 1,
            "result": "failed",
            "error_count": 6,
            "errors": EXPECTED_CLI_ERRORS,
        },
        "validate_history": {"exit_code": 0, "error_count": 0, "result": "pass_limited_scope"},
        "registry_consistency": {"result": "pass", "revision": 31, "sequence": 31},
        "godot_regression": {"result": "pass", "version": "4.7.1"},
        "seeded_matches": acceptance_subject["seeded_matches"],
        "new_defects": [],
    }
    event33 = make_event(
        sequence=33,
        event_type="core.acceptance_recorded",
        actor=qa_actor,
        payload={
            "acceptance_kind": "automated_check",
            "record_id": automated_record_id,
            "subject_digest": acceptance_digest,
            "record": automated_record,
        },
        evidence_refs=[qa_ref],
        previous_digest=event32["integrity"]["event_digest"],
        causation_event_id=event32["event_id"],
        correlation_id=correlation_id,
        request_id=QA_REPORT_COMMIT,
        occurred_at=occurred_at,
    )

    review_id = str(uuid.uuid4())
    professional_record = {
        "review_id": review_id,
        "reviewer_assignment_id": "9589489a-be2a-436f-bde4-8488d684c0bb",
        "reviewer_instance_id": "inst:01M02NJ3JFHVZ5C4SP5MTJFJR6",
        "verdict": "pass_with_owner_approved_tooling_exception",
        "technical_regression": "pass",
        "professional_result": "owner-approved tooling exception",
        "evidence_state": "sufficient",
        "current_submission_accepted": True,
        "full_gate1": False,
        "gate_decision": "not_made",
        "transition_to_review_allowed": True,
        "evidence_ref": qa_ref,
        "subject_digest": acceptance_digest,
        "defect_regression": [
            {"defect_id": "QA-P1-001", "status": "closed"},
            {"defect_id": "QA-P1-002", "status": "closed"},
            {
                "defect_id": "QA-P1-003",
                "status": "controlled_temporary_exception",
                "classification": "owner-approved tooling exception",
                "official_cli": "failed",
            },
        ],
        "new_defects": [],
        "formal_production": "forbidden_until_separate_gate_1_approval",
        "legal_next_action": "transition_active_to_review_then_prepare_gate_1_decision_package",
    }
    event34 = make_event(
        sequence=34,
        event_type="core.acceptance_recorded",
        actor=qa_actor,
        payload={
            "acceptance_kind": "professional_review",
            "record_id": review_id,
            "subject_digest": acceptance_digest,
            "record": professional_record,
        },
        evidence_refs=[qa_ref],
        previous_digest=event33["integrity"]["event_digest"],
        causation_event_id=event33["event_id"],
        correlation_id=correlation_id,
        request_id=QA_REPORT_COMMIT,
        occurred_at=occurred_at,
    )

    event35 = make_event(
        sequence=35,
        event_type="core.state_transitioned",
        actor=project_manager,
        payload={
            "transition_id": "TR-ACTIVE-REVIEW",
            "from_state": "active",
            "to_state": "review",
            "iteration": {"before": 1, "after": 1},
            "reason": "iteration_submitted_after_independent_qa_owner_approved_tooling_exception",
            "subject_digest": acceptance_digest,
        },
        evidence_refs=[qa_ref, f"event:{event34['event_id']}@digest:{event34['integrity']['event_digest']}"],
        previous_digest=event34["integrity"]["event_digest"],
        causation_event_id=event34["event_id"],
        correlation_id=correlation_id,
        request_id=QA_REPORT_COMMIT,
        occurred_at=occurred_at,
    )

    for event in (event32, event33, event34, event35):
        history_bytes = append_event_bytes(history_bytes, event)
    qa_output.clear()
    qa_output.update(copy.deepcopy(event32["payload"]["after"]))
    acceptance = snapshot["acceptance_snapshot"]
    acceptance["subject_digest"] = acceptance_digest
    acceptance["automated_checks"].append(automated_record)
    acceptance["professional_reviews"].append(professional_record)
    runtime = snapshot["runtime"]
    runtime["current_state"] = "review"
    runtime["state_entered_at"] = occurred_at
    runtime["last_transition_id"] = "TR-ACTIVE-REVIEW"
    runtime["last_event_id"] = event35["event_id"]
    runtime["last_event_digest"] = event35["integrity"]["event_digest"]
    runtime["last_event_sequence"] = 35
    runtime["record_revision"] = 35
    snapshot["budget"]["usage"]["completed_iterations"] = 1
    replace_registry_pair(history_bytes, dump_yaml(snapshot_doc))
    print(json.dumps({
        "result": "review",
        "qa_report_sha256": QA_REPORT_DIGEST,
        "acceptance_subject_digest": acceptance_digest,
        "events": [
            {"sequence": item["sequence"], "event_type": item["event_type"], "event_id": item["event_id"], "event_digest": item["integrity"]["event_digest"]}
            for item in (event32, event33, event34, event35)
        ],
        "snapshot_revision": 35,
        "last_event_sequence": 35,
        "current_state": "review",
        "gate_1_decision": "not_made",
        "formal_production": "forbidden",
    }, ensure_ascii=False, indent=2))


def minimize_final_snapshot_diff() -> None:
    """Restore rev30 layout while retaining the complete rev35 materialized view."""
    current_doc = load_yaml(SNAPSHOT_PATH)
    current = current_doc["registry_snapshot"]
    completed = subprocess.run(
        ["git", "show", "10ce887:game-pipeline/loops/registry/first-production-loop/snapshot.yaml"],
        cwd=PROJECT_ROOT,
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    base_bytes = completed.stdout
    if hashlib.sha256(base_bytes).hexdigest() != REV30_SNAPSHOT_DIGEST:
        raise RuntimeError("Git 中的 rev30 Snapshot 摘要不匹配")
    text = base_bytes.decode("utf-8")
    runtime = current["runtime"]
    v2_digest = build_v2()[1]
    replacements = [
        (
            "  contract_binding:\n"
            "    contract_id: LOOP-CTR-GATE1-VERTICAL-SLICE-001\n"
            "    contract_version: 1\n"
            f"    contract_digest: {V1_SUBJECT_DIGEST}\n",
            "  contract_binding:\n"
            "    contract_id: LOOP-CTR-GATE1-VERTICAL-SLICE-001\n"
            "    contract_version: 2\n"
            f"    contract_digest: {v2_digest}\n",
        ),
        ("    current_state: active\n", "    current_state: review\n"),
        (
            "    state_entered_at: '2026-08-15T20:15:17.6009401+08:00'\n",
            f"    state_entered_at: '{runtime['state_entered_at']}'\n",
        ),
        ("    last_transition_id: TR-READY-ACTIVE\n", "    last_transition_id: TR-ACTIVE-REVIEW\n"),
        ("    last_event_id: 947ef717-8f6a-4199-8fab-de9bfe02110a\n", f"    last_event_id: {runtime['last_event_id']}\n"),
        (f"    last_event_digest: {REV30_TAIL_DIGEST}\n", f"    last_event_digest: {runtime['last_event_digest']}\n"),
        ("    last_event_sequence: 30\n", f"    last_event_sequence: {runtime['last_event_sequence']}\n"),
        ("    record_revision: 30\n", f"    record_revision: {runtime['record_revision']}\n"),
        ("      completed_iterations: 0\n", "      completed_iterations: 1\n"),
    ]
    for before, after in replacements:
        if text.count(before) != 1:
            raise RuntimeError(f"Snapshot 最小替换目标不是唯一项: {before!r}")
        text = text.replace(before, after, 1)

    outputs = current["resources"]["outputs"]
    qa_index = next(index for index, item in enumerate(outputs) if item["deliverable_id"] == "DELIVERABLE-QA-001")
    qa_dump = yaml.safe_dump(outputs[qa_index:], allow_unicode=True, sort_keys=False, width=120).rstrip("\n")
    qa_block = "\n".join("      " + line for line in qa_dump.splitlines()) + "\n"
    qa_start = text.index("      - deliverable_id: DELIVERABLE-QA-001\n")
    qa_end = text.index("  acceptance_snapshot:\n", qa_start)
    text = text[:qa_start] + qa_block + text[qa_end:]

    acceptance_dump = yaml.safe_dump(
        {"acceptance_snapshot": current["acceptance_snapshot"]},
        allow_unicode=True,
        sort_keys=False,
        width=120,
    ).rstrip("\n")
    acceptance_block = "\n".join("  " + line for line in acceptance_dump.splitlines()) + "\n"
    acceptance_start = text.index("  acceptance_snapshot:\n")
    acceptance_end = text.index("  interruption: null\n", acceptance_start)
    text = text[:acceptance_start] + acceptance_block + text[acceptance_end:]

    minimized_bytes = text.encode("utf-8")
    if yaml.safe_load(minimized_bytes) != current_doc:
        raise RuntimeError("最小格式 rev35 Snapshot 与已验证语义不一致")
    temp = SNAPSHOT_PATH.with_name(SNAPSHOT_PATH.name + ".minimize-final.tmp")
    temp.write_bytes(minimized_bytes)
    os.replace(temp, SNAPSHOT_PATH)
    print(json.dumps({
        "result": "OK",
        "snapshot_revision": runtime["record_revision"],
        "semantic_change": False,
        "format_churn_removed": True,
    }, ensure_ascii=False, indent=2))


def register_gate1_package() -> None:
    verify_final_review()
    package_path = PROJECT_ROOT / "game-pipeline/loops/evidence/GATE-1-decision-package.md"
    package_digest = file_digest(package_path)
    snapshot_doc = load_yaml(SNAPSHOT_PATH)
    snapshot = snapshot_doc["registry_snapshot"]
    history_bytes = HISTORY_PATH.read_bytes()
    history = load_yaml(HISTORY_PATH)["event_history"]
    previous_event = history[-1]
    occurred_at = now_china()
    after_output = {
        "deliverable_id": "DELIVERABLE-GATE1-001",
        "artifact": {
            "artifact_id": "artifact:veilfront-xiangqi-siege:gate1-decision-package@v1",
            "artifact_type": "human-decision-package",
            "version": f"awaiting-human@sha256:{package_digest}",
            "uri": package_path.relative_to(PROJECT_ROOT).as_posix(),
            "manifest_paths": [package_path.relative_to(PROJECT_ROOT).as_posix()],
            "digest": {"algorithm": "sha256", "value": package_digest},
        },
        "produced_in_iteration": 1,
        "lifecycle_status": "submitted",
        "registered_by_event_id": None,
    }
    event = make_event(
        sequence=36,
        event_type="core.output_registered",
        actor={
            "actor_id": "inst:01M02M6X3Q8YWJXHY52K3V5AR2",
            "role": "pos:veilfront-xiangqi-siege:root:project-manager",
            "authority_id": "AUTH-VEILFRONT-PROJECT-MANAGER",
        },
        payload={
            "deliverable_id": "DELIVERABLE-GATE1-001",
            "before": None,
            "after": after_output,
        },
        evidence_refs=[
            package_path.relative_to(PROJECT_ROOT).as_posix() + "@sha256:" + package_digest,
            f"event:{previous_event['event_id']}@digest:{previous_event['integrity']['event_digest']}",
        ],
        previous_digest=previous_event["integrity"]["event_digest"],
        causation_event_id=previous_event["event_id"],
        correlation_id=str(uuid.uuid4()),
        request_id="GATE-1-decision-package-preparation",
        occurred_at=occurred_at,
    )
    event["payload"]["after"]["registered_by_event_id"] = event["event_id"]
    event["integrity"]["event_digest"] = canonical_event_digest(event)
    history_bytes = append_event_bytes(history_bytes, event)
    snapshot["resources"]["outputs"].append(copy.deepcopy(event["payload"]["after"]))
    runtime = snapshot["runtime"]
    runtime["last_event_id"] = event["event_id"]
    runtime["last_event_digest"] = event["integrity"]["event_digest"]
    runtime["last_event_sequence"] = 36
    runtime["record_revision"] = 36
    replace_registry_pair(history_bytes, dump_yaml(snapshot_doc))
    print(json.dumps({
        "result": "registered",
        "event_sequence": 36,
        "event_id": event["event_id"],
        "event_digest": event["integrity"]["event_digest"],
        "gate1_package_sha256": package_digest,
        "snapshot_revision": 36,
        "current_state": "review",
        "gate_1_decision": "not_made",
    }, ensure_ascii=False, indent=2))


def verify_final_review() -> None:
    history_bytes = HISTORY_PATH.read_bytes()
    if hashlib.sha256(history_bytes[:REV30_HISTORY_SIZE]).hexdigest() != REV30_HISTORY_DIGEST:
        raise RuntimeError("rev30 Event History 字节前缀摘要不匹配")
    history = load_yaml(HISTORY_PATH)["event_history"]
    snapshot = load_yaml(SNAPSHOT_PATH)["registry_snapshot"]
    if len(history) != 36:
        raise RuntimeError(f"最终 Event History 预期 36 条，实际 {len(history)}")
    expected_types = [
        "core.contract_migrated",
        "core.output_registered",
        "core.acceptance_recorded",
        "core.acceptance_recorded",
        "core.state_transitioned",
        "core.output_registered",
    ]
    if [item["event_type"] for item in history[30:36]] != expected_types:
        raise RuntimeError("seq31-36 事件类型序列不匹配")
    v2_digest = build_v2()[1]
    for index, event in enumerate(history, start=1):
        if event["sequence"] != index:
            raise RuntimeError(f"事件 sequence 不连续: index={index}")
        if event["integrity"]["event_digest"] != canonical_event_digest(event):
            raise RuntimeError(f"事件摘要不匹配: sequence={index}")
        if index > 1 and event["integrity"]["previous_event_digest"] != history[index - 2]["integrity"]["event_digest"]:
            raise RuntimeError(f"事件摘要断链: sequence={index}")
    for event in history[31:36]:
        if event["binding_snapshot"]["contract_digest"] != v2_digest:
            raise RuntimeError(f"迁移后事件未绑定 Contract v2: sequence={event['sequence']}")
    runtime = snapshot["runtime"]
    checks = [
        (snapshot["contract_binding"]["contract_version"], 2, "Contract version"),
        (snapshot["contract_binding"]["contract_digest"], v2_digest, "Contract digest"),
        (runtime["current_state"], "review", "state"),
        (runtime["current_iteration"], 1, "iteration"),
        (runtime["record_revision"], 36, "revision"),
        (runtime["last_event_sequence"], 36, "sequence"),
        (runtime["last_event_id"], history[-1]["event_id"], "last_event_id"),
        (runtime["last_event_digest"], history[-1]["integrity"]["event_digest"], "last_event_digest"),
        (runtime["last_transition_id"], "TR-ACTIVE-REVIEW", "last_transition_id"),
        (snapshot["budget"]["usage"]["completed_iterations"], 1, "completed_iterations"),
        (snapshot["acceptance_snapshot"]["human_gates"], [], "human_gates"),
        (snapshot["pending_approvals"], [], "pending_approvals"),
    ]
    for actual, expected, label in checks:
        if actual != expected:
            raise RuntimeError(f"最终 Snapshot {label} 不匹配: expected={expected} actual={actual}")
    automated = snapshot["acceptance_snapshot"]["automated_checks"][-1]
    professional = snapshot["acceptance_snapshot"]["professional_reviews"][-1]
    if automated["official_cli"] != {
        "exit_code": 1,
        "result": "failed",
        "error_count": 6,
        "errors": EXPECTED_CLI_ERRORS,
    }:
        raise RuntimeError("最终自动检查没有如实记录官方 CLI failed/exit1/六项错误")
    if professional["professional_result"] != "owner-approved tooling exception":
        raise RuntimeError("最终专业审查没有使用批准的例外名称")
    if professional["gate_decision"] != "not_made" or professional["formal_production"] != "forbidden_until_separate_gate_1_approval":
        raise RuntimeError("GATE-1 或正式生产边界记录不正确")
    gate_output = next(
        item for item in snapshot["resources"]["outputs"]
        if item["deliverable_id"] == "DELIVERABLE-GATE1-001"
    )
    gate_path = PROJECT_ROOT / gate_output["artifact"]["uri"]
    if gate_output["artifact"]["digest"]["value"] != file_digest(gate_path):
        raise RuntimeError("GATE-1 决策包 Registry 摘要与文件不匹配")
    print(json.dumps({
        "result": "OK",
        "rev30_prefix_sha256": REV30_HISTORY_DIGEST,
        "contract_v2_subject_digest": v2_digest,
        "record_revision": 36,
        "last_event_sequence": 36,
        "last_event_digest": history[-1]["integrity"]["event_digest"],
        "current_state": "review",
        "current_iteration": 1,
        "official_cli": "failed",
        "exception_status": "owner-approved tooling exception",
        "gate_1_decision": "not_made",
        "gate_1_package_sha256": gate_output["artifact"]["digest"]["value"],
        "formal_production": "forbidden",
    }, ensure_ascii=False, indent=2))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "action",
        choices=[
            "migrate-registry",
            "minimize-snapshot-diff",
            "minimize-final-snapshot-diff",
            "prepare-contract",
            "record-qa-and-enter-review",
            "register-gate1-package",
            "verify-contract",
            "verify-history",
            "verify-final-review",
            "verify-migrated",
            "verify-rev30",
        ],
    )
    args = parser.parse_args()
    if args.action == "verify-rev30":
        assert_rev30_baseline()
        print("OK: rev30/seq30 基线、文件摘要与尾事件摘要一致")
    elif args.action == "verify-contract":
        verify_contract()
    elif args.action == "verify-history":
        verify_history_unmodified()
    elif args.action == "migrate-registry":
        migrate_registry()
    elif args.action == "verify-migrated":
        verify_migrated()
    elif args.action == "minimize-snapshot-diff":
        minimize_snapshot_diff()
    elif args.action == "record-qa-and-enter-review":
        record_qa_and_enter_review()
    elif args.action == "minimize-final-snapshot-diff":
        minimize_final_snapshot_diff()
    elif args.action == "verify-final-review":
        verify_final_review()
    elif args.action == "register-gate1-package":
        register_gate1_package()
    else:
        prepare_contract()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
