#!/usr/bin/env python3
"""Build the project-owner decision package for the draft GATE-3 v1 contract."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
from typing import Any

import yaml


PROJECT_ROOT = Path(__file__).resolve().parents[3]
CONTRACT_REL = "game-pipeline/loops/contracts/loop-contract-content-integration-gate3-v1.yaml"
PACKAGE_REL = "game-pipeline/loops/evidence/GATE-3-v1-contract-decision-package.md"
CONTRACT_PATH = PROJECT_ROOT / CONTRACT_REL
PACKAGE_PATH = PROJECT_ROOT / PACKAGE_REL
GATE2_APPROVAL_REL = "game-pipeline/approvals/gate-2-approval-0213f500a100.yaml"
GATE2_HANDOFF_REL = "game-pipeline/loops/evidence/GATE-2-v3-final-handoff.md"
SOURCE_REFS = {
	"audio_proposal": "docs/audio/veilfront-bgm-sfx-contract-proposal-v1.md",
	"ui_audit": "docs/ui/ui-ux-audit-2026-08-23.md",
	"content_catalog": "resources/game/levels/level_catalog.tres",
	"tutorial_design_proposal": "docs/design/tutorial/veilfront-ftue-dual-track-complete-design-v1.md",
}


def canonical_bytes(value: Any) -> bytes:
	return json.dumps(
		value,
		ensure_ascii=False,
		allow_nan=False,
		separators=(",", ":"),
		sort_keys=True,
	).encode("utf-8")


def file_digest(relative: str) -> str:
	return hashlib.sha256((PROJECT_ROOT / relative).read_bytes()).hexdigest()


def main() -> None:
	contract = yaml.safe_load(CONTRACT_PATH.read_text(encoding="utf-8"))
	if contract["loop_contract"]["status"] != "draft" or contract["approval_binding"] is not None:
		raise RuntimeError("GATE-3 contract must remain an unapproved draft")
	snapshot = yaml.safe_load(
		(PROJECT_ROOT / "game-pipeline/loops/registry/formal-foundation-gate2/snapshot.yaml").read_text(encoding="utf-8")
	)["registry_snapshot"]
	if snapshot["runtime"]["current_state"] != "completed" or snapshot["runtime"]["record_revision"] != 102:
		raise RuntimeError("GATE-2 is not at the approved completed waterline")

	subject = {
		"subject": "LOOP-CTR-CONTENT-INTEGRATION-GATE3-001@v1",
		"decision": "not_made",
		"requested_action": "approve_gate3_content_integration_contract_v1",
		"project_brief_digest": "8e9d4285c1c7237a22f308808e944fd8571700f896b8dd8cfb118f0fe0de3d3e",
		"gate_2_approval_id": "approval:veilfront-xiangqi-siege:gate-2:0213f500a100",
		"gate_2_subject_digest": "0213f500a10070198ccdf1090ddcdd2ea519828233251e9896076ff0ced68525",
		"gate_2_registry": {
			"state": "completed",
			"sequence": 102,
			"revision": 102,
			"last_event_digest": snapshot["runtime"]["last_event_digest"],
		},
		"contract": {"path": CONTRACT_REL, "sha256": file_digest(CONTRACT_REL)},
		"gate_2_handoff_sha256": file_digest(GATE2_HANDOFF_REL),
		"source_digests": {name: file_digest(path) for name, path in SOURCE_REFS.items()},
		"approved_scope_if_confirmed": {
			"p0": "export_filtering_texture_font_budget_public_cue_contracts",
			"parallel_lines": ["observer_safe_sfx", "observer_safe_vfx", "ui_interaction", "tutorial_and_challenge_content"],
			"content_wave": ["T0-T10", "C1-C3"],
			"core_sfx_cue_families_min": 12,
			"core_vfx_families": ["selection", "move", "capture", "bombardment", "wall", "flag", "terminal"],
			"windows_exe_max_bytes": 320000000,
			"external_spend_cny": 0,
		},
		"explicit_deferrals": [
			"formal_bgm_production",
			"voice_and_ambience",
			"dual_track_P0_B1_B2_B3_modules",
			"challenge_levels_C4_plus",
			"internet_services_and_ai_delivery",
			"toon_rendered_3d_mainline",
			"external_release",
		],
		"audio_ownership_condition": "formal_sfx_files_require_owner_supplied_or_license_cleared_source_or_separate_temporary_audio_authorization",
	}
	digest = hashlib.sha256(canonical_bytes(subject)).hexdigest()
	request_id = f"approval:veilfront-xiangqi-siege:loop-contract:{digest[:12]}"
	canonical_json = canonical_bytes(subject).decode("utf-8")
	package = f"""# GATE-3 内容与集成 Contract v1 人工决策包

状态：`awaiting_human / contract_not_approved / production_not_started`

本决策包不批准 GATE-3 冻结，也不代表 SFX、VFX、UI 交互和关卡生产已经开工。它只请求批准第三生产循环的范围、预算、责任、验收和回退规则。

## 前置状态

- GATE-2：`approved / completed`
- GATE-2 approval：`approval:veilfront-xiangqi-siege:gate-2:0213f500a100`
- GATE-2 Registry：`sequence 102 / revision 102`
- Contract 草案：`{CONTRACT_REL}`
- Contract SHA-256：`{file_digest(CONTRACT_REL)}`

## 批准后允许的工作

1. P0先行：导出资源过滤、纹理/字体/包体预算、公开AudioCue/VfxCue合同、UI动效与响应式基线。
2. 并行启动四条线：观察者安全SFX、观察者安全VFX、UI交互手感、T0-T10教学与C1-C3闯关补全。
3. 进入统一集成、试玩、独立QA，再提交最终GATE-3内容冻结人工判断。

## 本次明确冻结的范围选择

- 第一波内容固定为现有 `T0-T10 + C1-C3`，不自动新增C4+。
- SFX不少于12个核心cue族；BGM正式作曲、语音和完整环境声延期。
- VFX覆盖选中、移动、吃子、炮击、城墙、旗帜、终局七类核心效果族。
- 双轨教学提案中的P0/B1/B2/B3与能力状态迁移延期，需另行批准附录或Contract修订。
- Windows EXE目标不超过320,000,000 bytes；超出必须取得项目所有者例外。
- 本Contract不授权外部支出；正式SFX文件必须有项目所有者提供、许可清晰的来源，或另获临时音频制作授权。

## 项目所有者选择

- `批准`：接受上述范围、延期项、0元外部支出、音频所有权条件和验收阈值；允许物化Contract并登记新Loop。
- `修订`：指出需要改变的内容数量、BGM/双轨教学范围、包体阈值、音频来源或其他条款。
- `拒绝`：不启动当前GATE-3生产循环。

## 待决定

- 审批请求：`{request_id}`
- Contract 决策摘要：`{digest}`

摘要输入（canonical JSON）：

```json
{canonical_json}
```

任一Contract条款、GATE-2绑定或源提案内容变化后必须重算摘要，旧摘要不得批准。
"""
	PACKAGE_PATH.write_text(package, encoding="utf-8", newline="\n")
	print(f"GATE3_V1_CONTRACT_REVIEW_PASS request_id={request_id} digest={digest}")


if __name__ == "__main__":
	main()
