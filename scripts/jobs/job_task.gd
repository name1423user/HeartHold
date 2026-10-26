class_name JobTask
extends RefCounted
## 村人が拾う仕事1つ(伐る・掘る・建てる・加工・狩りなど)。

var id: int = 0
var type: String = ""
## 対象の列。掘るときは pos も使う
var cell: Vector2i = Vector2i.ZERO
var pos: Vector3i = Vector3i.ZERO
var building_id: int = -1
var recipe: String = ""
var work_needed: float = 0.0
var progress: float = 0.0
var assigned: int = -1
## 保留の理由(文言キー)。空なら拾える
var blocked_reason: String = ""
var retry_at: float = 0.0
var extra: Dictionary = {}


func is_available(now: float) -> bool:
	return assigned == -1 and (blocked_reason.is_empty() or now >= retry_at)


func to_dict() -> Dictionary:
	return {
		"id": id, "type": type, "cell": [cell.x, cell.y], "pos": [pos.x, pos.y, pos.z], "building_id": building_id,
		"recipe": recipe, "work_needed": work_needed, "progress": progress, "blocked_reason": blocked_reason,
		"retry_at": retry_at, "extra": extra.duplicate(true),
	}


static func from_dict(data: Dictionary) -> JobTask:
	var t := JobTask.new()
	t.id = int(data["id"])
	t.type = str(data["type"])
	t.cell = Vector2i(int(data["cell"][0]), int(data["cell"][1]))
	t.pos = Vector3i(int(data["pos"][0]), int(data["pos"][1]), int(data["pos"][2]))
	t.building_id = int(data["building_id"])
	t.recipe = str(data["recipe"])
	t.work_needed = float(data["work_needed"])
	t.progress = float(data["progress"])
	t.blocked_reason = str(data["blocked_reason"])
	t.retry_at = float(data["retry_at"])
	t.extra = (data.get("extra", {}) as Dictionary).duplicate(true)
	return t
