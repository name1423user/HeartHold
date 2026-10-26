class_name OrdersPanel
extends VBoxContainer
## 指示・役職パネル: 範囲指示の道具、役職の割り当て、村長の方針、予約中の仕事。


func refresh(game: Game) -> void:
	for child in get_children():
		child.queue_free()
	var village: Village = game.village
	var tools := HBoxContainer.new()
	add_child(tools)
	for tool: String in ["select", "chop", "dig", "plant"]:
		var button := Button.new()
		button.text = Texts.t("tool_" + tool)
		button.tooltip_text = Texts.t("tooltip_tool_" + tool)
		button.toggle_mode = true
		button.button_pressed = game.tool == tool
		button.pressed.connect(func() -> void: game.set_tool(tool))
		tools.add_child(button)

	_label(Texts.t("policy_label"))
	var policy := OptionButton.new()
	var ids: Array = village.chief.cfg()["policies"].keys()
	for i in ids.size():
		policy.add_item(village.chief.policy_name(ids[i]), i)
		if ids[i] == village.chief.policy:
			policy.select(i)
	policy.tooltip_text = Texts.t("tooltip_policy")
	policy.item_selected.connect(func(index: int) -> void:
		var result: Dictionary = village.chief.set_policy(ids[index])
		game.hud.toast(Texts.t("policy_changed", {"name": village.chief.policy_name()}) if result["ok"] else str(result["message"]))
		game.hud.refresh_now())
	add_child(policy)

	_label(Texts.t("schedule_label"))
	var schedule: Schedule = village.system("schedule") as Schedule
	var grid := GridContainer.new()
	grid.columns = 8
	add_child(grid)
	for hour in 24:
		var slot := Button.new()
		slot.text = "%d%s" % [hour, Texts.t("schedule_short_" + str(schedule.table[hour]))]
		slot.tooltip_text = "%d時: %s" % [hour, GameData.get_dict("schedule")["kinds"][schedule.table[hour]]]
		slot.pressed.connect(func() -> void:
			schedule.cycle_slot(hour)
			refresh(game))
		grid.add_child(slot)

	_label(Texts.t("job_label"))
	var jobs: Array[String] = Job.available(village)
	for v in village.living_villagers():
		if v.is_chief:
			continue
		var row := HBoxContainer.new()
		add_child(row)
		var name_label := Label.new()
		name_label.text = v.display_name
		name_label.custom_minimum_size = Vector2(110, 0)
		row.add_child(name_label)
		var option := OptionButton.new()
		if not jobs.has(v.job):
			jobs = jobs.duplicate()
			jobs.append(v.job)
		for i in jobs.size():
			option.add_item(Job.display_name(jobs[i]), i)
			if jobs[i] == v.job:
				option.select(i)
		option.item_selected.connect(func(index: int) -> void: Job.assign(village, v, jobs[index]))
		row.add_child(option)

	var tasks: Dictionary = {}
	for task: JobTask in village.tasks.tasks.values():
		var key: String = task.type + ("|" + Designation.status_text(task) if not task.blocked_reason.is_empty() else "")
		tasks[key] = int(tasks.get(key, 0)) + 1
	if tasks.is_empty():
		_label(Texts.t("empty_tasks"))
	for key: String in tasks:
		var parts: PackedStringArray = key.split("|")
		_label("%s × %d %s" % [Texts.t("task_type_" + parts[0]), tasks[key], ("(%s)" % parts[1]) if parts.size() > 1 else ""])


func _label(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(label)
