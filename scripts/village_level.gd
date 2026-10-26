class_name VillageLevel
extends RefCounted
## 村レベルと節目の課題(AC-025)。課題を全部満たすとレベルが上がり、通知が出る。
## 時代(AS-010)はデータの構造だけ用意し、MVP は石と木の時代のみ。課題は data/milestones.json。

signal level_up(level: int)

var village: Village
var level: int = 0
var cfg: Dictionary = {}


func _init(target: Village) -> void:
	village = target
	cfg = GameData.get_dict("milestones")
	level = int(cfg["start_level"])


func next_entry() -> Dictionary:
	for entry: Dictionary in cfg["levels"]:
		if int(entry["level"]) == level + 1:
			return entry
	return {}


func current_era() -> String:
	for entry: Dictionary in cfg["levels"]:
		if int(entry["level"]) == level:
			return str(entry["era"])
	return "stone"


func era_name() -> String:
	return str(cfg["eras"][current_era()]["name"])


## 次のレベルの課題と達成状況: [{"label", "done"}]
func goals() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for goal: Dictionary in next_entry().get("goals", []):
		result.append({"label": str(goal["label"]), "done": is_met(goal)})
	return result


func is_met(goal: Dictionary) -> bool:
	match str(goal["type"]):
		"building_count":
			var count: int = 0
			for b: Building in village.buildings.values():
				if b.type == goal["building"] and b.is_complete():
					count += 1
			return count >= int(goal["count"])
		"residents":
			return residents() >= int(goal["count"])
		"satisfaction":
			return ScoreCard.satisfaction_score(village) >= float(goal["value"])
		"food_days":
			return FoodStock.days_left(village) >= int(goal["days"])
	return false


## 住人の数(村長は数えない)
func residents() -> int:
	return village.living_villagers().filter(func(v: Villager) -> bool: return not v.is_chief).size()


func update() -> void:
	var entry: Dictionary = next_entry()
	if entry.is_empty():
		return
	for goal: Dictionary in entry["goals"]:
		if not is_met(goal):
			return
	level = int(entry["level"])
	village.raise_alert("level", Texts.t("alert_level_up", {"level": level, "name": entry["name"]}), village.world.start)
	level_up.emit(level)
