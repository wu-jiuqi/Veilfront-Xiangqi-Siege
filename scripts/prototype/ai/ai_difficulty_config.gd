extends Resource

@export_category("Prototype hypothesis — not frozen")
@export var profile_id: String = "prototype-default-hypothesis"
@export var conclusion_status: String = "hypothesis"

@export_group("Budget hypothesis")
@export_range(1, 1024, 1) var candidate_limit: int = 32
@export_range(1, 1000, 1) var time_budget_ms_hint: int = 25

@export_group("Scoring hypothesis")
@export_range(0, 100, 1) var random_score_span: int = 4
@export_range(0, 100, 1) var reveal_weight: int = 3
@export_range(0, 100, 1) var flag_weight: int = 20
@export_range(0, 100, 1) var wall_pressure_weight: int = 8
@export_range(0, 100, 1) var revisit_penalty: int = 2

@export_group("Visible tactical hypothesis")
@export_enum("weighted-one-ply", "visible-tactical-one-ply") var strategy_mode: String = "weighted-one-ply"
@export_range(1, 10, 1) var capture_priority_multiplier: int = 1
@export_range(0, 20, 1) var advance_weight: int = 0
@export_range(0, 20, 1) var center_control_weight: int = 0
@export_range(0, 300, 1) var threat_penalty_percent: int = 0
@export_range(0, 100, 1) var support_bonus_percent: int = 0
@export_range(0, 100000, 100) var general_safety_penalty: int = 0


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
		"strategy_mode": strategy_mode,
		"capture_priority_multiplier": capture_priority_multiplier,
		"advance_weight": advance_weight,
		"center_control_weight": center_control_weight,
		"threat_penalty_percent": threat_penalty_percent,
		"support_bonus_percent": support_bonus_percent,
		"general_safety_penalty": general_safety_penalty,
	}
