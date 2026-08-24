class_name VfxCatalog
extends Resource

const REQUIRED_FAMILIES: Array[String] = [
	"selection", "move", "capture", "bombardment", "wall", "flag", "terminal",
]

@export var definitions: Array[VfxCueDefinition] = []


func definition_for(cue_key: String) -> VfxCueDefinition:
	for definition: VfxCueDefinition in definitions:
		if definition != null and definition.matches(cue_key):
			return definition
	return null


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	var seen: Dictionary = {}
	for definition: VfxCueDefinition in definitions:
		if definition == null:
			errors.append("null_definition")
			continue
		if not definition.is_valid_definition():
			errors.append("invalid_definition:%s" % definition.resource_path)
		if seen.has(definition.family):
			errors.append("duplicate_family:%s" % definition.family)
		seen[definition.family] = true
	for family: String in REQUIRED_FAMILIES:
		if not seen.has(family):
			errors.append("missing_family:%s" % family)
	return errors
