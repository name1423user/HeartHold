extends GutTest
## M9: 魔物の追加と相性・防具・罠・上位の武器・魔法の武器・魔物の巣と視察隊・他の村の手がかり・魔法

var village: Village


func before_each() -> void:
	village = Village.create(12345)
	village.clock.minutes = 6.0 * 1440.0 + 10.0 * 60.0
	var storage: Building = village.add_building("storage", village.world.start + Vector2i(4, 4), true)
	storage.inventory = {"smoked_meat": 100}


func _monster(type: String, at: Vector2i) -> Monster:
	var m := Monster.new()
	m.setup(type)
	m.pos = Vector2(at) + Vector2(0.5, 0.5)
	village.raids.monsters.append(m)
	return m


func test_raid_mix_depends_on_era() -> void:
	var seen: Dictionary = {}
	for i in 50:
		seen[village.raids.pick_monster_type()] = true
	assert_eq(seen.keys(), ["goblin"], "石と木の時代はゴブリンだけ")
	(village.system("era") as EraSystem).current = "medieval"
	for i in 200:
		seen[village.raids.pick_monster_type()] = true
	for type in ["wolf", "bandit", "troll"]:
		assert_true(seen.has(type), type)


func test_weapon_affinity() -> void:
	var guard: Villager = village.add_villager("カール")
	Equipment.equip(guard, "wooden_spear")
	var goblin: Monster = _monster("goblin", village.world.start + Vector2i(20, 0))
	var wolf: Monster = _monster("wolf", village.world.start + Vector2i(22, 0))
	assert_almost_eq(Combat.attack_damage(village, guard, goblin), 8.0 * 1.3, 0.001, "素早いゴブリンには槍")
	Equipment.equip(guard, "bow")
	assert_almost_eq(Combat.attack_damage(village, guard, wolf), 7.0 * 1.4, 0.001, "狼には弓")


func test_armor_reduces_damage() -> void:
	var a: Villager = village.add_villager("鎧なし")
	var b: Villager = village.add_villager("鎧あり")
	Equipment.equip(b, "leather_vest")
	Equipment.equip(b, "leather_cap")
	village.damage_villager(a, 10.0)
	village.damage_villager(b, 10.0)
	assert_almost_eq(100.0 - b.needs.get_value("health"), 10.0 * 0.85 * 0.9, 0.001)
	assert_gt(b.needs.get_value("health"), a.needs.get_value("health"))


func test_traps_hurt_and_stun_monsters() -> void:
	var cell: Vector2i = village.world.start + Vector2i(10, 0)
	village.add_building("spike_trap", cell, true)
	assert_true(village.world.is_walkable(cell), "罠の上は歩ける")
	var m: Monster = _monster("goblin", cell)
	var hp: float = m.hp
	m.update(village, 0.1)
	assert_lt(m.hp, hp, "杭の罠で傷つく")
	(village.system("era") as EraSystem).current = "iron"
	var pit_cell: Vector2i = village.world.start + Vector2i(10, 3)
	village.add_building("pit_trap", pit_cell, true)
	var m2: Monster = _monster("goblin", pit_cell)
	m2.update(village, 0.1)
	assert_gt(m2.stunned, 0.0, "落とし穴で動けない")


func test_troll_targets_buildings_and_bandit_steals() -> void:
	var house: Building = village.add_building("house", village.world.start + Vector2i(-8, -8), true)
	var troll: Monster = _monster("troll", house.cell + Vector2i(-1, 0))
	for i in 10:
		troll.update(village, 1.0)
	assert_lt(house.current_hp(), house.max_hp(), "トロルは建物を壊しに来る")
	var storage: Building = village.stockpiles()[0]
	var bandit: Monster = _monster("bandit", storage.cell + Vector2i(-1, 0))
	var before: int = storage.stored_total()
	bandit.update(village, 1.0)
	assert_lt(storage.stored_total(), before, "盗賊は倉庫の物を盗る")


func test_expedition_destroys_nest_and_reduces_raids() -> void:
	var nests: Nests = village.system("nests") as Nests
	assert_between(nests.sites.size(), 2, 4)
	var before: float = village.raids.nest_multiplier()
	var party: Array[Villager] = []
	for i in 4:
		var v: Villager = village.add_villager("隊員%d" % i)
		Job.assign(village, v, "guard")
		Equipment.equip(v, "wooden_spear")
		party.append(v)
	var nest: Dictionary = nests.sites[0]
	var expeditions: Expeditions = village.system("expeditions") as Expeditions
	assert_true(expeditions.send(party, nest["cell"])["ok"])
	for i in 72 * 6:
		village.tick(10.0)
		if nest["destroyed"] and expeditions.parties.is_empty():
			break
	assert_true(nest["destroyed"], "巣を潰す")
	assert_lt(village.raids.nest_multiplier(), before, "襲撃が減る")
	assert_true(village.fog.is_explored(nest["cell"]), "歩いた先の霧が晴れる")


func test_expedition_needs_enough_members() -> void:
	var v: Villager = village.add_villager("ひとり")
	var expeditions: Expeditions = village.system("expeditions") as Expeditions
	assert_false(expeditions.send([v] as Array[Villager], village.world.start + Vector2i(40, 0))["ok"])


func test_mage_casts_barrier_and_farsight_with_mana() -> void:
	var era: EraSystem = village.system("era") as EraSystem
	era.current = "medieval"
	village.add_building("mage_tower", village.world.start + Vector2i(-8, 6), true)
	var mage: Villager = village.add_villager("魔術師")
	assert_true(Job.assign(village, mage, "mage"))
	var magic: Magic = village.system("magic") as Magic
	mage.mana = 100.0
	var far: Vector2i = village.world.start + Vector2i(70, 0)
	assert_false(village.fog.is_explored(far))
	assert_true(magic.cast(mage, "farsight", far)["ok"])
	assert_true(village.fog.is_explored(far), "遠見で霧が晴れる")
	assert_true(magic.cast(mage, "barrier", mage.cell())["ok"])
	var hurt: Villager = village.add_villager("守られる人")
	hurt.place_at(mage.cell())
	village.damage_villager(hurt, 10.0)
	assert_almost_eq(hurt.needs.get_value("health"), 95.0, 0.001, "結界で傷が半分")
	assert_eq(magic.cast(mage, "barrier", mage.cell())["message"], "魔素が足りません")
	var normal: Villager = village.add_villager("村人")
	normal.mana = 100.0
	assert_false(magic.cast(normal, "heal", normal.cell())["ok"], "魔術師だけ")


func test_magic_staff_uses_mana() -> void:
	var mage: Villager = village.add_villager("杖の人")
	Equipment.equip(mage, "magic_staff")
	mage.mana = 4.0
	assert_false(Magic.can_use_weapon(mage))
	mage.mana = 10.0
	assert_true(Magic.can_use_weapon(mage))
	Magic.pay_weapon(mage)
	assert_eq(mage.mana, 5.0)


func test_finding_clue_unlocks_partner() -> void:
	var clues: VillageClues = village.system("village_clues") as VillageClues
	assert_between(clues.sites.size(), 3, 5)
	var v: Villager = village.add_villager("探検家")
	v.place_at(village.pathing.nearest_standable(clues.sites[0]["cell"], clues.sites[0]["cell"]))
	village.fog.refresh()
	clues.update(1.0)
	assert_true(clues.sites[0]["found"])
