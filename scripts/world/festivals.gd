class_name Festivals
extends VillageSystem
## 宴と祭り(M7-T09)。宴は余った食べ物を使って、夕方に焚き火か酒場へ集まり気分を大きく上げる。
## 祭りは礼拝堂があれば季節の初日に開かれ、気分・娯楽・安心が上がり、評判も少し上がる。

signal feast_started

## 開催中: {"kind": "feast"/"festival", "until": 分, "place": 建物ID}
var current: Dictionary = {}
var last_feast_day: int = -100
var last_festival_season: int = -1


func _init(target: Village) -> void:
	super(target)
	plan_stage = "urgent"


func key() -> String:
	return "festivals"


func cfg() -> Dictionary:
	return GameData.get_dict("festivals")


func can_hold_feast() -> String:
	var c: Dictionary = cfg()["feast"]
	if not current.is_empty():
		return "feast_running"
	if village.clock.day() - last_feast_day < int(c["cooldown_days"]):
		return "feast_cooldown"
	if village.nearest_building(Vector2(village.world.start), c["places"]) == null:
		return "feast_no_place"
	if FoodStock.total_food(village) < _food_needed(int(c["food_per_person"])):
		return "feast_no_food"
	return ""


func _food_needed(per_person: int) -> float:
	return per_person * 25.0 * village.living_villagers().size()


## 宴を開く(プレイヤーの操作)。食べ物を使い、集まる時間を決める
func hold_feast() -> Dictionary:
	var error: String = can_hold_feast()
	if not error.is_empty():
		return {"ok": false, "message": Texts.t(error)}
	var c: Dictionary = cfg()["feast"]
	_consume_food(_food_needed(int(c["food_per_person"])))
	var place: Building = village.nearest_building(Vector2(village.world.start), c["places"])
	current = {"kind": "feast", "until": village.clock.minutes + float(c["minutes"]), "place": place.id}
	last_feast_day = village.clock.day()
	village.raise_alert("feast", Texts.t("alert_feast"), place.cell)
	feast_started.emit()
	_release_all()
	return {"ok": true}


func _consume_food(amount: float) -> void:
	var left: float = amount
	for s: Building in village.stockpiles():
		for item: String in s.inventory.keys():
			var d: Dictionary = village.item_def(item)
			if d.get("category", "") != "food" or left <= 0.0:
				continue
			var value: float = float(d.get("food", 1.0))
			var count: int = mini(int(s.inventory[item]), ceili(left / value))
			village.take_from({"kind": "building", "id": s.id}, item, count)
			left -= count * value


func _release_all() -> void:
	for v in village.living_villagers():
		if v.is_active() and v.plan_kind != "carry_patient":
			village.release_plan(v)


func update(_dt: float) -> void:
	if not current.is_empty():
		if village.clock.minutes >= float(current["until"]):
			_finish()
		return
	var cal: Calendar = village.calendar()
	var season_index: int = cal.season_index() + cal.year() * 4
	var chapel: Building = village.nearest_building(Vector2(village.world.start), [cfg()["festival"]["place"]])
	if chapel != null and season_index != last_festival_season and village.clock.hour() >= 10.0:
		last_festival_season = season_index
		var c: Dictionary = cfg()["festival"]
		_consume_food(_food_needed(int(c["food_per_person"])))
		current = {"kind": "festival", "until": village.clock.minutes + float(c["minutes"]), "place": chapel.id}
		village.raise_alert("festival", Texts.t("alert_festival", {"season": cal.season()["name"]}), chapel.cell)
		_release_all()


func _finish() -> void:
	var c: Dictionary = cfg()[current["kind"]]
	var place: Building = village.buildings.get(int(current["place"])) as Building
	for v in village.living_villagers():
		if place != null and v.pos.distance_to(place.center()) > 8.0:
			continue
		v.needs.add("mood", float(c["mood"]))
		v.needs.add("fun", float(c["fun"]))
		v.needs.add("social", float(c.get("social", 0.0)))
		v.needs.add("calm", float(c.get("calm", 0.0)))
	if current["kind"] == "festival":
		var rep: Reputation = village.system("reputation") as Reputation
		if rep != null:
			rep.change(float(c["reputation"]), "festival")
	current = {}


## 開催中はみんな会場へ集まる
func choose_plan(v: Villager) -> bool:
	if current.is_empty() or village.raid_alarm:
		return false
	var place: Building = village.buildings.get(int(current["place"])) as Building
	if place == null:
		return false
	village.set_plan(v, "festival", [
		{"op": "goto", "target": place.cell, "adjacent": true, "building": place.id},
		{"op": "wait", "minutes": maxf(1.0, float(current["until"]) - village.clock.minutes)},
	])
	return true


func to_dict() -> Dictionary:
	return {"current": current.duplicate(), "last_feast_day": last_feast_day, "last_festival_season": last_festival_season}


func from_dict(data: Dictionary) -> void:
	current = (data.get("current", {}) as Dictionary).duplicate()
	last_feast_day = int(data.get("last_feast_day", -100))
	last_festival_season = int(data.get("last_festival_season", -1))
