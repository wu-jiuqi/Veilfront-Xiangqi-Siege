extends SceneTree

const FormalMatchApplication = preload(
	"res://scripts/game/application/formal_match_application.gd"
)
const Catalog = preload("res://scripts/game/tutorial/tutorial_chapter_catalog.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var application: RefCounted = FormalMatchApplication.create_trusted_scenario(
		Catalog.authority("T0")
	)
	_expect(application != null, "could not create tutorial application")
	if application != null:
		var result: Dictionary = application.submit_trusted_tutorial_transition("t0_move")
		var event: Dictionary = result.get("domain_event", {})
		_expect(bool(result.get("ok", false)), "formal tutorial transition was rejected")
		_expect(bool(result.get("applied", false)), "formal tutorial transition was not applied")
		_expect(
			str(event.get("outcome", {}).get("result_code", "")) \
			== "tutorial_transition_resolved",
			"tutorial transition has no formal domain event"
		)
		_expect(
			str(event.get("tutorial_step_id", "")) == "t0_move",
			"tutorial transition event lost its step identity"
		)

	var application_source := FileAccess.get_file_as_string(
		"res://scripts/game/application/formal_match_application.gd"
	)
	var rule_source := FileAccess.get_file_as_string("res://scripts/game/domain/rule_engine.gd")
	_expect(
		not application_source.contains("TutorialEffectApplier"),
		"application layer still mutates tutorial state through TutorialEffectApplier"
	)
	_expect(
		rule_source.contains("resolve_tutorial_transition") \
		and rule_source.contains("TutorialEffectApplier.apply"),
		"tutorial transition is not owned by the formal rule boundary"
	)

	if _failures.is_empty():
		print("TUTORIAL_RULE_BOUNDARY_CONTRACT_PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
