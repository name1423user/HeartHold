class_name Crafting
extends RefCounted
## レシピ方式の加工(AC-010)。レシピは data/recipes.json で、コードを変えずに足せる。


static func recipe(recipe_id: String) -> Dictionary:
	return GameData.get_dict("recipes").get(recipe_id, {})


## 予約できない理由の文言。できるなら空(時代と、専用台などの設備)
static func order_error(village: Village, recipe_id: String) -> String:
	var r: Dictionary = recipe(recipe_id)
	if r.is_empty():
		return "?"
	if not Era.allows(r, village.era()):
		return Texts.t("locked_era", {"era": Era.display_name(str(r.get("era", "stone")))})
	if r.has("requires_fixture") and find_station(village, str(r["station"]), str(r["requires_fixture"])) == null:
		return Texts.t("recipe_needs_fixture", {"name": BuildingFixture.def(str(r["requires_fixture"])).get("name", "")})
	return ""


## 加工の予約。count 回ぶんの仕事を積む。戻り値は作った仕事の数(時代が合わなければ0)
static func order(village: Village, recipe_id: String, count: int = 1) -> int:
	var r: Dictionary = recipe(recipe_id)
	if r.is_empty() or not order_error(village, recipe_id).is_empty():
		return 0
	for i in count:
		var task := JobTask.new()
		task.type = str(r.get("task_type", "craft"))
		task.recipe = recipe_id
		task.work_needed = float(r["work"])
		var station: Building = find_station(village, str(r["station"]), str(r.get("requires_fixture", "")))
		task.cell = station.cell if station != null else village.world.start
		village.tasks.add(task)
	return count


static func find_station(village: Village, station_type: String, fixture: String = "") -> Building:
	for b: Building in village.buildings.values():
		if b.type == station_type and b.is_complete() and (fixture.is_empty() or b.fixtures.has(fixture)):
			return b
	return null


## 素材の置き場(作業台)と、まだ運び込まれていない素材
static func supply_site(village: Village, task: JobTask) -> Dictionary:
	var r: Dictionary = recipe(task.recipe)
	var station: Building = find_station(village, str(r["station"]), str(r.get("requires_fixture", "")))
	if station == null:
		return {"cell": Village.NO_CELL, "missing": {}, "error": "no_station"}
	task.cell = station.cell
	var delivered: Dictionary = task.extra.get("delivered", {})
	var missing: Dictionary = {}
	var inputs: Dictionary = r["inputs"]
	for item: String in inputs:
		var lack: int = int(inputs[item]) - int(delivered.get(item, 0))
		if lack > 0:
			missing[item] = lack
	return {"cell": station.cell, "missing": missing, "building": station.id}


## 完成した品を作った村人に持たせる(その後、倉庫へ運ぶ)
static func complete(village: Village, v: Villager, task: JobTask) -> void:
	var outputs: Dictionary = recipe(task.recipe)["outputs"]
	for item: String in outputs:
		if v.carry_count > 0 and v.carry_item != item:
			village.drop_on_ground(v.cell(), v.carry_item, v.carry_count)
			v.carry_count = 0
		v.carry_item = item
		v.carry_count += int(outputs[item])
