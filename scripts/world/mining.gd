class_name Mining
extends VillageSystem
## 炭鉱(M8-T02)。炭鉱があると鉱夫が鉄鉱石と石炭を掘り出す(岩を削らなくてよい)。

var _turn: int = 0


func key() -> String:
	return "mining"


static func cfg() -> Dictionary:
	return {"minutes": 60.0, "outputs": [{"iron_ore": 2}, {"coal": 2}]}


func update(_dt: float) -> void:
	var mines: Array = village.buildings.values().filter(func(b: Building) -> bool: return b.type == "mine" and b.is_complete())
	if mines.is_empty():
		return
	var miners: int = village.living_villagers().filter(func(v: Villager) -> bool: return v.job == "miner").size()
	var tasks: Array[JobTask] = village.tasks.of_type("mine")
	for i in range(tasks.size(), mini(miners, mines.size() * 2)):
		var mine: Building = mines[i % mines.size()]
		var task := JobTask.new()
		task.type = "mine"
		task.building_id = mine.id
		task.cell = mine.cell
		task.work_needed = float(cfg()["minutes"])
		village.tasks.add(task)


func plan_for_task(_v: Villager, task: JobTask) -> Array[Dictionary]:
	if task.type != "mine":
		return []
	return [{"op": "goto", "target": task.cell, "adjacent": true, "building": task.building_id}, {"op": "work"}]


func complete_task(v: Villager, task: JobTask) -> bool:
	if task.type != "mine":
		return false
	var outputs: Array = cfg()["outputs"]
	var out: Dictionary = outputs[_turn % outputs.size()]
	_turn += 1
	village.give_or_drop(v, out)
	village.wear_tool(v, "dig")
	return true


func work_speed(v: Villager, kind: String) -> float:
	# 炭鉱の仕事にはつるはしが効く
	return Equipment.speed(v, "dig") if kind == "mine" else 1.0


func to_dict() -> Dictionary:
	return {"turn": _turn}


func from_dict(data: Dictionary) -> void:
	_turn = int(data.get("turn", 0))
