class_name Wildlife
extends RefCounted
## ウサギ(獲物)。うろつき、狩人に狩られると肉と毛皮を落とす。数値は data/wildlife.json。

var village: Village
var cfg: Dictionary = {}
## 生きているウサギ。id -> {"pos": Vector2, "move_timer": float}
var animals: Dictionary = {}
var next_id: int = 1
var respawn_timer: float = 0.0


func _init(target: Village) -> void:
	village = target
	cfg = GameData.get_dict("wildlife")["rabbit"]
	for i in int(cfg["count"]):
		spawn()


func spawn() -> int:
	var world: WorldData = village.world
	for attempt in 50:
		var cell := Vector2i(village.rng.randi_range(0, world.size.x - 1), village.rng.randi_range(0, world.size.z - 1))
		if world.is_walkable(cell) and Vector2(cell).distance_to(Vector2(world.start)) >= float(cfg["min_distance_from_start"]):
			animals[next_id] = {"pos": Vector2(cell) + Vector2(0.5, 0.5), "move_timer": village.rng.randf() * float(cfg["move_interval_minutes"])}
			next_id += 1
			return next_id - 1
	return -1


func cell_of(id: int) -> Vector2i:
	var pos: Vector2 = animals[id]["pos"]
	return Vector2i(floori(pos.x), floori(pos.y))


func update(dt: float) -> void:
	for id: int in animals:
		var animal: Dictionary = animals[id]
		animal["move_timer"] = float(animal["move_timer"]) - dt
		if float(animal["move_timer"]) > 0.0:
			continue
		animal["move_timer"] = float(cfg["move_interval_minutes"])
		var here: Vector2i = cell_of(id)
		var next: Vector2i = here + Pathing.NEIGHBORS[village.rng.randi_range(0, 3)]
		if village.world.is_walkable(next) and absi(village.world.top_y(next) - village.world.top_y(here)) <= 1:
			animal["pos"] = Vector2(next) + Vector2(0.5, 0.5)
	if animals.size() < int(cfg["count"]):
		respawn_timer += dt
		if respawn_timer >= float(cfg["respawn_minutes"]):
			respawn_timer = 0.0
			spawn()
	_keep_hunt_tasks()


## 狩人の数だけ、近いウサギの狩りを予約しておく
func _keep_hunt_tasks() -> void:
	var hunters: int = 0
	for v in village.living_villagers():
		if v.job == "hunter":
			hunters += 1
	var tasks: Array[JobTask] = village.tasks.of_type("hunt")
	for task in tasks:
		if not animals.has(int(task.extra["animal"])):
			village.tasks.remove(task.id)
	tasks = village.tasks.of_type("hunt")
	if tasks.size() >= hunters:
		return
	var targeted: Dictionary = {}
	for task in tasks:
		targeted[int(task.extra["animal"])] = true
	var candidates: Array = animals.keys().filter(func(id: int) -> bool: return not targeted.has(id))
	var start := Vector2(village.world.start)
	candidates.sort_custom(func(a: int, b: int) -> bool: return start.distance_to(animals[a]["pos"]) < start.distance_to(animals[b]["pos"]))
	for i in mini(hunters - tasks.size(), candidates.size()):
		var task := JobTask.new()
		task.type = "hunt"
		task.cell = cell_of(candidates[i])
		task.work_needed = float(cfg["hunt_work_minutes"])
		task.extra["animal"] = candidates[i]
		village.tasks.add(task)


## 狩りの手順。ウサギを追いかけ、届いたら仕留める。使った時間を返す(-1 は失敗)
func step_hunt(v: Villager, task: JobTask, budget: float) -> float:
	var id: int = int(task.extra["animal"])
	if not animals.has(id):
		v.plan.pop_front()
		return 0.0
	var target: Vector2 = animals[id]["pos"]
	if v.pos.distance_to(target) <= float(cfg["hunt_reach"]):
		task.progress += village.work_speed(v, "hunt") * budget
		village.gain_experience(v, "hunt", budget)
		if task.progress >= task.work_needed:
			v.plan.pop_front()
			village.tasks.remove(task.id)
			v.task_id = -1
			kill(v, id)
		return budget
	var target_cell := Vector2i(floori(target.x), floori(target.y))
	if v.path.is_empty() or v.path[-1] != target_cell:
		v.path = village.pathing.find_path(v.cell(), target_cell)
		if v.path.is_empty():
			return -1.0
		v.path.pop_front()
	if v.path.is_empty():
		return budget
	var next_pos: Vector2 = Vector2(v.path[0]) + Vector2(0.5, 0.5)
	var step: float = village.walk_speed(v) * budget
	if v.pos.distance_to(next_pos) <= step:
		v.pos = next_pos
		v.path.pop_front()
	else:
		v.pos = v.pos.move_toward(next_pos, step)
	return budget


## 仕留めて、落とした物を1種類ずつ倉庫へ運ぶ手順を積む
func kill(v: Villager, id: int) -> void:
	var drops: Dictionary = cfg["drops"]
	var cell: Vector2i = cell_of(id)
	animals.erase(id)
	var steps: Array[Dictionary] = []
	for item: String in drops:
		village.drop_on_ground(cell, item, int(drops[item]))
		steps.append({"op": "take", "source": {"kind": "ground", "cell": cell}, "item": item, "count": int(drops[item])})
		steps.append({"op": "store_carry"})
		steps.append({"op": "goto", "target": cell, "adjacent": false})
	steps.pop_back()
	for i in range(steps.size() - 1, -1, -1):
		v.plan.push_front(steps[i])
	village.wear_tool(v, "hunt")


func to_dict() -> Dictionary:
	var list: Array = []
	for id: int in animals:
		var pos: Vector2 = animals[id]["pos"]
		list.append([id, pos.x, pos.y])
	return {"animals": list, "next_id": next_id, "respawn_timer": respawn_timer}


func from_dict(data: Dictionary) -> void:
	animals.clear()
	for entry: Array in data["animals"]:
		animals[int(entry[0])] = {"pos": Vector2(float(entry[1]), float(entry[2])), "move_timer": 0.0}
	next_id = int(data["next_id"])
	respawn_timer = float(data["respawn_timer"])
