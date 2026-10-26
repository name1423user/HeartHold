extends Control
## タイトル画面(AC-030): 新しく始める(シード入力)/ 続きから / ロード / 設定 / 終了。

var box: VBoxContainer
var seed_edit: LineEdit


func _ready() -> void:
	Settings.load_settings()
	AudioDirector.apply_volumes()
	theme = UiTheme.build()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = UiTheme.color("wood")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(panel)
	box = VBoxContainer.new()
	box.custom_minimum_size = Vector2(320, 0)
	panel.add_child(box)
	_rebuild()


func _rebuild() -> void:
	for child in box.get_children():
		child.queue_free()
	var title := Label.new()
	title.text = Texts.t("game_title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", UiTheme.font_size(2.4))
	box.add_child(title)
	var row := HBoxContainer.new()
	box.add_child(row)
	var label := Label.new()
	label.text = Texts.t("title_seed")
	row.add_child(label)
	seed_edit = LineEdit.new()
	seed_edit.text = str(randi() % 100000)
	seed_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(seed_edit)
	_button(Texts.t("title_new"), func() -> void:
		Game.pending_seed = int(seed_edit.text) if seed_edit.text.is_valid_int() else seed_edit.text.hash()
		Game.pending_save = ""
		get_tree().change_scene_to_file("res://scenes/game.tscn"))
	var saves: Array[String] = SaveGame.list_saves()
	var continue_button: Button = _button(Texts.t("title_continue"), func() -> void: _open_save(saves[0]))
	continue_button.disabled = saves.is_empty()
	for save_name in saves:
		_button("%s: %s" % [Texts.t("title_load"), save_name], func() -> void: _open_save(save_name))
	_button(Texts.t("text_size", {"percent": roundi(Settings.text_scale() * 100)}), func() -> void:
		var count: int = (GameData.get_dict("ui")["text_scales"] as Array).size()
		Settings.text_scale_index = (Settings.text_scale_index + 1) % count
		Settings.save_settings()
		theme = UiTheme.build()
		_rebuild())
	_button(Texts.t("title_quit"), func() -> void: get_tree().quit())


func _open_save(save_name: String) -> void:
	Game.pending_save = save_name
	get_tree().change_scene_to_file("res://scenes/game.tscn")


func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	box.add_child(button)
	return button
