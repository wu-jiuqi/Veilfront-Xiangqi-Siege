class_name TutorialContextReminderPolicy
extends RefCounted

const REMINDERS: Array[Dictionary] = [
	{
		"id": "wall_breached",
		"tokens": ["wall_breached", "wall.breached", "breached"],
		"capability": "W-02",
		"title": "城墙已经破坏",
		"body": "破墙会开放区域视野，但不会自动看见隐身马；进入敌营仍要先从缓冲区起步。",
	},
	{
		"id": "wall_repairing",
		"tokens": ["wall_repairing", "wall.repairing", "repairing"],
		"capability": "W-05",
		"title": "城墙开始修复",
		"body": "修复窗口内重新出现三名入侵者会中断修复；完成后敌营内入侵者会被强制撤回。",
	},
	{
		"id": "flag_capture",
		"tokens": ["flag_capture", "flag.capture", "capture_started", "contested"],
		"capability": "FL-03",
		"title": "旗帜正在争夺",
		"body": "占领进度绑定当前棋子；离开、阵亡、献祭或撤回都会清零。",
	},
	{
		"id": "advisor_sacrifice",
		"tokens": ["advisor_sacrifice", "sacrifice", "resurrect"],
		"capability": "S-ADVISOR",
		"title": "士可献祭换援",
		"body": "提交后士会先阵亡，再从合资格的公开阵亡棋中随机复活一枚；预览阶段仍可取消。",
	},
	{
		"id": "reserve_deploy",
		"tokens": ["reserve_deploy", "reserve_queue", "deployment_queue", "auto_deploy"],
		"capability": "W-08",
		"title": "后备队列等待部署",
		"body": "本营没有空点时棋子按 FIFO 入队；本方下次行动开始且有空点时自动部署。",
	},
]


func reminder_for_events(events: Array, capability_states: Dictionary = {}) -> Dictionary:
	for event_value: Variant in events:
		if not event_value is Dictionary:
			continue
		var event: Dictionary = event_value
		var public_key := "%s %s" % [
			str(event.get("message_key", "")),
			str(event.get("event_type", "")),
		]
		var reminder := _match_public_key(public_key, capability_states)
		if not reminder.is_empty():
			return reminder
	return {}


func reminder_for_error(error: Dictionary, capability_states: Dictionary = {}) -> Dictionary:
	var public_key := "%s %s" % [
		str(error.get("message_key", "")),
		str(error.get("error_key", error.get("code", ""))),
	]
	return _match_public_key(public_key, capability_states)


func _match_public_key(public_key: String, capability_states: Dictionary) -> Dictionary:
	var normalized := public_key.to_lower()
	for reminder: Dictionary in REMINDERS:
		var capability_id := str(reminder.get("capability", ""))
		if str(capability_states.get(capability_id, TutorialProgressStore.UNSEEN)) \
			== TutorialProgressStore.COMPLETED:
			continue
		for token: String in reminder.get("tokens", []):
			if token in normalized:
				return reminder.duplicate(true)
	return {}
