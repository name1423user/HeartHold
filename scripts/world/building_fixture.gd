class_name BuildingFixture
extends RefCounted
## 建物の設備(AC-043, AC-045)。種類・効果・素材・上限は data/fixtures.json(元は BUILDINGS.md の設備表)。


static func defs() -> Dictionary:
	return GameData.get_dict("fixtures")


static func def(fixture: String) -> Dictionary:
	return defs().get(fixture, {})


static func limit(b: Building, fixture: String) -> int:
	var value: Variant = def(fixture).get("limit", 1)
	if str(value) == "residents":
		return int(b.def().get("residents", 0))
	return int(value)


static func count_group(b: Building, group: String) -> int:
	return b.fixtures.filter(func(f: String) -> bool: return str(def(f).get("group", "")) == group).size()


## 完成した建物に最初から付いている設備
static func install_initial(b: Building) -> void:
	for fixture: String in defs():
		var d: Dictionary = def(fixture)
		if d.get("building", "") != b.type or not d.has("initial"):
			continue
		var count: int = limit(b, fixture) if str(d["initial"]) == "residents" else int(d["initial"])
		for i in count:
			b.fixtures.append(fixture)


## 置けない理由の文言キー。置けるなら空
static func error(b: Building, fixture: String) -> String:
	var d: Dictionary = def(fixture)
	if d.is_empty() or d.get("building", "") != b.type:
		return "fixture_wrong_building"
	if not b.is_complete():
		return "fixture_not_built"
	if d.has("upgrade_of"):
		return "" if b.fixtures.has(str(d["upgrade_of"])) else "fixture_limit"
	if count_group(b, str(d["group"])) >= limit(b, fixture):
		return "fixture_limit"
	return ""


## 建物を選んだときに出す一覧: [{"id", "name", "materials", "ok", "reason"}]
static func options(b: Building) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for fixture: String in defs():
		var d: Dictionary = def(fixture)
		if d.get("building", "") != b.type:
			continue
		var reason: String = error(b, fixture)
		result.append({"id": fixture, "name": str(d["name"]), "materials": d["materials"], "ok": reason.is_empty(), "reason": Texts.t(reason) if not reason.is_empty() else ""})
	return result


## 設備の建設予約。建築係が素材を運んで設置する
static func order(village: Village, b: Building, fixture: String) -> Dictionary:
	var reason: String = error(b, fixture)
	if reason.is_empty():
		var pending: int = 0
		for task: JobTask in village.tasks.of_type("fixture"):
			if task.building_id == b.id and str(task.extra["fixture"]) == fixture:
				pending += 1
		var d: Dictionary = def(fixture)
		var room: int = b.fixtures.count(str(d["upgrade_of"])) if d.has("upgrade_of") else limit(b, fixture) - count_group(b, str(d["group"]))
		if pending >= room:
			reason = "fixture_limit"
	if not reason.is_empty():
		return {"ok": false, "message": Texts.t(reason)}
	var task := JobTask.new()
	task.type = "fixture"
	task.building_id = b.id
	task.cell = b.cell
	task.work_needed = float(def(fixture).get("work", 10.0))
	task.extra["fixture"] = fixture
	village.tasks.add(task)
	return {"ok": true, "task": task}


static func supply_site(village: Village, task: JobTask) -> Dictionary:
	var b: Building = village.buildings.get(task.building_id) as Building
	if b == null:
		return {"cell": Village.NO_CELL, "missing": {}, "error": "unreachable"}
	var delivered: Dictionary = task.extra.get("delivered", {})
	var missing: Dictionary = {}
	var materials: Dictionary = def(str(task.extra["fixture"]))["materials"]
	for item: String in materials:
		var lack: int = int(materials[item]) - int(delivered.get(item, 0))
		if lack > 0:
			missing[item] = lack
	return {"cell": b.cell, "missing": missing, "building": b.id}


static func complete(village: Village, task: JobTask) -> void:
	var b: Building = village.buildings.get(task.building_id) as Building
	if b == null:
		return
	var fixture: String = str(task.extra["fixture"])
	var d: Dictionary = def(fixture)
	if d.has("upgrade_of"):
		b.fixtures.erase(str(d["upgrade_of"]))
	b.fixtures.append(fixture)
	village.building_changed.emit(b)


## 効果の合計(足し算)。effect は fixtures.json の effects のキー
static func sum_effect(b: Building, effect: String) -> float:
	var total: float = 0.0
	for fixture: String in b.fixtures:
		total += float(def(fixture).get("effects", {}).get(effect, 0.0))
	return total


## 効果の積(掛け算)。設備がなければ 1.0
static func product_effect(b: Building, effect: String) -> float:
	var total: float = 1.0
	for fixture: String in b.fixtures:
		total *= float(def(fixture).get("effects", {}).get(effect, 1.0))
	return total


## 住人それぞれの寝床の睡眠回復倍率。良いベッドから順に住人へ割り当てる
static func bed_multiplier_for(village: Village, b: Building, v: Villager) -> float:
	var beds: Array = b.fixtures.filter(func(f: String) -> bool: return str(def(f).get("group", "")) == "bed")
	var values: Array = beds.map(func(f: String) -> float: return float(def(f)["effects"]["sleep_multiplier"]))
	values.sort()
	values.reverse()
	var index: int = village.residents_of(b).find(v)
	if index < 0 or index >= values.size():
		return float(village.needs_cfg["ground_sleep_multiplier"])
	return float(values[index])
