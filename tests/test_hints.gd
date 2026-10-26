extends GutTest


func test_hints_walk_through_first_house() -> void:
	var village: Village = Village.create(12345)
	var hints := Hints.new(village)
	hints.update()
	assert_string_contains(hints.current_text(), "伐る")
	Designation.chop_area(village, Rect2i(Vector2i.ZERO, Vector2i(256, 256)))
	hints.update()
	assert_string_contains(hints.current_text(), "倉庫")
	var storage: Building = village.add_building("storage", village.world.start + Vector2i(4, 4), true)
	hints.update()
	assert_string_contains(hints.current_text(), "作業台")
	village.add_building("workbench", village.world.start + Vector2i(-4, 4), true)
	hints.update()
	assert_string_contains(hints.current_text(), "木材")
	storage.inventory["plank"] = 8
	hints.update()
	assert_string_contains(hints.current_text(), "家")
	village.add_building("house", village.world.start + Vector2i(-8, -8), true)
	hints.update()
	assert_true(hints.is_finished())
	assert_eq(hints.current_text(), "")


func test_title_scene_opens() -> void:
	var title: Control = (load("res://scenes/ui/title.tscn") as PackedScene).instantiate()
	add_child_autofree(title)
	await wait_physics_frames(1)
	var texts: Array = []
	for child in title.find_children("*", "Button", true, false):
		texts.append((child as Button).text)
	for expected in ["新しく始める", "続きから", "終了"]:
		assert_has(texts, expected)
