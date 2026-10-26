class_name TaskQueue
extends RefCounted
## 予約された仕事の一覧。

var tasks: Dictionary = {}
var next_id: int = 1


func add(task: JobTask) -> JobTask:
	task.id = next_id
	next_id += 1
	tasks[task.id] = task
	return task


func get_task(id: int) -> JobTask:
	return tasks.get(id) as JobTask


func remove(id: int) -> void:
	tasks.erase(id)


func has_type_at(type: String, cell: Vector2i) -> bool:
	for task: JobTask in tasks.values():
		if task.type == type and task.cell == cell:
			return true
	return false


## types の順に、拾える仕事を近い順で探す
func find_for(types: Array, from: Vector2i, now: float) -> JobTask:
	for type: String in types:
		var best: JobTask = null
		var best_distance: int = 1 << 30
		for task: JobTask in tasks.values():
			if task.type != type or not task.is_available(now):
				continue
			var distance: int = absi(task.cell.x - from.x) + absi(task.cell.y - from.y)
			if distance < best_distance:
				best = task
				best_distance = distance
		if best != null:
			return best
	return null


func of_type(type: String) -> Array[JobTask]:
	var result: Array[JobTask] = []
	for task: JobTask in tasks.values():
		if task.type == type:
			result.append(task)
	return result
