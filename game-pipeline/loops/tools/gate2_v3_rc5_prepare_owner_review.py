#!/usr/bin/env python3
"""Build the refreshed GATE-2 v3 RC5 owner decision package without deciding it."""

from __future__ import annotations

import hashlib
import json
import subprocess
from pathlib import Path
from typing import Any


PROJECT_ROOT = Path(__file__).resolve().parents[3]
PACKAGE_PATH = PROJECT_ROOT / "game-pipeline/loops/evidence/GATE-2-v3-decision-package.md"
QA_REPORT_PATH = PROJECT_ROOT / "evidence/gate2/gate2-v3-independent-qa-rc5.md"
QA_SUMMARY_PATH = PROJECT_ROOT / "evidence/gate2/v3-candidate-05ada98/qa-evidence-summary.json"
EXE_RELATIVE_PATH = "builds/windows/Veilfront_Xiangqi_Siege_Gate2_v3_05ada98.exe"
EXE_PATH = PROJECT_ROOT / EXE_RELATIVE_PATH

PROJECT_BRIEF_DIGEST = "8e9d4285c1c7237a22f308808e944fd8571700f896b8dd8cfb118f0fe0de3d3e"
REGISTRY_CONTRACT_DIGEST = "9ea1fbab25b1a560b83896194099bd9b0131552d7321223622161615c1a2a205"
CONTRACT_APPROVAL_DIGEST = "9d9e3cfc5e92d41d38eea336dbcca95040bb858706ffd8130a8b33a3594e7dd9"
BASE_CANDIDATE = "419e2cef5d4fac9f099c8ea487b5e6d6a5c57445"
PRODUCT_CANDIDATE = "05ada9848c20c41b6d6cc92ce552df643c31438c"
QA_EVIDENCE_COMMIT = "d1f5482f058ec66db20087ab27b6c12539c0d176"
OLD_DECISION_DIGEST = "36efd026dd33a1caab9bd9d72e4a593c6853850e92904e865d29f434c4317a84"


def canonical_bytes(value: Any) -> bytes:
	return json.dumps(
		value,
		ensure_ascii=False,
		allow_nan=False,
		separators=(",", ":"),
		sort_keys=True,
	).encode("utf-8")


def digest_bytes(value: bytes) -> str:
	return hashlib.sha256(value).hexdigest()


def file_digest(path: Path) -> str:
	return digest_bytes(path.read_bytes())


def git(*args: str) -> str:
	return subprocess.check_output(
		["git", *args], cwd=PROJECT_ROOT, text=True, encoding="utf-8"
	).strip()


def main() -> None:
	qa = json.loads(QA_SUMMARY_PATH.read_text(encoding="utf-8"))
	if qa["candidate"] != PRODUCT_CANDIDATE:
		raise RuntimeError("QA candidate mismatch")
	if qa["contract_approval_digest"] != CONTRACT_APPROVAL_DIGEST:
		raise RuntimeError("QA contract approval mismatch")
	if qa["technical_verdict"] != "pass":
		raise RuntimeError("Independent QA did not pass")
	if git("rev-parse", "HEAD") != QA_EVIDENCE_COMMIT or git("rev-parse", "origin/main") != QA_EVIDENCE_COMMIT:
		raise RuntimeError("HEAD/origin are not the frozen QA evidence commit")
	if git("merge-base", "--is-ancestor", PRODUCT_CANDIDATE, QA_EVIDENCE_COMMIT) != "":
		# merge-base --is-ancestor succeeds with no output; this branch documents intent.
		pass

	exe = qa["windows_artifact"]
	if EXE_PATH.stat().st_size != int(exe["size_bytes"]):
		raise RuntimeError("EXE size mismatch")
	if file_digest(EXE_PATH).lower() != str(exe["sha256"]).lower():
		raise RuntimeError("EXE digest mismatch")

	impact = subprocess.check_output(
		["git", "diff", "--name-status", f"{BASE_CANDIDATE}..{PRODUCT_CANDIDATE}"],
		cwd=PROJECT_ROOT,
	)
	deliverable_digests = {
		"DELIVERABLE-PRESENTATION-2D-001": digest_bytes(
			canonical_bytes(
				{
					"base_candidate": BASE_CANDIDATE,
					"product_candidate": PRODUCT_CANDIDATE,
					"impact_name_status_sha256": digest_bytes(impact),
				}
			)
		),
		"DELIVERABLE-ART-2D-001": digest_bytes(
			canonical_bytes(
				{
					"product_candidate": PRODUCT_CANDIDATE,
					"asset_memory": qa["asset_memory"],
					"screenshots": "evidence/gate2/v3-candidate-05ada98/screenshots",
				}
			)
		),
		"DELIVERABLE-QA-2D-001": digest_bytes(
			canonical_bytes(
				{
					"qa_evidence_commit": QA_EVIDENCE_COMMIT,
					"qa_report_sha256": file_digest(QA_REPORT_PATH),
					"qa_summary_sha256": file_digest(QA_SUMMARY_PATH),
				}
			)
		),
	}

	acceptance_subject = {
		"project_brief_digest": PROJECT_BRIEF_DIGEST,
		"registry_contract_digest": REGISTRY_CONTRACT_DIGEST,
		"contract_approval_digest": CONTRACT_APPROVAL_DIGEST,
		"candidate_commit": PRODUCT_CANDIDATE,
		"deliverable_digests": deliverable_digests,
		"check_results": qa["check_matrix"],
	}
	decision = {
		"subject": "GATE-2-v3-formal-2d-baseline-rc5",
		"gate_2_decision": "not_made",
		"loop_instance_id": "83c995ff-37b9-4df8-9e84-8417d6632187",
		"project_brief_digest": PROJECT_BRIEF_DIGEST,
		"registry_contract_digest": REGISTRY_CONTRACT_DIGEST,
		"contract_approval_digest": CONTRACT_APPROVAL_DIGEST,
		"acceptance_subject_digest": digest_bytes(canonical_bytes(acceptance_subject)),
		"candidate_commit": PRODUCT_CANDIDATE,
		"qa_evidence_commit": QA_EVIDENCE_COMMIT,
		"qa_report_sha256": file_digest(QA_REPORT_PATH),
		"qa_summary_sha256": file_digest(QA_SUMMARY_PATH),
		"professional_review": "pass",
		"route_recommendation": "recommend_updated_owner_approval",
		"check_results": qa["check_matrix"],
		"deliverable_digests": deliverable_digests,
		"formal_equivalence": qa["formal_equivalence"],
		"executable": {
			"path": EXE_RELATIVE_PATH,
			"size_bytes": int(exe["size_bytes"]),
			"sha256": str(exe["sha256"]).lower(),
		},
		"registry_review": {
			"state": "waiting_approval",
			"sequence": 79,
			"revision": 79,
			"prior_decision_digest": OLD_DECISION_DIGEST,
			"prior_request_status": "stale_not_decidable",
		},
		"disclosed_risks": [
			"current_3_seed_formal_equivalence_timed_out_at_240_seconds",
			"current_20_seed_formal_equivalence_not_rerun",
			"all_resources_export_includes_non_runtime_art_and_requires_gate3_filtering",
			"independent_quality_tier_switch_not_yet_available",
		],
	}
	decision_digest = digest_bytes(canonical_bytes(decision))
	request_id = f"approval:veilfront-xiangqi-siege:gate-2:{decision_digest[:12]}"
	canonical_json = canonical_bytes(decision).decode("utf-8")

	package = f"""# GATE-2 v3 正式二维基线人工决策包（RC5）

状态：`awaiting_human / decision_not_made`

本文件只整理当前冻结候选与独立证据，不构成 GATE-2 批准。旧 RC4 决策摘要已因产品、UI、教学与证据变化失效。

## 冻结对象

- Project Brief：v7 / `{PROJECT_BRIEF_DIGEST}`
- Contract：v3 / owner approval `{CONTRACT_APPROVAL_DIGEST}`
- Registry contract digest：`{REGISTRY_CONTRACT_DIGEST}`
- 产品候选：`{PRODUCT_CANDIDATE}`
- QA 证据提交：`{QA_EVIDENCE_COMMIT}`
- QA 报告 SHA-256：`{file_digest(QA_REPORT_PATH)}`
- QA 摘要 SHA-256：`{file_digest(QA_SUMMARY_PATH)}`
- EXE：`{EXE_RELATIVE_PATH}`
- EXE size：`{int(exe['size_bytes'])}` bytes
- EXE SHA-256：`{str(exe['sha256']).upper()}`

## 验收结论

- Contract 十项检查：8 项 `pass`，`CHECK-REGRESSION-001=pass_with_limitation`，`CHECK-SCOPE-001=pass_with_risk`。
- 独立专业审查：`pass`；建议路由：`recommend_updated_owner_approval`。
- 当前候选 48/48 必要合同有效通过；定向镜头回归 12/12 通过。
- 三目标分辨率双方视角与新增 UI 样片通过；真实 GPU Match HUD 截图通过。
- Iris Xe：1280×720 默认运动平均 105.140 FPS、p99 14.255 ms；960×540 reduced motion 平均 162.597 FPS、p99 9.472 ms。
- embedded-PCK Windows 成品导出、直接启动与正式 LAN 全栈闭环均通过。

详细证据：`evidence/gate2/gate2-v3-independent-qa-rc5.md` 与 `evidence/gate2/v3-candidate-05ada98/`。

## 已披露限制与 Gate 3 必办风险

1. 当前 1-seed 九通道正式等价通过；3-seed 在 240 秒硬上限内无错误但未完成，20-seed 仅有历史 golden。
2. EXE 为 363,175,248 bytes；`all_resources` 仍包含概念图、漫画源图和未用资源，Gate 3 必须建立资源过滤、压缩与包体预算。
3. 项目尚无独立质量档位；当前只有 reduced-motion 低配验收配置。
4. 960×540 辅助信息密度仍偏高，列入 UI 打磨而非 Gate 2 阻断。

## GATE-2 人工问题

当前正式二维表现、教学与联机 UI、信息边界、二维样片、性能和 Windows 成品是否足够稳定，可以关闭 GATE-2 并进入 GATE-3 合同准备？

- `批准`：接受上述限制，关闭 GATE-2；允许准备 GATE-3 Contract。SFX、VFX、UI 交互与关卡批量生产仍须另行批准 Gate 3 Contract。
- `修订`：列出修改要求，返回 Gate 2 review/active。
- `拒绝`：停止当前二维基线或返回 Brief/Contract 重新定义。

## 待项目所有者决定

- 审批请求：`{request_id}`
- 选择：`批准 / 修订 / 拒绝`
- 决定者：`project-owner`
- 当前 GATE-2 决策摘要：`{decision_digest}`

摘要输入（canonical JSON）：

```json
{canonical_json}
```

任一绑定输入、候选提交、QA 报告、QA 摘要或 EXE 摘要变化后必须重新生成决策包，旧摘要不得批准。
"""
	PACKAGE_PATH.write_text(package, encoding="utf-8", newline="\n")
	print(f"GATE2_RC5_OWNER_PACKAGE_PASS request_id={request_id} digest={decision_digest}")


if __name__ == "__main__":
	main()
