#!/usr/bin/env python3
"""Register the v2 FTUE tutorial clarity producer integration outputs."""

from __future__ import annotations

import copy
import uuid
from typing import Any

from gate3_v1_ftue_dual_track_progress import (
    CONTENT_PATHS as BASE_CONTENT_PATHS,
    UIUX_PATHS as BASE_UIUX_PATHS,
)
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


HANDOFF_URI = "game-pipeline/loops/evidence/FTUE-TUTORIAL-CLARITY-IMPLEMENTATION-HANDOFF-v2.md"
VERSION = "g3-iteration2-ftue-tutorial-clarity-producer-v2"
OLD_HANDOFF_URI = "game-pipeline/loops/evidence/FTUE-DUAL-TRACK-IMPLEMENTATION-HANDOFF-v1.md"
IMAGE_PATHS = [
    f"assets/art/tutorial/comic_v2/page_{index:02d}_{suffix}.png"
    for index, suffix in enumerate(
        (
            "board_turns",
            "pawn",
            "horse_elephant",
            "rook_cannon",
            "palace_general",
            "fog_flag_memory",
            "special_eligibility",
            "hidden_horse_elephant_field",
            "special_rook_pawn",
            "bombardment",
            "advisor_sacrifice",
            "wall_breach_entry",
            "wall_repair",
            "flag_capture",
            "flag_contest",
            "victory",
            "casualty_reserve",
            "action_preview",
        )
    )
]
COMMON_PATHS = [
    HANDOFF_URI,
    "assets/art/tutorial/comic_v2/README.md",
    *IMAGE_PATHS,
    "tests/game/tutorial/capture_tutorial_codex_v2.gd",
    "evidence/ui/tutorial-codex-v2-p00-1280x720.png",
    "evidence/ui/tutorial-codex-v2-p09-1280x720.png",
    "evidence/ui/tutorial-codex-v2-p12-960x540.png",
]
CONTENT_PATHS = [
    path for path in BASE_CONTENT_PATHS if path != OLD_HANDOFF_URI
] + COMMON_PATHS + [
    "scripts/game/tutorial/tutorial_codex.gd",
    "tests/game/tutorial/run_tutorial_codex_contract.gd",
]
UIUX_PATHS = [
    path for path in BASE_UIUX_PATHS if path != OLD_HANDOFF_URI
] + COMMON_PATHS + [
    "docs/architecture/windows-runtime-resource-budget-v1.md",
    "export_presets.cfg",
    "tools/release/windows_runtime_manifest.json",
]
OUTPUTS: tuple[dict[str, Any], ...] = (
    {
        "deliverable_id": "DELIVERABLE-CONTENT-G3-001",
        "artifact_type": "tutorial-content-plus-clarity-v2",
        "manifest_paths": list(dict.fromkeys(CONTENT_PATHS)),
    },
    {
        "deliverable_id": "DELIVERABLE-UIUX-G3-001",
        "artifact_type": "desktop-ui-plus-tutorial-codex-v2",
        "manifest_paths": list(dict.fromkeys(UIUX_PATHS)),
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
        raise RuntimeError("tutorial clarity registration requires active iteration 2")
    if runtime["last_event_digest"] != history[-1]["integrity"]["event_digest"]:
        raise RuntimeError("snapshot/history tail mismatch")
    if any(
        output.get("artifact", {}).get("version") == VERSION
        for output in snapshot["resources"]["outputs"]
    ):
        raise RuntimeError("tutorial clarity outputs are already registered")
    for definition in OUTPUTS:
        for relative_path in definition["manifest_paths"]:
            if not (PROJECT_ROOT / relative_path).is_file():
                raise RuntimeError(f"tutorial clarity artifact missing: {relative_path}")

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
            {"deliverable_id": definition["deliverable_id"], "before": before, "after": output},
            definition["manifest_paths"],
            correlation_id,
            f"register-{definition['deliverable_id'].lower()}-tutorial-clarity-v2",
            occurred_at,
        )
        output["registered_by_event_id"] = event["event_id"]
        event["payload"]["after"]["registered_by_event_id"] = event["event_id"]
        event["integrity"]["event_digest"] = event_digest(event)
        runtime["last_event_digest"] = event["integrity"]["event_digest"]
        replace_output(snapshot, output)

    write_pair(snapshot_doc, history_doc)
    print(
        "GATE3_FTUE_TUTORIAL_CLARITY_PROGRESS_APPLIED "
        f"state={runtime['current_state']} iteration={runtime['current_iteration']} "
        f"sequence={runtime['last_event_sequence']} revision={runtime['record_revision']}"
    )


if __name__ == "__main__":
    main()
