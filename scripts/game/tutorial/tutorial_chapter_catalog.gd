class_name TutorialChapterCatalog
extends RefCounted

const TUTORIAL_IDS: Array[String] = [
	"T0", "T1", "T2", "T3", "T4", "T5", "T6", "T7", "T8", "T9", "T10",
]


static func authority(level_id: String) -> TutorialScenarioDefinition:
	if level_id not in TUTORIAL_IDS:
		return null
	return load("res://resources/game/tutorials/authority/%s.tres" % level_id.to_lower()) \
		as TutorialScenarioDefinition


static func presentation(level_id: String) -> TutorialPresentationTrack:
	if level_id not in TUTORIAL_IDS:
		return null
	return load("res://resources/game/tutorials/presentation/%s.tres" % level_id.to_lower()) \
		as TutorialPresentationTrack
