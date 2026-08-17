#!/usr/bin/env python3
"""Materialize the owner-confirmed revision 5 brief/contract and append Registry events.

The project owner supplied every revision-5 rule in the current project thread and
authorized completion of the GATE-1 prerequisites. This migration records that
authority without making the separate GATE-1 human decision.
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
BRIEF_PATH = PROJECT_ROOT / "game-pipeline/project-definition/project-brief.yaml"
V4_PATH = PROJECT_ROOT / "game-pipeline/loops/contracts/loop-contract-gate1-vertical-slice-v4.yaml"
V5_PATH = PROJECT_ROOT / "game-pipeline/loops/contracts/loop-contract-gate1-vertical-slice-v5.yaml"
APPROVALS_DIR = PROJECT_ROOT / "game-pipeline/approvals"
SNAPSHOT_PATH = PROJECT_ROOT / "game-pipeline/loops/registry/first-production-loop/snapshot.yaml"
HISTORY_PATH = PROJECT_ROOT / "game-pipeline/loops/registry/first-production-loop/event-history.yaml"
EVIDENCE_PATH = PROJECT_ROOT / "game-pipeline/loops/evidence/OWNER-RULE-REVISION-5-contract-v5-migration-check.md"

BRIEF_V4_SUBJECT_DIGEST = "df8deb810d8c06c8c2f5763031fde2c39f14aa81226e23ffb25636ee3f1eca0b"
V4_SUBJECT_DIGEST = "a0da0eec9d6d9513dd111d406c1165bc64d3b84ce1aa1ac430a2c95c10179e6a"
V5_DRAFT_SUBJECT_DIGEST = "7689efb359c806a7c56508a869833901966469bcde5bdb4a3cdfba7b6af4279f"
STATE_MACHINE_DIGEST = "810f414928b370a869b3a36a17cb504f290d17fa07c9ce5db9001136bfdb160c"
OWNER_SOURCE_REF = "codex-thread://current#owner-rule-revision-5"
EXPECTED_REVISION = 50


def load_yaml(path: Path) -> dict[str, Any]:
    value = yaml.safe_load(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise RuntimeError(f"{path} must contain a YAML mapping")
    return value


def dump_yaml(value: Any) -> bytes:
    return yaml.safe_dump(value, allow_unicode=True, sort_keys=False, width=120).encode("utf-8")


def canonical_digest(value: Any) -> str:
    encoded = json.dumps(
        value, ensure_ascii=False, allow_nan=False, separators=(",", ":"), sort_keys=True
    ).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()


def canonical_event_digest(event: dict[str, Any]) -> str:
    normalized = copy.deepcopy(event)
    normalized["integrity"]["event_digest"] = None
    return canonical_digest(normalized)


def file_digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def now_china() -> str:
    return datetime.now(timezone(timedelta(hours=8))).isoformat(timespec="microseconds")


def write_new(path: Path, data: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL)
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


def contract_subject(document: dict[str, Any]) -> dict[str, Any]:
    value = copy.deepcopy(document)
    value.pop("approval_binding", None)
    return value


def materialize_brief(decided_at: str) -> tuple[dict[str, Any], str]:
    document = load_yaml(BRIEF_PATH)
    brief = document["project_brief"]
    if brief["identity"]["version"] != 4 or brief["integrity"]["subject_digest"] != BRIEF_V4_SUBJECT_DIGEST:
        raise RuntimeError("Project Brief v4 draft digest/version mismatch")
    approval_id = f"approval:veilfront-xiangqi-siege:project-brief:{BRIEF_V4_SUBJECT_DIGEST[:12]}"
    brief["review"] = {
        "status": "confirmed",
        "approval_id": approval_id,
        "confirmed_by": "project-owner",
        "confirmed_at": decided_at,
    }
    return document, approval_id


def materialize_contract(decided_at: str) -> tuple[dict[str, Any], str, str]:
    draft = load_yaml(V5_PATH)
    if canonical_digest(contract_subject(draft)) != V5_DRAFT_SUBJECT_DIGEST:
        raise RuntimeError("Contract v5 draft subject digest mismatch")
    subject = contract_subject(draft)
    subject["loop_contract"]["status"] = "approved"
    subject["start"]["required_inputs"][0]["version_requirement"] = (
        f"version 4，subject_digest={BRIEF_V4_SUBJECT_DIGEST}，"
        f"approval=approval:veilfront-xiangqi-siege:project-brief:{BRIEF_V4_SUBJECT_DIGEST[:12]}"
    )
    revision = subject["owner_rule_revision_5"]
    revision["status"] = "approved"
    revision["approved_by"] = "project-owner"
    revision["approved_at"] = decided_at
    revision["precedence"] = "本节覆盖 owner_rule_revision 中冲突的 v4 语义。"
    lan = subject["lan_playtest_tool_exception"]
    lan["status"] = "approved"
    lan["approved_at"] = decided_at
    lan["source_ref"] = OWNER_SOURCE_REF
    lan.pop("proposed_reapproval_source_ref", None)
    lan["rule_revision_binding"]["status"] = "reapproved_after_rule_and_information-boundary-change"
    tooling = subject["temporary_tooling_compatibility"]
    tooling["proposal_status"] = "owner_approved_with_contract_v5"
    subject_digest = canonical_digest(subject)
    approval_id = f"approval:veilfront-xiangqi-siege:loop-contract:{subject_digest[:12]}"
    materialized = {
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
    return materialized, subject_digest, approval_id


def approval_documents(
    brief: dict[str, Any], brief_approval_id: str,
    contract: dict[str, Any], contract_digest: str, contract_approval_id: str,
    decided_at: str,
) -> tuple[dict[str, Any], dict[str, Any]]:
    brief_file_digest = hashlib.sha256(dump_yaml(brief)).hexdigest()
    contract_file_digest = hashlib.sha256(dump_yaml(contract)).hexdigest()
    brief_approval = {
        "approval": {
            "schema_version": "game-production-approval/v1",
            "approval_id": brief_approval_id,
            "subject_kind": "project-brief",
            "subject_id": "brief:veilfront-xiangqi-siege:initial",
            "subject_digest": BRIEF_V4_SUBJECT_DIGEST,
            "decision": "approved",
            "decided_by": "project-owner",
            "decided_at": decided_at,
            "evidence": {"source_refs": [OWNER_SOURCE_REF]},
            "authorized_action": {
                "summary": "确认 revision 5 的交点棋盘、迷雾旗帜记忆、公开阵亡记录、士献祭、相阻挡与试玩表现边界。",
                "gate_1_decision": "not_made",
            },
            "application": {
                "materialized_path": BRIEF_PATH.relative_to(PROJECT_ROOT).as_posix(),
                "materialized_status": "confirmed",
                "materialized_digest": brief_file_digest,
                "applied_at": decided_at,
            },
        }
    }
    contract_approval = {
        "approval": {
            "schema_version": "game-production-approval/v1",
            "approval_id": contract_approval_id,
            "subject_kind": "loop-contract",
            "subject_id": "LOOP-CTR-GATE1-VERTICAL-SLICE-001@v5",
            "subject_digest": contract_digest,
            "decision": "approved",
            "decided_by": "project-owner",
            "decided_at": decided_at,
            "evidence": {
                "source_refs": [OWNER_SOURCE_REF],
                "immutable_baseline": {
                    "contract_v4_subject_digest": V4_SUBJECT_DIGEST,
                    "contract_v4_file_digest": file_digest(V4_PATH),
                    "registry_revision": EXPECTED_REVISION,
                },
            },
            "authorized_action": {
                "summary": "按 revision 5 重跑 GATE-1 前置、独立 QA、LAN 白名单与 1000 固定种子，并准备人工决策包。",
                "forbidden": ["自动批准 GATE-1", "把可丢弃 LAN 工具认定为正式联网架构"],
            },
            "application": {
                "materialized_path": V5_PATH.relative_to(PROJECT_ROOT).as_posix(),
                "materialized_status": "approved",
                "materialized_digest": contract_file_digest,
                "applied_at": decided_at,
            },
        }
    }
    return brief_approval, contract_approval


def make_event(
    snapshot: dict[str, Any], previous_event: dict[str, Any], sequence: int,
    event_type: str, payload: dict[str, Any], evidence_refs: list[str],
    request_id: str, binding_digest: str,
) -> dict[str, Any]:
    occurred_at = now_china()
    event = {
        "schema_version": "0.1",
        "event_id": str(uuid.uuid4()),
        "mutation_id": str(uuid.uuid4()),
        "loop_instance_id": snapshot["identity"]["loop_instance_id"],
        "sequence": sequence,
        "event_type": event_type,
        "occurred_at": occurred_at,
        "recorded_at": occurred_at,
        "actor": {
            "actor_id": "inst:01M02M6X3Q8YWJXHY52K3V5AR2",
            "role": "pos:veilfront-xiang-siege:root:project-manager".replace("xiang-siege", "xiangqi-siege"),
            "authority_id": "AUTH-VEILFRONT-PROJECT-MANAGER",
        },
        "causality": {
            "correlation_id": str(uuid.uuid4()),
            "causation_event_id": previous_event["event_id"],
            "request_id": request_id,
        },
        "concurrency": {"expected_record_revision": sequence - 1, "resulting_record_revision": sequence},
        "binding_snapshot": {
            "contract_digest": binding_digest,
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


def main() -> None:
    snapshot_doc = load_yaml(SNAPSHOT_PATH)
    history_doc = load_yaml(HISTORY_PATH)
    snapshot = snapshot_doc["registry_snapshot"]
    history = history_doc["event_history"]
    if snapshot["contract_binding"] != {
        "contract_id": "LOOP-CTR-GATE1-VERTICAL-SLICE-001",
        "contract_version": 4,
        "contract_digest": V4_SUBJECT_DIGEST,
    }:
        raise RuntimeError("Registry is not on Contract v4")
    if snapshot["runtime"]["record_revision"] != EXPECTED_REVISION or len(history) != EXPECTED_REVISION:
        raise RuntimeError("Registry must be at revision 50")
    if history[-1]["integrity"]["event_digest"] != snapshot["runtime"]["last_event_digest"]:
        raise RuntimeError("Registry history/snapshot tail mismatch")

    decided_at = now_china()
    brief, brief_approval_id = materialize_brief(decided_at)
    contract, contract_digest, contract_approval_id = materialize_contract(decided_at)
    brief_approval, contract_approval = approval_documents(
        brief, brief_approval_id, contract, contract_digest, contract_approval_id, decided_at
    )
    brief_approval_path = APPROVALS_DIR / f"project-brief-v4-{BRIEF_V4_SUBJECT_DIGEST[:12]}.yaml"
    contract_approval_path = APPROVALS_DIR / f"loop-contract-v5-{contract_digest[:12]}.yaml"

    BRIEF_PATH.write_bytes(dump_yaml(brief))
    V5_PATH.write_bytes(dump_yaml(contract))
    write_new(brief_approval_path, dump_yaml(brief_approval))
    write_new(contract_approval_path, dump_yaml(contract_approval))

    evidence = f"""# OWNER-RULE-REVISION-5 / Contract v5 迁移检查

状态：`approved rule and information-boundary migration / GATE-1 not decided`

- 项目所有者事实源：`{OWNER_SOURCE_REF}`
- Project Brief v4 subject digest：`{BRIEF_V4_SUBJECT_DIGEST}`
- Project Brief v4 file SHA-256：`{file_digest(BRIEF_PATH)}`
- Project Brief approval：`{brief_approval_id}`
- Contract v4 subject digest：`{V4_SUBJECT_DIGEST}`
- Contract v5 subject digest：`{contract_digest}`
- Contract v5 file SHA-256：`{file_digest(V5_PATH)}`
- Contract v5 approval：`{contract_approval_id}`
- Registry 迁移目标：revision/sequence 52，先迁移 Contract，再重绑 INPUT-BRIEF-001。
- QA-P1-003 仍必须记录为官方 CLI failed/exit 1/精确六项错误；出现第七项错误即阻断。
- 本迁移只批准 revision 5 的 GATE-1 前置范围，不构成 GATE-1 通过。
""".replace("\r\n", "\n").encode("utf-8")
    write_new(EVIDENCE_PATH, evidence)
    evidence_ref = EVIDENCE_PATH.relative_to(PROJECT_ROOT).as_posix() + "@sha256:" + hashlib.sha256(evidence).hexdigest()

    contract_after = {
        "contract_id": "LOOP-CTR-GATE1-VERTICAL-SLICE-001",
        "contract_version": 5,
        "contract_digest": contract_digest,
    }
    event_51 = make_event(
        snapshot, history[-1], 51, "core.contract_migrated",
        {
            "contract_before": copy.deepcopy(snapshot["contract_binding"]),
            "contract_after": contract_after,
            "migration_check_ref": evidence_ref,
            "approval_id": contract_approval_id,
        },
        [
            contract_approval_path.relative_to(PROJECT_ROOT).as_posix(),
            V5_PATH.relative_to(PROJECT_ROOT).as_posix() + "@sha256:" + file_digest(V5_PATH),
            evidence_ref,
            OWNER_SOURCE_REF,
        ],
        contract_approval_id,
        V4_SUBJECT_DIGEST,
    )
    old_input = next(item for item in snapshot["resources"]["inputs"] if item["input_slot_id"] == "INPUT-BRIEF-001")
    new_artifact = {
        "artifact_id": "artifact:veilfront-xiangqi-siege:project-brief@v4",
        "artifact_type": "confirmed-project-brief",
        "version": 4,
        "uri": "game-pipeline/project-definition/project-brief.yaml",
        "digest": {"algorithm": "sha256", "value": BRIEF_V4_SUBJECT_DIGEST},
    }
    event_52 = make_event(
        snapshot, event_51, 52, "core.input_bound",
        {
            "input_slot_id": "INPUT-BRIEF-001",
            "before": {
                "artifact_id": old_input["artifact"]["artifact_id"],
                "version": old_input["artifact"]["version"],
                "uri": old_input["artifact"]["uri"],
                "digest": old_input["artifact"]["digest"]["value"],
            },
            "after": {
                "artifact_id": new_artifact["artifact_id"],
                "version": 4,
                "uri": new_artifact["uri"],
                "digest": BRIEF_V4_SUBJECT_DIGEST,
            },
        },
        [brief_approval_path.relative_to(PROJECT_ROOT).as_posix(), OWNER_SOURCE_REF],
        brief_approval_id,
        contract_digest,
    )

    original_history_bytes = HISTORY_PATH.read_bytes()
    history_bytes = append_event_bytes(append_event_bytes(original_history_bytes, event_51), event_52)
    snapshot["contract_binding"] = contract_after
    old_input["artifact"] = new_artifact
    old_input["source_loop_id"] = None
    old_input["bound_by_event_id"] = event_52["event_id"]
    old_input["bound_at"] = event_52["occurred_at"]
    snapshot["runtime"]["last_event_id"] = event_52["event_id"]
    snapshot["runtime"]["last_event_digest"] = event_52["integrity"]["event_digest"]
    snapshot["runtime"]["last_event_sequence"] = 52
    snapshot["runtime"]["record_revision"] = 52
    HISTORY_PATH.write_bytes(history_bytes)
    SNAPSHOT_PATH.write_bytes(dump_yaml(snapshot_doc))
    if not HISTORY_PATH.read_bytes().startswith(original_history_bytes):
        raise RuntimeError("Existing Registry history was not preserved byte-for-byte")

    print(json.dumps({
        "result": "migrated",
        "project_brief_v4_subject_digest": BRIEF_V4_SUBJECT_DIGEST,
        "contract_v5_subject_digest": contract_digest,
        "contract_v5_file_digest": file_digest(V5_PATH),
        "contract_event_id": event_51["event_id"],
        "brief_input_event_id": event_52["event_id"],
        "revision": 52,
        "sequence": 52,
        "gate_1_decision": "not_made",
    }, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
