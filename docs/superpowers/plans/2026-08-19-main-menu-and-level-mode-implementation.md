# Main Menu and Level Mode Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver a Godot 4.7.1 graybox flow from the main menu to LAN play or a fourteen-level catalog containing T0–T10 tutorials and C1–C3 limited-AI challenges.

**Architecture:** Finish and independently review the Iteration 2 observer-channel equivalence first. Then add a seat-bound formal local session behind `MatchClientPort`, preset frontend scenes, Resource-driven level definitions, observer-safe tutorials, and a challenge-only opponent controller that consumes the black PlayerView and formal ActionPreviews.

**Tech Stack:** Godot 4.7.1, typed GDScript, `.tscn` preset Control scenes, `.tres` custom Resources, ConfigFile persistence, existing formal domain/application/projection codecs, headless SceneTree test runners.

**Spec:** `docs/godot-prompter/specs/2026-08-19-main-menu-and-level-mode-design.md`

**Execution shape:** Frontend, tutorial, and challenge work are distinct reviewable slices, but they intentionally remain in one ordered plan because all three depend on the same Iteration 2 closure, seat-bound formal session, catalog, and observer-safe DTO boundary. Do not execute a later slice by bypassing those shared gates.

## Global Constraints

- Do not start Iteration 3 production until Iteration 2 ActionPreview equivalence has producer evidence, independent technical/QA approval, and a legal Registry transition.
- Domain cannot depend on Node, Control, presentation, tutorial, challenge opponent, LAN, AI, or prototype code.
- Presentation, tutorial, frontend, and challenge opponent code cannot read `FullState`, raw `DomainEvent`, rule RNG, authoritative replay, or an unbound viewer.
- Fixed scene trees use preset `.tscn` nodes; only catalog cards and match-lifecycle visuals may be instantiated dynamically.
- The limited opponent exists only in C1–C3 and has no difficulty setting, training, free setup, or general human-vs-AI menu.
- T0–T10 scripts advance only through formal Intent/Event and observer-safe DTOs.
- Keep owner rule revision 5, random consumption order, LAN protocol, and the existing GATE-1 prototype behavior unchanged.
- Test 960×540, 1280×720, and 1920×1080.
- Every commit uses Chinese `feat: ...` and is pushed after its focused checks pass.

---

### Task 1: Close the Iteration 2 source ActionPreview equivalence defect

**Files:**
- Modify: `tests/game/migration/gate1_channel_capture.gd`
- Modify: `tests/game/migration/source_channel_mapper.gd`
- Create: `tests/game/migration/run_source_preview_independence_contract.gd`
- Create: `evidence/gate2/iteration2-core-migration-remediation-r3-v1.md`
- Preserve: `tests/game/migration/golden/gate1-successor-20-seeds-v1.json`
- Preserve: `tests/game/migration/golden/gate1-successor-20-seeds-v2.json`
- Preserve: `tests/game/migration/golden/gate1-successor-20-seeds-v3.json`

**Interfaces:**
- Consumes: `SourceChannelMapper.player_view(state: Dictionary, side: String, seed_value: int) -> Dictionary`
- Produces: `SourceChannelMapper.player_view_with_action_previews(state: Dictionary, side: String, seed_value: int, include_action_previews: bool) -> Dictionary`
- Produces: `Gate1ChannelCapture.compare_live(seed_value: int, round_limit: int = 50, source_preview_mutation: String = "") -> Dictionary`

- [ ] **Step 1: Verify the mutation contract rejects a source-only preview change**

Run:

```powershell
D:\Godot\godot.cmd --headless --path . --script res://tests/game/migration/run_source_preview_independence_contract.gd
```

Expected: exit `0` and `SOURCE_PREVIEW_INDEPENDENCE_PASS seed=471021 mutation=drop_first`.

- [ ] **Step 2: Run the exact twenty-seed equivalence sample**

```powershell
D:\Godot\godot.cmd --headless --path . --script res://tests/game/migration/run_gate1_formal_equivalence.gd -- --start-seed 471001 --seeds 20 --round-limit 50 --replay-samples 20 --channels state,event,red_player_view,black_player_view,red_visible_event,black_visible_event,visible_error,action_preview,replay
```

Expected: exit `0`, `completed=20`, `replay_verified=20`, `channels=9`, `visible_error_checked=2080`, `authoritative_replay_checked=20`, and `observer_replay_frames_checked=4000`.

- [ ] **Step 3: Record the project-owner sampling exception for the one-thousand-seed command**

```powershell
D:\Godot\godot.cmd --headless --path . --script res://tests/game/migration/run_gate1_formal_equivalence.gd -- --start-seed 471001 --seeds 1000 --round-limit 50 --replay-samples 20 --channels state,event,red_player_view,black_player_view,red_visible_event,black_visible_event,visible_error,action_preview,replay
```

The command was started against the frozen R3 files on 2026-08-19, then explicitly cancelled by the project owner before completion. Record it as cancelled and do not count it as passing evidence. For this R3 acceptance only, the owner accepts the naturally completed source-preview mutation contract plus the exact twenty-seed golden sample and the full regression set. This exception does not rewrite historical 1000-seed evidence, does not claim `completed=1000`, and does not prevent an independent reviewer from returning `revision_required` if the approved Contract still requires the full run.

- [ ] **Step 4: Run the complete formal and prototype regression set**

```powershell
$commands = @(
  'res://tests/game/architecture/run_formal_architecture_checks.gd',
  'res://tests/game/contracts/run_observer_contract_checks.gd',
  'res://tests/game/contracts/run_hidden_equivalence.gd',
  'res://tests/game/migration/run_observer_live_frame_contract.gd',
  'res://tests/game/migration/run_source_preview_independence_contract.gd',
  'res://tests/game/scenes/run_formal_scene_smoke.gd',
  'res://tests/game/scenes/run_tutorial_shell_smoke.gd',
  'res://tests/game/presentation/run_board_layout_contract.gd',
  'res://tests/game/presentation/run_board_observer_fixture.gd',
  'res://tests/prototype/run_all.gd'
)
foreach ($script in $commands) {
  & 'D:\Godot\godot.cmd' --headless --path . --script $script
  if ($LASTEXITCODE -ne 0) { throw "failed: $script" }
}
```

Expected: every command exits `0`; layout-generated snapshot paths must be restored to their frozen values before commit.

- [ ] **Step 5: Write immutable producer evidence**

The report must bind the current commit parent, all three modified/test file SHA-256 values, golden v1/v2/v3 hashes, exact start/end times, command lines, exit codes, summary counters, and `git diff --check` result. It must state `producer_verified_pending_independent_review` and must not approve Iteration 2.

- [ ] **Step 6: Commit and push the focused R3 remediation**

```powershell
git add -- tests/game/migration/gate1_channel_capture.gd tests/game/migration/source_channel_mapper.gd tests/game/migration/run_source_preview_independence_contract.gd evidence/gate2/iteration2-core-migration-remediation-r3-v1.md
git diff --cached --check
git commit -m "feat: 补全行动预览全量跨实现等价"
git push origin main
```

### Task 2: Independently approve Iteration 2 and advance the Registry

**Files:**
- Create: `evidence/gate2/iteration2-core-migration-technical-approval-r4.md`
- Create: `evidence/gate2/iteration2-core-migration-independent-qa-approval-r4.md`
- Create: `game-pipeline/loops/tools/formal_foundation_gate2_iteration_progress.py`
- Modify append-only: `game-pipeline/loops/registry/formal-foundation-gate2/event-history.yaml`
- Modify generated snapshot: `game-pipeline/loops/registry/formal-foundation-gate2/snapshot.yaml`

**Interfaces:**
- Consumes: `evidence/gate2/iteration1-completion-handoff-v1.md`, Task 1 commit, and `iteration2-core-migration-remediation-r3-v1.md`
- Produces CLI subcommand: `formal_foundation_gate2_iteration_progress.py advance-to-iteration3`; required flags are `--iteration1-handoff`, `--technical-review`, `--qa-review`, and `--candidate-commit`, using the exact paths and `git rev-parse HEAD` value shown in Step 5.
- Produces Registry state: `runtime.current_iteration: 3`, `runtime.current_state: active`, and completed Iteration 2 output bindings.

- [ ] **Step 1: Obtain an independent technical review from the approved Godot technical role**

The reviewer must use a clean detached worktree, bind the Task 1 commit and evidence hashes, rerun the source-preview contract and exact twenty-seed suite, audit the project-owner sampling exception and cancelled one-thousand-seed run without treating it as a pass, and conclude either `approved` or `revision_required`.

- [ ] **Step 2: Obtain an independent QA review from the approved QA role**

The reviewer must independently rerun the source-preview mutation, hidden equivalence, architecture, observer codecs, formal scenes, tutorial shell, board fixture/layout, and prototype aggregate. Approval must explicitly close the previous live-980 ActionPreview blind spot.

- [ ] **Step 3: Write a failing Registry transition test into the progress tool**

```python
assert snapshot["registry_snapshot"]["runtime"]["current_iteration"] == 1
assert sha256(iteration1_handoff) == recorded_iteration1_handoff_sha256
assert technical_review["conclusion"] == "approved"
assert qa_review["conclusion"] == "approved"
assert candidate_commit == git_head
```

Before implementation, running `advance-to-iteration3` must fail because the command is not yet implemented and leave both Registry files byte-identical.

- [ ] **Step 4: Implement the append-only transition**

The current Registry is still at Iteration 1, so the command must perform an ordered evidence-backed catch-up rather than skipping state. It verifies the approved Iteration 1 handoff and reviews, appends `iteration_completed` for `ITERATION-1-ARCHITECTURE`, appends `iteration_started` for `ITERATION-2-CORE-MIGRATION`, binds its reviewed migration inputs, appends `iteration_completed` for Iteration 2, then appends `iteration_started` for `ITERATION-3-TUTORIAL-VISUAL`. It binds the reviewed Iteration 1 shell deliverables, `DELIVERABLE-MIGRATION-001`, and the Iteration 2 portion of `DELIVERABLE-QA-002`, increments event sequence/revision for every event, regenerates the snapshot, and rejects duplicate application.

- [ ] **Step 5: Validate Registry and project instance**

```powershell
uv run --with 'PyYAML>=6.0,<7' python game-pipeline/loops/tools/formal_foundation_gate2_iteration_progress.py advance-to-iteration3 --iteration1-handoff evidence/gate2/iteration1-completion-handoff-v1.md --technical-review evidence/gate2/iteration2-core-migration-technical-approval-r4.md --qa-review evidence/gate2/iteration2-core-migration-independent-qa-approval-r4.md --candidate-commit (git rev-parse HEAD)
uv run --with 'PyYAML>=6.0,<7' python C:\Users\30114\.codex\plugins\cache\personal\game-production-pipeline\0.4.0-alpha.2\scripts\validate_loop_registry.py --registry-dir game-pipeline/loops/registry/formal-foundation-gate2
uv run --with 'PyYAML>=6.0,<7' python C:\Users\30114\.codex\plugins\cache\personal\game-production-pipeline\0.4.0-alpha.2\scripts\validate_project_instance.py --project-root .
```

Expected: both validators exit `0`; duplicate `advance-to-iteration3` exits non-zero without changing hashes.

- [ ] **Step 6: Commit and push governance evidence separately**

```powershell
git add -- evidence/gate2/iteration2-core-migration-technical-approval-r4.md evidence/gate2/iteration2-core-migration-independent-qa-approval-r4.md game-pipeline/loops/tools/formal_foundation_gate2_iteration_progress.py game-pipeline/loops/registry/formal-foundation-gate2/event-history.yaml game-pipeline/loops/registry/formal-foundation-gate2/snapshot.yaml
git diff --cached --check
git commit -m "feat: 完成正式核心迁移并启动教学迭代"
git push origin main
```

### Task 3: Add the formal seat-bound local session and MatchClientPort adapter

**Files:**
- Create: `scripts/game/application/formal_local_session.gd`
- Create: `scripts/game/ports/formal_match_client_port.gd`
- Create: `tests/game/application/run_formal_local_session_contract.gd`
- Modify: `tests/game/architecture/check_dependency_boundaries.gd`

**Interfaces:**
- Produces: `FormalLocalSession.create(seed_value: int, configuration: Dictionary, red_scenario: Dictionary = {}) -> RefCounted`
- Produces: `FormalLocalSession.create_red_port() -> MatchClientPort`
- Produces: `FormalLocalSession.create_black_opponent_port() -> MatchClientPort`
- Produces: `FormalMatchClientPort.publish_current() -> Dictionary`
- Preserves: `MatchClientPort` public request methods and observer-safe signal types.

- [ ] **Step 1: Write the failing two-seat isolation test**

```gdscript
var session: RefCounted = FormalLocalSession.create(471001, {"full_round_limit_hypothesis": 50})
var red_port: RefCounted = session.create_red_port()
var black_port: RefCounted = session.create_black_opponent_port()
var red_views: Array = []
var black_views: Array = []
red_port.player_view_updated.connect(func(view: Dictionary): red_views.append(view))
black_port.player_view_updated.connect(func(view: Dictionary): black_views.append(view))
assert(red_port != null and black_port != null)
assert(red_port.publish_current()["ok"])
assert(black_port.publish_current()["ok"])
var red_view: Dictionary = red_views[-1]
var black_view: Dictionary = black_views[-1]
assert(red_view["viewer_side"] == "red")
assert(black_view["viewer_side"] == "black")
assert(red_view != black_view)
```

- [ ] **Step 2: Run the test and verify RED**

```powershell
D:\Godot\godot.cmd --headless --path . --script res://tests/game/application/run_formal_local_session_contract.gd
```

Expected: parse/load failure because `FormalLocalSession` does not exist.

- [ ] **Step 3: Implement one authority state with two immutable seat bindings**

`FormalLocalSession` owns the only live FullState. Each port stores one trusted `ViewerContext`, cannot change side after construction, submits only for its bound seat, and publishes through existing codecs. Neither port exposes FullState, seed, RNG, raw events, or another port's DTO.

- [ ] **Step 4: Add negative assertions**

The test must prove a red intent cannot be submitted by the black port, a stale preview is rejected with the same observer-safe error shape, a caller cannot request an arbitrary viewer, and two simultaneous sessions do not share state.

- [ ] **Step 5: Run focused and architecture tests**

```powershell
D:\Godot\godot.cmd --headless --path . --script res://tests/game/application/run_formal_local_session_contract.gd
D:\Godot\godot.cmd --headless --path . --script res://tests/game/architecture/run_formal_architecture_checks.gd
D:\Godot\godot.cmd --headless --path . --script res://tests/game/contracts/run_observer_contract_checks.gd
```

Expected: all exit `0` and architecture scanner reports no application dependency on tutorial, challenge, LAN, AI, or prototype.

- [ ] **Step 6: Commit and push**

```powershell
git add -- scripts/game/application/formal_local_session.gd scripts/game/ports/formal_match_client_port.gd tests/game/application/run_formal_local_session_contract.gd tests/game/architecture/check_dependency_boundaries.gd
git commit -m "feat: 建立正式本地双席会话端口"
git push origin main
```

### Task 4: Add Resource-driven catalog and local progress storage

**Files:**
- Create: `scripts/game/frontend/level_definition.gd`
- Create: `scripts/game/frontend/level_catalog.gd`
- Create: `scripts/game/frontend/level_progress_store.gd`
- Create: `resources/game/levels/level_catalog.tres`
- Create: `resources/game/levels/definitions/t0.tres` through `t10.tres`
- Create: `resources/game/levels/definitions/c1.tres` through `c3.tres`
- Create: `tests/game/frontend/run_level_catalog_contract.gd`
- Create: `tests/game/frontend/run_level_progress_contract.gd`

**Interfaces:**
- Produces: `LevelDefinition.is_valid_definition() -> bool`
- Produces: `LevelCatalog.ordered_levels(category: String) -> Array[LevelDefinition]`
- Produces: `LevelCatalog.find_level(level_id: String) -> LevelDefinition`
- Produces: `LevelProgressStore.load_from(path: String = "user://level_progress.cfg") -> Dictionary`
- Produces: `LevelProgressStore.mark_completed(level_id: String) -> Error`
- Produces: `LevelProgressStore.mark_skipped(level_id: String) -> Error`
- Produces: `LevelProgressStore.clear_tutorial() -> Error`
- Produces: `LevelProgressStore.clear_all() -> Error`

- [ ] **Step 1: Write failing catalog assertions**

```gdscript
assert(catalog.ordered_levels("tutorial").map(func(level): return level.level_id) == ["T0","T1","T2","T3","T4","T5","T6","T7","T8","T9","T10"])
assert(catalog.ordered_levels("challenge").map(func(level): return level.level_id) == ["C1","C2","C3"])
assert(catalog.find_level("missing") == null)
```

- [ ] **Step 2: Run the catalog test and verify RED**

```powershell
D:\Godot\godot.cmd --headless --path . --script res://tests/game/frontend/run_level_catalog_contract.gd
```

Expected: load failure for missing Resource classes or catalog.

- [ ] **Step 3: Implement strict read-only definitions**

Validation accepts only IDs `T0`–`T10` and `C1`–`C3`, categories `tutorial/challenge`, allow-listed `res://scenes/game/` scene paths, unique order values, valid prerequisite IDs, and non-null authority/presentation resources when required. C1–C3 have no unlock prerequisite; T1–T10 each require the previous tutorial ID.

- [ ] **Step 4: Write failing progress corruption tests**

Create a temporary ConfigFile with schema `999`, unknown ID `X9`, valid completed `T2`, and selected category `challenge`. Loading must keep `T2` only if T0/T1 are also present, ignore `X9`, reset unknown schema data to an empty valid snapshot, and never throw.

- [ ] **Step 5: Implement atomic ConfigFile persistence**

For the method's concrete `path` argument, write to `path + ".tmp"`, verify save returns `OK`, then replace `path`. Persist only schema version, completed IDs, skipped tutorial IDs, last category/level, and public checkpoint IDs. No FullState, seed, RNG, hidden data, or replay fields are accepted.

- [ ] **Step 6: Run catalog and progress tests**

```powershell
D:\Godot\godot.cmd --headless --path . --script res://tests/game/frontend/run_level_catalog_contract.gd
D:\Godot\godot.cmd --headless --path . --script res://tests/game/frontend/run_level_progress_contract.gd
```

- [ ] **Step 7: Commit and push**

```powershell
git add -- scripts/game/frontend resources/game/levels tests/game/frontend
git commit -m "feat: 建立关卡目录与本地进度资源"
git push origin main
```

### Task 5: Build the preset main menu and level-select scenes

**Files:**
- Create: `scripts/game/frontend/front_end_navigator.gd`
- Create: `scripts/game/frontend/main_menu.gd`
- Create: `scripts/game/frontend/level_select.gd`
- Create: `scripts/game/frontend/level_card.gd`
- Create: `scenes/game/frontend/main_menu.tscn`
- Create: `scenes/game/frontend/level_select.tscn`
- Create: `scenes/game/frontend/level_card.tscn`
- Modify: `scenes/prototype/network/lan_lobby.tscn`
- Modify: `scripts/prototype/network/lan_lobby.gd`
- Create: `tests/game/frontend/run_frontend_navigation_contract.gd`
- Create: `tests/game/frontend/run_frontend_layout_contract.gd`

**Interfaces:**
- Produces signal: `FrontEndNavigator.navigation_failed(message_key: String)`
- Produces: `FrontEndNavigator.open_main_menu() -> void`
- Produces: `FrontEndNavigator.open_lan_lobby() -> void`
- Produces: `FrontEndNavigator.open_level_select() -> void`
- Produces: `FrontEndNavigator.open_level(level: LevelDefinition) -> void`
- Produces signal: `LevelCard.play_requested(level_id: String)`

- [ ] **Step 1: Write a failing preset-tree and route test**

The test instantiates both scenes and asserts every node path from the approved spec, exactly fourteen cards after catalog binding, button minimum height at least `44`, and routes `LanButton` to `lan_lobby.tscn` and `LevelModeButton` to `level_select.tscn` through a fake navigator.

- [ ] **Step 2: Run the test and verify RED**

```powershell
D:\Godot\godot.cmd --headless --path . --script res://tests/game/frontend/run_frontend_navigation_contract.gd
```

Expected: missing scene failure.

- [ ] **Step 3: Build the scenes with Containers and preset nodes**

Use `res://resources/game/ui/formal_graybox_theme.tres`, Full Rect roots, SafeMargin, Center/VBox for the menu, TabContainer plus ScrollContainer/GridContainer for the catalog, and one prebuilt `ConfirmationDialog`. Only `LevelCard` instances are generated from the fixed catalog.

- [ ] **Step 4: Implement guarded scene transitions**

Reject a second transition while one is pending, verify `ResourceLoader.exists(scene_path)`, use `change_scene_to_file`, emit `navigation_failed("frontend.scene_unavailable")` on failure, and restore the previous button's enabled state. LAN's new return button must invoke the existing disconnect path before navigating to the main menu.

- [ ] **Step 5: Run navigation and three-resolution layout tests**

```powershell
D:\Godot\godot.cmd --headless --path . --script res://tests/game/frontend/run_frontend_navigation_contract.gd
D:\Godot\godot.cmd --headless --path . --script res://tests/game/frontend/run_frontend_layout_contract.gd -- --resolutions 960x540,1280x720,1920x1080
```

Expected: all primary buttons remain inside the visible rect; keyboard focus starts at the main action and returns to the previously selected card.

- [ ] **Step 6: Commit and push**

```powershell
git add -- scripts/game/frontend scenes/game/frontend scenes/prototype/network/lan_lobby.tscn scripts/prototype/network/lan_lobby.gd tests/game/frontend
git commit -m "feat: 建立游戏首界面与关卡选择界面"
git push origin main
```

### Task 6: Add trusted scenario bootstrap and a real formal tutorial port

**Files:**
- Create: `scripts/game/domain/scenario_bootstrap.gd`
- Create: `scripts/game/application/tutorial_match_factory.gd`
- Modify: `scripts/game/application/tutorial_scenario_definition.gd`
- Modify: `scripts/game/application/application_host.gd`
- Modify: `scenes/game/tutorial/tutorial_level.tscn`
- Create: `tests/game/tutorial/run_tutorial_authority_contract.gd`

**Interfaces:**
- Produces: `ScenarioBootstrap.create_validated(base_state: Dictionary, scenario: Dictionary) -> Dictionary`
- Produces: `TutorialMatchFactory.create_port(definition: TutorialScenarioDefinition) -> MatchClientPort`
- Produces: `ApplicationHost.start_trusted_tutorial() -> bool`

- [ ] **Step 1: Write a failing authority bootstrap test**

```gdscript
var port: RefCounted = TutorialMatchFactory.create_port(load("res://resources/game/tutorials/authority/t0.tres"))
assert(port != null)
var published_views: Array = []
port.player_view_updated.connect(func(view: Dictionary): published_views.append(view))
assert(port.publish_current()["ok"])
var last_view: Dictionary = published_views[-1]
assert(last_view["viewer_side"] == "red")
assert(not last_view.has("rng"))
assert(not last_view.has("initial_flag_positions"))
```

- [ ] **Step 2: Run the test and verify RED**

```powershell
D:\Godot\godot.cmd --headless --path . --script res://tests/game/tutorial/run_tutorial_authority_contract.gd
```

- [ ] **Step 3: Implement strict pre-match scenario validation**

Scenario bootstrap may run only before action index `0`. It validates board bounds, unique occupied cells, known piece IDs/types/sides, wall state enum, exactly allowed flag records, active side, round limit, and fixed scenario ID. It returns a deep copy and never accepts Callable, Object, Resource, NodePath, unknown field, raw event, replay, or RNG override.

- [ ] **Step 4: Bind the formal port through ApplicationHost**

`TutorialLevel` calls `start_trusted_tutorial()` after exported authority Resource validation. All subsequent preview, prepare, confirm, cancel, restart, and skip calls continue through `MatchClientPort`; TutorialDirector remains unable to access the authority Resource type.

- [ ] **Step 5: Add hidden-boundary and invalid-scenario assertions**

Tests must reject duplicate piece cells, out-of-board coordinates, caller-provided seed override, mismatched seat, unknown allowed preview, and any Scenario containing `full_state`, `rng`, `raw_events`, or another viewer.

- [ ] **Step 6: Run authority, architecture, codec, and tutorial-shell tests**

```powershell
D:\Godot\godot.cmd --headless --path . --script res://tests/game/tutorial/run_tutorial_authority_contract.gd
D:\Godot\godot.cmd --headless --path . --script res://tests/game/architecture/run_formal_architecture_checks.gd
D:\Godot\godot.cmd --headless --path . --script res://tests/game/contracts/run_observer_contract_checks.gd
D:\Godot\godot.cmd --headless --path . --script res://tests/game/scenes/run_tutorial_shell_smoke.gd
```

- [ ] **Step 7: Commit and push**

```powershell
git add -- scripts/game/domain/scenario_bootstrap.gd scripts/game/application/tutorial_match_factory.gd scripts/game/application/tutorial_scenario_definition.gd scripts/game/application/application_host.gd scenes/game/tutorial/tutorial_level.tscn tests/game/tutorial/run_tutorial_authority_contract.gd
git commit -m "feat: 接入正式教学权威局面端口"
git push origin main
```

### Task 7: Implement T0–T10 resources and tutorial progression

**Files:**
- Modify: `scripts/game/tutorial/tutorial_director.gd`
- Modify: `scripts/game/tutorial/tutorial_presentation_track.gd`
- Modify: `scripts/game/tutorial/tutorial_overlay.gd`
- Modify: `scenes/game/ui/tutorial_overlay.tscn`
- Create: `resources/game/tutorials/authority/t0.tres` through `t10.tres`
- Create: `resources/game/tutorials/presentation/t0.tres` through `t10.tres`
- Create: `tests/game/tutorial/run_all_tutorial_levels.gd`
- Create: `tests/game/tutorial/run_t6_sacrifice_cancel_contract.gd`
- Create: `tests/game/tutorial/run_tutorial_hidden_equivalence.gd`

**Interfaces:**
- Produces: `TutorialDirector.configure(level_id: String, presentation_track: TutorialPresentationTrack) -> bool`
- Produces: `TutorialDirector.get_public_checkpoint_id() -> String`
- Produces signal: `TutorialDirector.level_completed(level_id: String)`
- Produces signal: `TutorialDirector.level_failed(level_id: String, public_reason_key: String)`
- Consumes only: PlayerView, VisibleEvent, VisibleError, ActionPreview, prepared-action ID, cancel/restart/skip authority results.

- [ ] **Step 1: Write failing catalog-to-resource coverage assertions**

The test loads every T0–T10 LevelDefinition, resolves both authority and presentation Resources, checks matching IDs and bound seat, and ensures all presentation trigger keys are observer-public message keys.

- [ ] **Step 2: Run the test and verify RED**

```powershell
D:\Godot\godot.cmd --headless --path . --script res://tests/game/tutorial/run_all_tutorial_levels.gd
```

Expected: missing resources or incomplete progression.

- [ ] **Step 3: Encode the eleven approved chapters exactly**

Use the titles, prompts, fixed positions, intended actions, checkpoints, failure conditions, and completion conditions from `docs/design/tutorial/veilfront-ftue-formal-level-design-v2.md`. Each Resource has a unique stable ID; authority files contain no display prose, and presentation files contain no coordinates or hidden facts not present in observer DTOs.

- [ ] **Step 4: Implement event-driven progression**

The Director maps only visible message keys, prepared IDs, and authority resolutions to the next public step. It emits completion once, ignores late events after completion, and resets by requesting a new authority session rather than mutating nodes or state.

- [ ] **Step 5: Implement and test the exact T6 cancel sequence**

```gdscript
var before_action_index: int = int(latest_player_view["action_index"])
open_sacrifice_preview()
cancel_prepared_action()
assert(director.get_public_checkpoint_id() == "t6_cancel_verified")
assert(latest_player_view["pieces"].any(func(piece: Dictionary): return piece.get("piece_id", "") == "red-advisor-2"))
assert(int(latest_player_view["action_index"]) == before_action_index)
request_continue()
confirm_sacrifice_preview()
assert(director.get_public_checkpoint_id() == "t6_candidate_quiz")
```

- [ ] **Step 6: Run all tutorial and hidden-equivalence tests**

```powershell
D:\Godot\godot.cmd --headless --path . --script res://tests/game/tutorial/run_all_tutorial_levels.gd
D:\Godot\godot.cmd --headless --path . --script res://tests/game/tutorial/run_t6_sacrifice_cancel_contract.gd
D:\Godot\godot.cmd --headless --path . --script res://tests/game/tutorial/run_tutorial_hidden_equivalence.gd
D:\Godot\godot.cmd --headless --path . --script res://tests/game/scenes/run_tutorial_shell_smoke.gd
```

- [ ] **Step 7: Commit and push in two focused commits**

```powershell
git add -- resources/game/tutorials resources/game/levels/definitions/t*.tres tests/game/tutorial/run_all_tutorial_levels.gd
git commit -m "feat: 配置十一章新手教学关卡资源"
git push origin main
git add -- scripts/game/tutorial scenes/game/ui/tutorial_overlay.tscn tests/game/tutorial/run_t6_sacrifice_cancel_contract.gd tests/game/tutorial/run_tutorial_hidden_equivalence.gd
git commit -m "feat: 实现新手教学事件驱动流程"
git push origin main
```

### Task 8: Migrate C1–C3 and implement the limited challenge opponent

**Files:**
- Create: `scripts/game/challenge/challenge_definition.gd`
- Create: `scripts/game/challenge/challenge_opponent_policy.gd`
- Create: `scripts/game/challenge/challenge_level.gd`
- Create: `scenes/game/challenge/challenge_level.tscn`
- Create: `resources/game/challenges/c1.tres`
- Create: `resources/game/challenges/c2.tres`
- Create: `resources/game/challenges/c3.tres`
- Create: `tests/game/challenge/run_challenge_initial_state_contract.gd`
- Create: `tests/game/challenge/run_challenge_opponent_fairness.gd`
- Create: `tests/game/challenge/run_challenge_determinism.gd`

**Interfaces:**
- Produces: `ChallengeOpponentPolicy.choose_preview(player_view: Dictionary, previews: Array, decision_seed: int) -> String`
- Produces: `ChallengeLevel.start_challenge(definition: ChallengeDefinition) -> bool`
- Consumes: black `MatchClientPort` observer signals and ActionPreview arrays only.

- [ ] **Step 1: Write failing initial-state tests for all three challenges**

```gdscript
assert(enemy_types("C1") == ["elephant"])
assert(enemy_types("C2") == ["elephant", "elephant"])
assert(enemy_types("C3") == ["horse", "horse"])
assert(enemy_positions("C1") == [[5,16]])
assert(enemy_positions("C2") == [[3,16],[7,16]])
assert(enemy_positions("C3") == [[3,16],[7,16]])
```

The test-local helpers `enemy_types(level_id)` and `enemy_positions(level_id)` start the ChallengeDefinition through the formal session, capture the red PlayerView, and filter visible black pieces. The red army and five wall-line pawns must match the old approved challenge intent; flags are absent and the playable area ends at Y=16.

- [ ] **Step 2: Run the state test and verify RED**

```powershell
D:\Godot\godot.cmd --headless --path . --script res://tests/game/challenge/run_challenge_initial_state_contract.gd
```

- [ ] **Step 3: Implement the challenge opponent as a pure observer policy**

The function copies input DTOs, rejects non-black views, filters only supplied `KNOWN_LEGAL`/`TENTATIVE` preview records, ranks threatened-piece moves first, then safe captures, then safe non-captures, then remaining supplied candidates, and breaks ties with its challenge-local deterministic RNG. Threat and safety are lightweight preferences computed only from the bound black PlayerView and supplied previews; legality always comes from the supplied previews, so this policy cannot become a second rule engine. It never imports domain, projection, prototype, old level-test, or general AI scripts.

- [ ] **Step 4: Add fairness mutations**

Create two black PlayerViews with byte-identical public fields but different hidden authority facts in the test harness. The chosen preview ID and timing bucket must remain identical. Adding `seed`, hidden horse, undiscovered flag position, elephant source ID, or FullState digest to the policy input must be rejected.

- [ ] **Step 5: Add deterministic full-challenge runs**

Run C1–C3 for seeds `471001..471020` twice. Compare opponent preview ID sequence, public event digest, terminal reason, winner, and final observer replay digest. Each pair must match exactly; every run must terminate by enemy cleared, red general death, or fifty full rounds.

- [ ] **Step 6: Run challenge, architecture, and formal-rule regressions**

```powershell
D:\Godot\godot.cmd --headless --path . --script res://tests/game/challenge/run_challenge_initial_state_contract.gd
D:\Godot\godot.cmd --headless --path . --script res://tests/game/challenge/run_challenge_opponent_fairness.gd
D:\Godot\godot.cmd --headless --path . --script res://tests/game/challenge/run_challenge_determinism.gd
D:\Godot\godot.cmd --headless --path . --script res://tests/game/architecture/run_formal_architecture_checks.gd
D:\Godot\godot.cmd --headless --path . --script res://tests/prototype/run_all.gd
```

- [ ] **Step 7: Commit and push**

```powershell
git add -- scripts/game/challenge scenes/game/challenge resources/game/challenges resources/game/levels/definitions/c*.tres tests/game/challenge
git commit -m "feat: 迁移三关有限规则对手挑战"
git push origin main
```

### Task 9: Integrate the main scene, progress flow, and full graybox regression

**Files:**
- Modify: `project.godot`
- Modify: `tests/game/scenes/run_formal_scene_smoke.gd`
- Create: `tests/game/frontend/run_demo_entry_flow.gd`
- Create: `evidence/gate2/iteration3-main-menu-and-level-mode-technical-v1.md`
- Create: `docs/playtest/demo-graybox-guide.md`

**Interfaces:**
- Sets: `run/main_scene="res://scenes/game/frontend/main_menu.tscn"`
- Verifies complete routes: MainMenu→LAN→MainMenu and MainMenu→LevelSelect→Level→LevelSelect→MainMenu.

- [ ] **Step 1: Write the failing complete-entry flow test**

The test loads the project main scene, asserts menu focus, enters LevelSelect, starts T0, exits back, starts C1, exits back, returns to MainMenu, enters LAN, invokes LAN return, and confirms no duplicate scene transition or leaked session node remains.

- [ ] **Step 2: Run the test and verify RED before changing `project.godot`**

```powershell
D:\Godot\godot.cmd --headless --path . --script res://tests/game/frontend/run_demo_entry_flow.gd
```

Expected: main scene is still the LAN lobby or frontend route is incomplete.

- [ ] **Step 3: Change only the main scene setting and update formal scene coverage**

Add MainMenu, LevelSelect, LevelCard, TutorialLevel, and ChallengeLevel to the scene smoke list. Preserve existing Input Map and stretch settings.

- [ ] **Step 4: Run the full entry, tutorial, challenge, formal, LAN, and prototype suite**

```powershell
$commands = @(
  'res://tests/game/frontend/run_demo_entry_flow.gd',
  'res://tests/game/frontend/run_frontend_navigation_contract.gd',
  'res://tests/game/frontend/run_frontend_layout_contract.gd',
  'res://tests/game/tutorial/run_all_tutorial_levels.gd',
  'res://tests/game/tutorial/run_t6_sacrifice_cancel_contract.gd',
  'res://tests/game/tutorial/run_tutorial_hidden_equivalence.gd',
  'res://tests/game/challenge/run_challenge_initial_state_contract.gd',
  'res://tests/game/challenge/run_challenge_opponent_fairness.gd',
  'res://tests/game/challenge/run_challenge_determinism.gd',
  'res://tests/game/architecture/run_formal_architecture_checks.gd',
  'res://tests/game/contracts/run_observer_contract_checks.gd',
  'res://tests/game/contracts/run_hidden_equivalence.gd',
  'res://tests/game/scenes/run_formal_scene_smoke.gd',
  'res://tests/game/scenes/run_tutorial_shell_smoke.gd',
  'res://tests/game/presentation/run_board_layout_contract.gd',
  'res://tests/game/presentation/run_board_observer_fixture.gd',
  'res://tests/prototype/network/run_lan_host_session.gd',
  'res://tests/prototype/network/run_lan_network_integration.gd',
  'res://tests/prototype/network/run_lan_lobby_scene.gd',
  'res://tests/prototype/run_all.gd'
)
foreach ($script in $commands) {
  & 'D:\Godot\godot.cmd' --headless --path . --script $script
  if ($LASTEXITCODE -ne 0) { throw "failed: $script" }
}
```

- [ ] **Step 5: Produce Iteration 3 technical evidence**

Bind the exact commit, Godot version, fourteen LevelDefinition hashes, all scenario/track/challenge Resource hashes, route and resolution results, hidden-equivalence counters, challenge determinism counters, LAN regression, and `git diff --check`. Mark the result `producer_verified_pending_independent_review`.

- [ ] **Step 6: Commit and push the integration**

```powershell
git add -- project.godot tests/game/scenes/run_formal_scene_smoke.gd tests/game/frontend/run_demo_entry_flow.gd evidence/gate2/iteration3-main-menu-and-level-mode-technical-v1.md docs/playtest/demo-graybox-guide.md
git commit -m "feat: 接入Demo首界面与完整关卡模式"
git push origin main
```

### Task 10: Independent Iteration 3 review and handoff

**Files:**
- Create: `evidence/gate2/iteration3-main-menu-and-level-mode-technical-review-v1.md`
- Create: `evidence/gate2/iteration3-main-menu-and-level-mode-independent-qa-v1.md`
- Modify append-only: `game-pipeline/loops/registry/formal-foundation-gate2/event-history.yaml`
- Modify generated snapshot: `game-pipeline/loops/registry/formal-foundation-gate2/snapshot.yaml`

**Interfaces:**
- Consumes: all Task 3–9 commits and technical evidence.
- Produces: reviewed `DELIVERABLE-TUTORIAL-001`, updated `DELIVERABLE-PRESENTATION-001`, and the Iteration 3 portion of `DELIVERABLE-QA-002`.

- [ ] **Step 1: Run technical review from a clean detached worktree**

Check scene/resource mapping, preset-node policy, session/port ownership, no prototype dependency from formal tutorial/challenge code, fixed AI scope, main scene routing, and all focused commands.

- [ ] **Step 2: Run independent QA from a separate clean detached worktree**

Execute every Task 9 command, manually inspect three target resolutions, play T6 cancellation, complete at least T0/T3/T6/T9/T10 and C1/C2/C3, and audit PlayerView-only opponent inputs.

- [ ] **Step 3: Return any failed requirement to its owning task**

Frontend/layout defects return to Task 5 or 9; tutorial logic and leaks return to Task 6 or 7; challenge fairness/determinism returns to Task 8; formal session boundary returns to Task 3. Do not patch production code from the QA role.

- [ ] **Step 4: Bind approved reviews and close Iteration 3 only after both approve**

Append review artifact events, Iteration 3 completion, and Iteration 4 start. Validate Registry and project instance with the same validators from Task 2. This transition authorizes independent GATE-2 review but does not approve GATE-2.

- [ ] **Step 5: Commit and push review evidence separately**

```powershell
git add -- evidence/gate2/iteration3-main-menu-and-level-mode-technical-review-v1.md evidence/gate2/iteration3-main-menu-and-level-mode-independent-qa-v1.md game-pipeline/loops/registry/formal-foundation-gate2/event-history.yaml game-pipeline/loops/registry/formal-foundation-gate2/snapshot.yaml
git commit -m "feat: 完成首界面与关卡模式独立验收"
git push origin main
```
