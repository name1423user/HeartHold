class_name Crafting
extends RefCounted
## レシピ方式の加工(AC-010)。レシピは data/recipes.json で、コードを変えずに足せる。


static func recipe(recipe_id: String) -> Dictionary:
	return GameData.get_dict("recipes").get(recipe_id, {})


## 加工の予約。count 回ぶんの仕事を積む。戻り値は作った仕事の数
static func order(village: Village, recipe_id: String, count: int = 1) -> int:
	var r: Dictionary = recipe(recipe_id)
	if r.is_empty():
		return 0
	for i in count:
		var task := JobTask.new()
		task.type = "craft"
		task.recipe = recipe_id
		task.work_needed = float(r["work"])
		var station: Building = find_station(village, str(r["station"]))
		task.cell = station.cell if station != null else village.world.start
		village.tasks.add(task)
	return count


static func find_station(village: Village, station_type: String) -> Building:
	for b: Building in village.buildings.values():
		if b.type == station_type and b.is_complete():
			return b
	return null


## 素材の置き場(作業台)と、まだ運び込まれていない素材
static func supply_site(village: Village, task: JobTask) -> Dictionary:
	var r: Dictionary = recipe(task.recipe)
	var station: Building = find_station(village, str(r["station"]))
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
