extends Resource

@export_category("Prototype hypothesis — not frozen")
@export var profile_id: String = "prototype-default-hypothesis"
@export var conclusion_status: String = "hypothesis"

@export_group("Budget hypothesis")
@export_range(1, 256, 1) var candidate_limit: int = 32
@export_range(1, 1000, 1) var time_budget_ms_hint: int = 25

@export_group("Scoring hypothesis")
@export_range(0, 100, 1) var random_score_span: int = 4
@export_range(0, 100, 1) var reveal_weight: int = 3
@export_range(0, 100, 1) var flag_weight: int = 20
@export_range(0, 100, 1) var wall_pressure_weight: int = 8
@export_range(0, 100, 1) var revisit_penalty: int = 2


func audit_snapshot() -> Dictionary:
	return {
		"profile_id": profile_id,
		"conclusion_status": conclusion_status,
		"candidate_limit": candidate_limit,
		"time_budget_ms_hint": time_budget_ms_hint,
		"random_score_span": random_score_span,
		"reveal_weight": reveal_weight,
		"flag_weight": flag_weight,
		"wall_pressure_weight": wall_pressure_weight,
		"revisit_penalty": revisit_penalty,
	}
