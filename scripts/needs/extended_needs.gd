class_name ExtendedNeeds
extends VillageSystem
## 欲求の残り(M7-T02): 娯楽・人間関係・衛生・体温・安心(不安の少なさ)。
## 体温は気温・服・屋内・焚き火で決まり、0になると体力が減る。低い欲求は気分を下げる。
## 自分で洗う・温まる・くつろぐ。数値は data/needs.json の extended。

var _last_day: int = 0


func _init(target: Village) -> void:
	super(target)
	plan_stage = "need"
	village.alert_raised.connect(_on_alert)


func key() -> String:
	return "extended_needs"


func c() -> Dictionary:
	return village.needs_cfg["extended"]


func update(_dt: float) -> void:
	var day: int = village.clock.day()
	if day != _last_day:
		if _last_day != 0:
			_wear_clothes()
		_last_day = day


func update_villager(v: Villager, dt: float) -> void:
	var hours: float = dt / 60.0
	var n: Needs = v.needs
	var decay: Dictionary = c()["decay_per_hour"]
	var mult: Dictionary = Traits.need_decay(v)
	if v.plan_kind != "relax":
		n.add("fun", -float(decay["fun"]) * float(mult.get("fun", 1.0)) * hours)
	else:
		n.add("fun", _relax_gain(v) * hours)
	n.add("hygiene", -float(decay["hygiene"]) * hours)
	# 食いしん坊はお腹が早く減る(基本の減りは Needs.tick)
	var glutton: float = float(mult.get("food", 1.0)) - 1.0
	if glutton != 0.0:
		n.add("food", -float(village.needs_cfg["decay_per_hour"]["food"]) * glutton * hours)
	if _has_company(v):
		n.add("social", float(c()["social_gain_per_hour"]) * hours)
	else:
		n.add("social", -float(decay["social"]) * float(mult.get("social", 1.0)) * hours)
	var felt: float = felt_temperature(v)
	var comfort: float = float(c()["comfort_temperature"])
	if felt < comfort:
		n.add("warmth", -(comfort - felt) * float(c()["cold_loss_per_degree_hour"]) * float(mult.get("cold", 1.0)) * hours)
	else:
		n.add("warmth", float(c()["warm_gain_per_hour"]) * hours)
	if n.get_value("warmth") <= 0.0:
		n.add("health", -float(c()["hypothermia_health_per_hour"]) * hours)
	if village.raid_alarm:
		n.add("calm", -float(c()["calm_raid_loss_per_hour"]) * float(mult.get("calm", 1.0)) * hours)
	else:
		n.add("calm", float(c()["calm_recovery_per_hour"]) * village.calm_rate(v) * hours)
	for k: String in c()["keys"]:
		if n.get_value(k) < float(c()["low_below"]):
			n.add("mood", -float(c()["low_mood_per_hour"]) * hours)


## 感じる気温 = 外の気温 + 服 + 屋内 + 近くの焚き火
func felt_temperature(v: Villager) -> float:
	var t: float = village.calendar().temperature() + Equipment.insulation(v)
	if village.is_indoors(v) or v.plan_kind == "warm_up":
		t += float(c()["indoor_bonus"]) + village.heating_bonus(v)
	if village.near_building_type(v.pos, "campfire", float(c()["campfire_radius"])):
		t += float(c()["campfire_bonus"])
	return t


func _has_company(v: Villager) -> bool:
	var radius: float = float(c()["social_radius"])
	for other in village.villagers:
		if other != v and other.state == Villager.State.NORMAL and other.pos.distance_to(v.pos) <= radius:
			return true
	return false


func _relax_gain(v: Villager) -> float:
	var gains: Dictionary = c()["relax_gain_per_hour"]
	var place: String = str(v.timers.get("relax_at", "none"))
	return float(gains.get(place, gains["none"]))


func choose_plan(v: Villager) -> bool:
	var seek: Dictionary = c()["seek_below"]
	var n: Needs = v.needs
	if n.get_value("warmth") < float(seek["warmth"]) and village.calendar().temperature() < float(c()["comfort_temperature"]):
		var warm: Building = village.nearest_building(v.pos, ["campfire"] if village.buildings.get(v.home_id) == null else [])
		var home: Building = village.buildings.get(v.home_id) as Building
		var target: Building = home if home != null and home.is_complete() else warm
		if target != null:
			village.set_plan(v, "warm_up", [
				{"op": "goto", "target": target.cell, "adjacent": true, "building": target.id},
				{"op": "wait", "minutes": float(c()["warm_minutes"])},
			])
			return true
	if n.get_value("hygiene") < float(seek["hygiene"]):
		var spot: Dictionary = _wash_spot(v)
		if not spot.is_empty():
			village.set_plan(v, "wash", [
				{"op": "goto", "target": spot["cell"], "adjacent": true, "building": spot.get("building", -1)},
				{"op": "wash", "gain": spot["gain"]},
			])
			return true
	if n.get_value("fun") < float(seek["fun"]):
		return plan_relax(v)
	return false


## くつろぐ(酒場 > 焚き火 > その場)
func plan_relax(v: Villager) -> bool:
	var place: Building = village.nearest_building(v.pos, ["tavern"])
	var kind: String = "tavern"
	if place == null:
		place = village.nearest_building(v.pos, ["campfire"])
		kind = "campfire"
	var steps: Array[Dictionary] = []
	if place != null:
		steps.append({"op": "goto", "target": place.cell, "adjacent": true, "building": place.id})
	else:
		kind = "none"
	v.timers["relax_at"] = kind
	steps.append({"op": "wait", "minutes": float(c()["relax_minutes"])})
	village.set_plan(v, "relax", steps)
	return true


func _wash_spot(v: Villager) -> Dictionary:
	var gains: Dictionary = c()["wash_gain"]
	for type: String in ["bathhouse", "well"]:
		var b: Building = village.nearest_building(v.pos, [type])
		if b != null:
			return {"cell": b.cell, "building": b.id, "gain": float(gains[type])}
	var water: Vector2i = village.nearest_water(v.cell(), int(c()["river_search_radius"]))
	if water != Village.NO_CELL:
		return {"cell": water, "gain": float(gains["river"])}
	return {}


func execute_step(v: Villager, step: Dictionary, _budget: float) -> float:
	if str(step["op"]) != "wash":
		return NAN
	v.plan.pop_front()
	v.needs.add("hygiene", float(step["gain"]))
	return 0.0


## 服は1日ごとに傷む(0で壊れて警告)
func _wear_clothes() -> void:
	for v in village.living_villagers():
		for i in int(c()["clothes_wear_per_day"]):
			Equipment.wear(village, v, "clothes")


func _on_alert(kind: String, _message: String, _cell: Vector2i) -> void:
	if kind == "death":
		for v in village.villagers:
			v.needs.add("calm", -float(c()["calm_death_shock"]) * float(Traits.need_decay(v).get("calm", 1.0)))


func to_dict() -> Dictionary:
	return {"last_day": _last_day}


func from_dict(data: Dictionary) -> void:
	_last_day = int(data.get("last_day", 0))
