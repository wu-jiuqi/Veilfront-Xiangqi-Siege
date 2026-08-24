# GATE-3 SFX 来源与许可登记 v1

状态：`producer_registered / pending_independent_QA`

## 许可结论

- 来源类型：本项目内原创程序合成。
- 生成入口：`docs/audio/generate_original_sfx_v1.ps1`。
- 外部采样、录音、素材包、模型服务或第三方音源：无。
- 外部支出：`0 CNY`。
- 作者/供应商署名要求：无第三方署名要求。
- 允许修改：是。
- 可分发范围：允许随《雾疆：九路烽棋》的开发版、测试版、Windows 构建及未来 Steam 商业构建一起复制、修改与分发。
- 独立转售：不作为独立音效素材包对外转售；如未来要独立发布素材包，需另行复核。
- 权利登记：项目内原创工作产物，归项目所有者的项目资产记录管理；不存在已知第三方版权链。

该记录用于项目资产来源追踪，不替代发行平台或法务的最终审查。

## 生成规范

- 48,000 Hz、16-bit PCM、mono WAV；
- 每个文件由固定 recipe、duration、seed 生成；
- noise 为脚本内固定整数序列，不读取系统随机数；
- 所有首尾使用短 attack/release 包络；
- Godot `.wav.import` 固定 `compress/mode=0`，运行时保持 PCM。

复现命令：

```powershell
& .\docs\audio\generate_original_sfx_v1.ps1
```

## 文件清单与 SHA-256

| 文件 | recipe / seed | SHA-256 |
|---|---|---|
| `sfx_ui_activate_v01.wav` | ui_activate / 1101 | `2c6addb26a2bf10ca5cfa152620ed177c5ef548fd2183b5d8ef51160b283abe9` |
| `sfx_ui_cancel_v01.wav` | ui_cancel / 1102 | `ad2897e3d8b5ef534bc8caac59f798af11cb6df6f8fafab1ac20012e343aee14` |
| `sfx_ui_reject_v01.wav` | ui_reject / 1103 | `31b671d4d8adb990c7580a1b9824bb6aac8eef354c86b20df5aebb9a9abb550d` |
| `sfx_board_select_v01.wav` | board_select / 1201 | `72d7639f4ea89884eb46524dc0735463dc920eb666c384a9bbed6c455d2bb442` |
| `sfx_move_foot_v01.wav` | move_foot / 1301 | `3f92bdf6a3c14fb168dd7b0643665368033bb9dfb57305ae92b79299896c6cd1` |
| `sfx_move_cavalry_v01.wav` | move_cavalry / 1302 | `e96ad7c44802024c2dc883251491bb3c76e343257a762b07bc915bdfa6b076fc` |
| `sfx_move_chariot_v01.wav` | move_chariot / 1303 | `145ce7bb18c5975409f4a2ba07b876eb6e6b1b80ba26273074a6e458f23f2bc4` |
| `sfx_move_cannon_v01.wav` | move_cannon / 1304 | `288fdb77aca2cb005ff826890ca8dacce198e61b61bf3b4b5807052108750977` |
| `sfx_action_pass_v01.wav` | pass / 1401 | `334a629e73da1c167a8ca5ba12b08d775507dc3d90172f9a67efb01142ecee79` |
| `sfx_turn_timeout_v01.wav` | timeout / 1402 | `dbed3ccc98ede67d1c999a4c31d599a8d599836105eaf739dda459c51c97e5f3` |
| `sfx_capture_impact_v01.wav` | capture / 1501 | `c04cf02c205842f9e1f474f5f4865e434062a4574737762341491f602ecb375c` |
| `sfx_casualty_public_v01.wav` | casualty / 1502 | `712eb1ac6e36c042c54c761d281b84d758b8ec4f05b78d2944a29d73fd4ac9d7` |
| `sfx_bombard_launch_v01.wav` | bombard_launch / 1601 | `c974cad17a5fe87844cab7f831b8e9cfd4aba0cdc63eb2c8d244f9966b9ad4fd` |
| `sfx_bombard_impact_bed_v01.wav` | bombard_impact / 1602 | `134a4f0cac8ee01de4d6774153e3c87c68eb1c5076ad57c07ed7dd97364f7fcb` |
| `sfx_advisor_sacrifice_v01.wav` | advisor_sacrifice / 1701 | `4e39a94c40c253b12bf767610db83f50dccc05e31c7e251c0deb3c6b04f422b6` |
| `sfx_advisor_resurrect_v01.wav` | advisor_resurrect / 1702 | `827a90d5433612b7a7870ff591885fbaa9c3a3a1839e76e7885b0cb45e8fc311` |
| `sfx_wall_breached_v01.wav` | wall_breach / 1801 | `a65459644db8b31b92b06fe392f8cf6cc9aa637debb2c4a64f1e99392e909ef3` |
| `sfx_wall_repairing_v01.wav` | wall_repairing / 1802 | `0eff101e2fbc654325d57030ecf890cb696650c2a5d4aba8ba02b17790f827b7` |
| `sfx_wall_repaired_v01.wav` | wall_repaired / 1803 | `4189785e8cb8cebaf2a468c8f2a085c6b8bd20339b7b73ac2f17fabc5d754129` |
| `sfx_flag_discovered_v01.wav` | flag_discovered / 1901 | `e41193a6879183b8dac79ee089932077651672db1e172b3f62292599c8f0ac95` |
| `sfx_flag_capture_progress_v01.wav` | flag_progress / 1902 | `201a0b82e757d2a69b2869215a77327da9a02e93a546a71c06f41e7c30c0d3d9` |
| `sfx_flag_captured_v01.wav` | flag_captured / 1903 | `f1f8b37d1d3858c949d1b490d2d9b1c6cdacdebe4b73705b0979ec81119fd36a` |
| `sfx_flag_capture_cancelled_v01.wav` | flag_cancelled / 1904 | `939b77a50d33047ecdc5377c5c35e5495364b28bd12faea9b0b39fcb25feb804` |
| `sfx_fog_reveal_v01.wav` | fog_reveal / 2001 | `f41931d0928079e84a0cdaf4d4b1177bfd704d48a7ae9167622e3b8f9a46a023` |
| `sfx_contact_unknown_v01.wav` | contact / 2002 | `060ba6a1ce0ffc0ec57b91f3e0909efb7ad5de9727160df7a9d050f75ed5846f` |
| `sfx_reveal_piece_v01.wav` | reveal_piece / 2003 | `2af7b359ead3c5d17128b8698f428d787baba67750809283df7d6837d641ec2b` |
| `sfx_special_elephant_field_v01.wav` | elephant_field / 2004 | `f504e4f55c8a1aa4d43ceabc52ff6bd0d30c52739e14fe5a97b49646e26326b3` |
| `sfx_turn_local_start_v01.wav` | turn / 2101 | `47a81d44b8f01549fa5cc8bdfcbe50032620f2e46609a8f9bde5835acd738cdf` |
| `sfx_match_victory_v01.wav` | victory / 2201 | `a9a8c2310709d7d1169b6ded742262baaee49a97ca0f52ef31ce770db055dd74` |
| `sfx_match_defeat_v01.wav` | defeat / 2202 | `8e99dbcca7c77c24dc1541f1c58d69522dc127d2de86c458fd5b6382ac0777fe` |
| `sfx_match_draw_v01.wav` | draw / 2203 | `49166f4adfa767838c06f56e241cce0419cbf2affa904b18cd04793b37c83b72` |
