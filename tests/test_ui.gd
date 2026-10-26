extends GutTest
## M4 の画面まわり(サイドバー・警告・一時停止・近道・説明)を、実際の Game シーンで確かめる。

var game: Game


func before_each() -> void:
	Game.pending_seed = 12345
	Game.pending_save = ""
	game = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child_autofree(game)


func test_sidebar_has_four_panels_and_opens_and_closes() -> void:
	var hud: Hud = game.hud
	assert_gte(hud.panels.size(), 4, "4パネル+交易・探索")
	assert_false(hud.sidebar.visible)
	hud.toggle_panel(0)
	assert_true(hud.sidebar.visible)
	assert_true(hud.panels[0].visible)
	hud.toggle_panel(2)
	assert_true(hud.panels[2].visible)
	assert_false(hud.panels[0].visible)
	hud.toggle_panel(2)
	assert_false(hud.sidebar.visible, "同じボタンで閉じる")


func test_low_food_shows_color_and_icon_and_alert() -> void:
	var v: Villager = game.village.villagers[1]
	v.needs.set_value("food", 15.0)
	var entries: Array[Dictionary] = VillagersPanel.need_entries(game.village, v)
	assert_eq(entries[0]["key"], "food")
	assert_true(entries[0]["warning"])
	assert_eq(entries[0]["icon"], "⚠", "アイコン")
	assert_eq(entries[0]["color"], UiTheme.color("warning"), "色")
	assert_false(entries[1]["warning"])
	game.village.tick(1.0)
	assert_eq(game.alerts.history[0]["kind"], "hunger", "警告マークが出る")


func test_empty_villager_panel_text() -> void:
	for v in game.village.villagers:
		v.state = Villager.State.DEAD
	var panel := VillagersPanel.new()
	add_child_autofree(panel)
	panel.refresh(game)
	assert_eq((panel.get_child(panel.get_child_count() - 1) as Label).text, "村人がいません。移住希望者を待ちましょう")


func test_alert_history_and_click_moves_camera() -> void:
	var village: Village = game.village
	var cell: Vector2i = village.world.start + Vector2i(30, 10)
	for kind in ["raid", "applicant", "faint", "hunger", "death"]:
		village.raise_alert(kind, "テスト " + kind, cell)
	assert_eq(game.alerts.history.size(), 5, "履歴に残る")
	village.raise_alert("raid", "テスト raid", cell)
	assert_eq(game.alerts.history.size(), 5, "同じ警告の連発はまとめる")
	assert_true(game.hud.alert_button.visible, "警告マーク")
	game.hud.alert_button.pressed.emit()
	assert_almost_eq(game.camera.position.x, cell.x + 0.5, 0.01, "クリックで該当地点へ")
	assert_almost_eq(game.camera.position.z, cell.y + 0.5, 0.01)


func test_pause_stops_world_but_accepts_orders() -> void:
	var village: Village = game.village
	var v: Villager = village.villagers[1]
	game.toggle_pause()
	var minutes: float = village.clock.minutes
	var pos: Vector2 = v.pos
	village.raids.monsters.clear()
	var m := Monster.new()
	m.setup("goblin")
	m.pos = Vector2(village.world.start + Vector2i(30, 0))
	village.raids.monsters.append(m)
	village.raids.active = true
	village.tick(60.0)
	assert_eq(village.clock.minutes, minutes, "時間が止まる")
	assert_eq(v.pos, pos, "村人が止まる")
	assert_eq(m.pos, Vector2(village.world.start + Vector2i(30, 0)), "魔物が止まる")
	assert_gt(Designation.chop_area(village, Rect2i(Vector2i.ZERO, Vector2i(256, 256))), 0, "範囲指示")
	assert_true(Job.assign(village, v, "builder"), "役職変更")
	assert_true(village.plan_building("house", village.world.start + Vector2i(-8, 6))["ok"], "建設予約")
	assert_true(DirectOrder.move(village, v, village.world.start + Vector2i(3, 3))["ok"], "個人命令")
	game.toggle_pause()
	village.tick(1.0)
	assert_gt(village.clock.minutes, minutes)


func test_keyboard_shortcuts_are_mapped() -> void:
	for action in ["toggle_pause", "panel_1", "panel_2", "panel_3", "panel_4"]:
		assert_true(InputMap.has_action(action), action)
	var space := InputEventKey.new()
	space.physical_keycode = KEY_SPACE
	space.pressed = true
	assert_true(space.is_action_pressed("toggle_pause"))
	var paused: bool = game.village.clock.paused
	game._input(space)
	assert_ne(game.village.clock.paused, paused, "スペースで一時停止")
	var two := InputEventKey.new()
	two.physical_keycode = KEY_2
	two.pressed = true
	game._input(two)
	assert_eq(game.hud.current_panel, 1, "2キーで指示パネル")


func test_buttons_have_tooltips() -> void:
	for button in game.hud.activity_buttons:
		assert_ne(button.tooltip_text, "")
	var panel := BuildPanel.new()
	add_child_autofree(panel)
	panel.refresh(game)
	for child in panel.get_children():
		if child is Button:
			assert_ne((child as Button).tooltip_text, "", (child as Button).text)
	var house: Building = game.village.add_building("house", game.village.world.start + Vector2i(-8, -8), true)
	assert_string_contains(BuildPanel.building_tooltip(game, house), "村人が眠る家")


func test_score_dialog_highlights_weak_items() -> void:
	var result: Dictionary = {
		"name": "マルタ", "scores": {"food": 10.0, "housing": 0.0, "safety": 50.0, "facilities": 80.0, "satisfaction": 60.0},
		"weights": {"food": 0.5, "housing": 0.2, "safety": 0.1, "facilities": 0.1, "satisfaction": 0.1},
		"total": 27.0, "passed": false, "weak": ["food", "housing"],
	}
	var rows: Array[Dictionary] = ScoreView.rows(result)
	assert_true(rows[0]["weak"])
	assert_true(rows[1]["weak"])
	assert_false(rows[2]["weak"])
	assert_string_contains(rows[0]["text"], "重み0.50", "重みは採点表で見える")
	assert_eq(ScoreView.verdict_text(result), "不合格。足りなかったもの: 食料・住居")
	game.hud.show_score(result)
	assert_not_null(game.hud.score_dialog)
