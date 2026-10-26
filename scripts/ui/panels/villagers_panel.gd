class_name VillagersPanel
extends VBoxContainer
## 村人パネル: 一覧と欲求・状態。低い欲求は色とアイコンの両方で示す(AC-008)。


static func need_entries(village: Village, v: Villager) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for key in Needs.ALL_KEYS:
		var warning: bool = v.needs.is_low(key)
		out.append({
			"key": key, "label": Texts.t("need_" + key), "value": roundi(v.needs.get_value(key)), "warning": warning,
			"icon": Texts.t("warning_icon") if warning else "",
			"color": UiTheme.color("warning") if warning else UiTheme.color("ink"),
		})
	return out


static func state_text(v: Villager) -> String:
	return Texts.t("state_" + ["normal", "unconscious", "in_treatment", "dead"][v.state])


func refresh(game: Game) -> void:
	for child in get_children():
		child.queue_free()
	var village: Village = game.village
	var shown: Array[Villager] = village.living_villagers()
	if shown.is_empty():
		_label(Texts.t("empty_villagers"))
		return
	for v in shown:
		var row := VBoxContainer.new()
		add_child(row)
		var head := Button.new()
		var job: String = Texts.t("chief_title") if v.is_chief else Job.display_name(v.job)
		head.text = "%s(%s) %s" % [v.display_name, job, state_text(v)]
		head.alignment = HORIZONTAL_ALIGNMENT_LEFT
		head.toggle_mode = true
		head.button_pressed = v.id == game.selected_villager
		head.pressed.connect(func() -> void:
			game.selected_villager = v.id
			game.focus_cell(v.cell())
			refresh(game))
		row.add_child(head)
		var needs := HBoxContainer.new()
		row.add_child(needs)
		for entry in need_entries(village, v):
			var label := Label.new()
			label.text = "%s%s%d" % [entry["icon"], entry["label"], entry["value"]]
			label.tooltip_text = Texts.t("need_%s_long" % entry["key"])
			label.mouse_filter = Control.MOUSE_FILTER_PASS
			label.add_theme_color_override("font_color", entry["color"])
			needs.add_child(label)
		if not v.complaint.is_empty():
			_label("「%s」" % v.complaint, row)
		if v.id == game.selected_villager:
			_details(game, v, row)


func _details(game: Game, v: Villager, parent: Control) -> void:
	var village: Village = game.village
	if not v.specialty.is_empty():
		_label("%s: %s" % [Texts.t("specialty_label"), Specialty.display_name(v.specialty)], parent)
	if not v.traits.is_empty():
		_label("%s: %s" % [Texts.t("traits_label"), "・".join(Traits.names(v))], parent)
	_label("%s: %d" % [Texts.t("age_label"), int(v.age)], parent)
	if not v.line.is_empty():
		_label("「%s」" % v.line, parent)
	var tool: String = Equipment.equipped(v, "tool")
	var weapon: String = Equipment.equipped(v, "weapon")
	_label("%s: %s / %s" % [Texts.t("equipment_label"),
		village.item_def(tool).get("name", Texts.t("bare_hands")) if not tool.is_empty() else Texts.t("bare_hands"),
		village.item_def(weapon).get("name", Texts.t("bare_hands")) if not weapon.is_empty() else Texts.t("bare_hands")], parent)
	var skills: Array[String] = []
	for entry in Proficiency.summary(v):
		skills.append("%s%d" % [entry["name"], entry["level"]])
	if not skills.is_empty():
		_label("%s: %s" % [Texts.t("proficiency"), " ".join(skills)], parent)
	if v.home_id == -1:
		_label(Texts.t("home_none"), parent)
	if not v.is_chief and v.is_active():
		var move := Button.new()
		move.text = Texts.t("tool_move")
		move.tooltip_text = Texts.t("tooltip_move")
		move.pressed.connect(func() -> void: game.set_tool("move"))
		parent.add_child(move)


func _label(text: String, parent: Control = self) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
