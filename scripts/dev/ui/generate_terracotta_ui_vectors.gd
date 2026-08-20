@tool
extends SceneTree

## 可复现地生成兵马俑 UI 的 36 个图标、6 个光标与 4 个纹样。
## 小地图元素通过资源清单复用这些语义图形，不额外占用矢量源文件额度。

const ROOT := "res://assets/art/ui/terracotta_metal"
const GOLD := "#c8a868"
const LIGHT := "#eee1bd"
const BRONZE := "#5d563f"
const DARK := "#141b1a"
const RED := "#8f3f32"
const GREEN := "#48665c"

var _written := 0


func _init() -> void:
	_write_icons()
	_write_cursors()
	_write_patterns()
	print("TERRACOTTA_UI_VECTOR_GENERATION_PASS files=%d" % _written)
	quit(0 if _written == 46 else 1)


func _write_icons() -> void:
	var groups := {
		"roles": {
			"infantry": _shield("M32 8 L50 16 V34 C50 46 42 54 32 58 C22 54 14 46 14 34 V16 Z", "M22 27 H42 M32 18 V44"),
			"trebuchet": _line_art("M10 52 H54 M18 50 L31 14 L45 50 M22 40 H46 M31 14 L52 25 M48 22 L55 27 L51 32 M15 52 L21 58 M49 52 L43 58"),
			"chariot": _line_art("M11 42 H48 L54 27 H19 Z M18 42 L14 23 M48 42 L52 23 M21 20 H53 M25 50 A7 7 0 1 0 25.1 50 M45 50 A7 7 0 1 0 45.1 50"),
			"cavalry": _shield("M16 52 C18 40 16 28 23 18 C29 9 42 9 49 17 L41 22 L52 30 L43 34 L39 51 Z", "M25 24 C31 30 36 33 43 34 M24 43 H40"),
			"minister": _line_art("M15 54 H49 M20 51 V25 L27 17 H37 L44 25 V51 M24 17 L28 9 H36 L40 17 M26 31 H38 M26 39 H38"),
			"guard": _line_art("M14 53 H50 M19 50 L23 24 L32 13 L41 24 L45 50 M24 26 H40 M27 35 H37 M28 44 H36 M32 13 V7"),
			"general": _line_art("M13 53 H51 M18 50 L22 22 L32 11 L42 22 L46 50 M22 25 H42 M25 34 H39 M26 43 H38 M32 11 V5 M25 8 H39"),
		},
		"actions": {
			"move": _line_art("M32 7 V57 M7 32 H57 M32 7 L25 14 M32 7 L39 14 M57 32 L50 25 M57 32 L50 39 M32 57 L25 50 M32 57 L39 50 M7 32 L14 25 M7 32 L14 39"),
			"attack": _line_art("M13 51 L49 15 M40 13 L51 13 L51 24 M18 46 L11 53 M13 38 L26 51 M12 52 L20 54"),
			"repair": _line_art("M12 50 L30 32 M35 27 L49 13 M38 10 L53 11 L54 26 L47 20 L38 29 M28 35 L17 54 Z"),
			"marker": _line_art("M32 57 C27 48 15 39 15 26 A17 17 0 1 1 49 26 C49 39 37 48 32 57 Z M32 19 A7 7 0 1 0 32.1 19"),
			"confirm": _line_art("M10 33 L25 48 L54 17"),
			"cancel": _line_art("M14 14 L50 50 M50 14 L14 50"),
			"skip": _line_art("M12 13 L35 32 L12 51 Z M34 13 L56 32 L34 51 Z"),
			"back": _line_art("M28 12 L8 32 L28 52 M10 32 H52 C56 32 58 36 58 40"),
		},
		"status": {
			"selected": _line_art("M21 8 H8 V21 M43 8 H56 V21 M21 56 H8 V43 M43 56 H56 V43 M21 32 L29 40 L45 22"),
			"visible": _line_art("M6 32 C14 18 23 13 32 13 C41 13 50 18 58 32 C50 46 41 51 32 51 C23 51 14 46 6 32 Z M32 22 A10 10 0 1 0 32.1 22"),
			"hidden": _line_art("M7 32 C14 19 23 14 32 14 C42 14 51 20 57 32 C53 39 47 44 41 47 M25 49 C18 47 12 41 7 32 M10 10 L54 54"),
			"damaged": _line_art("M32 6 L58 54 H6 Z M32 20 V37 M32 46 V48"),
			"repairing": _line_art("M12 34 A20 20 0 0 1 47 20 M47 20 V10 M47 20 H37 M52 31 A20 20 0 0 1 17 46 M17 46 V56 M17 46 H27"),
			"captured": _line_art("M18 56 V8 M19 11 H49 L42 22 L49 33 H19 M12 56 H27"),
			"turn": _line_art("M14 22 A22 22 0 1 1 13 43 M14 22 V9 M14 22 H27 M32 19 V33 L42 39"),
			"locked": _line_art("M16 28 H48 V56 H16 Z M23 28 V20 A9 9 0 0 1 41 20 V28 M32 39 V47"),
		},
		"markers": {
			"flag": _line_art("M17 57 V8 M18 11 H49 L42 22 L49 33 H18 M10 57 H27"),
			"waypoint": _line_art("M32 6 L57 32 L32 58 L7 32 Z M20 32 H44 M32 20 V44"),
			"warning": _line_art("M32 6 L58 55 H6 Z M32 20 V38 M32 47 V49"),
			"attack_point": _line_art("M32 8 A24 24 0 1 0 32.1 8 M32 18 A14 14 0 1 0 32.1 18 M32 4 V20 M32 44 V60 M4 32 H20 M44 32 H60"),
			"defend_point": _shield("M32 7 L53 16 V31 C53 45 44 54 32 59 C20 54 11 45 11 31 V16 Z", "M20 32 H44 M32 20 V44"),
			"question": _line_art("M21 23 C22 14 30 10 38 13 C47 16 49 27 42 33 L34 39 V43 M33 53 V55"),
		},
		"system": {
			"play": _line_art("M18 10 L54 32 L18 54 Z"),
			"pause": _line_art("M18 11 H27 V53 H18 Z M37 11 H46 V53 H37 Z"),
			"settings": _line_art("M32 9 L37 15 L45 13 L49 20 L45 27 L55 32 L51 40 L43 39 L40 49 H31 L28 40 L20 42 L15 35 L20 28 L11 22 L15 15 L24 18 Z M32 24 A8 8 0 1 0 32.1 24"),
			"help": _line_art("M32 7 A25 25 0 1 0 32.1 7 M22 24 C23 15 32 13 39 17 C47 22 45 32 38 36 L33 40 V44 M32 52 V54"),
			"close": _line_art("M13 13 L51 51 M51 13 L13 51"),
			"reset": _line_art("M15 20 A22 22 0 1 1 12 43 M15 20 V7 M15 20 H29"),
			"network": _line_art("M32 10 A6 6 0 1 0 32.1 10 M13 43 A6 6 0 1 0 13.1 43 M51 43 A6 6 0 1 0 51.1 43 M28 21 L17 39 M36 21 L47 39 M20 49 H44"),
		},
	}
	for group: String in groups:
		for icon_name: String in groups[group]:
			_write_svg("%s/icons/%s/%s.svg" % [ROOT, group, icon_name], _icon_svg(groups[group][icon_name]))


func _write_cursors() -> void:
	var cursors := {
		"default": "<path d='M10 7 L44 34 L29 37 L37 54 L28 58 L20 40 L10 50 Z' fill='url(#metal)' stroke='%s' stroke-width='2.5'/>" % LIGHT,
		"hover": "<path d='M17 32 V18 A5 5 0 0 1 27 18 V29 V13 A5 5 0 0 1 37 13 V29 V18 A5 5 0 0 1 47 18 V39 C47 51 40 58 30 58 C20 58 13 49 10 38 A5 5 0 0 1 17 32 Z' fill='url(#metal)' stroke='%s' stroke-width='2.5'/>" % LIGHT,
		"select": "<path d='M22 7 H7 V22 M42 7 H57 V22 M22 57 H7 V42 M42 57 H57 V42 M20 33 L28 41 L45 23' fill='none' stroke='url(#metal)' stroke-width='4' stroke-linecap='round' stroke-linejoin='round'/>",
		"attack": "<circle cx='32' cy='32' r='21' fill='none' stroke='%s' stroke-width='4'/><circle cx='32' cy='32' r='8' fill='%s'/><path d='M32 4 V18 M32 46 V60 M4 32 H18 M46 32 H60' stroke='%s' stroke-width='4'/>" % [RED, RED, LIGHT],
		"forbidden": "<circle cx='32' cy='32' r='23' fill='%s' fill-opacity='.22' stroke='%s' stroke-width='4'/><path d='M16 16 L48 48' stroke='%s' stroke-width='6'/>" % [RED, RED, LIGHT],
		"pan": "<path d='M32 5 L40 16 H35 V27 H46 V22 L57 32 L46 42 V37 H35 V48 H40 L32 59 L24 48 H29 V37 H18 V42 L7 32 L18 22 V27 H29 V16 H24 Z' fill='url(#metal)' stroke='%s' stroke-width='2'/>" % LIGHT,
	}
	for cursor_name: String in cursors:
		_write_svg("%s/cursors/%s.svg" % [ROOT, cursor_name], _icon_svg(cursors[cursor_name]))


func _write_patterns() -> void:
	var patterns := {
		"cloud_thunder": "<path d='M0 40 H20 V20 H44 V44 H24 V64 H64 V24 H88 V8 H120 V32 H104 V56 H128 M0 104 H28 V80 H52 V112 H84 V88 H104 V72 H128' fill='none' stroke='%s' stroke-opacity='.55' stroke-width='4'/>" % GOLD,
		"qin_border": "<rect x='5' y='5' width='118' height='118' rx='2' fill='none' stroke='%s' stroke-width='4'/><rect x='14' y='14' width='100' height='100' fill='none' stroke='%s' stroke-opacity='.55' stroke-width='2'/><path d='M5 32 H32 V5 M96 5 V32 H123 M123 96 H96 V123 M32 123 V96 H5' fill='none' stroke='%s' stroke-width='5'/>" % [GOLD, LIGHT, GOLD],
		"command_seal": "<rect x='10' y='10' width='108' height='108' rx='5' fill='%s' fill-opacity='.12' stroke='%s' stroke-width='5'/><path d='M30 33 H98 V52 H64 V75 H96 V96 H31 V77 H48 V52 H30 Z' fill='none' stroke='%s' stroke-width='7' stroke-linejoin='miter'/>" % [RED, RED, GOLD],
		"hammered_noise": "<g fill='none' stroke='%s' stroke-opacity='.28'><path d='M4 18 Q18 6 31 17 T58 16 T87 19 T124 13'/><path d='M0 51 Q13 38 27 49 T57 48 T88 53 T128 45'/><path d='M6 84 Q23 69 39 84 T72 82 T101 88 T128 78'/><path d='M0 115 Q17 101 35 114 T68 111 T102 117 T128 108'/></g><g fill='%s' fill-opacity='.18'><circle cx='18' cy='34' r='3'/><circle cx='72' cy='31' r='2'/><circle cx='109' cy='65' r='3'/><circle cx='46' cy='99' r='2'/></g>" % [LIGHT, GOLD],
	}
	for pattern_name: String in patterns:
		_write_svg("%s/patterns/%s.svg" % [ROOT, pattern_name], _pattern_svg(patterns[pattern_name]))


func _shield(fill_path: String, detail_path: String) -> String:
	return "<path d='%s' fill='url(#metal)' stroke='%s' stroke-width='2.5' stroke-linejoin='round'/><path d='%s' fill='none' stroke='%s' stroke-width='3' stroke-linecap='round' stroke-linejoin='round'/>" % [fill_path, LIGHT, detail_path, DARK]


func _line_art(path_data: String) -> String:
	return "<path d='%s' fill='none' stroke='url(#metal)' stroke-width='4' stroke-linecap='round' stroke-linejoin='round'/>" % path_data


func _defs() -> String:
	return "<defs><linearGradient id='metal' x1='0' y1='0' x2='1' y2='1'><stop offset='0' stop-color='%s'/><stop offset='.35' stop-color='%s'/><stop offset='.7' stop-color='%s'/><stop offset='1' stop-color='%s'/></linearGradient></defs>" % [LIGHT, GOLD, BRONZE, GREEN]


func _icon_svg(body: String) -> String:
	return "<svg xmlns='http://www.w3.org/2000/svg' width='64' height='64' viewBox='0 0 64 64'>%s%s</svg>" % [_defs(), body]


func _pattern_svg(body: String) -> String:
	return "<svg xmlns='http://www.w3.org/2000/svg' width='128' height='128' viewBox='0 0 128 128'>%s<rect width='128' height='128' fill='%s' fill-opacity='.03'/>%s</svg>" % [_defs(), DARK, body]


func _write_svg(path: String, svg: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("无法写入 %s: %s" % [path, FileAccess.get_open_error()])
		return
	file.store_string(svg + "\n")
	file.close()
	_written += 1
