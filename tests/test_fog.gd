extends GutTest

var village: Village


func before_each() -> void:
	village = Village.create(12345)


func test_unexplored_until_seen_then_stays_explored() -> void:
	var far: Vector2i = village.world.start + Vector2i(40, 0)
	assert_true(village.fog.is_explored(village.world.start), "開始地点のまわりは見えている")
	assert_false(village.fog.is_explored(far), "未探索は霧")
	var v: Villager = village.add_villager("ハンス")
	v.place_at(far)
	village.fog.refresh()
	assert_true(village.fog.is_explored(far), "視界に入ると晴れる")
	assert_true(village.fog.is_visible(far))
	v.place_at(village.world.start)
	village.fog.refresh()
	assert_true(village.fog.is_explored(far), "視界外でも地形は見えたまま")
	assert_false(village.fog.is_visible(far))


func test_monster_outside_vision_is_hidden() -> void:
	var v: Villager = village.add_villager("アンナ")
	var m := Monster.new()
	m.setup("goblin")
	m.pos = Vector2(v.cell() + Vector2i(5, 0))
	village.fog.refresh()
	assert_true(village.fog.is_monster_visible(m))
	# 晴れているが、いまはだれも見ていない場所
	var explored_far: Vector2i = village.world.start + Vector2i(18, 0)
	assert_true(village.fog.is_explored(explored_far))
	m.pos = Vector2(explored_far)
	assert_false(village.fog.is_monster_visible(m), "視界外の魔物は表示しない")


func test_fog_round_trip() -> void:
	var v: Villager = village.add_villager("クララ")
	v.place_at(village.world.start + Vector2i(60, 30))
	village.fog.refresh()
	var data: Dictionary = village.fog.to_dict()
	var other: Village = Village.create(12345)
	other.fog.from_dict(data)
	assert_true(other.fog.explored == village.fog.explored)
