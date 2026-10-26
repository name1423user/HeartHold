extends GutTest

var world: WorldData
var editor: TerrainEditor


func before_each() -> void:
	world = TerrainGenerator.generate(12345)
	editor = TerrainEditor.new(world)


func test_can_dig_four_levels() -> void:
	var cell: Vector2i = world.start
	var top: int = world.top_y(cell)
	for i in 4:
		var result: Dictionary = editor.break_block(Vector3i(cell.x, top - i, cell.y))
		assert_true(result["ok"], "段 %d" % (i + 1))
	assert_eq(world.top_y(cell), top - 4)


func test_fifth_level_is_rejected() -> void:
	var cell: Vector2i = world.start
	var top: int = world.top_y(cell)
	var result: Dictionary = editor.break_block(Vector3i(cell.x, top - 4, cell.y))
	assert_false(result["ok"])
	assert_eq(result["message"], "これ以上は掘れません")


func test_place_and_break_updates_top() -> void:
	var cell: Vector2i = world.start
	var top: int = world.top_y(cell)
	var pos := Vector3i(cell.x, top + 1, cell.y)
	watch_signals(editor)
	assert_true(editor.place_block(pos, world.block_id("stone"))["ok"])
	assert_eq(world.top_y(cell), top + 1)
	assert_signal_emitted(editor, "block_changed")
	assert_false(editor.place_block(pos, world.block_id("stone"))["ok"], "埋まっている所には置けない")
	assert_true(editor.break_block(pos)["ok"])
	assert_eq(world.top_y(cell), top)


func test_cannot_break_air_or_water() -> void:
	var cell: Vector2i = world.start
	assert_false(editor.break_block(Vector3i(cell.x, world.size.y - 1, cell.y))["ok"])
