extends GutTest

var village: Village
var life: LifeCycle


func before_each() -> void:
	village = Village.create(12345)
	life = village.system("life_cycle") as LifeCycle
	var storage: Building = village.add_building("storage", village.world.start + Vector2i(4, 4), true)
	storage.inventory = {"smoked_meat": 200}


func test_couple_in_house_with_free_bed_has_child_who_inherits_skill() -> void:
	village.add_building("house", village.world.start + Vector2i(-8, -8), true)
	village.add_building("house", village.world.start + Vector2i(-3, -8), true)
	var a: Villager = village.add_villager("ハンス")
	var b: Villager = village.add_villager("アンナ")
	a.experience["build"] = 1000.0
	# 2人を同じ家に。家の寝床は2なので、3人住める大きさにする
	var home: Building = village.buildings[a.home_id]
	b.home_id = home.id
	GameData.get_dict("buildings")["house"]["residents"] = 3
	var chance: float = float(LifeCycle.cfg()["birth_chance_per_day"])
	LifeCycle.cfg()["birth_chance_per_day"] = 1.0
	for v in [a, b]:
		v.age = 25.0
		v.needs.set_value("social", 90.0)
	var born: Villager = null
	for i in 5:
		for v in [a, b]:
			v.needs.set_value("social", 90.0)
		village.tick(1440.0)
		for v in village.villagers:
			if not v.parents.is_empty():
				born = v
		if born != null:
			break
	GameData.get_dict("buildings")["house"]["residents"] = 2
	LifeCycle.cfg()["birth_chance_per_day"] = chance
	gut.p("村人 %d 人、家の寝床 %s、住人 %d" % [village.villagers.size(), str(home.def()["residents"]), village.residents_of(home).size()])
	assert_not_null(born, "子どもが生まれる")
	assert_true(LifeCycle.is_child(born))
	assert_gte(float(born.experience.get("build", 0.0)), 500.0, "親の技を受け継ぐ")
	assert_false(village.can_work(born), "子どもは働かない")


func test_children_grow_up_and_elders_die_of_age() -> void:
	var kid: Villager = village.add_villager("こども")
	kid.age = 13.9
	kid.job = ""
	village.tick(1440.0)
	village.tick(1440.0)
	assert_false(LifeCycle.is_child(kid), "大人になる")
	assert_eq(kid.job, "gatherer")
	var elder: Villager = village.add_villager("長老")
	elder.age = 95.0
	for i in 200:
		village.tick(1440.0)
		if elder.state == Villager.State.DEAD:
			break
	assert_eq(elder.state, Villager.State.DEAD, "老衰")
