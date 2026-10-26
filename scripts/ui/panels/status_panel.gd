class_name StatusPanel
extends VBoxContainer
## 村の状態パネル: 村レベルと課題、食料、最近の審査、警告履歴(クリックでその場所へ)。


func refresh(game: Game) -> void:
	for child in get_children():
		child.queue_free()
	var village: Village = game.village
	_label("%s  %s" % [Texts.t("village_level", {"level": game.level.level}), Era.display_name(village.era())])
	var goals: Array[Dictionary] = game.level.goals()
	if not goals.is_empty():
		_label(Texts.t("next_milestone"))
		for goal in goals:
			_label("%s %s" % [Texts.t("milestone_done") if goal["done"] else Texts.t("milestone_todo"), goal["label"]])
	_label(Texts.t("food_days", {"days": FoodStock.days_left(village)}))
	var feast := Button.new()
	feast.text = Texts.t("hold_feast")
	feast.tooltip_text = Texts.t("tooltip_feast")
	feast.pressed.connect(func() -> void:
		var result: Dictionary = (village.system("festivals") as Festivals).hold_feast()
		game.hud.toast(str(result.get("message", "")) if not result["ok"] else Texts.t("alert_feast")))
	add_child(feast)
	var results: Array = village.inspection.results
	if not results.is_empty():
		var latest: Dictionary = results[-1]
		var button := Button.new()
		button.text = "%s: %s %s" % [Texts.t("inspection_latest"), latest["name"], ScoreView.total_text(latest)]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(func() -> void: game.hud.show_score(latest))
		add_child(button)
	var achievements: Achievements = village.system("achievements") as Achievements
	_label(Texts.t("achievements_label", {"done": achievements.unlocked.size(), "total": Achievements.list().size()}))
	for entry: Dictionary in Achievements.list():
		var got: bool = achievements.unlocked.has(entry["id"])
		_label("%s %s — %s" % [Texts.t("milestone_done") if got else Texts.t("milestone_todo"), entry["name"], entry["desc"]])
	var era: EraSystem = village.system("era") as EraSystem
	if not era.next_era().is_empty():
		_label(Texts.t("next_era", {"name": Era.display_name(era.next_era())}))
		for r in era.requirements():
			_label("%s %s" % [Texts.t("milestone_done") if r["done"] else Texts.t("milestone_todo"), r["label"]])
	_label(Texts.t("alert_history"))
	if game.alerts.history.is_empty():
		_label(Texts.t("empty_alerts"))
	for entry in game.alerts.history.slice(0, 30):
		var button := Button.new()
		button.text = "%s %s %s" % [entry["time"], entry["icon"], entry["message"]]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.clip_text = true
		button.pressed.connect(func() -> void: game.focus_cell(entry["cell"]))
		add_child(button)


func _label(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(label)
