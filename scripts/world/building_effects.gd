class_name BuildingEffects
extends VillageSystem
## 建物の効果(M8-T04, M8-T07)。data/buildings.json の effects を村全体にかける:
## 作業速度(狩猟小屋・水車)、熟練度の伸び(兵舎・学舎)、審査の安全・満足度、評判(村の象徴)。
## 隣り合わせのボーナス(焚き火の近くの家は気分の回復が上がる、data/adjacency.json)もここ。


func key() -> String:
	return "building_effects"


func _complete_buildings() -> Array[Building]:
	var result: Array[Building] = []
	for b: Building in village.buildings.values():
		if b.is_complete():
			result.append(b)
	return result


func effect(b: Building) -> Dictionary:
	return b.def().get("effects", {})


func work_speed(_v: Villager, kind: String) -> float:
	var speed: float = 1.0
	var seen: Dictionary = {}
	for b in _complete_buildings():
		if seen.has(b.type):
			continue
		var table: Dictionary = effect(b).get("work_speed", {})
		if table.has(kind):
			speed *= float(table[kind])
			seen[b.type] = true
	return speed


## 熟練度の伸びの倍率("*" はすべての作業)
func experience_rate(kind: String) -> float:
	var rate: float = 1.0
	var seen: Dictionary = {}
	for b in _complete_buildings():
		if seen.has(b.type):
			continue
		var table: Dictionary = effect(b).get("experience_rate", {})
		if table.has(kind) or table.has("*"):
			rate *= float(table.get(kind, table.get("*", 1.0)))
			seen[b.type] = true
	return rate


## 審査の点に足す値(safety / satisfaction / inspection_bonus)
func score_bonus(key_name: String) -> float:
	var total: float = 0.0
	for b in _complete_buildings():
		total += float(effect(b).get(key_name, 0.0))
	return total


func mood_rate(v: Villager) -> float:
	var home: Building = village.buildings.get(v.home_id) as Building
	if home == null or not home.is_complete():
		return 1.0
	var rate: float = 1.0
	for rule: Dictionary in GameData.get_dict("adjacency")["rules"]:
		if rule["building"] == home.type and village.near_building_type(home.center(), str(rule["near"]), float(rule["radius"])):
			rate += float(rule["mood_rate"])
	return rate


func on_building_completed(b: Building) -> void:
	var rep: float = float(effect(b).get("reputation", 0.0))
	if rep != 0.0:
		(village.system("reputation") as Reputation).change(rep, "landmark")


## 村の象徴(landmark)はすでにあるか
func has_landmark() -> bool:
	for b: Building in village.buildings.values():
		if bool(b.def().get("landmark", false)):
			return true
	return false
