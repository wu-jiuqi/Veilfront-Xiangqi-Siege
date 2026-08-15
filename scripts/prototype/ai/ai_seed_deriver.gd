extends RefCounted

const Canonical = preload("res://scripts/prototype/ai/ai_canonical.gd")


static func derive(match_ai_seed: int, decision_id: String) -> int:
	# This stream is derived only from the AI-owned match seed and a public
	# decision identifier. No rule RNG object/state/result is accepted here.
	var material: Dictionary = {
		"domain": "veilfront-prototype-ai-seed-v1",
		"match_ai_seed": match_ai_seed,
		"decision_id": decision_id,
	}
	var digest_text: String = Canonical.digest(material)
	return digest_text.substr(0, 15).hex_to_int()


static func audit_record(match_ai_seed: int, decision_id: String) -> Dictionary:
	return {
		"schema_version": "ai-seed-derivation-v1",
		"algorithm": "sha256-domain-separated-prefix60",
		"inputs": {
			"match_ai_seed": match_ai_seed,
			"decision_id": decision_id,
		},
		"derived_ai_seed": derive(match_ai_seed, decision_id),
		"forbidden_inputs": ["rule_rng", "rule_rng_state", "unpublished_random_result"],
	}
