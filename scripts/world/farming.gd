class_name Farming
extends VillageSystem
## 農業・畜産(M7-T08)。畑に作物をまき、季節の育ちで実り、収穫する(冬に残った作物は枯れる)。
## 家畜小屋のニワトリは卵、ヒツジは羊毛を出す。干し草をやらないと出さず、長く飢えると死ぬ。
## 農夫・牧夫の役職が拾う(役職がなければ誰でも)。数値は data/farming.json。

## 畑: 建物ID -> {"crop", "stage": empty/growing/ripe, "growth"}
var fields: Dictionary = {}
## 小屋: 建物ID -> {"animals": {種類: 数}, "fed_until": 分, "produce": {種類: 端数}, "hunger": 日, "breed": 日}
var barns: Dictionary = {}


func key() -> String:
	return "farming"


func cfg() -> Dictionary:
	return GameData.get_dict("farming")


func on_building_completed(b: Building) -> void:
	if b.type == "field":
		fields[b.id] = {"crop": str(cfg()["default_crop"]), "stage": "empty", "growth": 0.0}
	elif b.type == "barn":
		barns[b.id] = {"animals": (cfg()["barn_start"] as Dictionary).duplicate(), "fed_until": village.clock.minutes + GameClock.MINUTES_PER_DAY, "produce": {}, "hunger": 0.0, "breed": 0.0, "stock": {}}


func set_crop(b: Building, crop: String) -> void:
	if fields.has(b.id) and cfg()["crops"].has(crop):
		fields[b.id]["crop"] = crop


func update(dt: float) -> void:
	var cal: Calendar = village.calendar()
	for id: int in fields.keys():
		if not village.buildings.has(id):
			fields.erase(id)
			continue
		var f: Dictionary = fields[id]
		var crop: Dictionary = cfg()["crops"][f["crop"]]
		if f["stage"] == "growing":
			if cal.season_id() == "winter":
				f["stage"] = "empty"
				f["growth"] = 0.0
				village.raise_alert("crop_lost", Texts.t("alert_crop_lost"), (village.buildings[id] as Building).cell)
				continue
			f["growth"] = float(f["growth"]) + dt * cal.growth() / (float(crop["grow_days"]) * GameClock.MINUTES_PER_DAY)
			if float(f["growth"]) >= 1.0:
				f["stage"] = "ripe"
		_ensure_task(id, f, crop)
	for id: int in barns.keys():
		if not village.buildings.has(id):
			barns.erase(id)
			continue
		_update_barn(id, barns[id], dt)


func _ensure_task(id: int, f: Dictionary, crop: Dictionary) -> void:
	var type: String = ""
	if f["stage"] == "empty" and (crop["seasons"] as Array).has(village.calendar().season_id()):
		type = "sow"
	elif f["stage"] == "ripe":
		type = "harvest"
	if type.is_empty():
		return
	for task: JobTask in village.tasks.of_type(type):
		if task.building_id == id:
			return
	var b: Building = village.buildings[id]
	var task := JobTask.new()
	task.type = type
	task.building_id = id
	task.cell = b.cell
	task.work_needed = float(cfg()["sow_minutes" if type == "sow" else "harvest_minutes"])
	village.tasks.add(task)


func _update_barn(id: int, barn: Dictionary, dt: float) -> void:
	var b: Building = village.buildings[id]
	var days: float = dt / GameClock.MINUTES_PER_DAY
	var fed: bool = float(barn["fed_until"]) > village.clock.minutes
	var animals: Dictionary = barn["animals"]
	if fed:
		barn["hunger"] = 0.0
		var produce: Dictionary = barn["produce"]
		for species: String in animals:
			var a: Dictionary = cfg()["animals"][species]
			produce[species] = float(produce.get(species, 0.0)) + days / float(a["every_days"])
			while float(produce[species]) >= 1.0:
				produce[species] = float(produce[species]) - 1.0
				var stock: Dictionary = barn["stock"]
				stock[str(a["product"])] = int(stock.get(str(a["product"]), 0)) + int(a["per_animal"]) * int(animals[species])
		barn["breed"] = float(barn["breed"]) + days
		if float(barn["breed"]) >= float(cfg()["breed_days"]):
			barn["breed"] = 0.0
			var total: int = 0
			for species: String in animals:
				total += int(animals[species])
			for species: String in animals:
				if int(animals[species]) >= 2 and total < int(b.def()["capacity_animals"]):
					animals[species] = int(animals[species]) + 1
					total += 1
	else:
		barn["hunger"] = float(barn["hunger"]) + days
		if float(barn["hunger"]) >= float(cfg()["starve_days"]):
			barn["hunger"] = 0.0
			for species: String in animals.keys():
				animals[species] = maxi(0, int(animals[species]) - 1)
			village.raise_alert("animal_died", Texts.t("alert_animal_died"), b.cell)
	_ensure_barn_tasks(id, barn)


func _ensure_barn_tasks(id: int, barn: Dictionary) -> void:
	var b: Building = village.buildings[id]
	var wanted: Array[String] = []
	if float(barn["fed_until"]) - village.clock.minutes < GameClock.MINUTES_PER_DAY * 0.5 and village.stock_count(str(cfg()["feed_item"])) > 0:
		wanted.append("feed")
	if not (barn["stock"] as Dictionary).is_empty():
		wanted.append("collect")
	for type in wanted:
		var exists: bool = false
		for task: JobTask in village.tasks.of_type(type):
			if task.building_id == id:
				exists = true
		if exists:
			continue
		var task := JobTask.new()
		task.type = type
		task.building_id = id
		task.cell = b.cell
		task.work_needed = float(cfg()["feed_minutes" if type == "feed" else "collect_minutes"])
		village.tasks.add(task)


## 1日ぶんのえさの量
func feed_needed(barn: Dictionary) -> int:
	var total: float = 0.0
	for species: String in barn["animals"]:
		total += float(cfg()["animals"][species]["feed_per_day"]) * int(barn["animals"][species])
	return maxi(1, ceili(total))


func plan_for_task(_v: Villager, task: JobTask) -> Array[Dictionary]:
	if task.type in ["sow", "harvest", "collect"]:
		return [{"op": "goto", "target": task.cell, "adjacent": true, "building": task.building_id}, {"op": "work"}]
	if task.type == "feed":
		return [{"op": "supply"}]
	return []


func supply_site(task: JobTask) -> Dictionary:
	if task.type != "feed":
		return {}
	var barn: Dictionary = barns.get(task.building_id, {})
	if barn.is_empty():
		return {"cell": Village.NO_CELL, "missing": {}, "error": "unreachable"}
	var delivered: int = int(task.extra.get("delivered", {}).get(str(cfg()["feed_item"]), 0))
	var lack: int = feed_needed(barn) - delivered
	var missing: Dictionary = {str(cfg()["feed_item"]): lack} if lack > 0 else {}
	return {"cell": (village.buildings[task.building_id] as Building).cell, "missing": missing, "building": task.building_id}


func complete_task(v: Villager, task: JobTask) -> bool:
	match task.type:
		"sow":
			var f: Dictionary = fields.get(task.building_id, {})
			if not f.is_empty():
				f["stage"] = "growing"
				f["growth"] = 0.0
			return true
		"harvest":
			var f: Dictionary = fields.get(task.building_id, {})
			if not f.is_empty() and f["stage"] == "ripe":
				var crop_yield: Dictionary = cfg()["crops"][f["crop"]]["yield"]
				for item: String in crop_yield:
					village.drop_on_ground(v.cell(), item, int(crop_yield[item]))
				f["stage"] = "empty"
				f["growth"] = 0.0
			return true
		"feed":
			var barn: Dictionary = barns.get(task.building_id, {})
			if not barn.is_empty():
				barn["fed_until"] = maxf(float(barn["fed_until"]), village.clock.minutes) + GameClock.MINUTES_PER_DAY
			return true
		"collect":
			var barn: Dictionary = barns.get(task.building_id, {})
			if not barn.is_empty():
				var stock: Dictionary = barn["stock"]
				for item: String in stock:
					village.drop_on_ground(v.cell(), item, int(stock[item]))
				stock.clear()
			return true
	return false


func to_dict() -> Dictionary:
	var f: Dictionary = {}
	for id: int in fields:
		f[str(id)] = fields[id]
	var b: Dictionary = {}
	for id: int in barns:
		b[str(id)] = barns[id]
	return {"fields": f, "barns": b}


func from_dict(data: Dictionary) -> void:
	fields.clear()
	barns.clear()
	for id: String in data.get("fields", {}):
		fields[int(id)] = data["fields"][id]
	for id: String in data.get("barns", {}):
		barns[int(id)] = data["barns"][id]
