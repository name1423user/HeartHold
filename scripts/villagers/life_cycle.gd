class_name LifeCycle
extends VillageSystem
## 年齢と世代交代(M7-T10)。村人は年を取り、同じ家に住む仲のよい大人がいて寝床が空いていれば子どもが生まれる。
## 子どもは早く育ち(child_growth_multiplier)、大人になるまで働かない。親の技(熟練度)の一部と個性を受け継ぐ。
## 年を取ると老衰で亡くなることがある(村長は除く)。数値は data/aging.json。

var _last_day: int = 0
var _name_index: int = 0


func key() -> String:
	return "life_cycle"


static func cfg() -> Dictionary:
	return GameData.get_dict("aging")


static func is_child(v: Villager) -> bool:
	return v.age < float(cfg()["adult_age"])


func update(_dt: float) -> void:
	var day: int = village.clock.day()
	if day == _last_day:
		return
	var first: bool = _last_day == 0
	_last_day = day
	if first:
		return
	var days_per_year: float = float(village.calendar().days_per_year())
	for v in village.living_villagers():
		var was_child: bool = is_child(v)
		v.age += (float(cfg()["child_growth_multiplier"]) if was_child else 1.0) / days_per_year
		if was_child and not is_child(v):
			v.job = "gatherer"
			village.raise_alert("grown", Texts.t("alert_grown", {"name": v.display_name}), v.cell())
		if not v.is_chief and village.rng.randf() < _death_chance(v.age) / days_per_year:
			_die_of_age(v)
	for house in village.houses():
		_try_birth(house)


func _death_chance(age: float) -> float:
	var chance: float = 0.0
	for pair: Array in cfg()["old_age_death_per_year"]:
		if age >= float(pair[0]):
			chance = float(pair[1])
	return chance


func _die_of_age(v: Villager) -> void:
	v.state = Villager.State.DEAD
	v.home_id = -1
	village.release_plan(v)
	village.raise_alert("death", Texts.t("alert_old_age", {"name": v.display_name}), v.cell())


func _try_birth(house: Building) -> void:
	var residents: Array[Villager] = village.residents_of(house)
	if residents.size() >= int(house.def().get("residents", 0)):
		return
	var range_age: Array = cfg()["parent_age"]
	var parents: Array[Villager] = []
	for v in residents:
		if not v.is_chief and v.age >= float(range_age[0]) and v.age <= float(range_age[1]) and v.needs.get_value("social") >= float(cfg()["min_social"]):
			parents.append(v)
	if parents.size() < 2 or village.rng.randf() >= float(cfg()["birth_chance_per_day"]):
		return
	var names: Array = cfg()["child_names"]
	var child: Villager = village.add_villager(str(names[_name_index % names.size()]), house.cell)
	_name_index += 1
	child.age = 0.0
	child.job = ""
	child.parents = [parents[0].id, parents[1].id]
	child.home_id = house.id
	child.traits = Traits.roll(village.rng)
	# 親の技と個性を受け継ぐ
	for p in [parents[0], parents[1]]:
		for skill: String in p.experience:
			var inherited: float = float(p.experience[skill]) * float(cfg()["inherit_fraction"])
			child.experience[skill] = maxf(float(child.experience.get(skill, 0.0)), inherited)
		if not p.traits.is_empty() and village.rng.randf() < float(cfg()["inherit_trait_chance"]):
			var t: String = p.traits[village.rng.randi_range(0, p.traits.size() - 1)]
			if not child.traits.has(t) and not Traits._conflicts(child.traits, t):
				child.traits.append(t)
	village.raise_alert("birth", Texts.t("alert_birth", {"name": child.display_name, "parent": parents[0].display_name}), house.cell)


func to_dict() -> Dictionary:
	return {"last_day": _last_day, "name_index": _name_index}


func from_dict(data: Dictionary) -> void:
	_last_day = int(data.get("last_day", 0))
	_name_index = int(data.get("name_index", 0))
