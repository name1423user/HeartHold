class_name Hud
extends CanvasLayer
## プレイ画面の UI。上部バー・中央上の警告マーク・左のアクティビティバーと開閉サイドバー(AC-008)、
## 一時停止メニュー、審査結果、ヒント、マウスを乗せたときの説明。

const PANEL_KEYS: Array[String] = ["villagers", "orders", "build", "status", "trade"]

var game: Game
var root: Control
var top_bar: TopBar
var sidebar: PanelContainer
var sidebar_title: Label
var sidebar_body: VBoxContainer
var panels: Array[Control] = []
var activity_buttons: Array[Button] = []
var current_panel: int = -1
var alert_button: Button
var tool_label: Label
var toast_label: Label
var hint_label: Label
var tooltip_label: Label
var tutorial_box: PanelContainer
var tutorial_label: Label
var tutorial_next: Button
var pause_menu: PauseMenu
var score_dialog: PanelContainer
var _refresh_timer: float = 0.0
var _alert_timer: float = 0.0
var _toast_timer: float = 0.0
var _last_alert: Dictionary = {}


func setup(target: Game) -> void:
	game = target
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiTheme.build()
	add_child(root)
	_build_top_bar()
	_build_activity_bar()
	_build_sidebar()
	_build_alert_banner()
	_build_bottom()
	_build_tutorial()
	pause_menu = preload("res://scenes/ui/pause_menu.tscn").instantiate() as PauseMenu
	root.add_child(pause_menu)
	pause_menu.setup(game)
	game.alerts.added.connect(_on_alert)
	game.village.inspection.inspection_finished.connect(show_score)
	(game.village.system("story") as Story).chapter_started.connect(show_story)
	refresh_now()


func apply_text_scale() -> void:
	root.theme = UiTheme.build()


func _build_top_bar() -> void:
	top_bar = TopBar.new()
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	root.add_child(top_bar)
	top_bar.setup(game)


func _build_activity_bar() -> void:
	var bar := PanelContainer.new()
	bar.position = Vector2(0, 44)
	root.add_child(bar)
	var box := VBoxContainer.new()
	bar.add_child(box)
	for i in PANEL_KEYS.size():
		var button := Button.new()
		button.text = Texts.t("activity_" + PANEL_KEYS[i])
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(40, 40)
		button.tooltip_text = "%s (%d)" % [Texts.t("panel_" + PANEL_KEYS[i]), i + 1]
		button.pressed.connect(toggle_panel.bind(i))
		box.add_child(button)
		activity_buttons.append(button)


func _build_sidebar() -> void:
	sidebar = PanelContainer.new()
	sidebar.position = Vector2(52, 44)
	sidebar.size = Vector2(float(GameData.get_dict("ui")["sidebar_width"]), 600)
	sidebar.visible = false
	root.add_child(sidebar)
	var outer := VBoxContainer.new()
	sidebar.add_child(outer)
	sidebar_title = Label.new()
	sidebar_title.add_theme_font_size_override("font_size", UiTheme.font_size(1.2))
	outer.add_child(sidebar_title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(float(GameData.get_dict("ui")["sidebar_width"]) - 16, 540)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	sidebar_body = VBoxContainer.new()
	sidebar_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(sidebar_body)
	for panel: Control in [VillagersPanel.new(), OrdersPanel.new(), BuildPanel.new(), StatusPanel.new(), TradePanel.new()]:
		panel.visible = false
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sidebar_body.add_child(panel)
		panels.append(panel)


func _build_alert_banner() -> void:
	alert_button = Button.new()
	alert_button.anchor_left = 0.5
	alert_button.anchor_right = 0.5
	alert_button.position = Vector2(-200, 48)
	alert_button.custom_minimum_size = Vector2(400, 36)
	alert_button.visible = false
	alert_button.add_theme_color_override("font_color", Color.WHITE)
	var style := StyleBoxFlat.new()
	style.bg_color = UiTheme.color("warning")
	style.set_corner_radius_all(4)
	style.set_content_margin_all(6)
	alert_button.add_theme_stylebox_override("normal", style)
	alert_button.pressed.connect(func() -> void:
		if not _last_alert.is_empty():
			game.focus_cell(_last_alert["cell"]))
	root.add_child(alert_button)


func _build_bottom() -> void:
	tool_label = _floating_label(Control.PRESET_CENTER_BOTTOM, Vector2(0, -90))
	toast_label = _floating_label(Control.PRESET_CENTER_BOTTOM, Vector2(0, -130))
	hint_label = _floating_label(Control.PRESET_CENTER_BOTTOM, Vector2(0, -50))
	tooltip_label = Label.new()
	tooltip_label.visible = false
	tooltip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = UiTheme.color("ink")
	style.set_content_margin_all(6)
	tooltip_label.add_theme_stylebox_override("normal", style)
	tooltip_label.add_theme_color_override("font_color", UiTheme.color("parchment"))
	root.add_child(tooltip_label)


func _build_tutorial() -> void:
	tutorial_box = PanelContainer.new()
	tutorial_box.anchor_left = 0.5
	tutorial_box.anchor_right = 0.5
	tutorial_box.anchor_top = 1.0
	tutorial_box.anchor_bottom = 1.0
	tutorial_box.position = Vector2(-260, -170)
	tutorial_box.custom_minimum_size = Vector2(520, 0)
	root.add_child(tutorial_box)
	var box := VBoxContainer.new()
	tutorial_box.add_child(box)
	tutorial_label = Label.new()
	tutorial_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tutorial_label.custom_minimum_size = Vector2(500, 0)
	box.add_child(tutorial_label)
	var row := HBoxContainer.new()
	box.add_child(row)
	tutorial_next = Button.new()
	tutorial_next.text = Texts.t("tutorial_next")
	tutorial_next.pressed.connect(func() -> void:
		game.tutorial.next()
		refresh_now())
	row.add_child(tutorial_next)
	var stop := Button.new()
	stop.text = Texts.t("tutorial_stop")
	stop.pressed.connect(func() -> void:
		game.tutorial.stop()
		refresh_now())
	row.add_child(stop)


func _floating_label(preset: Control.LayoutPreset, offset: Vector2) -> Label:
	var label := Label.new()
	label.set_anchors_preset(preset)
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.position += offset
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(UiTheme.color("parchment"), 0.92)
	style.border_color = UiTheme.color("wood")
	style.set_border_width_all(1)
	style.set_content_margin_all(6)
	label.add_theme_stylebox_override("normal", style)
	label.visible = false
	root.add_child(label)
	return label


func toggle_panel(index: int) -> void:
	if current_panel == index:
		current_panel = -1
	else:
		current_panel = index
	_apply_panel()


func show_panel(index: int) -> void:
	current_panel = index
	_apply_panel()


func _apply_panel() -> void:
	sidebar.visible = current_panel >= 0
	for i in panels.size():
		panels[i].visible = i == current_panel
		activity_buttons[i].set_pressed_no_signal(i == current_panel)
	if current_panel >= 0:
		sidebar_title.text = Texts.t("panel_" + PANEL_KEYS[current_panel])
	refresh_now()


func toggle_pause_menu() -> void:
	pause_menu.toggle()


func toast(message: String) -> void:
	if message.is_empty():
		return
	toast_label.text = message
	toast_label.visible = true
	_toast_timer = 3.0


func refresh_tool() -> void:
	var text: String = ""
	if game.tool in ["chop", "dig", "plant"]:
		text = Texts.t("tool_hint_" + game.tool)
	elif game.tool.begins_with("build:"):
		text = Texts.t("tool_hint_build", {"name": GameData.get_dict("buildings")[game.tool.get_slice(":", 1)]["name"]})
	elif game.tool == "expedition" or game.tool == "farsight":
		text = Texts.t("tool_hint_" + game.tool)
	elif game.tool == "move":
		var v: Villager = game.village.get_villager(game.selected_villager)
		text = Texts.t("tool_hint_move", {"name": v.display_name if v != null else ""})
	tool_label.text = text
	tool_label.visible = not text.is_empty()


func refresh_now() -> void:
	_refresh_timer = 0.0
	top_bar.refresh()
	if current_panel >= 0:
		panels[current_panel].call("refresh", game)
	var tutorial_on: bool = not game.tutorial.is_finished()
	tutorial_box.visible = tutorial_on
	if tutorial_on:
		tutorial_label.text = "(%d/%d) %s" % [game.tutorial.step + 1, Tutorial.steps().size(), game.tutorial.current()["text"]]
		tutorial_next.visible = game.tutorial.needs_next_button()
	var hint: String = "" if tutorial_on else game.hints.current_text()
	hint_label.text = hint
	hint_label.visible = not hint.is_empty()


func _process(delta: float) -> void:
	if game == null:
		return
	_refresh_timer += delta
	# クリックの途中で作り直すと押せなくなるので、ボタンを押している間は待つ
	if _refresh_timer >= float(GameData.get_dict("ui")["refresh_seconds"]) and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		refresh_now()
	if _alert_timer > 0.0:
		_alert_timer -= delta
		alert_button.visible = _alert_timer > 0.0
	if _toast_timer > 0.0:
		_toast_timer -= delta
		toast_label.visible = _toast_timer > 0.0
	_update_tooltip()


## 3D の建物にマウスを乗せたときの説明(AC-050)
func _update_tooltip() -> void:
	var over_ui: bool = root.get_viewport().gui_get_hovered_control() != null
	var b: Building = null if over_ui else game.building_under_mouse()
	tooltip_label.visible = b != null
	if b != null:
		tooltip_label.text = BuildPanel.building_tooltip(game, b)
		tooltip_label.position = root.get_viewport().get_mouse_position() + Vector2(16, 16)


func _on_alert(entry: Dictionary) -> void:
	_last_alert = entry
	alert_button.text = "%s %s" % [entry["icon"], entry["message"]]
	alert_button.visible = true
	_alert_timer = float(GameData.get_dict("ui")["alert_seconds"])


## 審査結果ダイアログ(AC-014, AC-032)。重みはここで初めて見せる
func show_score(result: Dictionary) -> void:
	if score_dialog != null:
		score_dialog.queue_free()
	score_dialog = PanelContainer.new()
	score_dialog.set_anchors_preset(Control.PRESET_CENTER)
	score_dialog.grow_horizontal = Control.GROW_DIRECTION_BOTH
	score_dialog.grow_vertical = Control.GROW_DIRECTION_BOTH
	root.add_child(score_dialog)
	var box := VBoxContainer.new()
	score_dialog.add_child(box)
	var title := Label.new()
	title.text = Texts.t("score_title", {"name": result["name"]})
	title.add_theme_font_size_override("font_size", UiTheme.font_size(1.3))
	box.add_child(title)
	for row in ScoreView.rows(result):
		var label := Label.new()
		label.text = row["text"]
		if row["weak"]:
			label.text = Texts.t("warning_icon") + " " + label.text
			label.add_theme_color_override("font_color", UiTheme.color("warning"))
		box.add_child(label)
	var total := Label.new()
	total.text = ScoreView.total_text(result)
	box.add_child(total)
	var verdict := Label.new()
	verdict.text = ScoreView.verdict_text(result)
	verdict.add_theme_color_override("font_color", UiTheme.color("good") if result["passed"] else UiTheme.color("warning"))
	box.add_child(verdict)
	if game.village.inspection.pending.get("result", {}) == result:
		# 双方向の審査: 合格者を迎えるか断るか
		var hint := Label.new()
		hint.text = Texts.t("decision_hint")
		box.add_child(hint)
		var row := HBoxContainer.new()
		box.add_child(row)
		for accept in [true, false]:
			var choice := Button.new()
			choice.text = Texts.t("welcome") if accept else Texts.t("refuse")
			choice.pressed.connect(func() -> void:
				game.village.inspection.decide(accept)
				score_dialog.queue_free())
			row.add_child(choice)
		return
	var close := Button.new()
	close.text = Texts.t("close")
	close.pressed.connect(func() -> void: score_dialog.queue_free())
	box.add_child(close)


## 物語の章(M10-T03)
func show_story(chapter: Dictionary) -> void:
	var dialog := PanelContainer.new()
	dialog.set_anchors_preset(Control.PRESET_CENTER)
	dialog.grow_horizontal = Control.GROW_DIRECTION_BOTH
	dialog.grow_vertical = Control.GROW_DIRECTION_BOTH
	root.add_child(dialog)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(460, 0)
	dialog.add_child(box)
	var title := Label.new()
	title.text = str(chapter["title"])
	title.add_theme_font_size_override("font_size", UiTheme.font_size(1.3))
	box.add_child(title)
	var text := Label.new()
	text.text = str(chapter["text"])
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(440, 0)
	box.add_child(text)
	var close := Button.new()
	close.text = Texts.t("close")
	close.pressed.connect(dialog.queue_free)
	box.add_child(close)
