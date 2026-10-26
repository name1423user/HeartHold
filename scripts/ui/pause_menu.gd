class_name PauseMenu
extends PanelContainer
## 一時停止メニュー: 再開 / セーブ / ロード / 設定(文字サイズ・音量)/ タイトルへ。

var game: Game
var box: VBoxContainer
var _was_paused: bool = false


func setup(target: Game) -> void:
	game = target
	set_anchors_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	visible = false
	box = VBoxContainer.new()
	box.custom_minimum_size = Vector2(280, 0)
	add_child(box)


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func open() -> void:
	_was_paused = game.village.clock.paused
	game.village.clock.paused = true
	visible = true
	_rebuild()


func close() -> void:
	visible = false
	game.village.clock.paused = _was_paused


func _rebuild() -> void:
	for child in box.get_children():
		child.queue_free()
	var title := Label.new()
	title.text = Texts.t("menu_title")
	title.add_theme_font_size_override("font_size", UiTheme.font_size(1.3))
	box.add_child(title)
	_button(Texts.t("menu_resume"), close)
	_button(Texts.t("menu_save"), func() -> void:
		var error: Error = SaveGame.save_game(game, "manual")
		game.hud.toast(Texts.t("saved") if error == OK else Texts.t("save_failed")))
	for save_name in SaveGame.list_saves():
		_button("%s: %s" % [Texts.t("menu_load"), save_name], func() -> void: game.load_save(save_name))
	_button(Texts.t("text_size", {"percent": roundi(Settings.text_scale() * 100)}), func() -> void:
		var count: int = (GameData.get_dict("ui")["text_scales"] as Array).size()
		Settings.text_scale_index = (Settings.text_scale_index + 1) % count
		Settings.save_settings()
		game.hud.apply_text_scale()
		_rebuild())
	for bus: String in Settings.volumes:
		var row := HBoxContainer.new()
		box.add_child(row)
		var label := Label.new()
		label.text = Texts.t("volume_label", {"bus": Texts.t("bus_" + bus), "percent": roundi(float(Settings.volumes[bus]) * 100)})
		label.custom_minimum_size = Vector2(170, 0)
		row.add_child(label)
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.value = float(Settings.volumes[bus])
		slider.custom_minimum_size = Vector2(110, 0)
		slider.value_changed.connect(func(value: float) -> void:
			Settings.volumes[bus] = value
			Settings.save_settings()
			AudioDirector.apply_volumes()
			label.text = Texts.t("volume_label", {"bus": Texts.t("bus_" + bus), "percent": roundi(value * 100)}))
		row.add_child(slider)
	_button(Texts.t("menu_title_screen"), func() -> void:
		game.get_tree().change_scene_to_file("res://scenes/ui/title.tscn"))


func _button(text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	box.add_child(button)
