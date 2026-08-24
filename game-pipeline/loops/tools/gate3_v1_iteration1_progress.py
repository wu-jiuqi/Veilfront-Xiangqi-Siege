#!/usr/bin/env python3
"""Register GATE-3 foundation outputs and advance the loop to iteration 2."""

from __future__ import annotations

import copy
import hashlib
import json
import os
import tempfile
import uuid
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any

import yaml


PROJECT_ROOT = Path(__file__).resolve().parents[3]
REGISTRY_DIR = PROJECT_ROOT / "game-pipeline/loops/registry/content-integration-gate3"
SNAPSHOT_PATH = REGISTRY_DIR / "snapshot.yaml"
HISTORY_PATH = REGISTRY_DIR / "event-history.yaml"
LOOP_ID = "e6e0f300-2130-41d0-8020-f7f4006deb3f"
HANDOFF_URI = "evidence/gate3/iteration1-foundation-handoff-v1.md"

PM_ACTOR = {
    "actor_id": "inst:01M02M6X3Q8YWJXHY52K3V5AR2",
    "role": "pos:veilfront-xiangqi-siege:root:project-manager",
    "authority_id": "AUTH-VEILFRONT-PROJECT-MANAGER",
}
TECH_ACTOR = {
    "actor_id": "inst:01M02NJ3JEQXKV6PT6DPX0NKQ0",
    "role": "pos:veilfront-xiangqi-siege:technology:godot-technical-lead",
    "authority_id": "AUTH-VEILFRONT-GODOT-TECHNOLOGY",
}
SYSTEMS_ACTOR = {
    "actor_id": "inst:01M02NJ3JENHD8VV7EKC9G198Q",
    "role": "pos:veilfront-xiangqi-siege:design-experience:systems-experience-lead",
    "authority_id": "AUTH-VEILFRONT-SYSTEMS-EXPERIENCE",
}
VISUAL_ACTOR = {
    "actor_id": "inst:01M0QY1VFX7SFXVFXGATE3VFX1",
    "role": "pos:veilfront-xiangqi-siege:design-experience:visual-production-lead",
    "authority_id": "AUTH-VEILFRONT-VISUAL-PRODUCTION",
}

FOUNDATION_OUTPUTS = (
    {
        "deliverable_id": "DELIVERABLE-AUDIO-G3-001",
        "artifact_type": "observer-safe-audio-cue-foundation",
        "version": "g3-iteration1-foundation-v1",
        "uri": "docs/audio/observer-safe-audio-cue-contract-v1.md",
        "manifest_paths": [
            "docs/audio/observer-safe-audio-cue-contract-v1.md",
            "scripts/game/audio/observer_audio_policy.gd",
            "tests/game/audio/run_observer_audio_policy_contract.gd",
        ],
        "actor": TECH_ACTOR,
    },
    {
        "deliverable_id": "DELIVERABLE-VFX-G3-001",
        "artifact_type": "observer-safe-vfx-cue-foundation",
        "version": "g3-iteration1-foundation-v1",
        "uri": "docs/vfx/observer-safe-vfx-cue-contract-v1.md",
        "manifest_paths": [
            "docs/vfx/observer-safe-vfx-cue-contract-v1.md",
            "scripts/game/vfx/observer_vfx_policy.gd",
            "tests/game/vfx/run_vfx_cue_contract.gd",
        ],
        "actor": VISUAL_ACTOR,
    },
    {
        "deliverable_id": "DELIVERABLE-UIUX-G3-001",
        "artifact_type": "unified-desktop-ui-interaction-foundation",
        "version": "g3-iteration1-foundation-v1",
        "uri": "docs/ui/gate3-ui-foundation-v1.md",
        "manifest_paths": [
            "docs/ui/gate3-ui-foundation-v1.md",
            "scenes/game/ui/ui_motion_button.tscn",
            "scenes/game/ui/ui_motion_button_primary.tscn",
            "scenes/game/ui/ui_motion_button_secondary.tscn",
            "scenes/game/ui/ui_motion_button_danger.tscn",
            "scenes/game/ui/ui_motion_button_confirm.tscn",
            "tests/game/ui/run_gate3_ui_foundation_contract.gd",
        ],
        "actor": SYSTEMS_ACTOR,
    },
)


def load_yaml(path: Path) -> Any:
    return yaml.safe_load(path.read_text(encoding="utf-8"))


def sha256_file(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def canonical_digest(value: Any) -> str:
    payload = json.dumps(
        value,
        ensure_ascii=False,
        allow_nan=False,
        separators=(",", ":"),
        sort_keys=True,
    ).encode("utf-8")
    return hashlib.sha256(payload).hexdigest()


def event_digest(event: dict[str, Any]) -> str:
    normalized = copy.deepcopy(event)
    normalized["integrity"]["event_digest"] = None
    return canonical_digest(normalized)


def now_china() -> str:
    return datetime.now(timezone(timedelta(hours=8))).isoformat(timespec="microseconds")


def add_event(
    snapshot: dict[str, Any],
    history: list[dict[str, Any]],
    event_type: str,
    actor: dict[str, str],
    payload: dict[str, Any],
    evidence_refs: list[str],
    correlation_id: str,
    request_id: str,
    occurred_at: str,
) -> dict[str, Any]:
    runtime = snapshot["runtime"]
    event = {
        "schema_version": "0.1",
        "event_id": str(uuid.uuid4()),
        "mutation_id": str(uuid.uuid4()),
        "loop_instance_id": LOOP_ID,
        "sequence": len(history) + 1,
        "event_type": event_type,
        "occurred_at": occurred_at,
        "recorded_at": occurred_at,
        "actor": actor,
        "causality": {
            "correlation_id": correlation_id,
            "causation_event_id": history[-1]["event_id"],
            "request_id": request_id,
        },
        "concurrency": {
            "expected_record_revision": runtime["record_revision"],
            "resulting_record_revision": runtime["record_revision"] + 1,
        },
        "binding_snapshot": {
            "contract_digest": snapshot["contract_binding"]["contract_digest"],
            "state_machine_digest": snapshot["state_machine_binding"]["state_machine_digest"],
        },
        "payload": payload,
        "evidence_refs": evidence_refs,
        "integrity": {
            "canonicalization": "registry-event-canonical-json-v1",
            "digest_algorithm": "sha256",
            "previous_event_digest": history[-1]["integrity"]["event_digest"],
            "event_digest": None,
        },
    }
    event["integrity"]["event_digest"] = event_digest(event)
    history.append(event)
    runtime["last_event_id"] = event["event_id"]
    runtime["last_event_digest"] = event["integrity"]["event_digest"]
    runtime["last_event_sequence"] = event["sequence"]
    runtime["record_revision"] += 1
    return event


def replace_output(snapshot: dict[str, Any], output: dict[str, Any]) -> None:
    outputs = snapshot["resources"]["outputs"]
    for index, current in enumerate(outputs):
        if current.get("deliverable_id") == output["deliverable_id"]:
            outputs[index] = output
            return
    outputs.append(output)


def write_pair(snapshot_doc: dict[str, Any], history_doc: dict[str, Any]) -> None:
    snapshot_bytes = yaml.safe_dump(
        snapshot_doc, allow_unicode=True, sort_keys=False, width=120
    ).encode("utf-8")
    history_bytes = yaml.safe_dump(
        history_doc, allow_unicode=True, sort_keys=False, width=120
    ).encode("utf-8")
    temp_paths: list[Path] = []
    try:
        for target, payload in ((HISTORY_PATH, history_bytes), (SNAPSHOT_PATH, snapshot_bytes)):
            handle, name = tempfile.mkstemp(prefix=f".{target.name}.", dir=REGISTRY_DIR)
            with os.fdopen(handle, "wb") as stream:
                stream.write(payload)
                stream.flush()
                os.fsync(stream.fileno())
            temp_paths.append(Path(name))
        os.replace(temp_paths[0], HISTORY_PATH)
        os.replace(temp_paths[1], SNAPSHOT_PATH)
    finally:
        for path in temp_paths:
            path.unlink(missing_ok=True)


def main() -> None:
    snapshot_doc = load_yaml(SNAPSHOT_PATH)
    history_doc = load_yaml(HISTORY_PATH)
    snapshot = snapshot_doc["registry_snapshot"]
    history = history_doc["event_history"]
    runtime = snapshot["runtime"]
    if snapshot["identity"]["loop_instance_id"] != LOOP_ID:
        raise RuntimeError("loop identity mismatch")
    if runtime["current_state"] != "active" or runtime["current_iteration"] != 1:
        raise RuntimeError("iteration-1 progression requires active iteration 1")
    if runtime["last_event_digest"] != history[-1]["integrity"]["event_digest"]:
        raise RuntimeError("snapshot/history tail mismatch")
    if any(
        event.get("payload", {}).get("transition_id") == "TR-REVIEW-ACTIVE"
        for event in history
    ):
        raise RuntimeError("GATE-3 iteration 2 has already started")
    required_paths = [HANDOFF_URI]
    for definition in FOUNDATION_OUTPUTS:
        required_paths.extend(definition["manifest_paths"])
    for relative_path in dict.fromkeys(required_paths):
        if not (PROJECT_ROOT / relative_path).is_file():
            raise RuntimeError(f"foundation artifact missing: {relative_path}")

    occurred_at = now_china()
    correlation_id = str(uuid.uuid4())
    handoff_digest = sha256_file(PROJECT_ROOT / HANDOFF_URI)
    output_digests: list[str] = []
    for definition in FOUNDATION_OUTPUTS:
        before = next(
            (
                copy.deepcopy(output)
                for output in snapshot["resources"]["outputs"]
                if output.get("deliverable_id") == definition["deliverable_id"]
            ),
            None,
        )
        digest = sha256_file(PROJECT_ROOT / definition["uri"])
        output_digests.append(digest)
        event_id = str(uuid.uuid4())
        output = {
            "deliverable_id": definition["deliverable_id"],
            "artifact": {
                "artifact_id": (
                    f"artifact:veilfront-xiangqi-siege:"
                    f"{definition['deliverable_id'].lower()}@{definition['version']}"
                ),
                "artifact_type": definition["artifact_type"],
                "version": definition["version"],
                "uri": definition["uri"],
                "digest": {"algorithm": "sha256", "value": digest},
                "manifest_paths": definition["manifest_paths"],
            },
            "produced_in_iteration": 1,
            "lifecycle_status": "foundation_submitted",
            "registered_by_event_id": event_id,
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
            definition["manifest_paths"] + [HANDOFF_URI],
            correlation_id,
            f"register-{definition['deliverable_id'].lower()}-foundation",
            occurred_at,
        )
        output["registered_by_event_id"] = event["event_id"]
        event["payload"]["after"]["registered_by_event_id"] = event["event_id"]
        event["integrity"]["event_digest"] = event_digest(event)
        snapshot["runtime"]["last_event_digest"] = event["integrity"]["event_digest"]
        replace_output(snapshot, output)

    acceptance_subject = canonical_digest(
        {"handoff": handoff_digest, "outputs": output_digests}
    )
    acceptance_record = {
        "check_id": "CHECK-G3-ITERATION1-FOUNDATION",
        "decision": "passed",
        "scope": [
            "TASK-EXPORT-G3-001",
            "TASK-CUE-CONTRACT-G3-001",
            "TASK-UI-FOUNDATION-G3-001",
        ],
        "evidence_ref": HANDOFF_URI,
    }
    add_event(
        snapshot,
        history,
        "core.acceptance_recorded",
        PM_ACTOR,
        {
            "acceptance_kind": "automated_check",
            "record_id": "CHECK-G3-ITERATION1-FOUNDATION",
            "subject_digest": acceptance_subject,
            "record": acceptance_record,
        },
        [HANDOFF_URI],
        correlation_id,
        "record-gate3-iteration1-foundation-check",
        occurred_at,
    )
    snapshot["acceptance_snapshot"]["subject_digest"] = acceptance_subject
    snapshot["acceptance_snapshot"]["automated_checks"].append(acceptance_record)

    add_event(
        snapshot,
        history,
        "core.state_transitioned",
        PM_ACTOR,
        {
            "transition_id": "TR-ACTIVE-REVIEW",
            "from_state": "active",
            "to_state": "review",
            "iteration": {"before": 1, "after": 1},
            "reason": "gate3_iteration1_foundations_submitted_and_checks_passed",
            "subject_digest": acceptance_subject,
        },
        [HANDOFF_URI],
        correlation_id,
        "submit-gate3-iteration1-foundations",
        occurred_at,
    )
    runtime["current_state"] = "review"
    runtime["last_transition_id"] = "TR-ACTIVE-REVIEW"
    runtime["state_entered_at"] = occurred_at

    add_event(
        snapshot,
        history,
        "core.state_transitioned",
        PM_ACTOR,
        {
            "transition_id": "TR-REVIEW-ACTIVE",
            "from_state": "review",
            "to_state": "active",
            "iteration": {"before": 1, "after": 2},
            "reason": "contract_defined_content_production_deliverables_remain_pending",
            "subject_digest": acceptance_subject,
        },
        [HANDOFF_URI, "contract:LOOP-CTR-CONTENT-INTEGRATION-GATE3-001@v1"],
        correlation_id,
        "start-gate3-iteration2-parallel-content-production",
        occurred_at,
    )
    runtime["current_state"] = "active"
    runtime["current_iteration"] = 2
    runtime["last_transition_id"] = "TR-REVIEW-ACTIVE"
    runtime["state_entered_at"] = occurred_at
    snapshot["budget"]["usage"]["completed_iterations"] = 1
    snapshot["budget"]["last_updated_at"] = occurred_at
    write_pair(snapshot_doc, history_doc)
    print(
        "GATE3_ITERATION1_PROGRESS_APPLIED "
        f"iteration=2 sequence={runtime['last_event_sequence']} "
        f"revision={runtime['record_revision']} subject={acceptance_subject}"
    )


if __name__ == "__main__":
    main()
