#!/usr/bin/env python3
"""Register RC3 evidence, enter review, and prepare the human GATE-1 package."""

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
SNAPSHOT_PATH = PROJECT_ROOT / "game-pipeline/loops/registry/first-production-loop/snapshot.yaml"
HISTORY_PATH = PROJECT_ROOT / "game-pipeline/loops/registry/first-production-loop/event-history.yaml"
PACKAGE_PATH = PROJECT_ROOT / "game-pipeline/loops/evidence/GATE-1-decision-package.md"
QA_DIR = PROJECT_ROOT / "evidence/prototype/qa"

LOOP_ID = "4cbb03b6-dd5a-41c5-a624-895c4b884bcb"
CONTRACT_DIGEST = "d88d9017bb30437ac480e0fcf4f7b262b5ae6b3427447946e50ec37a5d3b44ca"
BRIEF_DIGEST = "df8deb810d8c06c8c2f5763031fde2c39f14aa81226e23ffb25636ee3f1eca0b"
STATE_MACHINE_DIGEST = "810f414928b370a869b3a36a17cb504f290d17fa07c9ce5db9001136bfdb160c"
CANDIDATE_COMMIT = "6253678157157091584b253470e709bad17c534f"
PRODUCTION_FIX_COMMIT = "b3bc3861b6e88e875fb991951dcdad53249bf687"
QA_EVIDENCE_COMMIT = "7e20acbf61a42e9dcedb88dcf68b8bc8b68d9c9f"
RC3_PATH = "builds/windows/Veilfront_Xiangqi_Siege_GATE1_RC3.exe"
RC3_SIZE = 109740336
RC3_SHA256 = "480273ddeae985c0c4aa03be449e5999fba57ca7b296b591ac7ed36b5bc8a229"

EXPECTED_CLI_ERRORS = [
    "Snapshot 模板初始状态必须等于状态机 initial_state",
    "Snapshot 模板 current_iteration 必须从 0 开始",
    "注册后的 Snapshot 模板必须位于 sequence=1、record_revision=1",
    "draft 注册基线的 inputs 和 outputs 必须为空",
    "Snapshot input_slot_id 必须完整对应 Contract required_inputs",
    "Snapshot deliverable_id 必须完整对应 Contract required_deliverables",
]

QA_PATHS = [
    "evidence/prototype/qa/gate1-rc3-independent-review.md",
    "evidence/prototype/qa/gate1-rc3-command-summary.txt",
    "evidence/prototype/qa/gate1-rc3-evidence-index.yaml",
    "evidence/prototype/qa/gate1-rc3-rules-stress-1000-seeds-round50.jsonl",
    "evidence/prototype/qa/gate1-rc3-rules-stress-1000-seeds-round50-summary.json",
    "evidence/prototype/qa/gate1-rc3-ai-difficulty-seed-matrix-100x4-summary.json",
    "evidence/prototype/qa/gate1-rc3-ai-difficulty-seed-matrix-100x4.jsonl.zip",
]

OUTPUT_SCOPES = {
    "DELIVERABLE-RULES-001": {
        "artifact_id": "artifact:veilfront-xiangqi-siege:rules-spec@gate1-revision5",
        "artifact_type": "executable-rules-spec",
        "version": f"owner-freeze-revision-5@{CANDIDATE_COMMIT}",
        "uri": f"git:veilfront-xiangqi-siege:{CANDIDATE_COMMIT}#docs/prototype/rules-spec-v1.md",
        "paths": [
            "docs/prototype/rules-spec-v1.md",
            "docs/prototype/settlement-order-v1.md",
            "docs/prototype/rules-test-coverage-matrix-v1.md",
        ],
    },
    "DELIVERABLE-INFO-001": {
        "artifact_id": "artifact:veilfront-xiangqi-siege:information-boundary@gate1-revision5",
        "artifact_type": "information-boundary-contract",
        "version": f"owner-freeze-revision-5@{CANDIDATE_COMMIT}",
        "uri": f"git:veilfront-xiangqi-siege:{CANDIDATE_COMMIT}#docs/prototype/information-boundary-v1.md",
        "paths": [
            "docs/prototype/information-boundary-v1.md",
            "docs/prototype/gate1-observation-plan-v1.md",
            "docs/prototype/ai-input-contract-v1.md",
        ],
    },
    "DELIVERABLE-GODOT-001": {
        "artifact_id": "source:veilfront-xiangqi-siege:godot-prototype@gate1-rc3",
        "artifact_type": "disposable-godot-prototype",
        "version": f"gate1-rc3@{CANDIDATE_COMMIT}",
        "uri": f"git:veilfront-xiangqi-siege:{CANDIDATE_COMMIT}#gate1-rc3-disposable-prototype",
        "paths": [
            "project.godot",
            "docs/prototype/godot-artifact-map-v1.md",
            "docs/prototype/lan-playtest-tool-map-v1.md",
            "scenes/prototype/gate1_logic_lab.tscn",
            "scenes/prototype/network/lan_lobby.tscn",
            "scripts/prototype/core/rule_engine.gd",
            "scripts/prototype/view/player_view_projector.gd",
            "scripts/prototype/network/lan_network_session.gd",
            "tests/prototype/run_all.gd",
            "tests/prototype/network/run_lan_network_integration.gd",
            "evidence/prototype/playtest/owner-lan-dual-machine-2026-08-17.md",
        ],
        "executable": {"path": RC3_PATH, "size_bytes": RC3_SIZE, "sha256": RC3_SHA256},
    },
    "DELIVERABLE-AI-001": {
        "artifact_id": "source:veilfront-xiangqi-siege:player-view-ai@gate1-rc3",
        "artifact_type": "auditable-baseline-ai",
        "version": f"four-difficulty-player-view-ai@{CANDIDATE_COMMIT}",
        "uri": f"git:veilfront-xiangqi-siege:{CANDIDATE_COMMIT}#scripts/prototype/ai",
        "paths": [
            "scripts/prototype/ai/ai_decision_engine.gd",
            "scripts/prototype/ai/ai_player_view.gd",
            "scripts/prototype/ai/ai_two_ply_search.gd",
            "resources/prototype/ai/prototype_low_budget_hypothesis.tres",
            "resources/prototype/ai/prototype_default_hypothesis.tres",
            "resources/prototype/ai/prototype_high_budget_hypothesis.tres",
            "resources/prototype/ai/prototype_expert_tactical_hypothesis.tres",
            "tests/prototype/run_ai_difficulty_seed_matrix.gd",
        ],
    },
    "DELIVERABLE-QA-001": {
        "artifact_id": "artifact:veilfront-xiangqi-siege:gate1-evidence@rc3",
        "artifact_type": "independent-gate-evidence",
        "version": f"gate1-rc3-pass@{QA_EVIDENCE_COMMIT}",
        "uri": f"git:veilfront-xiangqi-siege:{QA_EVIDENCE_COMMIT}#evidence/prototype/qa/gate1-rc3-independent-review.md",
        "paths": QA_PATHS,
    },
}

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


def load_yaml(path: Path) -> dict[str, Any]:
    value = yaml.safe_load(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise RuntimeError(f"YAML 根节点必须是映射: {path}")
    return value


def dump_yaml(value: Any) -> bytes:
    return yaml.safe_dump(value, allow_unicode=True, sort_keys=False, width=120).encode("utf-8")


def canonical_digest(value: Any) -> str:
    encoded = json.dumps(
        value, ensure_ascii=False, allow_nan=False, separators=(",", ":"), sort_keys=True
    ).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()


def file_digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def canonical_event_digest(event: dict[str, Any]) -> str:
    normalized = copy.deepcopy(event)
    normalized["integrity"]["event_digest"] = None
    return canonical_digest(normalized)


def now_china() -> str:
    return datetime.now(timezone(timedelta(hours=8))).isoformat(timespec="microseconds")


def append_event_bytes(history_bytes: bytes, event: dict[str, Any]) -> bytes:
    dumped = yaml.safe_dump(event, allow_unicode=True, sort_keys=False, width=120).rstrip("\n")
    lines = dumped.splitlines()
    event_text = "  - " + lines[0] + "\n" + "\n".join("    " + line for line in lines[1:]) + "\n"
    if not history_bytes.endswith(b"\n"):
        history_bytes += b"\n"
    return history_bytes + event_text.encode("utf-8")


def make_event(
    snapshot: dict[str, Any],
    previous_event: dict[str, Any],
    sequence: int,
    event_type: str,
    actor: dict[str, str],
    payload: dict[str, Any],
    evidence_refs: list[str],
    request_id: str,
    correlation_id: str,
    occurred_at: str,
) -> dict[str, Any]:
    event = {
        "schema_version": "0.1",
        "event_id": str(uuid.uuid4()),
        "mutation_id": str(uuid.uuid4()),
        "loop_instance_id": snapshot["identity"]["loop_instance_id"],
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
        "concurrency": {"expected_record_revision": sequence - 1, "resulting_record_revision": sequence},
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
    event["integrity"]["event_digest"] = canonical_event_digest(event)
    return event


def manifest_digest(commit: str, paths: list[str], extra: dict[str, Any] | None = None) -> str:
    files = []
    for relative in paths:
        absolute = PROJECT_ROOT / relative
        if not absolute.is_file():
            raise RuntimeError(f"登记文件不存在: {relative}")
        files.append({"path": relative, "sha256": file_digest(absolute)})
    manifest: dict[str, Any] = {"commit": commit, "files": files}
    if extra:
        manifest.update(extra)
    return canonical_digest(manifest)


def build_output(deliverable_id: str, event_id: str) -> dict[str, Any]:
    scope = OUTPUT_SCOPES[deliverable_id]
    commit = QA_EVIDENCE_COMMIT if deliverable_id == "DELIVERABLE-QA-001" else CANDIDATE_COMMIT
    extra = scope.get("executable")
    digest = manifest_digest(commit, scope["paths"], {"executable": extra} if extra else None)
    return {
        "deliverable_id": deliverable_id,
        "artifact": {
            "artifact_id": scope["artifact_id"],
            "artifact_type": scope["artifact_type"],
            "version": scope["version"],
            "uri": scope["uri"],
            "manifest_paths": scope["paths"],
            "digest": {"algorithm": "sha256", "value": digest},
        },
        "produced_in_iteration": 2,
        "lifecycle_status": "submitted",
        "registered_by_event_id": event_id,
    }


def verify_baseline(snapshot: dict[str, Any], history: list[dict[str, Any]]) -> None:
    runtime = snapshot["runtime"]
    if snapshot["identity"]["loop_instance_id"] != LOOP_ID:
        raise RuntimeError("Loop identity mismatch")
    if snapshot["contract_binding"] != {
        "contract_id": "LOOP-CTR-GATE1-VERTICAL-SLICE-001",
        "contract_version": 5,
        "contract_digest": CONTRACT_DIGEST,
    }:
        raise RuntimeError("Registry 未绑定 Contract v5")
    if runtime["current_state"] != "active" or runtime["current_iteration"] != 2:
        raise RuntimeError("Registry 必须位于 active / iteration 2")
    if runtime["record_revision"] != 52 or runtime["last_event_sequence"] != 52 or len(history) != 52:
        raise RuntimeError("Registry 必须位于 rev52/seq52")
    if runtime["last_event_digest"] != history[-1]["integrity"]["event_digest"]:
        raise RuntimeError("Registry history/snapshot tail mismatch")
    report = (QA_DIR / "gate1-rc3-independent-review.md").read_text(encoding="utf-8")
    for marker in [
        "专业结论为 **`pass`**",
        "1000/1000",
        "QA-P1-004` 状态为 **closed**",
        "active -> review",
        "awaiting_human",
    ]:
        if marker not in report:
            raise RuntimeError(f"独立 QA 报告缺少必要标记: {marker}")
    index = load_yaml(QA_DIR / "gate1-rc3-evidence-index.yaml")
    if index["candidate"]["commit"] != CANDIDATE_COMMIT:
        raise RuntimeError("QA candidate commit mismatch")
    if index["acceptance"]["professional_review"] != "pass":
        raise RuntimeError("QA professional review is not pass")
    if index["simulation_batch"]["completed"] != 1000 or index["simulation_batch"]["failures"] != 0:
        raise RuntimeError("QA 1000-seed threshold not satisfied")
    if index["qa_p1_004"]["status"] != "closed":
        raise RuntimeError("QA-P1-004 is not closed")


def package_text(
    baseline_revision: int,
    baseline_sequence: int,
    baseline_tail_digest: str,
    acceptance_digest: str,
    output_digests: dict[str, str],
) -> tuple[str, str]:
    qa_report_hash = file_digest(QA_DIR / "gate1-rc3-independent-review.md")
    qa_index_hash = file_digest(QA_DIR / "gate1-rc3-evidence-index.yaml")
    subject = {
        "subject": "GATE-1-decision-package-rc3-v5",
        "loop_instance_id": LOOP_ID,
        "registry_revision": baseline_revision,
        "last_event_sequence": baseline_sequence,
        "last_event_digest": baseline_tail_digest,
        "loop_contract_digest": CONTRACT_DIGEST,
        "project_brief_digest": BRIEF_DIGEST,
        "candidate_commit": CANDIDATE_COMMIT,
        "production_fix_commit": PRODUCTION_FIX_COMMIT,
        "rc3": {"path": RC3_PATH, "size_bytes": RC3_SIZE, "sha256": RC3_SHA256},
        "qa_evidence_commit": QA_EVIDENCE_COMMIT,
        "qa_report_sha256": qa_report_hash,
        "qa_index_sha256": qa_index_hash,
        "qa_acceptance_subject_digest": acceptance_digest,
        "deliverable_digests": output_digests,
        "official_cli": {"result": "failed", "exit_code": 1, "error_count": 6},
        "exception_status": "owner-approved tooling exception",
        "gate_1_decision": "not_made",
    }
    decision_digest = canonical_digest(subject)
    canonical_json = json.dumps(subject, ensure_ascii=False, separators=(",", ":"), sort_keys=True)
    text = f"""# GATE-1 核心体验假设人工决策包（RC3 / Contract v5）

状态：`awaiting_human / decision_not_made`

本文件只整理证据，不构成批准。项目所有者未对当前决策摘要作出选择前，不得开始正式功能开发或高成本资产生产。

## 当前冻结基线

- Loop：`LOOP-GATE1-001 / Iteration 2`
- Registry：`review / revision {baseline_revision} / sequence {baseline_sequence}`
- Registry 尾摘要：`{baseline_tail_digest}`
- Project Brief：`v4 / {BRIEF_DIGEST}`
- Loop Contract：`v5 / {CONTRACT_DIGEST}`
- 候选提交：`{CANDIDATE_COMMIT}`
- 生产修复提交：`{PRODUCTION_FIX_COMMIT}`
- RC3：`{RC3_PATH}`
- RC3 size：`{RC3_SIZE}` bytes
- RC3 SHA-256：`{RC3_SHA256.upper()}`
- 独立 QA 证据提交：`{QA_EVIDENCE_COMMIT}`
- QA 报告 SHA-256：`{qa_report_hash}`
- QA 索引 SHA-256：`{qa_index_hash}`
- QA 验收 subject digest：`{acceptance_digest}`

## 自动与独立专业结论

| 检查 | 结果 | 证据摘要 |
|---|---|---|
| Contract / Brief / Registry | PASS WITH CONTROLLED EXCEPTION | 项目实例、CTR、组织与未修改历史均 exit 0；官方 Loop CLI 仍 exit 1 且精确六项批准错误，无第七项 |
| Godot 4.7.1 / UI / LAN | PASS | import、主场景、15 套聚合回归、灰盒、LAN host/network/lobby、RC3 启动均通过 |
| 规则与信息边界 | PASS | revision 5 规则、PlayerView、旗帜记忆、阵亡记录、士献祭、相田、隐身马、墙线与镜像均通过 |
| 1000 固定种子 | PASS | 1000/1000，failure 0，determinism mismatch 0，replay 20/20 |
| AI 公平矩阵 | PASS | 100 seeds × 4 难度 = 400/400；隐藏等价、确定性、映射、提交错误均为 0 |
| QA-P1-004 | CLOSED | seed 471016 单测、诊断与完整批次全部通过，实跑/回放摘要一致 |
| 独立专业审查 | PASS | 允许 `active -> review`；QA 未代替项目所有者批准 GATE-1 |

详细证据：`evidence/prototype/qa/gate1-rc3-independent-review.md`、`gate1-rc3-evidence-index.yaml`、`gate1-rc3-command-summary.txt`。

## 真人试玩事实

项目所有者已报告 Windows 真双机局域网试玩通过，记录见 `evidence/prototype/playtest/owner-lan-dual-machine-2026-08-17.md`。该记录支持真人可连接和完成对局，但不替代独立自动 QA，也不把可丢弃 LAN 工具认定为正式联网架构。

## 仍需人工判断的风险

1. 1000 局中 590 局在 50 轮达到平局；50 轮仍是 `hypothesis_cli_overridable`，不是冻结平衡结论。
2. QA-P1-003 仍是临时工具兼容例外，官方 Loop CLI 没有通过；插件、校验器或错误集合变化会使例外失效。
3. clean source 加载仍有两个 `invalid UID` 文本路径回退 warning，编辑器强制退出仍有 `Scan thread aborted` warning；本轮未出现解析、导入或资源加载错误。
4. RC3 是可丢弃垂直切片与可信 LAN 试玩工具，不是 Steam 发布候选、正式联网架构或正式功能架构冻结。

## 可逆决策选项

- `批准`：认可核心循环值得进入正式功能规划；保留上述风险与后续 Gate，不默认继承原型架构。
- `修订`：指定体验、规则、反馈或技术补证项，Loop 返回 active 开启下一轮。
- `拒绝`：停止当前方向或返回 P0/P1 重新定义；保留全部失败与通过证据。

## 项目所有者需要回答

1. 移动、侦察、破城、炮击、三旗争夺与将帅死亡是否形成值得继续的核心循环？
2. 迷雾、占旗、阵亡、复活、截停与胜负反馈是否足够可理解？
3. 590/1000 的 50 轮平局是否可接受为后续平衡实验，而不是当前阻断？
4. 是否接受可丢弃原型边界与正式开发前需重新审查架构的成本？

## 待项目所有者决定

- 选择：`批准 / 修订 / 拒绝`
- 决定者：`project-owner`
- 决定时间：`待填写`
- 条件或修订要求：`待填写`
- 当前 GATE-1 决策摘要：`{decision_digest}`

摘要输入（canonical JSON）：

```json
{canonical_json}
```

任一绑定输入变化后必须重新生成决策包，旧摘要不得批准。
""".replace("\r\n", "\n")
    return text, decision_digest


def atomic_replace(history_bytes: bytes, snapshot_bytes: bytes, package_bytes: bytes) -> None:
    originals = {
        HISTORY_PATH: HISTORY_PATH.read_bytes(),
        SNAPSHOT_PATH: SNAPSHOT_PATH.read_bytes(),
        PACKAGE_PATH: PACKAGE_PATH.read_bytes(),
    }
    temps: dict[Path, Path] = {}
    try:
        for path, data in [
            (HISTORY_PATH, history_bytes),
            (SNAPSHOT_PATH, snapshot_bytes),
            (PACKAGE_PATH, package_bytes),
        ]:
            temp = path.with_name(path.name + ".gate1-rc3.tmp")
            temp.write_bytes(data)
            temps[path] = temp
        for path, temp in temps.items():
            os.replace(temp, path)
    except Exception:
        for path, data in originals.items():
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

    original_history_bytes = HISTORY_PATH.read_bytes()
    history_bytes = original_history_bytes
    previous_event = history[-1]
    outputs = snapshot["resources"]["outputs"]
    output_by_id = {item["deliverable_id"]: item for item in outputs}
    occurred_at = now_china()
    correlation_id = str(uuid.uuid4())
    qa_ref = (
        f"git:veilfront-xiangqi-siege:{QA_EVIDENCE_COMMIT}#"
        "evidence/prototype/qa/gate1-rc3-independent-review.md"
    )
    events: list[dict[str, Any]] = []
    registered_outputs: dict[str, dict[str, Any]] = {}

    for sequence, deliverable_id in enumerate(OUTPUT_SCOPES.keys(), start=53):
        placeholder_id = str(uuid.uuid4())
        after = build_output(deliverable_id, placeholder_id)
        event = make_event(
            snapshot,
            previous_event,
            sequence,
            "core.output_registered",
            PM_ACTOR,
            {
                "deliverable_id": deliverable_id,
                "before": copy.deepcopy(output_by_id[deliverable_id]),
                "after": after,
            },
            [after["artifact"]["uri"], qa_ref],
            f"GATE-1-RC3-register-{deliverable_id}",
            correlation_id,
            occurred_at,
        )
        event["payload"]["after"]["registered_by_event_id"] = event["event_id"]
        event["integrity"]["event_digest"] = canonical_event_digest(event)
        registered_outputs[deliverable_id] = copy.deepcopy(event["payload"]["after"])
        events.append(event)
        previous_event = event

    output_digests = {
        key: value["artifact"]["digest"]["value"] for key, value in registered_outputs.items()
    }
    acceptance_subject = {
        "subject": "LOOP-GATE1-001-iteration-2-rc3-contract-v5-acceptance",
        "contract_digest": CONTRACT_DIGEST,
        "project_brief_digest": BRIEF_DIGEST,
        "candidate_commit": CANDIDATE_COMMIT,
        "production_fix_commit": PRODUCTION_FIX_COMMIT,
        "qa_evidence_commit": QA_EVIDENCE_COMMIT,
        "rc3": {"path": RC3_PATH, "size_bytes": RC3_SIZE, "sha256": RC3_SHA256},
        "deliverable_digests": output_digests,
        "official_cli": {"result": "failed", "exit_code": 1, "errors": EXPECTED_CLI_ERRORS},
        "validate_history": {"exit_code": 0, "error_count": 0},
        "seeded_matches": {
            "completed": 1000,
            "passed": 1000,
            "failure_count": 0,
            "determinism_checked_count": 1000,
            "determinism_mismatch_count": 0,
            "replay_verified": "20/20",
            "records_digest": "25c40f9467a7c4d4ad45162e3aef7f5f95b1948a76757bd2808b4eb6fc906064",
        },
        "ai_matrix": {
            "records": 400,
            "failure_count": 0,
            "determinism_mismatch_count": 0,
            "hidden_equivalence_mismatch_count": 0,
            "mapping_failure_count": 0,
            "submit_failure_count": 0,
            "records_digest": "879b1e381944c0183fb49cd7c5975b4d0303c24627e0b4ff9742b99942abcc20",
        },
        "qa_p1_004": "closed",
    }
    acceptance_digest = canonical_digest(acceptance_subject)
    automated_id = str(uuid.uuid4())
    automated_record = {
        "check_set_id": automated_id,
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
        "registry_consistency": {"result": "pass", "revision": 52, "sequence": 52},
        "godot_regression": {"result": "pass", "version": "4.7.1"},
        "seeded_matches": acceptance_subject["seeded_matches"],
        "ai_matrix": acceptance_subject["ai_matrix"],
        "qa_p1_004": {"seed": 471016, "status": "closed"},
        "new_defects": [],
    }
    event_58 = make_event(
        snapshot,
        previous_event,
        58,
        "core.acceptance_recorded",
        QA_ACTOR,
        {
            "acceptance_kind": "automated_check",
            "record_id": automated_id,
            "subject_digest": acceptance_digest,
            "record": automated_record,
        },
        [qa_ref],
        QA_EVIDENCE_COMMIT,
        correlation_id,
        occurred_at,
    )
    events.append(event_58)
    previous_event = event_58

    review_id = str(uuid.uuid4())
    professional_record = {
        "review_id": review_id,
        "reviewer_assignment_id": "9589489a-be2a-436f-bde4-8488d684c0bb",
        "reviewer_instance_id": "inst:01M02NJ3JFHVZ5C4SP5MTJFJR6",
        "verdict": "pass_with_owner_approved_tooling_exception",
        "technical_regression": "pass",
        "professional_result": "pass",
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
                "status": "controlled_temporary_exception_requalified",
                "classification": "owner-approved tooling exception",
                "official_cli": "failed",
            },
            {"defect_id": "QA-P1-004", "status": "closed", "seed": 471016},
        ],
        "new_defects": [],
        "formal_production": "forbidden_until_separate_gate_1_approval",
        "legal_next_action": "transition_active_to_review_then_prepare_gate_1_decision_package",
    }
    event_59 = make_event(
        snapshot,
        previous_event,
        59,
        "core.acceptance_recorded",
        QA_ACTOR,
        {
            "acceptance_kind": "professional_review",
            "record_id": review_id,
            "subject_digest": acceptance_digest,
            "record": professional_record,
        },
        [qa_ref],
        QA_EVIDENCE_COMMIT,
        correlation_id,
        occurred_at,
    )
    events.append(event_59)
    previous_event = event_59

    event_60 = make_event(
        snapshot,
        previous_event,
        60,
        "core.state_transitioned",
        PM_ACTOR,
        {
            "transition_id": "TR-ACTIVE-REVIEW",
            "from_state": "active",
            "to_state": "review",
            "iteration": {"before": 2, "after": 2},
            "reason": "iteration_2_rc3_submitted_after_contract_v5_independent_qa_pass",
            "subject_digest": acceptance_digest,
        },
        [qa_ref, f"event:{event_59['event_id']}@digest:{event_59['integrity']['event_digest']}"],
        QA_EVIDENCE_COMMIT,
        correlation_id,
        occurred_at,
    )
    events.append(event_60)
    previous_event = event_60

    package, decision_digest = package_text(
        60, 60, event_60["integrity"]["event_digest"], acceptance_digest, output_digests
    )
    package_bytes = package.encode("utf-8")
    package_hash = hashlib.sha256(package_bytes).hexdigest()
    gate_before = copy.deepcopy(output_by_id["DELIVERABLE-GATE1-001"])
    gate_after = {
        "deliverable_id": "DELIVERABLE-GATE1-001",
        "artifact": {
            "artifact_id": "artifact:veilfront-xiangqi-siege:gate1-decision-package@rc3-v5",
            "artifact_type": "human-decision-package",
            "version": f"awaiting-human@sha256:{package_hash}",
            "uri": "game-pipeline/loops/evidence/GATE-1-decision-package.md",
            "manifest_paths": ["game-pipeline/loops/evidence/GATE-1-decision-package.md"],
            "digest": {"algorithm": "sha256", "value": package_hash},
        },
        "produced_in_iteration": 2,
        "lifecycle_status": "submitted",
        "registered_by_event_id": None,
    }
    event_61 = make_event(
        snapshot,
        previous_event,
        61,
        "core.output_registered",
        PM_ACTOR,
        {"deliverable_id": "DELIVERABLE-GATE1-001", "before": gate_before, "after": gate_after},
        [
            f"game-pipeline/loops/evidence/GATE-1-decision-package.md@sha256:{package_hash}",
            f"event:{event_60['event_id']}@digest:{event_60['integrity']['event_digest']}",
        ],
        "GATE-1-RC3-decision-package-preparation",
        correlation_id,
        occurred_at,
    )
    event_61["payload"]["after"]["registered_by_event_id"] = event_61["event_id"]
    event_61["integrity"]["event_digest"] = canonical_event_digest(event_61)
    events.append(event_61)

    for event in events:
        history_bytes = append_event_bytes(history_bytes, event)
    for deliverable_id, after in registered_outputs.items():
        output_by_id[deliverable_id].clear()
        output_by_id[deliverable_id].update(copy.deepcopy(after))
    output_by_id["DELIVERABLE-GATE1-001"].clear()
    output_by_id["DELIVERABLE-GATE1-001"].update(copy.deepcopy(event_61["payload"]["after"]))
    acceptance = snapshot["acceptance_snapshot"]
    acceptance["subject_digest"] = acceptance_digest
    acceptance["automated_checks"].append(automated_record)
    acceptance["professional_reviews"].append(professional_record)
    runtime = snapshot["runtime"]
    runtime["current_state"] = "review"
    runtime["state_entered_at"] = occurred_at
    runtime["last_transition_id"] = "TR-ACTIVE-REVIEW"
    runtime["last_event_id"] = event_61["event_id"]
    runtime["last_event_digest"] = event_61["integrity"]["event_digest"]
    runtime["last_event_sequence"] = 61
    runtime["record_revision"] = 61
    snapshot["budget"]["usage"]["completed_iterations"] = 2

    atomic_replace(history_bytes, dump_yaml(snapshot_doc), package_bytes)
    if not HISTORY_PATH.read_bytes().startswith(original_history_bytes):
        raise RuntimeError("Existing Registry history was not preserved byte-for-byte")
    print(json.dumps({
        "result": "awaiting_human",
        "current_state": "review",
        "record_revision": 61,
        "last_event_sequence": 61,
        "last_event_digest": event_61["integrity"]["event_digest"],
        "acceptance_subject_digest": acceptance_digest,
        "gate1_decision_digest": decision_digest,
        "gate1_package_sha256": package_hash,
        "gate_1_decision": "not_made",
        "formal_production": "forbidden",
    }, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
