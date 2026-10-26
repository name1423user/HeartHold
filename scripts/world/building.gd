class_name Building
extends RefCounted
## 建物1つ。予約 → 建設中 → 完成。倉庫は在庫も持つ。種類ごとの定義は data/buildings.json。

enum State { PLANNED, BUILDING, COMPLETE }

var id: int = 0
var type: String = ""
var cell: Vector2i = Vector2i.ZERO
var state: int = State.PLANNED
## 運び込まれた素材
var delivered: Dictionary = {}
var progress: float = 0.0
## 倉庫の在庫
var inventory: Dictionary = {}
## 倉庫に置ける物の分類(空なら全部)と優先度(M2-T11)
var filter: Array = []
var priority: int = 0
## 設置済みの設備(M2-T12)。設備ID の列
var fixtures: Array = []
## 素材不足で建設が止まっている(不足アイコンを出す)
var short: bool = false
## 耐久(M8-T06)。0で壊れる(柵・壁・門は消える)
var hp: float = -1.0
var broken: bool = false


func def() -> Dictionary:
	return GameData.get_dict("buildings").get(type, {})


func size() -> Vector2i:
	var s: Array = def().get("size", [1, 1])
	return Vector2i(int(s[0]), int(s[1]))


func cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var s: Vector2i = size()
	for dz in s.y:
		for dx in s.x:
			result.append(cell + Vector2i(dx, dz))
	return result


func center() -> Vector2:
	return Vector2(cell) + Vector2(size()) * 0.5


## 完成していて、壊れていない(使える)
func is_complete() -> bool:
	return state == State.COMPLETE and not broken


func max_hp() -> float:
	return float(def().get("hp", 100.0)) * BuildingFixture.product_effect(self, "hp_multiplier")


func current_hp() -> float:
	return max_hp() if hp < 0.0 else hp


func display_name() -> String:
	return str(def().get("name", type))


func materials() -> Dictionary:
	return def().get("materials", {})


func missing_materials() -> Dictionary:
	var missing: Dictionary = {}
	var needed: Dictionary = materials()
	for item: String in needed:
		var lack: int = int(needed[item]) - int(delivered.get(item, 0))
		if lack > 0:
			missing[item] = lack
	return missing


func capacity() -> int:
	return int(float(def().get("capacity", 0)) * (1.0 + BuildingFixture.sum_effect(self, "capacity_bonus")))


func stored_total() -> int:
	var total: int = 0
	for item: String in inventory:
		total += int(inventory[item])
	return total


func free_space() -> int:
	return capacity() - stored_total()


func to_dict() -> Dictionary:
	return {
		"id": id, "type": type, "cell": [cell.x, cell.y], "state": state, "delivered": delivered.duplicate(),
		"progress": progress, "inventory": inventory.duplicate(), "filter": filter.duplicate(),
		"priority": priority, "fixtures": fixtures.duplicate(), "hp": hp, "broken": broken,
	}


static func from_dict(data: Dictionary) -> Building:
	var b := Building.new()
	b.id = int(data["id"])
	b.type = str(data["type"])
	b.cell = Vector2i(int(data["cell"][0]), int(data["cell"][1]))
	b.state = int(data["state"])
	b.delivered = _int_dict(data["delivered"])
	b.progress = float(data["progress"])
	b.inventory = _int_dict(data["inventory"])
	b.filter = (data.get("filter", []) as Array).duplicate()
	b.priority = int(data.get("priority", 0))
	b.fixtures = (data.get("fixtures", []) as Array).duplicate()
	b.hp = float(data.get("hp", -1.0))
	b.broken = bool(data.get("broken", false))
	return b


static func _int_dict(source: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key: String in source:
		out[key] = int(source[key])
	return out
