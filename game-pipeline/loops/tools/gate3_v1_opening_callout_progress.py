#!/usr/bin/env python3
"""Register the Iteration 2 opening SFX and callout/special VFX integration update."""

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


HANDOFF_URI = "evidence/gate3/opening-sfx-and-callout-vfx-integration-v1.md"
VERSION = "g3-iteration2-producer-integrated-v2"

OUTPUTS: tuple[dict[str, Any], ...] = (
    {
        "deliverable_id": "DELIVERABLE-AUDIO-G3-001",
        "artifact_type": "observer-safe-sfx-system-and-core-cues",
        "actor": TECH_ACTOR,
        "manifest_paths": [
            HANDOFF_URI,
            "docs/audio/generate_original_sfx_v1.ps1",
            "docs/audio/sfx-source-license-register-v1.md",
            "resources/game/audio/sfx_catalog.tres",
            "scenes/game/audio/audio_root.tscn",
            "scenes/game/audio/frontend_audio_feedback.tscn",
            "scripts/game/audio/frontend_audio_feedback.gd",
            "scripts/game/audio/observer_audio_policy.gd",
            "scripts/game/frontend/start_screen.gd",
            "scenes/game/frontend/start_screen.tscn",
            "tests/game/audio/run_audio_runtime_contract.gd",
            "tests/game/audio/run_frontend_audio_feedback_contract.gd",
            "tests/game/audio/run_observer_audio_policy_contract.gd",
            "tools/release/windows_runtime_manifest.json",
        ],
    },
    {
        "deliverable_id": "DELIVERABLE-VFX-G3-001",
        "artifact_type": "observer-safe-2d-vfx-system-and-core-effects",
        "actor": VISUAL_ACTOR,
        "manifest_paths": [
            HANDOFF_URI,
            "evidence/gate3/vfx/vfx-review-1280x720.png",
            "resources/game/vfx/vfx_catalog.tres",
            "resources/game/vfx/definitions/bombardment_vfx.tres",
            "resources/game/vfx/definitions/callout_vfx.tres",
            "resources/game/vfx/definitions/resurrection_vfx.tres",
            "scenes/game/vfx/vfx_effect_slot.tscn",
            "scenes/game/vfx/vfx_review_lab.tscn",
            "scripts/game/vfx/observer_vfx_policy.gd",
            "scripts/game/vfx/vfx_effect_slot.gd",
            "scripts/game/vfx/vfx_review_lab.gd",
            "tests/game/vfx/run_vfx_cue_contract.gd",
            "tests/game/vfx/run_vfx_scene_smoke.gd",
            "tests/game/vfx/capture_vfx_review_sample.gd",
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
        raise RuntimeError("Audio/VFX update registration requires active iteration 2")
    if runtime["last_event_digest"] != history[-1]["integrity"]["event_digest"]:
        raise RuntimeError("snapshot/history tail mismatch")
    if any(
        output.get("artifact", {}).get("version") == VERSION
        for output in snapshot["resources"]["outputs"]
    ):
        raise RuntimeError("opening/callout integration outputs are already registered")

    for definition in OUTPUTS:
        for relative_path in definition["manifest_paths"]:
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
            f"register-{definition['deliverable_id'].lower()}-opening-callout-update",
            occurred_at,
        )
        output["registered_by_event_id"] = event["event_id"]
        event["payload"]["after"]["registered_by_event_id"] = event["event_id"]
        event["integrity"]["event_digest"] = event_digest(event)
        runtime["last_event_digest"] = event["integrity"]["event_digest"]
        replace_output(snapshot, output)

    write_pair(snapshot_doc, history_doc)
    print(
        "GATE3_OPENING_CALLOUT_PROGRESS_APPLIED "
        f"state={runtime['current_state']} iteration={runtime['current_iteration']} "
        f"sequence={runtime['last_event_sequence']} revision={runtime['record_revision']}"
    )


if __name__ == "__main__":
    main()
