class_name ChallengeCatalog
extends RefCounted

const DEFINITIONS: Dictionary = {
	"C1": preload("res://resources/game/challenges/c1/challenge_definition.tres"),
	"C2": preload("res://resources/game/challenges/c2/challenge_definition.tres"),
	"C3": preload("res://resources/game/challenges/c3/challenge_definition.tres"),
}


static func definition(level_id: String) -> ChallengeDefinition:
	var value: Variant = DEFINITIONS.get(level_id)
	return value as ChallengeDefinition


static func all_definitions() -> Array[ChallengeDefinition]:
	var result: Array[ChallengeDefinition] = []
	for level_id: String in ["C1", "C2", "C3"]:
		var challenge := definition(level_id)
		if challenge != null:
			result.append(challenge)
	return result
