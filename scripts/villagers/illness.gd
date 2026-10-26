class_name Illness
extends VillageSystem
## 病気(風邪)と負傷(M7-T03)。不潔・寒さ・病人のそばでかかり、作業が遅くなる。
## 休むと早く治り、薬棚のある救護室ならもっと早い。気絶から回復したあと数日は負傷で作業が遅い。

func _init(target: Village) -> void:
	super(target)
	plan_stage = "urgent"


func key() -> String:
	return "illness"


static func cfg() -> Dictionary:
	return GameData.get_dict("diseases")


static func disease_of(v: Villager) -> String:
	return str(v.timers.get("disease", ""))


static func is_injured(village: Village, v: Villager) -> bool:
	return float(v.timers.get("injured_until", -1.0)) > village.clock.minutes


func update_villager(v: Villager, dt: float) -> void:
	var hours: float = dt / 60.0
	var current: String = disease_of(v)
	if current.is_empty():
		_maybe_infect(v, hours)
		return
	var d: Dictionary = cfg()["diseases"][current]
	v.needs.add("health", float(d["health_per_hour"]) * hours)
	var speed: float = 1.0
	if v.plan_kind == "rest":
		speed = float(d["rest_multiplier"])
		var place: Building = village.buildings.get(int(v.timers.get("rest_at", -1))) as Building
		if place != null and place.fixtures.has("medicine_cabinet"):
			speed = float(d["cabinet_multiplier"])
	v.timers["disease_left"] = float(v.timers["disease_left"]) - hours * speed
	if float(v.timers["disease_left"]) <= 0.0:
		v.timers.erase("disease")
		v.timers.erase("disease_left")
		village.raise_alert("cured", Texts.t("alert_cured", {"name": v.display_name, "disease": d["name"]}), v.cell())


func _maybe_infect(v: Villager, hours: float) -> void:
	for id: String in cfg()["diseases"]:
		var d: Dictionary = cfg()["diseases"][id]
		var chance: float = float(d["base_chance_per_hour"])
		if v.needs.get_value("hygiene") < float(d["hygiene_below"]):
			chance += float(d["hygiene_chance_per_hour"])
		if v.needs.get_value("warmth") < float(d["warmth_below"]):
			chance += float(d["warmth_chance_per_hour"])
		for other in village.villagers:
			if other != v and disease_of(other) == id and other.pos.distance_to(v.pos) <= float(d["contagion_radius"]):
				chance += float(d["contagion_chance_per_hour"])
		chance *= Traits.product(v, "disease_chance")
		if village.rng.randf() < chance * hours:
			infect(v, id)
			return


func infect(v: Villager, id: String) -> void:
	var d: Dictionary = cfg()["diseases"][id]
	v.timers["disease"] = id
	v.timers["disease_left"] = float(d["duration_hours"])
	village.raise_alert("disease", Texts.t("alert_disease", {"name": v.display_name, "disease": d["name"]}), v.cell())


## 病人は休む(薬棚のある救護室 > 家)
func choose_plan(v: Villager) -> bool:
	if disease_of(v).is_empty():
		return false
	var place: Building = null
	for b: Building in village.buildings.values():
		if b.type == "infirmary" and b.is_complete() and b.fixtures.has("medicine_cabinet"):
			place = b
			break
	if place == null:
		place = village.buildings.get(v.home_id) as Building
	var steps: Array[Dictionary] = []
	if place != null and place.is_complete():
		steps.append({"op": "goto", "target": place.cell, "adjacent": true, "building": place.id})
		v.timers["rest_at"] = place.id
	else:
		v.timers.erase("rest_at")
	steps.append({"op": "wait", "minutes": float(cfg()["rest_minutes"])})
	village.set_plan(v, "rest", steps)
	return true


func work_speed(v: Villager, kind: String) -> float:
	var speed: float = 1.0
	var current: String = disease_of(v)
	if not current.is_empty() and kind != "combat":
		speed *= float(cfg()["diseases"][current]["work_speed"])
	if is_injured(village, v):
		speed *= float(cfg()["injury"]["work_speed"])
	return speed
