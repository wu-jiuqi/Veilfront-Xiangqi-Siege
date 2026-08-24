#!/usr/bin/env python3
"""Register the Iteration 2 screen-center capture/general callout revision."""

from __future__ import annotations

import copy
import uuid

from gate3_v1_iteration1_progress import (
    LOOP_ID,
    PROJECT_ROOT,
    SNAPSHOT_PATH,
    HISTORY_PATH,
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
VERSION = "g3-iteration2-producer-integrated-v3"
DELIVERABLE_ID = "DELIVERABLE-VFX-G3-001"
MANIFEST_PATHS = [
    HANDOFF_URI,
    "assets/vfx/source/README.md",
    "assets/vfx/source/screen_callout_seal_v1.svg",
    "docs/vfx/vfx-asset-license-manifest-v1.yaml",
    "evidence/gate3/vfx/vfx-review-1280x720.png",
    "evidence/gate3/vfx/screen-callout-capture-1280x720.png",
    "evidence/gate3/vfx/screen-callout-general-1280x720.png",
    "resources/game/vfx/vfx_catalog.tres",
    "resources/game/vfx/definitions/bombardment_vfx.tres",
    "resources/game/vfx/definitions/callout_vfx.tres",
    "resources/game/vfx/definitions/resurrection_vfx.tres",
    "scenes/game/presentation/match_feedback_coordinator.tscn",
    "scenes/game/vfx/screen_callout_overlay.tscn",
    "scenes/game/vfx/vfx_effect_slot.tscn",
    "scenes/game/vfx/vfx_review_lab.tscn",
    "scripts/game/presentation/match_feedback_coordinator.gd",
    "scripts/game/vfx/observer_vfx_policy.gd",
    "scripts/game/vfx/screen_callout_overlay.gd",
    "scripts/game/vfx/vfx_effect_slot.gd",
    "scripts/game/vfx/vfx_review_lab.gd",
    "tests/game/presentation/run_match_feedback_integration_contract.gd",
    "tests/game/vfx/capture_vfx_review_sample.gd",
    "tests/game/vfx/capture_screen_callout_samples.gd",
    "tests/game/vfx/run_screen_callout_overlay_smoke.gd",
    "tests/game/vfx/run_vfx_cue_contract.gd",
    "tests/game/vfx/run_vfx_scene_smoke.gd",
]


def main() -> None:
    snapshot_doc = load_yaml(SNAPSHOT_PATH)
    history_doc = load_yaml(HISTORY_PATH)
    snapshot = snapshot_doc["registry_snapshot"]
    history = history_doc["event_history"]
    runtime = snapshot["runtime"]
    if snapshot["identity"]["loop_instance_id"] != LOOP_ID:
        raise RuntimeError("loop identity mismatch")
    if runtime["current_state"] != "active" or runtime["current_iteration"] != 2:
        raise RuntimeError("screen callout registration requires active iteration 2")
    if runtime["last_event_digest"] != history[-1]["integrity"]["event_digest"]:
        raise RuntimeError("snapshot/history tail mismatch")
    if any(
        output.get("artifact", {}).get("version") == VERSION
        for output in snapshot["resources"]["outputs"]
    ):
        raise RuntimeError("screen callout revision is already registered")
    for relative_path in MANIFEST_PATHS:
        if not (PROJECT_ROOT / relative_path).is_file():
            raise RuntimeError(f"screen callout artifact missing: {relative_path}")

    before = next(
        (
            copy.deepcopy(output)
            for output in snapshot["resources"]["outputs"]
            if output.get("deliverable_id") == DELIVERABLE_ID
        ),
        None,
    )
    if before is None:
        raise RuntimeError("VFX deliverable is not registered")
    output = {
        "deliverable_id": DELIVERABLE_ID,
        "artifact": {
            "artifact_id": (
                "artifact:veilfront-xiangqi-siege:"
                f"{DELIVERABLE_ID.lower()}@{VERSION}"
            ),
            "artifact_type": "observer-safe-2d-vfx-system-and-core-effects",
            "version": VERSION,
            "uri": HANDOFF_URI,
            "digest": {
                "algorithm": "sha256",
                "value": sha256_file(PROJECT_ROOT / HANDOFF_URI),
            },
            "manifest_paths": MANIFEST_PATHS,
        },
        "produced_in_iteration": 2,
        "lifecycle_status": "producer_integrated",
        "registered_by_event_id": "pending",
    }
    event = add_event(
        snapshot,
        history,
        "core.output_registered",
        VISUAL_ACTOR,
        {
            "deliverable_id": DELIVERABLE_ID,
            "before": before,
            "after": output,
        },
        MANIFEST_PATHS,
        str(uuid.uuid4()),
        "register-deliverable-vfx-g3-001-screen-callout-revision",
        now_china(),
    )
    output["registered_by_event_id"] = event["event_id"]
    event["payload"]["after"]["registered_by_event_id"] = event["event_id"]
    event["integrity"]["event_digest"] = event_digest(event)
    runtime["last_event_digest"] = event["integrity"]["event_digest"]
    replace_output(snapshot, output)
    write_pair(snapshot_doc, history_doc)
    print(
        "GATE3_SCREEN_CALLOUT_PROGRESS_APPLIED "
        f"state={runtime['current_state']} iteration={runtime['current_iteration']} "
        f"sequence={runtime['last_event_sequence']} revision={runtime['record_revision']}"
    )


if __name__ == "__main__":
    main()
