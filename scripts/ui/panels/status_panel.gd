class_name StatusPanel
extends VBoxContainer
## 村の状態パネル: 村レベルと課題、食料、最近の審査、警告履歴(クリックでその場所へ)。


func refresh(game: Game) -> void:
	for child in get_children():
		child.queue_free()
	var village: Village = game.village
	_label("%s  %s" % [Texts.t("village_level", {"level": game.level.level}), game.level.era_name()])
	var goals: Array[Dictionary] = game.level.goals()
	if not goals.is_empty():
		_label(Texts.t("next_milestone"))
		for goal in goals:
			_label("%s %s" % [Texts.t("milestone_done") if goal["done"] else Texts.t("milestone_todo"), goal["label"]])
	_label(Texts.t("food_days", {"days": FoodStock.days_left(village)}))
	var results: Array = village.inspection.results
	if not results.is_empty():
		var latest: Dictionary = results[-1]
		var button := Button.new()
		button.text = "%s: %s %s" % [Texts.t("inspection_latest"), latest["name"], ScoreView.total_text(latest)]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(func() -> void: game.hud.show_score(latest))
		add_child(button)
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
