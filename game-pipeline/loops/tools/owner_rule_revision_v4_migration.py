#!/usr/bin/env python3
"""Materialize the owner-approved 2026-08-17 rule revision as Contract v4.

This one-shot project migration preserves Contract v3 and the first 49 Registry
events, writes immutable approval/evidence records, and appends revision 50.
"""

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
V3_PATH = PROJECT_ROOT / "game-pipeline/loops/contracts/loop-contract-gate1-vertical-slice-v3.yaml"
V4_PATH = PROJECT_ROOT / "game-pipeline/loops/contracts/loop-contract-gate1-vertical-slice-v4.yaml"
APPROVALS_DIR = PROJECT_ROOT / "game-pipeline/approvals"
SNAPSHOT_PATH = PROJECT_ROOT / "game-pipeline/loops/registry/first-production-loop/snapshot.yaml"
HISTORY_PATH = PROJECT_ROOT / "game-pipeline/loops/registry/first-production-loop/event-history.yaml"
EVIDENCE_PATH = PROJECT_ROOT / "game-pipeline/loops/evidence/OWNER-RULE-REVISION-contract-v4-migration-check.md"

V3_SUBJECT_DIGEST = "ce51fe2b91220a618cc81d22e7685f9bb06caa2fc15fa36b2cca83d51a235410"
STATE_MACHINE_DIGEST = "810f414928b370a869b3a36a17cb504f290d17fa07c9ce5db9001136bfdb160c"
OWNER_SOURCE_REF = "codex-thread://current#owner-rule-revision-2026-08-17"


def load_yaml(path: Path) -> dict[str, Any]:
    value = yaml.safe_load(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise RuntimeError(f"{path} must contain a YAML mapping")
    return value


def dump_yaml(value: Any) -> bytes:
    return yaml.safe_dump(value, allow_unicode=True, sort_keys=False, width=120).encode("utf-8")


def file_digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def canonical_digest(value: Any) -> str:
    encoded = json.dumps(
        value, ensure_ascii=False, allow_nan=False, separators=(",", ":"), sort_keys=True
    ).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()


def canonical_event_digest(event: dict[str, Any]) -> str:
    normalized = copy.deepcopy(event)
    normalized["integrity"]["event_digest"] = None
    return canonical_digest(normalized)


def now_china() -> str:
    return datetime.now(timezone(timedelta(hours=8))).isoformat(timespec="microseconds")


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


def append_event_bytes(history_bytes: bytes, event: dict[str, Any]) -> bytes:
    dumped = yaml.safe_dump(event, allow_unicode=True, sort_keys=False, width=120).rstrip("\n")
    lines = dumped.splitlines()
    event_text = "  - " + lines[0] + "\n" + "\n".join("    " + line for line in lines[1:]) + "\n"
    separator = b"\n" if history_bytes.endswith(b"\n") else b"\n\n"
    return history_bytes + separator + event_text.encode("utf-8")


def build_v4(decided_at: str) -> tuple[dict[str, Any], str]:
    source = load_yaml(V3_PATH)
    subject = copy.deepcopy(source)
    subject.pop("approval_binding", None)
    subject["loop_contract"]["version"] = 4

    subject["owner_rule_revision"] = {
        "revision_id": "OWNER-RULE-REVISION-2026-08-17",
        "status": "approved",
        "approved_by": "project-owner",
        "approved_at": decided_at,
        "source_ref": OWNER_SOURCE_REF,
        "rules": {
            "wall_geometry": {
                "red_base": "Y=1..3",
                "red_buffer": "Y=4..8",
                "red_wall": "Y=3/4",
                "black_buffer": "Y=17..21",
                "black_base": "Y=22..24",
                "black_wall": "Y=21/22",
                "battlefield": "X=1..9,Y=9..16",
                "special_region": "Y=4..21",
                "pawn_wall_alignment": "red pawns Y=4; black pawns Y=21",
            },
            "elephant_field": {
                "vision_union": "origin-centered 3x3 + move 3x3 field + target-centered 3x3",
                "rook_blocking": "only enemy rooks entering from outside stop at the first path/field intersection",
                "friendly_rooks_blocked": False,
                "applies_in": "buffer plus battlefield only",
                "lifecycle": "until source elephant next moves, leaves play, returns to base/reserve, or loses the source on wall breach",
            },
            "hidden_flags": {
                "spawn": "three unique cells uniformly sampled from the complete 8x9 battlefield",
                "position_visibility": "never disclosed to either player or AI",
                "capture_start": "stepping on a hidden capturable flag starts at 1/3",
                "public_feedback": [
                    "红方正在夺旗(1/3..3/3)",
                    "黑方正在夺旗(1/3..3/3)",
                    "红方成功夺得一面旗帜",
                    "黑方成功夺得一面旗帜",
                ],
            },
            "advisor_resurrection": {
                "mode": "active turn action",
                "cost": "sacrifice the acting advisor and consume the action",
                "random_pool": "dead friendly non-general non-advisor pieces only",
                "dead_advisors_in_pool": False,
                "dead_generals_in_pool": False,
                "destination": "one random empty cell in the acting side base",
                "availability": "illegal when the pool is empty or the base has no empty cell",
            },
        },
    }

    subject["iteration"]["carry_forward"].append(
        "OWNER-RULE-REVISION-2026-08-17 及其受影响测试必须在最新稳定提交上重检。"
    )
    for check in subject["acceptance"]["automated_checks"]:
        if check["check_id"] == "CHECK-RULES-001":
            check["description"] += " 包含新墙线、敌车田字阻挡、隐藏旗位进度和士主动献祭复活。"
        elif check["check_id"] == "CHECK-FOG-001":
            check["description"] += " 旗位及未触发的敌方相田字阻挡源不得出现在 PlayerView、AI 或联网下行。"
        elif check["check_id"] == "CHECK-AI-001":
            check["description"] += " AI 不得读取隐藏旗位，并须能合法评估士主动复活和敌车田字阻挡后的公开结果。"

    lan = subject["lan_playtest_tool_exception"]
    lan["approved_at"] = decided_at
    lan["source_ref"] = OWNER_SOURCE_REF
    lan["rule_revision_binding"] = {
        "status": "reapproved_after_rule_and_information-boundary_change",
        "rule_revision_id": "OWNER-RULE-REVISION-2026-08-17",
        "requirements": [
            "客户端与房主 UI 均不得接收隐藏旗位。",
            "客户端仅接收自身 PlayerView 中的夺旗进度与成功反馈。",
            "房主权威处理敌车田字阻挡和士献祭复活随机结果。",
            "规则改动后的双实例、隐藏等价和下行白名单必须重新验证。",
        ],
    }
    lan["invalidation_conditions"][0] = "再次发生未经项目所有者批准的信息边界、规则语义、单机核心范围或目标平台变化。"

    tooling = subject["temporary_tooling_compatibility"]
    tooling["immutable_baseline"]["contract_v3_subject_digest"] = V3_SUBJECT_DIGEST
    tooling["immutable_baseline"]["contract_v3_file_digest"] = file_digest(V3_PATH)
    tooling["invalidation_conditions"] = [
        "Contract v4 被替换或撤销。" if value == "Contract v3 被替换或撤销。" else value
        for value in tooling["invalidation_conditions"]
    ]

    subject_digest = canonical_digest(subject)
    approval_id = f"approval:veilfront-xiangqi-siege:loop-contract:{subject_digest[:12]}"
    ordered = {
        "loop_contract": subject.pop("loop_contract"),
        "approval_binding": {
            "approval_id": approval_id,
            "subject_digest": subject_digest,
            "approved_by": "project-owner",
            "approved_at": decided_at,
            "source_ref": OWNER_SOURCE_REF,
        },
        **subject,
    }
    return ordered, subject_digest


def main() -> None:
    snapshot_doc = load_yaml(SNAPSHOT_PATH)
    history_doc = load_yaml(HISTORY_PATH)
    snapshot = snapshot_doc["registry_snapshot"]
    history = history_doc["event_history"]
    if snapshot["contract_binding"] != {
        "contract_id": "LOOP-CTR-GATE1-VERTICAL-SLICE-001",
        "contract_version": 3,
        "contract_digest": V3_SUBJECT_DIGEST,
    }:
        raise RuntimeError("Registry is not on the approved Contract v3 baseline")
    if snapshot["runtime"]["record_revision"] != 49 or snapshot["runtime"]["last_event_sequence"] != 49:
        raise RuntimeError("Registry must be at revision/sequence 49")
    previous_event = history[-1]
    if previous_event["sequence"] != 49 or previous_event["integrity"]["event_digest"] != snapshot["runtime"]["last_event_digest"]:
        raise RuntimeError("Registry tail does not match Snapshot")

    decided_at = now_china()
    v4, subject_digest = build_v4(decided_at)
    v4_bytes = dump_yaml(v4)
    write_new(V4_PATH, v4_bytes)
    v4_file_digest = hashlib.sha256(v4_bytes).hexdigest()
    approval_id = v4["approval_binding"]["approval_id"]
    approval_path = APPROVALS_DIR / f"loop-contract-v4-{subject_digest[:12]}.yaml"
    approval = {
        "approval": {
            "schema_version": "game-production-approval/v1",
            "approval_id": approval_id,
            "subject_kind": "loop-contract",
            "subject_id": "LOOP-CTR-GATE1-VERTICAL-SLICE-001@v4",
            "subject_digest": subject_digest,
            "decision": "approved",
            "decided_by": "project-owner",
            "decided_at": decided_at,
            "evidence": {
                "source_refs": [OWNER_SOURCE_REF],
                "immutable_baseline": {
                    "contract_v3_subject_digest": V3_SUBJECT_DIGEST,
                    "contract_v3_file_digest": file_digest(V3_PATH),
                    "snapshot_rev49_file_digest": file_digest(SNAPSHOT_PATH),
                    "event_history_rev49_file_digest": file_digest(HISTORY_PATH),
                    "record_revision": 49,
                    "last_event_sequence": 49,
                },
            },
            "authorized_action": {
                "summary": "修改墙线、相田字阻挡与视野、隐藏旗帜及士主动献祭复活，并在新规则下继续 AI、LAN UI 和 Windows 测试构建。",
                "allowed": [
                    "创建 Contract v4 并追加 core.contract_migrated 事件。",
                    "更新规则规格、信息边界、Godot 原型、AI、LAN 适配器、测试与导出预置。",
                    "客户端仅接收自身 PlayerView 和不含旗位的公开夺旗反馈。",
                    "生成供项目所有者真实双机测试的 Windows 可分发构建。",
                ],
                "forbidden": [
                    "公开隐藏旗位或向 AI/LAN 客户端泄露相应 FullState 字段。",
                    "把阵亡将帅或阵亡士纳入士献祭复活随机池。",
                    "让相田字区域阻挡己方车。",
                    "把测试 EXE 解释为正式发布联网架构或 GATE-1 自动通过。",
                ],
            },
            "application": {
                "materialized_path": V4_PATH.relative_to(PROJECT_ROOT).as_posix(),
                "materialized_status": "approved",
                "materialized_digest": v4_file_digest,
                "applied_at": decided_at,
            },
        }
    }
    write_new(approval_path, dump_yaml(approval))

    evidence = f"""# OWNER-RULE-REVISION Contract v4 迁移检查

状态：`approved rule and information-boundary migration / pre-implementation`
检查时间：{decided_at}
人工决定者：项目所有者

## 确认规则

- 墙线移至红 `Y=3/4`、黑 `Y=21/22`；兵卒位于缓冲区第一线，战区保持完整 `8x9`。
- 相的视野为起点中心 `3x3`、移动田字九格与终点中心 `3x3` 的并集；田字区域只阻挡从外部进入的敌方车。
- 三旗从整个战区抽取且位置永不进入 PlayerView、AI 或 LAN 下行；仅公开夺旗进度和成功消息。
- 士改为主动献祭复活；随机池只含已阵亡的非将帅、非士友军，阵亡士明确不入池。

## 迁移与边界

- Contract v3 subject digest：`{V3_SUBJECT_DIGEST}`
- Contract v4 subject digest：`{subject_digest}`
- Contract v4 file digest：`{v4_file_digest}`
- approval：`{approval_id}`
- Loop 保持 `active / iteration 2`，迁移不增加 iteration，不批准 GATE-1。
- 原 LAN 例外因规则与信息边界变化失效；项目所有者在本修订中明确要求继续 LAN UI 与双机测试，因此以 v4 重新批准，并要求重跑下行白名单和隐藏等价测试。
- QA-P1-003 官方 CLI 仍必须记录为 `failed / exit 1 / 精确六项已知错误`；若出现第七项错误则停止进入 review。
""".replace("\r\n", "\n").encode("utf-8")
    write_new(EVIDENCE_PATH, evidence)
    evidence_ref = EVIDENCE_PATH.relative_to(PROJECT_ROOT).as_posix() + "@sha256:" + hashlib.sha256(evidence).hexdigest()

    occurred_at = now_china()
    event_id = str(uuid.uuid4())
    event = {
        "schema_version": "0.1",
        "event_id": event_id,
        "mutation_id": str(uuid.uuid4()),
        "loop_instance_id": snapshot["identity"]["loop_instance_id"],
        "sequence": 50,
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
        "concurrency": {"expected_record_revision": 49, "resulting_record_revision": 50},
        "binding_snapshot": {
            "contract_digest": V3_SUBJECT_DIGEST,
            "state_machine_digest": STATE_MACHINE_DIGEST,
        },
        "payload": {
            "contract_before": {
                "contract_id": "LOOP-CTR-GATE1-VERTICAL-SLICE-001",
                "contract_version": 3,
                "contract_digest": V3_SUBJECT_DIGEST,
            },
            "contract_after": {
                "contract_id": "LOOP-CTR-GATE1-VERTICAL-SLICE-001",
                "contract_version": 4,
                "contract_digest": subject_digest,
            },
            "migration_check_ref": evidence_ref,
            "approval_id": approval_id,
        },
        "evidence_refs": [
            approval_path.relative_to(PROJECT_ROOT).as_posix(),
            V4_PATH.relative_to(PROJECT_ROOT).as_posix() + "@sha256:" + v4_file_digest,
            evidence_ref,
            OWNER_SOURCE_REF,
        ],
        "integrity": {
            "canonicalization": "registry-event-canonical-json-v1",
            "digest_algorithm": "sha256",
            "previous_event_digest": previous_event["integrity"]["event_digest"],
            "event_digest": None,
        },
    }
    event["integrity"]["event_digest"] = canonical_event_digest(event)
    original_history = HISTORY_PATH.read_bytes()
    HISTORY_PATH.write_bytes(append_event_bytes(original_history, event))
    snapshot["contract_binding"] = copy.deepcopy(event["payload"]["contract_after"])
    snapshot["runtime"]["last_event_id"] = event_id
    snapshot["runtime"]["last_event_digest"] = event["integrity"]["event_digest"]
    snapshot["runtime"]["last_event_sequence"] = 50
    snapshot["runtime"]["record_revision"] = 50
    SNAPSHOT_PATH.write_bytes(dump_yaml(snapshot_doc))
    if not HISTORY_PATH.read_bytes().startswith(original_history):
        raise RuntimeError("The first 49 Registry events were not preserved byte-for-byte")
    print(json.dumps({
        "result": "migrated",
        "contract_v4_subject_digest": subject_digest,
        "contract_v4_file_digest": v4_file_digest,
        "approval_path": approval_path.relative_to(PROJECT_ROOT).as_posix(),
        "event_id": event_id,
        "event_digest": event["integrity"]["event_digest"],
        "revision": 50,
        "sequence": 50,
    }, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
