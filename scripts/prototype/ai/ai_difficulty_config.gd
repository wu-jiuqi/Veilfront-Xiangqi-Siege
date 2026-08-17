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
@export_range(0, 100, 1) var actor_revisit_penalty: int = 2
@export_range(0, 1000, 10) var uncommitted_actor_bonus: int = 100
@export_range(1, 32, 1) var vision_cell_cap: int = 4
@export_range(1, 24, 1) var territory_step_cap: int = 3

@export_group("Visible tactical hypothesis")
@export_enum("weighted-one-ply", "visible-tactical-one-ply", "visible-state-evaluation-v1") \
var strategy_mode: String = "visible-state-evaluation-v1"
@export_range(0, 10, 1) var material_weight: int = 1
@export_range(1, 10, 1) var capture_priority_multiplier: int = 1
@export_range(0, 20, 1) var advance_weight: int = 0
@export_range(0, 20, 1) var center_control_weight: int = 0
@export_range(0, 300, 1) var threat_penalty_percent: int = 0
@export_range(0, 100, 1) var support_bonus_percent: int = 0
@export_range(0, 100000, 100) var general_safety_penalty: int = 0
@export_range(0, 20, 1) var territory_weight: int = 0
@export_range(0, 20, 1) var mobility_weight: int = 0
@export_range(0, 200, 1) var threat_opportunity_percent: int = 0
@export_range(0, 100, 1) var unsupported_advance_penalty_percent: int = 0
@export_range(0, 10000, 1) var critical_capture_value: int = 30

@export_group("Objective priority hypothesis")
@export_range(0, 5000, 10) var flag_capture_priority: int = 820
@export_range(0, 5000, 10) var flag_defense_priority: int = 650
@export_range(0, 200, 1) var flag_proximity_weight: int = 18
@export_range(0, 200, 1) var flag_vision_weight: int = 12
@export_range(0, 5000, 10) var enemy_general_attack_priority: int = 820
@export_range(0, 100, 1) var resurrection_value_weight_percent: int = 85

@export_group("Bounded two-ply belief search hypothesis")
@export_range(0, 256, 1) var search_candidate_limit: int = 12
@export_range(1, 128, 1) var opponent_response_limit: int = 12
@export_range(0, 32, 1) var belief_sample_count: int = 2
@export_range(0, 200, 1) var belief_risk_weight_percent: int = 75


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
		"actor_revisit_penalty": actor_revisit_penalty,
		"uncommitted_actor_bonus": uncommitted_actor_bonus,
		"vision_cell_cap": vision_cell_cap,
		"territory_step_cap": territory_step_cap,
		"strategy_mode": strategy_mode,
		"material_weight": material_weight,
		"capture_priority_multiplier": capture_priority_multiplier,
		"advance_weight": advance_weight,
		"center_control_weight": center_control_weight,
		"threat_penalty_percent": threat_penalty_percent,
		"support_bonus_percent": support_bonus_percent,
		"general_safety_penalty": general_safety_penalty,
		"territory_weight": territory_weight,
		"mobility_weight": mobility_weight,
		"threat_opportunity_percent": threat_opportunity_percent,
		"unsupported_advance_penalty_percent": unsupported_advance_penalty_percent,
		"critical_capture_value": critical_capture_value,
		"flag_capture_priority": flag_capture_priority,
		"flag_defense_priority": flag_defense_priority,
		"flag_proximity_weight": flag_proximity_weight,
		"flag_vision_weight": flag_vision_weight,
		"enemy_general_attack_priority": enemy_general_attack_priority,
		"resurrection_value_weight_percent": resurrection_value_weight_percent,
		"search_candidate_limit": search_candidate_limit,
		"opponent_response_limit": opponent_response_limit,
		"belief_sample_count": belief_sample_count,
		"belief_risk_weight_percent": belief_risk_weight_percent,
	}
