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
	for tutorial in [false, true]:
		_button(Texts.t("title_tutorial") if tutorial else Texts.t("title_new"), func() -> void:
			Game.pending_seed = int(seed_edit.text) if seed_edit.text.is_valid_int() else seed_edit.text.hash()
			Game.pending_save = ""
			Game.pending_tutorial = tutorial
			get_tree().change_scene_to_file("res://scenes/game.tscn"))
	var saves: Array[String] = SaveGame.list_saves()
	var continue_button: Button = _button(Texts.t("title_continue"), func() -> void: _open_save(saves[0]))
	continue_button.disabled = saves.is_empty()
	for save_name in saves:
		var save_row := HBoxContainer.new()
		box.add_child(save_row)
		var load_button := Button.new()
		load_button.text = "%s: %s" % [Texts.t("title_load"), save_name]
		load_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		load_button.pressed.connect(func() -> void: _open_save(save_name))
		save_row.add_child(load_button)
		var delete_button := Button.new()
		delete_button.text = Texts.t("title_delete")
		delete_button.pressed.connect(func() -> void: _confirm_delete(save_name))
		save_row.add_child(delete_button)
	_button(Texts.t("text_size", {"percent": roundi(Settings.text_scale() * 100)}), func() -> void:
		var count: int = (GameData.get_dict("ui")["text_scales"] as Array).size()
		Settings.text_scale_index = (Settings.text_scale_index + 1) % count
		Settings.save_settings()
		theme = UiTheme.build()
		_rebuild())
	_button(Texts.t("title_quit"), func() -> void: get_tree().quit())


## セーブの削除は確認してから(SPEC 6章)
func _confirm_delete(save_name: String) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.dialog_text = Texts.t("confirm_delete", {"name": save_name})
	dialog.confirmed.connect(func() -> void:
		SaveGame.delete_save(save_name)
		_rebuild())
	add_child(dialog)
	dialog.popup_centered()


func _open_save(save_name: String) -> void:
	if SaveGame.load_village(save_name) == null:
		var dialog := AcceptDialog.new()
		dialog.dialog_text = SaveGame.last_error
		add_child(dialog)
		dialog.popup_centered()
		return
	Game.pending_save = save_name
	get_tree().change_scene_to_file("res://scenes/game.tscn")


func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	box.add_child(button)
	return button
