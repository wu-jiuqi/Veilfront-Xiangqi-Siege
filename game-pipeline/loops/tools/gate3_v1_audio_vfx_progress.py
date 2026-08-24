#!/usr/bin/env python3
"""Register Iteration 2 Audio/VFX producer integration without advancing GATE-3."""

from __future__ import annotations

import copy
import uuid
from typing import Any

from gate3_v1_iteration1_progress import (
    LOOP_ID,
    PROJECT_ROOT,
    SNAPSHOT_PATH,
    HISTORY_PATH,
    TECH_ACTOR,
    VISUAL_ACTOR,
    add_event,
    event_digest,
    load_yaml,
    now_china,
    replace_output,
    sha256_file,
    write_pair,
)


HANDOFF_URI = "evidence/gate3/audio-vfx-mainline-integration-v1.md"
VERSION = "g3-iteration2-producer-integrated-v1"

OUTPUTS: tuple[dict[str, Any], ...] = (
    {
        "deliverable_id": "DELIVERABLE-AUDIO-G3-001",
        "artifact_type": "observer-safe-sfx-system-and-core-cues",
        "actor": TECH_ACTOR,
        "manifest_paths": [
            HANDOFF_URI,
            "docs/audio/gate3-sfx-producer-handoff-v1.md",
            "docs/audio/sfx-source-license-register-v1.md",
            "resources/game/audio/sfx_catalog.tres",
            "default_bus_layout.tres",
            "scenes/game/audio/audio_root.tscn",
            "scenes/game/audio/board_audio_emitter_pool.tscn",
            "scenes/game/presentation/match_feedback_coordinator.tscn",
            "scenes/game/presentation/board_feedback_layer.tscn",
            "scripts/game/audio/observer_audio_policy.gd",
            "scripts/game/audio/audio_root.gd",
            "scripts/game/presentation/match_feedback_coordinator.gd",
            "scenes/game/match/match_screen.tscn",
            "scenes/game/match/online_match_screen.tscn",
            "tests/game/audio/run_audio_runtime_contract.gd",
            "tests/game/presentation/run_match_feedback_integration_contract.gd",
        ],
    },
    {
        "deliverable_id": "DELIVERABLE-VFX-G3-001",
        "artifact_type": "observer-safe-2d-vfx-system-and-core-effects",
        "actor": VISUAL_ACTOR,
        "manifest_paths": [
            HANDOFF_URI,
            "evidence/gate3/vfx/vfx-producer-handoff-v1.md",
            "resources/game/vfx/vfx_catalog.tres",
            "scenes/game/vfx/vfx_root.tscn",
            "scenes/game/presentation/board_feedback_layer.tscn",
            "scenes/game/presentation/match_feedback_coordinator.tscn",
            "scripts/game/vfx/observer_vfx_policy.gd",
            "scripts/game/vfx/vfx_director.gd",
            "scripts/game/presentation/match_feedback_coordinator.gd",
            "scenes/game/match/board/board_viewport.tscn",
            "scenes/game/match/match_screen.tscn",
            "scenes/game/match/online_match_screen.tscn",
            "tests/game/vfx/run_vfx_scene_smoke.gd",
            "tests/game/presentation/run_board_feedback_layer_contract.gd",
            "tests/game/presentation/run_match_feedback_integration_contract.gd",
        ],
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
        raise RuntimeError("Audio/VFX integration registration requires active iteration 2")
    if runtime["last_event_digest"] != history[-1]["integrity"]["event_digest"]:
        raise RuntimeError("snapshot/history tail mismatch")
    if any(
        output.get("artifact", {}).get("version") == VERSION
        for output in snapshot["resources"]["outputs"]
    ):
        raise RuntimeError("Audio/VFX integration outputs are already registered")

    required_paths: list[str] = []
    for definition in OUTPUTS:
        required_paths.extend(definition["manifest_paths"])
    for relative_path in dict.fromkeys(required_paths):
        if not (PROJECT_ROOT / relative_path).is_file():
            raise RuntimeError(f"integration artifact missing: {relative_path}")

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
            "lifecycle_status": "producer_integrated",
            "registered_by_event_id": "pending",
        }
        event = add_event(
            snapshot,
            history,
            "core.output_registered",
            definition["actor"],
            {
                "deliverable_id": definition["deliverable_id"],
                "before": before,
                "after": output,
            },
            definition["manifest_paths"],
            correlation_id,
            f"register-{definition['deliverable_id'].lower()}-producer-integration",
            occurred_at,
        )
        output["registered_by_event_id"] = event["event_id"]
        event["payload"]["after"]["registered_by_event_id"] = event["event_id"]
        event["integrity"]["event_digest"] = event_digest(event)
        runtime["last_event_digest"] = event["integrity"]["event_digest"]
        replace_output(snapshot, output)

    write_pair(snapshot_doc, history_doc)
    print(
        "GATE3_AUDIO_VFX_PROGRESS_APPLIED "
        f"state={runtime['current_state']} iteration={runtime['current_iteration']} "
        f"sequence={runtime['last_event_sequence']} revision={runtime['record_revision']}"
    )


if __name__ == "__main__":
    main()

