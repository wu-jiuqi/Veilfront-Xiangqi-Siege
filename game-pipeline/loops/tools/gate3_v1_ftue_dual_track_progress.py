#!/usr/bin/env python3
"""Register the owner-approved dual-track FTUE producer integration outputs."""

from __future__ import annotations

import copy
import uuid
from typing import Any

from gate3_v1_iteration1_progress import (
    HISTORY_PATH,
    LOOP_ID,
    PROJECT_ROOT,
    SNAPSHOT_PATH,
    SYSTEMS_ACTOR,
    add_event,
    event_digest,
    load_yaml,
    now_china,
    replace_output,
    sha256_file,
    write_pair,
)


HANDOFF_URI = "game-pipeline/loops/evidence/FTUE-DUAL-TRACK-IMPLEMENTATION-HANDOFF-v1.md"
VERSION = "g3-iteration2-ftue-dual-track-producer-v1"

CONTENT_PATHS = [
    HANDOFF_URI,
    "game-pipeline/approvals/production-scope-exception-ftue-dual-track-6e2d0f83914e.yaml",
    "docs/design/tutorial/veilfront-ftue-content-coverage-and-ux-proposal-v1.md",
    "resources/game/tutorials/tutorial_module_catalog.tres",
    "resources/game/tutorials/authority/p0.tres",
    "resources/game/tutorials/authority/b1.tres",
    "resources/game/tutorials/authority/b2.tres",
    "resources/game/tutorials/authority/b3.tres",
    "resources/game/tutorials/authority/t8-r.tres",
    "resources/game/tutorials/authority/t9-c.tres",
    "resources/game/tutorials/authority/t10-e.tres",
    "resources/game/tutorials/presentation/t0.tres",
    "resources/game/tutorials/presentation/t10.tres",
    "scripts/game/tutorial/tutorial_module_catalog.gd",
    "scripts/game/tutorial/tutorial_progress_store.gd",
    "scripts/game/tutorial/tutorial_level.gd",
    "tests/game/tutorial/run_all_tutorial_flows.gd",
    "tests/game/tutorial/run_tutorial_curriculum_contract.gd",
    "tests/game/tutorial/run_tutorial_t10_solution_variants_contract.gd",
]

UIUX_PATHS = [
    HANDOFF_URI,
    "docs/ui/gate3-ui-foundation-v1.md",
    "scenes/game/ui/ui_motion_button.tscn",
    "scenes/game/ui/ui_motion_button_primary.tscn",
    "scenes/game/ui/ui_motion_button_secondary.tscn",
    "scenes/game/ui/ui_motion_button_danger.tscn",
    "scenes/game/ui/ui_motion_button_confirm.tscn",
    "resources/game/levels/level_catalog.tres",
    "scenes/game/frontend/level_select.tscn",
    "scenes/game/tutorial/tutorial_level.tscn",
    "scenes/game/ui/level_guide_panel.tscn",
    "scenes/game/ui/tutorial_codex.tscn",
    "scenes/game/ui/tutorial_context_reminder.tscn",
    "scripts/game/frontend/level_select.gd",
    "scripts/game/presentation/ui/level_guide_panel.gd",
    "scripts/game/tutorial/tutorial_codex.gd",
    "scripts/game/tutorial/tutorial_context_reminder_policy.gd",
    "tests/game/ui/run_gate3_ui_foundation_contract.gd",
    "tests/game/frontend/run_level_select_ui_contract.gd",
    "tests/game/tutorial/run_tutorial_layout_contract.gd",
    "tests/game/tutorial/run_tutorial_codex_contract.gd",
    "tests/game/tutorial/run_tutorial_context_reminder_contract.gd",
]

OUTPUTS: tuple[dict[str, Any], ...] = (
    {
        "deliverable_id": "DELIVERABLE-CONTENT-G3-001",
        "artifact_type": "tutorial-and-challenge-content-wave-one-plus-approved-dual-track-ftue",
        "manifest_paths": CONTENT_PATHS,
    },
    {
        "deliverable_id": "DELIVERABLE-UIUX-G3-001",
        "artifact_type": "unified-desktop-ui-interaction-baseline-plus-dual-track-ftue",
        "manifest_paths": UIUX_PATHS,
    },
)


def main() -> None:
    snapshot_doc = load_yaml(SNAPSHOT_PATH)
    history_doc = load_yaml(HISTORY_PATH)
    snapshot = snapshot_doc["registry_snapshot"]
    history = history_doc["event_history"]
    runtime = snapshot["runtime"]
    if snapshot["identity"]["loop_instance_id"] != LOOP_ID:
        raise RuntimeError("loop identity mismatch")
    if runtime["current_state"] != "active" or runtime["current_iteration"] != 2:
        raise RuntimeError("FTUE integration registration requires active iteration 2")
    if runtime["last_event_digest"] != history[-1]["integrity"]["event_digest"]:
        raise RuntimeError("snapshot/history tail mismatch")
    if any(
        output.get("artifact", {}).get("version") == VERSION
        for output in snapshot["resources"]["outputs"]
    ):
        raise RuntimeError("dual-track FTUE outputs are already registered")
    if not any(
        item.get("input_slot_id") == "INPUT-FTUE-DUAL-TRACK-EXCEPTION-001"
        for item in snapshot["resources"]["inputs"]
    ):
        raise RuntimeError("owner-approved FTUE scope exception is not bound")
    for definition in OUTPUTS:
        for relative_path in definition["manifest_paths"]:
            if not (PROJECT_ROOT / relative_path).is_file():
                raise RuntimeError(f"FTUE integration artifact missing: {relative_path}")

    occurred_at = now_china()
    correlation_id = str(uuid.uuid4())
    handoff_digest = sha256_file(PROJECT_ROOT / HANDOFF_URI)
    for definition in OUTPUTS:
        before = next(
            (
                copy.deepcopy(output)
                for output in snapshot["resources"]["outputs"]
                if output.get("deliverable_id") == definition["deliverable_id"]
            ),
            None,
        )
        output = {
            "deliverable_id": definition["deliverable_id"],
            "artifact": {
                "artifact_id": (
                    "artifact:veilfront-xiangqi-siege:"
                    f"{definition['deliverable_id'].lower()}@{VERSION}"
                ),
                "artifact_type": definition["artifact_type"],
                "version": VERSION,
                "uri": HANDOFF_URI,
                "digest": {"algorithm": "sha256", "value": handoff_digest},
                "manifest_paths": definition["manifest_paths"],
            },
            "produced_in_iteration": 2,
            "lifecycle_status": "producer_integrated_awaiting_independent_qa",
            "registered_by_event_id": "pending",
        }
        event = add_event(
            snapshot,
            history,
            "core.output_registered",
            SYSTEMS_ACTOR,
            {
                "deliverable_id": definition["deliverable_id"],
                "before": before,
                "after": output,
            },
            definition["manifest_paths"],
            correlation_id,
            f"register-{definition['deliverable_id'].lower()}-dual-track-ftue",
            occurred_at,
        )
        output["registered_by_event_id"] = event["event_id"]
        event["payload"]["after"]["registered_by_event_id"] = event["event_id"]
        event["integrity"]["event_digest"] = event_digest(event)
        runtime["last_event_digest"] = event["integrity"]["event_digest"]
        replace_output(snapshot, output)

    write_pair(snapshot_doc, history_doc)
    print(
        "GATE3_FTUE_DUAL_TRACK_PROGRESS_APPLIED "
        f"state={runtime['current_state']} iteration={runtime['current_iteration']} "
        f"sequence={runtime['last_event_sequence']} revision={runtime['record_revision']}"
    )


if __name__ == "__main__":
    main()
