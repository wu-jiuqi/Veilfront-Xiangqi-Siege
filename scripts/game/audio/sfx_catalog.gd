class_name SfxCatalog
extends Resource

@export var catalog_version: String = "veilfront-sfx-catalog-v1"
@export var definitions: Array[AudioCueDefinition] = []

var _lookup: Dictionary = {}


func definition_for(cue_key: String) -> AudioCueDefinition:
	_ensure_lookup()
	return _lookup.get(cue_key) as AudioCueDefinition


func cue_keys() -> Array[String]:
	_ensure_lookup()
	var keys: Array[String] = []
	for key_value: Variant in _lookup.keys():
		keys.append(str(key_value))
	keys.sort()
	return keys


func validation_errors() -> Array[String]:
	var errors: Array[String] = []
	var seen: Dictionary = {}
	if catalog_version != "veilfront-sfx-catalog-v1":
		errors.append("unsupported catalog version")
	for index: int in definitions.size():
		var definition: AudioCueDefinition = definitions[index]
		if definition == null or not definition.is_valid_definition():
			errors.append("invalid definition at index %d" % index)
			continue
		if seen.has(definition.cue_key):
			errors.append("duplicate cue key: %s" % definition.cue_key)
		seen[definition.cue_key] = true
	return errors


func _ensure_lookup() -> void:
	if _lookup.size() == definitions.size() and not _lookup.is_empty():
		return
	_lookup.clear()
	for definition: AudioCueDefinition in definitions:
		if definition != null and not definition.cue_key.is_empty():
			_lookup[definition.cue_key] = definition
