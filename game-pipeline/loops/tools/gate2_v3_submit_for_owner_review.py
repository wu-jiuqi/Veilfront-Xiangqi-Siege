#!/usr/bin/env python3
"""Register the GATE-2 v3 RC4 evidence and enter project-owner approval wait."""

from __future__ import annotations

import copy
import hashlib
import json
import os
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
QA_REPORT_PATH = PROJECT_ROOT / "evidence/gate2/gate2-v3-independent-qa-rc4.md"
QA_EVIDENCE_DIR = PROJECT_ROOT / "evidence/gate2/v3-candidate-419e2ce"
EXE_RELATIVE_PATH = "builds/windows/Veilfront_Xiangqi_Siege_Gate2_v3_419e2ce.exe"
EXE_PATH = PROJECT_ROOT / EXE_RELATIVE_PATH

LOOP_ID = "83c995ff-37b9-4df8-9e84-8417d6632187"
CONTRACT_ID = "LOOP-CTR-FORMAL-FOUNDATION-GATE2-001"
CONTRACT_VERSION = 3
CONTRACT_DIGEST = "9ea1fbab25b1a560b83896194099bd9b0131552d7321223622161615c1a2a205"
CONTRACT_APPROVAL_DIGEST = "9d9e3cfc5e92d41d38eea336dbcca95040bb858706ffd8130a8b33a3594e7dd9"
BRIEF_DIGEST = "8e9d4285c1c7237a22f308808e944fd8571700f896b8dd8cfb118f0fe0de3d3e"
STATE_MACHINE_DIGEST = "810f414928b370a869b3a36a17cb504f290d17fa07c9ce5db9001136bfdb160c"
CANDIDATE_COMMIT = "419e2cef5d4fac9f099c8ea487b5e6d6a5c57445"
QA_EVIDENCE_COMMIT = "7404d78"
EXE_SIZE = 286_523_048
EXE_SHA256 = "ea008cf1b6f68dbd2598dbcf4981f8cd40f065d0f995f69878f543d38dd84130"
BASELINE_REVISION = 61

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

CHECK_RESULTS = {
    "CHECK-CONTRACT-V3-001": "pass",
    "CHECK-DEPENDENCY-001": "pass",
    "CHECK-INFORMATION-2D-001": "pass",
    "CHECK-GODOT-2D-001": "pass",
    "CHECK-COORDINATE-001": "pass",
    "CHECK-RESPONSIVE-2D-001": "pass",
    "CHECK-PERFORMANCE-2D-001": "pass",
    "CHECK-ART-2D-001": "pass",
    "CHECK-REGRESSION-001": "pass_with_limitation",
    "CHECK-SCOPE-001": "pass",
}

PRESENTATION_PATHS = [
    "evidence/gate2/gate2-v3-technical-handoff.md",
    "evidence/gate2/gate2-v3-ui-readability-handoff.md",
    "evidence/gate2/gate2-v3-systems-experience-handoff.md",
    "scenes/game/match/board/board_viewport.tscn",
    "scenes/game/match/match_screen.tscn",
    "scenes/game/ui/tutorial_overlay.tscn",
    "scripts/game/presentation/board/board_viewport_controller.gd",
    "tests/game/presentation/run_turn_camera_visibility_contract.gd",
]

ART_PATHS = [
    "docs/art/veilfront-2d-current-direction-v1.md",
    "docs/art/demo-2d-asset-inventory-v1.yaml",
    "evidence/gate2/gate2-v3-visual-handoff.md",
    "evidence/gate2/v3-candidate-419e2ce/screenshots/match-960x540-red.png",
    "evidence/gate2/v3-candidate-419e2ce/screenshots/match-960x540-black.png",
    "evidence/gate2/v3-candidate-419e2ce/screenshots/match-1280x720-red.png",
    "evidence/gate2/v3-candidate-419e2ce/screenshots/match-1280x720-black.png",
    "evidence/gate2/v3-candidate-419e2ce/screenshots/match-1920x1080-red.png",
    "evidence/gate2/v3-candidate-419e2ce/screenshots/match-1920x1080-black.png",
]


def load_yaml(path: Path) -> dict[str, Any]:
    value = yaml.safe_load(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise RuntimeError(f"YAML root must be a mapping: {path}")
    return value


def dump_yaml(value: Any) -> bytes:
    return yaml.safe_dump(value, allow_unicode=True, sort_keys=False, width=120).encode("utf-8")


def canonical_digest(value: Any) -> str:
    payload = json.dumps(
        value,
        ensure_ascii=False,
        allow_nan=False,
        separators=(",", ":"),
        sort_keys=True,
    ).encode("utf-8")
    return hashlib.sha256(payload).hexdigest()


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
    # This Registry uses an indentless sequence directly below `event_history:`.
    event_text = "- " + lines[0] + "\n" + "\n".join("  " + line for line in lines[1:]) + "\n"
    if not history_bytes.endswith(b"\n"):
        history_bytes += b"\n"
    return history_bytes + event_text.encode("utf-8")


def make_event(
    snapshot: dict[str, Any],
    previous_event: dict[str, Any],
    event_type: str,
    actor: dict[str, str],
    payload: dict[str, Any],
    evidence_refs: list[str],
    request_id: str,
    correlation_id: str,
    occurred_at: str,
) -> dict[str, Any]:
    runtime = snapshot["runtime"]
    sequence = previous_event["sequence"] + 1
    expected_revision = BASELINE_REVISION + (sequence - BASELINE_REVISION - 1)
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
            "expected_record_revision": expected_revision,
            "resulting_record_revision": expected_revision + 1,
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
    if runtime["record_revision"] != BASELINE_REVISION:
        raise RuntimeError("Snapshot changed after baseline verification")
    event["integrity"]["event_digest"] = event_digest(event)
    return event


def manifest_digest(commit: str, paths: list[str], extra: dict[str, Any] | None = None) -> str:
    files: list[dict[str, str]] = []
    for relative in paths:
        absolute = PROJECT_ROOT / relative
        if not absolute.is_file():
            raise RuntimeError(f"Missing manifest file: {relative}")
        files.append({"path": relative, "sha256": file_digest(absolute)})
    manifest: dict[str, Any] = {"commit": commit, "files": files}
    if extra:
        manifest.update(extra)
    return canonical_digest(manifest)


def qa_paths() -> list[str]:
    paths = ["evidence/gate2/gate2-v3-independent-qa-rc4.md"]
    for path in sorted(QA_EVIDENCE_DIR.rglob("*")):
        if path.is_file():
            paths.append(path.relative_to(PROJECT_ROOT).as_posix())
    return paths


def build_output(
    deliverable_id: str,
    artifact_type: str,
    version: str,
    uri: str,
    paths: list[str],
    commit: str,
    digest: str,
) -> dict[str, Any]:
    return {
        "deliverable_id": deliverable_id,
        "artifact": {
            "artifact_id": f"artifact:veilfront-xiangqi-siege:{deliverable_id.lower()}@{version}",
            "artifact_type": artifact_type,
            "version": version,
            "uri": uri,
            "manifest_paths": paths,
            "source_commit": commit,
            "digest": {"algorithm": "sha256", "value": digest},
        },
        "produced_in_iteration": 3,
        "lifecycle_status": "submitted",
        "registered_by_event_id": None,
    }


def verify_baseline(snapshot: dict[str, Any], history: list[dict[str, Any]]) -> None:
    runtime = snapshot["runtime"]
    expected_binding = {
        "contract_id": CONTRACT_ID,
        "contract_version": CONTRACT_VERSION,
        "contract_digest": CONTRACT_DIGEST,
    }
    if snapshot["identity"]["loop_instance_id"] != LOOP_ID:
        raise RuntimeError("Loop identity mismatch")
    if snapshot["contract_binding"] != expected_binding:
        raise RuntimeError("Contract v3 binding mismatch")
    if runtime["current_state"] != "active" or runtime["current_iteration"] != 3:
        raise RuntimeError("Registry must be active / iteration 3")
    if runtime["record_revision"] != BASELINE_REVISION or runtime["last_event_sequence"] != BASELINE_REVISION:
        raise RuntimeError("Registry must be revision/sequence 61")
    if len(history) != BASELINE_REVISION:
        raise RuntimeError("Unexpected event-history length")
    if runtime["last_event_digest"] != history[-1]["integrity"]["event_digest"]:
        raise RuntimeError("Snapshot/history tail mismatch")
    if snapshot.get("pending_approvals") or snapshot.get("interruption"):
        raise RuntimeError("Registry already has a pending approval or interruption")
    if not EXE_PATH.is_file() or EXE_PATH.stat().st_size != EXE_SIZE or file_digest(EXE_PATH) != EXE_SHA256:
        raise RuntimeError("RC4 executable identity mismatch")
    report = QA_REPORT_PATH.read_text(encoding="utf-8")
    for marker in [
        "独立技术结论：`pass`",
        "GATE-2 路由建议：`recommend_awaiting_human`",
        "CHECK-REGRESSION-001 | pass_with_limitation",
        "OWN_GODOT_PROCESS_COUNT=0",
    ]:
        if marker not in report:
            raise RuntimeError(f"QA report missing marker: {marker}")


def decision_package_text(
    acceptance_digest: str,
    output_digests: dict[str, str],
    review_event: dict[str, Any],
) -> tuple[str, str]:
    qa_report_sha = file_digest(QA_REPORT_PATH)
    decision_subject = {
        "subject": "GATE-2-v3-formal-2d-baseline-rc4",
        "gate_2_decision": "not_made",
        "loop_instance_id": LOOP_ID,
        "project_brief_digest": BRIEF_DIGEST,
        "contract_approval_digest": CONTRACT_APPROVAL_DIGEST,
        "registry_contract_digest": CONTRACT_DIGEST,
        "candidate_commit": CANDIDATE_COMMIT,
        "qa_evidence_commit": QA_EVIDENCE_COMMIT,
        "qa_report_sha256": qa_report_sha,
        "acceptance_subject_digest": acceptance_digest,
        "deliverable_digests": output_digests,
        "check_results": CHECK_RESULTS,
        "professional_review": "pass",
        "formal_equivalence": {
            "current_evidence": "1-seed-pass",
            "current_3_or_20_seed": "not_rerun",
            "historical_20_seed": "background_only",
        },
        "executable": {
            "path": EXE_RELATIVE_PATH,
            "size_bytes": EXE_SIZE,
            "sha256": EXE_SHA256,
        },
        "registry_review": {
            "revision": review_event["sequence"],
            "sequence": review_event["sequence"],
            "last_event_digest": review_event["integrity"]["event_digest"],
        },
    }
    decision_digest = canonical_digest(decision_subject)
    canonical_json = json.dumps(
        decision_subject,
        ensure_ascii=False,
        allow_nan=False,
        separators=(",", ":"),
        sort_keys=True,
    )
    text = f"""# GATE-2 v3 正式二维基线人工决策包（RC4）

状态：`awaiting_human / decision_not_made`

本文件只整理当前候选证据，不构成 GATE-2 批准。项目所有者完成 EXE 测试并对当前决策摘要作出选择前，不得把 Demo 级二维批量资产、完整 SFX/VFX、最终 UI 或教学扩展视为已获批准。

## 冻结对象

- Project Brief：v7 / `{BRIEF_DIGEST}`
- Contract：v3 / owner approval `{CONTRACT_APPROVAL_DIGEST}`
- Registry contract digest：`{CONTRACT_DIGEST}`
- 产品候选：`{CANDIDATE_COMMIT}`
- QA 证据提交：`{QA_EVIDENCE_COMMIT}`
- QA 报告 SHA-256：`{qa_report_sha}`
- EXE：`{EXE_RELATIVE_PATH}`
- EXE size：`{EXE_SIZE}` bytes
- EXE SHA-256：`{EXE_SHA256.upper()}`

## 验收结论

- Contract 十项检查：9 项 `pass`，`CHECK-REGRESSION-001` 为 `pass_with_limitation`。
- 独立专业审查：`pass`；建议路由：`recommend_awaiting_human`。
- 相机合同严格连续 5/5 通过；棋盘相机层、六分辨率布局、隐藏等价均通过。
- 960×540、1280×720、1920×1080 × 赤/玄六张真实 GPU 样片通过。
- Iris Xe / OpenGL：1280×720 默认运动平均 158.569 FPS、p99 10.016 ms；960×540 reduced motion 平均 154.343 FPS、p99 9.775 ms。
- embedded-PCK Windows 成品通过正式 LAN 全栈验证，覆盖 ready → start → match → submit → disconnect。

详细证据：`evidence/gate2/gate2-v3-independent-qa-rc4.md` 与 `evidence/gate2/v3-candidate-419e2ce/`。

## 已知但不阻断的风险

1. 当前正式等价证据为同代码 1-seed PASS；本机未重跑当前 3/20 seed，历史 20-seed golden 只作背景。
2. 960×540 reduced-motion 样本出现单帧 196.833 ms 尾部尖峰，但平均、p99、1% low 和连续可读性均稳定。
3. EXE 约 286.5 MB，当前 preset 仍含开发/测试资源；GATE-3/发布前需收敛导出过滤。
4. 项目没有独立质量档；目前只有低配验收配置。
5. 960×540 下辅助战况与棋子说明密度偏高、对比偏弱，属于 UI 打磨而非当前核心可读性阻断。

## GATE-2 人工问题

正式二维表现、教学灰盒、信息边界与二维视觉样片是否足够稳定，值得进入 Demo 级二维批量资产生产？

可逆选择：

- `批准`：允许进入 GATE-3 细节生产与补全，但不等于发布批准。
- `修订`：项目所有者列出测试发现与修改要求，Loop 恢复 review 后返回 active 修订。
- `拒绝`：停止当前二维基线或返回 Brief/Contract 重新定义。

## 待项目所有者决定

- 选择：`批准 / 修订 / 拒绝`
- 决定者：`project-owner`
- 决定时间：`待填写`
- 条件或修订要求：`待填写`
- 当前 GATE-2 决策摘要：`{decision_digest}`

摘要输入（canonical JSON）：

```json
{canonical_json}
```

任一绑定输入、候选提交、QA 报告或 EXE 摘要变化后必须重新生成决策包，旧摘要不得批准。
"""
    return text, decision_digest


def atomic_replace(history_bytes: bytes, snapshot_bytes: bytes, package_bytes: bytes) -> None:
    originals = {
        HISTORY_PATH: HISTORY_PATH.read_bytes(),
        SNAPSHOT_PATH: SNAPSHOT_PATH.read_bytes(),
    }
    if PACKAGE_PATH.exists():
        originals[PACKAGE_PATH] = PACKAGE_PATH.read_bytes()
    temps: dict[Path, Path] = {}
    try:
        for path, data in (
            (HISTORY_PATH, history_bytes),
            (SNAPSHOT_PATH, snapshot_bytes),
            (PACKAGE_PATH, package_bytes),
        ):
            handle, name = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
            with os.fdopen(handle, "wb") as stream:
                stream.write(data)
                stream.flush()
                os.fsync(stream.fileno())
            temps[path] = Path(name)
        for path in (HISTORY_PATH, SNAPSHOT_PATH, PACKAGE_PATH):
            os.replace(temps[path], path)
    except Exception:
        for path, data in originals.items():
            path.write_bytes(data)
        if PACKAGE_PATH not in originals and PACKAGE_PATH.exists():
            PACKAGE_PATH.unlink()
        raise
    finally:
        for temp in temps.values():
            temp.unlink(missing_ok=True)


def main() -> int:
    snapshot_doc = load_yaml(SNAPSHOT_PATH)
    history_doc = load_yaml(HISTORY_PATH)
    snapshot = snapshot_doc["registry_snapshot"]
    history: list[dict[str, Any]] = history_doc["event_history"]
    verify_baseline(snapshot, history)

    original_history_bytes = HISTORY_PATH.read_bytes()
    history_bytes = original_history_bytes
    previous_event = history[-1]
    occurred_at = now_china()
    correlation_id = str(uuid.uuid4())
    qa_ref = f"git:veilfront-xiangqi-siege:{QA_EVIDENCE_COMMIT}#evidence/gate2/gate2-v3-independent-qa-rc4.md"
    events: list[dict[str, Any]] = []

    qa_manifest_paths = qa_paths()
    outputs_to_register = [
        build_output(
            "DELIVERABLE-PRESENTATION-2D-001",
            "preset-godot-2d-match-shell",
            "candidate-419e2ce",
            "evidence/gate2/gate2-v3-technical-handoff.md",
            PRESENTATION_PATHS,
            CANDIDATE_COMMIT,
            manifest_digest(CANDIDATE_COMMIT, PRESENTATION_PATHS),
        ),
        build_output(
            "DELIVERABLE-ART-2D-001",
            "demo-2d-visual-baseline-and-asset-inventory",
            "rc4-419e2ce",
            "evidence/gate2/gate2-v3-visual-handoff.md",
            ART_PATHS,
            QA_EVIDENCE_COMMIT,
            manifest_digest(QA_EVIDENCE_COMMIT, ART_PATHS, {"candidate_commit": CANDIDATE_COMMIT}),
        ),
        build_output(
            "DELIVERABLE-QA-2D-001",
            "independent-gate2-v3-evidence",
            "rc4-7404d78",
            "evidence/gate2/gate2-v3-independent-qa-rc4.md",
            qa_manifest_paths,
            QA_EVIDENCE_COMMIT,
            manifest_digest(
                QA_EVIDENCE_COMMIT,
                qa_manifest_paths,
                {"candidate_commit": CANDIDATE_COMMIT, "executable_sha256": EXE_SHA256},
            ),
        ),
    ]

    output_by_id = {item["deliverable_id"]: item for item in snapshot["resources"]["outputs"]}
    registered_outputs: dict[str, dict[str, Any]] = {}
    for after in outputs_to_register:
        deliverable_id = after["deliverable_id"]
        event = make_event(
            snapshot,
            previous_event,
            "core.output_registered",
            PM_ACTOR,
            {"deliverable_id": deliverable_id, "before": copy.deepcopy(output_by_id.get(deliverable_id)), "after": after},
            after["artifact"]["manifest_paths"],
            f"GATE-2-v3-register-{deliverable_id}",
            correlation_id,
            occurred_at,
        )
        event["payload"]["after"]["registered_by_event_id"] = event["event_id"]
        event["integrity"]["event_digest"] = event_digest(event)
        registered_outputs[deliverable_id] = copy.deepcopy(event["payload"]["after"])
        events.append(event)
        previous_event = event

    output_digests = {
        deliverable_id: output["artifact"]["digest"]["value"]
        for deliverable_id, output in registered_outputs.items()
    }
    acceptance_subject = {
        "subject": "LOOP-GATE2-001-iteration-3-rc4-contract-v3-acceptance",
        "project_brief_digest": BRIEF_DIGEST,
        "contract_approval_digest": CONTRACT_APPROVAL_DIGEST,
        "registry_contract_digest": CONTRACT_DIGEST,
        "candidate_commit": CANDIDATE_COMMIT,
        "qa_evidence_commit": QA_EVIDENCE_COMMIT,
        "qa_report_sha256": file_digest(QA_REPORT_PATH),
        "executable": {"path": EXE_RELATIVE_PATH, "size_bytes": EXE_SIZE, "sha256": EXE_SHA256},
        "deliverable_digests": output_digests,
        "check_results": CHECK_RESULTS,
        "professional_review": "pass",
    }
    acceptance_digest = canonical_digest(acceptance_subject)
    automated_records: list[dict[str, Any]] = []
    for check_id, result in CHECK_RESULTS.items():
        record = {
            "check_id": check_id,
            "result": result,
            "candidate_commit": CANDIDATE_COMMIT,
            "qa_evidence_commit": QA_EVIDENCE_COMMIT,
            "evidence_ref": qa_ref,
            "subject_digest": acceptance_digest,
        }
        if check_id == "CHECK-REGRESSION-001":
            record["limitation"] = {
                "current_evidence": "1-seed-pass",
                "current_3_or_20_seed": "not_rerun",
                "historical_20_seed": "background_only",
                "frozen_representative_threshold_satisfied": True,
            }
        event = make_event(
            snapshot,
            previous_event,
            "core.acceptance_recorded",
            QA_ACTOR,
            {
                "acceptance_kind": "automated_check",
                "record_id": check_id,
                "subject_digest": acceptance_digest,
                "record": record,
            },
            [qa_ref],
            f"GATE-2-v3-{check_id}",
            correlation_id,
            occurred_at,
        )
        automated_records.append(record)
        events.append(event)
        previous_event = event

    professional_record = {
        "review_id": "GATE-2-v3-RC4-independent-review",
        "reviewer_instance_id": QA_ACTOR["actor_id"],
        "reviewer_role": QA_ACTOR["role"],
        "verdict": "pass",
        "route_recommendation": "recommend_awaiting_human",
        "evidence_state": "sufficient_with_disclosed_regression_limitation",
        "gate_decision": "not_made",
        "evidence_ref": qa_ref,
        "subject_digest": acceptance_digest,
        "new_blocking_defects": [],
    }
    professional_event = make_event(
        snapshot,
        previous_event,
        "core.acceptance_recorded",
        QA_ACTOR,
        {
            "acceptance_kind": "professional_review",
            "record_id": professional_record["review_id"],
            "subject_digest": acceptance_digest,
            "record": professional_record,
        },
        [qa_ref],
        "GATE-2-v3-RC4-independent-review",
        correlation_id,
        occurred_at,
    )
    events.append(professional_event)
    previous_event = professional_event

    review_event = make_event(
        snapshot,
        previous_event,
        "core.state_transitioned",
        PM_ACTOR,
        {
            "transition_id": "TR-ACTIVE-REVIEW",
            "from_state": "active",
            "to_state": "review",
            "iteration": {"before": 3, "after": 3},
            "reason": "iteration_3_rc4_submitted_after_contract_v3_independent_qa_pass",
            "subject_digest": acceptance_digest,
        },
        [qa_ref],
        "GATE-2-v3-RC4-submit-review",
        correlation_id,
        occurred_at,
    )
    events.append(review_event)
    previous_event = review_event

    package_text, decision_digest = decision_package_text(acceptance_digest, output_digests, review_event)
    package_bytes = package_text.encode("utf-8")
    package_sha = hashlib.sha256(package_bytes).hexdigest()
    gate_output = build_output(
        "DELIVERABLE-GATE2-2D-001",
        "human-decision-package",
        f"awaiting-human@sha256:{package_sha}",
        "game-pipeline/loops/evidence/GATE-2-v3-decision-package.md",
        ["game-pipeline/loops/evidence/GATE-2-v3-decision-package.md"],
        QA_EVIDENCE_COMMIT,
        package_sha,
    )
    gate_event = make_event(
        snapshot,
        previous_event,
        "core.output_registered",
        PM_ACTOR,
        {"deliverable_id": gate_output["deliverable_id"], "before": copy.deepcopy(output_by_id.get(gate_output["deliverable_id"])), "after": gate_output},
        [f"game-pipeline/loops/evidence/GATE-2-v3-decision-package.md@sha256:{package_sha}"],
        "GATE-2-v3-decision-package-preparation",
        correlation_id,
        occurred_at,
    )
    gate_event["payload"]["after"]["registered_by_event_id"] = gate_event["event_id"]
    gate_event["integrity"]["event_digest"] = event_digest(gate_event)
    events.append(gate_event)
    previous_event = gate_event

    approval_request_id = f"approval:veilfront-xiangqi-siege:gate-2:{decision_digest[:12]}"
    approval_record = {
        "request_id": approval_request_id,
        "requested_action": "decide_gate_2_for_demo_2d_batch_production",
        "subject_digest": decision_digest,
        "status": "pending",
        "requested_by": PM_ACTOR,
        "decision_authority": "project-owner",
        "request_ref": "game-pipeline/loops/evidence/GATE-2-v3-decision-package.md",
        "requested_at": occurred_at,
        "decision": None,
    }
    approval_event = make_event(
        snapshot,
        previous_event,
        "core.approval_requested",
        PM_ACTOR,
        {
            "request_id": approval_request_id,
            "requested_action": approval_record["requested_action"],
            "subject_digest": decision_digest,
            "request": approval_record,
        },
        ["game-pipeline/loops/evidence/GATE-2-v3-decision-package.md"],
        approval_request_id,
        correlation_id,
        occurred_at,
    )
    events.append(approval_event)
    previous_event = approval_event

    interruption_id = str(uuid.uuid4())
    interruption = {
        "interruption_id": interruption_id,
        "current_interruption_state": "waiting_approval",
        "resume_state": "review",
        "first_entered_from_state": "review",
        "first_entered_at": occurred_at,
        "current_reason": {
            "reason_code": "gate_2_project_owner_decision_required",
            "description": "Contract v3 自动检查和独立专业审查已满足；等待项目所有者测试 RC4 EXE 并对精确决策摘要批准、修订或拒绝。",
            "responsible_role": "project-owner",
            "evidence_refs": [
                "game-pipeline/loops/evidence/GATE-2-v3-decision-package.md",
                "evidence/gate2/gate2-v3-independent-qa-rc4.md",
                EXE_RELATIVE_PATH,
            ],
        },
        "entry_snapshot": {
            "contract_id": CONTRACT_ID,
            "contract_version": CONTRACT_VERSION,
            "contract_digest": CONTRACT_DIGEST,
            "input_set_digest": canonical_digest(snapshot["resources"]["inputs"]),
            "dependency_set_digest": canonical_digest(snapshot["topology"]["dependencies"]),
            "authority_set_digest": canonical_digest(snapshot["responsibility"]),
            "budget_usage_digest": canonical_digest(snapshot["budget"]["usage"]),
        },
        "latest_revalidation": None,
    }
    interruption_event = make_event(
        snapshot,
        previous_event,
        "core.interruption_entered",
        PM_ACTOR,
        {
            "transition_id": "TR-OPERATIONAL-INTERRUPTED",
            "from_state": "review",
            "to_state": "waiting_approval",
            "iteration": {"before": 3, "after": 3},
            "interruption": interruption,
        },
        ["game-pipeline/loops/evidence/GATE-2-v3-decision-package.md", qa_ref],
        approval_request_id,
        correlation_id,
        occurred_at,
    )
    events.append(interruption_event)

    for event in events:
        history_bytes = append_event_bytes(history_bytes, event)
    for output in registered_outputs.values():
        snapshot["resources"]["outputs"].append(copy.deepcopy(output))
    snapshot["resources"]["outputs"].append(copy.deepcopy(gate_event["payload"]["after"]))
    snapshot["acceptance_snapshot"]["subject_digest"] = acceptance_digest
    snapshot["acceptance_snapshot"]["automated_checks"].extend(copy.deepcopy(automated_records))
    snapshot["acceptance_snapshot"]["professional_reviews"].append(copy.deepcopy(professional_record))
    snapshot["pending_approvals"].append(copy.deepcopy(approval_record))
    snapshot["interruption"] = copy.deepcopy(interruption)
    snapshot["budget"]["usage"]["completed_iterations"] = 3
    runtime = snapshot["runtime"]
    runtime.update(
        {
            "current_state": "waiting_approval",
            "state_entered_at": occurred_at,
            "last_transition_id": "TR-OPERATIONAL-INTERRUPTED",
            "last_event_id": interruption_event["event_id"],
            "last_event_digest": interruption_event["integrity"]["event_digest"],
            "last_event_sequence": interruption_event["sequence"],
            "record_revision": interruption_event["concurrency"]["resulting_record_revision"],
        }
    )

    atomic_replace(history_bytes, dump_yaml(snapshot_doc), package_bytes)
    if not HISTORY_PATH.read_bytes().startswith(original_history_bytes):
        raise RuntimeError("Existing Registry history was not preserved byte-for-byte")
    print(json.dumps({
        "result": "awaiting_human",
        "current_state": runtime["current_state"],
        "record_revision": runtime["record_revision"],
        "last_event_sequence": runtime["last_event_sequence"],
        "last_event_digest": runtime["last_event_digest"],
        "acceptance_subject_digest": acceptance_digest,
        "gate_2_decision_digest": decision_digest,
        "gate_2_package_sha256": package_sha,
        "approval_request_id": approval_request_id,
        "gate_2_decision": "not_made",
    }, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
