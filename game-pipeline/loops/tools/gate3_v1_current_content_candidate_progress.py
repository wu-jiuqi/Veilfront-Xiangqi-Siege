#!/usr/bin/env python3
"""Register the reviewed current-content Windows candidate without advancing GATE-3."""

from __future__ import annotations

import copy
import uuid

from gate3_v1_iteration1_progress import (
    HISTORY_PATH,
    LOOP_ID,
    PROJECT_ROOT,
    SNAPSHOT_PATH,
    TECH_ACTOR,
    add_event,
    event_digest,
    load_yaml,
    now_china,
    replace_output,
    sha256_file,
    write_pair,
)


DELIVERABLE_ID = "DELIVERABLE-EXPORT-G3-001"
EVIDENCE_URI = (
    "game-pipeline/loops/evidence/"
    "GATE3-CURRENT-CONTENT-WINDOWS-CANDIDATE-v1.md"
)
VERSION = "g3-iteration2-current-content-windows-candidate-v1"
MANIFEST_PATHS = [
    EVIDENCE_URI,
    "docs/architecture/windows-runtime-resource-budget-v1.md",
    "export_presets.cfg",
    "tools/release/windows_runtime_manifest.json",
    "tools/release/verify_windows_runtime_budget.ps1",
    "tools/release/build_windows_runtime_candidate.ps1",
    "tools/release/verify_windows_lan_export.ps1",
    "tests/game/performance/run_match_interaction_performance_contract.gd",
    "tests/game/network/run_formal_lan_full_stack_loopback.gd",
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
        raise RuntimeError("current-content candidate requires active GATE-3 iteration 2")
    if runtime["last_event_digest"] != history[-1]["integrity"]["event_digest"]:
        raise RuntimeError("snapshot/history tail mismatch")
    if any(
        output.get("artifact", {}).get("version") == VERSION
        for output in snapshot["resources"]["outputs"]
    ):
        raise RuntimeError("current-content Windows candidate is already registered")
    for relative_path in MANIFEST_PATHS:
        if not (PROJECT_ROOT / relative_path).is_file():
            raise RuntimeError(f"candidate manifest path missing: {relative_path}")

    before = next(
        (
            copy.deepcopy(output)
            for output in snapshot["resources"]["outputs"]
            if output.get("deliverable_id") == DELIVERABLE_ID
        ),
        None,
    )
    if before is None:
        raise RuntimeError("export deliverable must already exist before candidate update")

    occurred_at = now_china()
    evidence_digest = sha256_file(PROJECT_ROOT / EVIDENCE_URI)
    output = {
        "deliverable_id": DELIVERABLE_ID,
        "artifact": {
            "artifact_id": (
                "artifact:veilfront-xiangqi-siege:"
                f"current-content-windows-candidate@{VERSION}"
            ),
            "artifact_type": "reviewed-current-content-windows-candidate",
            "version": VERSION,
            "uri": EVIDENCE_URI,
            "digest": {"algorithm": "sha256", "value": evidence_digest},
            "manifest_paths": MANIFEST_PATHS,
        },
        "produced_in_iteration": 2,
        "lifecycle_status": (
            "producer_reviewed_runnable_candidate_awaiting_independent_qa"
        ),
        "registered_by_event_id": "pending",
    }
    event = add_event(
        snapshot,
        history,
        "core.output_registered",
        TECH_ACTOR,
        {
            "deliverable_id": DELIVERABLE_ID,
            "before": before,
            "after": output,
        },
        MANIFEST_PATHS,
        str(uuid.uuid4()),
        "register-current-content-windows-candidate-producer-review",
        occurred_at,
    )
    output["registered_by_event_id"] = event["event_id"]
    event["payload"]["after"]["registered_by_event_id"] = event["event_id"]
    event["integrity"]["event_digest"] = event_digest(event)
    runtime["last_event_digest"] = event["integrity"]["event_digest"]
    replace_output(snapshot, output)

    write_pair(snapshot_doc, history_doc)
    print(
        "GATE3_CURRENT_CONTENT_CANDIDATE_REGISTERED "
        f"state={runtime['current_state']} iteration={runtime['current_iteration']} "
        f"sequence={runtime['last_event_sequence']} revision={runtime['record_revision']} "
        f"digest={evidence_digest}"
    )


if __name__ == "__main__":
    main()
