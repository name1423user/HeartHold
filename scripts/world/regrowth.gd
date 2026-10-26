class_name Regrowth
extends VillageSystem
## 資源の再生(M7-T07)。苗木は季節の育ち(冬は止まる)に合わせて育ち、木になる。
## 森の木は少しずつ周りに広がる。プレイヤーは「植える」範囲指示で植林できる。

## 苗木: Vector2i -> 育ち(0〜1)
var saplings: Dictionary = {}
var _spread: float = 0.0


func key() -> String:
	return "regrowth"


func cfg() -> Dictionary:
	return GameData.get_dict("regrowth")


func update(dt: float) -> void:
	var growth: float = village.calendar().growth()
	var step: float = dt * growth / (float(cfg()["grow_days"]) * GameClock.MINUTES_PER_DAY)
	var grown: Array = []
	for cell: Vector2i in saplings:
		saplings[cell] = float(saplings[cell]) + step
		if float(saplings[cell]) >= 1.0:
			grown.append(cell)
	for cell: Vector2i in grown:
		saplings.erase(cell)
		if village.world.is_walkable(cell):
			village.world.trees[cell] = true
			village.pathing.update_cell(cell)
	if not grown.is_empty():
		village.trees_changed.emit()
	_spread += village.world.trees.size() * float(cfg()["spread_per_tree_per_day"]) * growth * dt / GameClock.MINUTES_PER_DAY
	while _spread >= 1.0:
		_spread -= 1.0
		_spread_one()


func _spread_one() -> void:
	var trees: Array = village.world.trees.keys()
	if trees.is_empty():
		return
	var origin: Vector2i = trees[village.rng.randi_range(0, trees.size() - 1)]
	var r: int = int(cfg()["spread_radius"])
	var cell: Vector2i = origin + Vector2i(village.rng.randi_range(-r, r), village.rng.randi_range(-r, r))
	if can_plant(cell) and village.world.biome_at(cell) == WorldData.Biome.FOREST:
		saplings[cell] = 0.0


func can_plant(cell: Vector2i) -> bool:
	var world: WorldData = village.world
	if not world.is_walkable(cell) or saplings.has(cell):
		return false
	var top: int = world.get_block(Vector3i(cell.x, world.top_y(cell), cell.y))
	return top == world.block_id("grass") or top == world.block_id("dirt")


## 「植える」範囲指示。1列おきに苗木の予約を積む(通り道を残す)
func plant_area(area: Rect2i) -> int:
	var created: int = 0
	for z in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			var cell := Vector2i(x, z)
			if (x + z) % 2 != 0 or not can_plant(cell) or village.tasks.has_type_at("plant", cell):
				continue
			var task := JobTask.new()
			task.type = "plant"
			task.cell = cell
			task.work_needed = float(cfg()["plant_minutes"])
			village.tasks.add(task)
			created += 1
	return created


func complete_task(_v: Villager, task: JobTask) -> bool:
	if task.type != "plant":
		return false
	if can_plant(task.cell):
		saplings[task.cell] = 0.0
	return true


func to_dict() -> Dictionary:
	var list: Array = []
	for cell: Vector2i in saplings:
		list.append([cell.x, cell.y, saplings[cell]])
	return {"saplings": list, "spread": _spread}


func from_dict(data: Dictionary) -> void:
	saplings.clear()
	for entry: Array in data.get("saplings", []):
		saplings[Vector2i(int(entry[0]), int(entry[1]))] = float(entry[2])
	_spread = float(data.get("spread", 0.0))
