class_name MatchScreenPresenter
extends RefCounted


func player_view_model(view: Dictionary) -> Dictionary:
	var flags: Array = view.get("flags", [])
	var discovered_flags: int = 0
	var owned_red: int = 0
	var owned_black: int = 0
	for flag: Variant in flags:
		if not flag is Dictionary:
			continue
		if bool(flag.get("discovered", false)):
			discovered_flags += 1
		match str(flag.get("owner", "")):
			"red":
				owned_red += 1
			"black":
				owned_black += 1

	var wall_parts: PackedStringArray = []
	for wall: Variant in view.get("walls", []):
		if wall is Dictionary:
			wall_parts.append("%s:%s" % [str(wall.get("side", "?")), str(wall.get("status", "?"))])
	var red_casualties: int = 0
	var black_casualties: int = 0
	for casualty: Variant in view.get("casualties", []):
		if casualty is Dictionary:
			if str(casualty.get("side", "")) == "red":
				red_casualties += 1
			elif str(casualty.get("side", "")) == "black":
				black_casualties += 1

	return {
		"match_id": str(view.get("match_id", "")),
		"viewer_side": str(view.get("viewer_side", "")),
		"turn_text": "行动方：%s" % str(view.get("active_side", "--")),
		"round_text": "回合：%d / %d" % [int(view.get("full_round_index", 0)), int(view.get("round_limit_public", 50))],
		"wall_text": "城墙：%s" % " / ".join(wall_parts),
		"flag_text": "旗帜：已发现 %d / 3 · 红 %d · 黑 %d" % [discovered_flags, owned_red, owned_black],
		"casualty_text": "阵亡：红 %d · 黑 %d" % [red_casualties, black_casualties],
	}


func visible_event_model(events: Array) -> Dictionary:
	if events.is_empty() or not events.back() is Dictionary:
		return {"count": events.size(), "message_key": ""}
	return {"count": events.size(), "message_key": str(events.back().get("message_key", ""))}


func visible_error_model(error: Dictionary) -> Dictionary:
	return {
		"message_key": str(error.get("message_key", "")),
		"public_code": str(error.get("public_code", "")),
	}
