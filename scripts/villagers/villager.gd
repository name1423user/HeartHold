class_name Villager
extends RefCounted
## 村人1人の状態。行動は Village が plan(手順の列)で動かす。

enum State { NORMAL, UNCONSCIOUS, IN_TREATMENT, DEAD }

var id: int = 0
var display_name: String = ""
var job: String = "gatherer"
var pos: Vector2 = Vector2.ZERO
var needs := Needs.new()
var state: int = State.NORMAL
var is_chief: bool = false
var specialty: String = ""
var home_id: int = -1

## 今の行動。手順(Dictionary)の列と、その種類
var plan: Array[Dictionary] = []
var plan_kind: String = ""
var task_id: int = -1
var path: Array[Vector2i] = []
var sleeping: bool = false

var carry_item: String = ""
var carry_count: int = 0

## 道具・武器(M2-T09)。{"id": 装備ID, "durability": 残り} か空
var equipment: Dictionary = {"tool": {}, "weapon": {}, "clothes": {}}
## 作業の種類ごとの経験値(M2-T10)
var experience: Dictionary = {}
## 気絶・瀕死・治療の残り時間など(M3)
var timers: Dictionary = {}
## 最後に言った不満の一言(M4-T06)
var complaint: String = ""
## 個性(M7-T04)
var traits: Array = []
## 一言セリフ(US-017)と残り時間
var line: String = ""
## 年齢(年)と親(M7-T10)
var age: float = 25.0
var parents: Array = []
## 魔素量(M9-T05)
var mana: float = 0.0
## 食べた物の履歴(M7-T06)
var diet: Array = []


func cell() -> Vector2i:
	return Vector2i(floori(pos.x), floori(pos.y))


func place_at(target: Vector2i) -> void:
	pos = Vector2(target) + Vector2(0.5, 0.5)


func is_active() -> bool:
	return state == State.NORMAL


func clear_plan() -> void:
	plan.clear()
	plan_kind = ""
	task_id = -1
	path.clear()
	sleeping = false


func to_dict() -> Dictionary:
	return {
		"id": id, "name": display_name, "job": job, "pos": [pos.x, pos.y], "needs": needs.to_dict(),
		"state": state, "is_chief": is_chief, "specialty": specialty, "home_id": home_id,
		"carry_item": carry_item, "carry_count": carry_count, "equipment": equipment.duplicate(true),
		"experience": experience.duplicate(), "timers": timers.duplicate(), "task_id": task_id,
		"traits": traits.duplicate(), "age": age, "parents": parents.duplicate(), "mana": mana, "diet": diet.duplicate(),
	}


static func from_dict(data: Dictionary) -> Villager:
	var v := Villager.new()
	v.id = int(data["id"])
	v.display_name = str(data["name"])
	v.job = str(data["job"])
	v.pos = Vector2(float(data["pos"][0]), float(data["pos"][1]))
	v.needs.from_dict(data["needs"])
	v.state = int(data["state"])
	v.is_chief = bool(data["is_chief"])
	v.specialty = str(data.get("specialty", ""))
	v.home_id = int(data.get("home_id", -1))
	v.carry_item = str(data.get("carry_item", ""))
	v.carry_count = int(data.get("carry_count", 0))
	v.equipment = (data.get("equipment", {"tool": {}, "weapon": {}}) as Dictionary).duplicate(true)
	v.experience = (data.get("experience", {}) as Dictionary).duplicate()
	v.timers = (data.get("timers", {}) as Dictionary).duplicate()
	v.traits = (data.get("traits", []) as Array).duplicate()
	v.age = float(data.get("age", 25.0))
	v.parents = (data.get("parents", []) as Array).duplicate()
	v.mana = float(data.get("mana", 0.0))
	v.diet = (data.get("diet", []) as Array).duplicate()
	for slot in ["tool", "weapon", "clothes"]:
		if not v.equipment.has(slot):
			v.equipment[slot] = {}
	return v
