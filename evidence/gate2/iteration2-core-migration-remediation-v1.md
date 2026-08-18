# Iteration 2 正式核心迁移技术整改证据 v1

状态：`candidate_complete / awaiting_independent_rereview`

日期：2026-08-18（Asia/Shanghai）

责任实例：`inst:01M02NJ3JEQXKV6PT6DPX0NKQ0`

整改范围：`I2-XREV-001`、`I2-XREV-002`、`I2-XREV-003`

返回任务：`TASK-CORE-002`

## 1. 输入与边界

- 原冻结候选：`main@ba0f883c652f34a1611ed1598e0009da3e32dec6`。
- 整改期间共享 main 前进至：`5dc9871864287a48bb94b0b1bccab78ab8bb73da`；本实例未回退或覆盖并行提交。
- 交叉复审 SHA-256：`b9813e1907aee2d7fd73f6fcdb5b90e7720bac21831d58163c75a8b70142eb64`。
- RC3 迁移源：`6253678157157091584b253470e709bad17c534f`。
- HQ successor：`f6b07d8cbdc7db4492c33e8b4b028aca2906cccc8baf5921273aaa012d48e19b`。
- Godot：`4.7.1.stable.official.a13da4feb`。
- 未修改规则事实源、Contract、Registry、approval、教程、ApplicationHost、MatchScreen、AI、LAN 或互联网实现；`formal_match_application.gd` 的窄修改仅用于 observer replay schema v2 的安全 DTO、顺序与 audit。

## 2. TDD 记录

### RED

1. `run_hidden_equivalence.gd` 先增加规则输入绑定与合法字段形状篡改负向断言。首次运行退出 `1`：AuthoritativeReplay 仍为 v1、缺少 RC3/HQ/formal bundle 绑定；ObserverReplay 缺少 v2/audit，且合法形状的 VisibleEvent、VisibleError、ActionPreview 篡改可被接受。
2. migration runner 先切到不存在的 v2 golden 与待定摘要。首次运行退出 `1`：`FORMAL_EQUIVALENCE_FAIL golden_digest_mismatch`，证明 v1 未被静默覆盖或祝福。
3. VisibleError 与 replay 检查计数在实现前不存在；旧 runner 的成功行动错误摘要固定为空，live980 不执行这两个通道。

### GREEN

1. AuthoritativeReplay 升至 `veilfront-authoritative-replay-v2`，exact schema 与 audit surface 加入不可歧义的 `rules_input_binding`。每个绑定字段均有篡改拒绝测试。
2. ObserverReplay 升至 `veilfront-observer-replay-v2`：root audit 覆盖全部 frame；每帧加入 `frame_sequence`，校验 action index 单调、PlayerView action index 一致、VisibleEvent cursor/前缀连续及所有公开 codec。三类合法字段形状篡改均被拒绝。
3. VisibleError 语料固定为四类：实际 prototype/formal 已知非法；application stale；application invalid；同一隐藏马腿接触意图在 prototype/formal RuleEngine 的实际消费结果。输出按公开 mapper/projector 比较，不含隐藏位置或原始错误。
4. 每个 seed 的 replay 通道直接比较 normalized intents、execution results、mapped domain events 与 final state summary；红黑 observer frame 逐行动比较 PlayerView、VisibleEvent、VisibleError、ActionPreview 的完整安全 DTO 外形。
5. runner 输出由实际累加计数生成，不再以九通道常量代替执行证据。

## 3. 规则输入与 replay 绑定

AuthoritativeReplay v2 的规则输入包含：

- `source_commit=6253678157157091584b253470e709bad17c534f`
- `hq_successor_sha256=f6b07d8cbdc7db4492c33e8b4b028aca2906cccc8baf5921273aaa012d48e19b`
- `formal_rules_bundle_sha256=f3d09bca73a4e074d698fab29acceb425cc5374b080666af3fddfdb81e1a29a8`
- `implementation_revision=formal-core-revision-1`
- `canonical_revision=veilfront_canonical_json_sha256_v1`
- FullState/DomainEvent codec v1。

formal rules bundle 按 8 个正式规则输入文件路径排序，逐文件形成 `sha256  path`，条目 LF 连接、末尾无 LF 后计算；重算结果与运行时常量一致。规则语义没有因本整改变化。

## 4. Versioned golden

| 文件 | SHA-256 | 处理 |
|---|---|---|
| `gate1-successor-20-seeds-v1.json` | `e825641ca133eb9cae925d18e748660c7103fc5327120c5c48732027d6de0f4f` | 历史不可变，字节摘要未变 |
| `gate1-successor-20-seeds-v2.json` | `67ed6d953a756eac88e8fa8063612409b7b7de1e009c8b80e92b0c0fccf97411` | 新增真实 VisibleError 语料、权威 replay 语义与红黑 observer frame chain |

v2 仍绑定相同 RC3 source commit 与 HQ successor。重生原因是验收证据结构从伪 checkpoint/固定空错误升级为真实九通道，不是规则变化；v1 保留用于历史追溯，不允许 runner 回退使用。

## 5. 最终验证

### 精确 20-seed

命令使用 `start=471001`、`seeds=20`、`round_limit=50`、`replay_samples=20` 和 manifest 九通道顺序。

结果：

`FORMAL_EQUIVALENCE_PASS completed=20 replay_verified=20 channels=9 visible_error_checked=2080 authoritative_replay_checked=20 observer_replay_frames_checked=4000`

### 精确 1000-seed

命令使用 `start=471001`、`seeds=1000`、`round_limit=50`、`replay_samples=20` 和相同九通道顺序。

结果：

- `FORMAL_EQUIVALENCE_PROGRESS completed_live=980/980 workers=4`
- `FORMAL_EQUIVALENCE_PASS completed=1000 replay_verified=20 channels=9 visible_error_checked=103987 authoritative_replay_checked=1000 observer_replay_frames_checked=199974`

差异 seed：无；九通道失败：无；replay verify 失败：无。

### 全回归

- `FORMAL_ARCHITECTURE_CHECKS_PASSED self_tests=17 scanned_files=68`
- `OBSERVER_CONTRACT_CHECKS_PASSED checks=30`
- `HIDDEN_EQUIVALENCE_PASS pairs=6 checks=2723`
- `PROTOTYPE_BASIS_CHECKS_PASSED scaffold=9 focused_suites=15 full_gate1=false`
- `FORMAL_SCENE_SMOKE_PASS roots=3 components=16 inputs=11`
- `TUTORIAL_SHELL_SMOKE_PASS`
- `BOARD_LAYOUT_CONTRACT_PASS resolutions=3`
- `BOARD_OBSERVER_FIXTURE_PASS`
- `git diff --check`：通过。

## 6. 最终文件摘要

| 文件 | SHA-256 |
|---|---|
| `scripts/game/domain/authoritative_replay.gd` | `72810a5b938f4ee684e176e77af13ee41066e6f7d45e122dff2f99238acaa822` |
| `scripts/game/application/observer_replay_validator.gd` | `dfcfe495c12349b79645c3dc1c476c0907a13278561a718985f5406e38e2d00a` |
| `scripts/game/application/formal_match_application.gd` | `c13a72344677df135d790cf953d0598f2735b70f99e60dd8bd80ae1124e4f998` |
| `tests/game/contracts/run_hidden_equivalence.gd` | `876adf79e8a1f043e448b5381397a56ed61b2d2fc17b2e97aee356f3f9074a94` |
| `tests/game/migration/capture_gate1_golden.gd` | `269e18a5738313212b96fdf4e2fc749b0041febd8b3e519dad9573b55f789835` |
| `tests/game/migration/gate1_channel_capture.gd` | `aef39c561dac1d4609512236fd1b16381b19e803e82850298a0907821a2232c7` |
| `tests/game/migration/run_gate1_formal_equivalence.gd` | `2c5317cca069116cb1339ea14f8ef99792161f0ea500872d294facb3db0e29c4` |
| `tests/game/migration/source_channel_mapper.gd` | `642e6b67098925e929016a52ce2cb1bef18e1b877f45d3a884e8b77fb4c7d66b` |

## 7. 关闭判断与下一合法动作

- `I2-XREV-001`：候选关闭。九通道由实际执行计数证明，VisibleError 四类语料、权威 replay、红黑 observer frame 均进入 20/1000 比较。
- `I2-XREV-002`：候选关闭。schema v2 audit 覆盖全部 frame，顺序/cursor 连续性与合法字段形状篡改负向测试通过。
- `I2-XREV-003`：候选关闭。runtime replay 精确绑定 RC3、HQ successor、正式规则 bundle、实现与 codec revision，逐字段篡改拒绝。

下一合法动作是独立技术/QA 从新冻结候选复算 v2 golden 摘要、规则 bundle、20/1000 计数与 tamper 测试。本证据不自行批准 Iteration 2 或 GATE-2，也不宣称 ApplicationHost/MatchScreen 已接入正式核心。
