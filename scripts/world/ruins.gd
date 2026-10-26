class_name Ruins
extends RefCounted
## 遺跡の跡(AC-048)。生成時に霧の中へ3〜5か所置く(シードで決まる)。
## 村人の視界に入ると発見の警告が出て、調べると資源の詰め合わせが1回だけ手に入る。

var village: Village
var cfg: Dictionary = {}
## [{"id", "cell": Vector2i, "reward": int, "discovered": bool, "looted": bool}]
var sites: Array[Dictionary] = []


func _init(target: Village) -> void:
	village = target
	cfg = GameData.get_dict("ruins")
	_generate()


func _generate() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = village.world.seed + 3
	var range_count: Array = cfg["count"]
	var count: int = rng.randi_range(int(range_count[0]), int(range_count[1]))
	var world: WorldData = village.world
	var attempts: int = 0
	while sites.size() < count and attempts < 2000:
		attempts += 1
		var cell := Vector2i(rng.randi_range(4, world.size.x - 5), rng.randi_range(4, world.size.z - 5))
		if not world.is_walkable(cell) or Vector2(cell).distance_to(Vector2(world.start)) < float(cfg["min_distance"]):
			continue
		if village.fog.is_explored(cell) or sites.any(func(s: Dictionary) -> bool: return Vector2(s["cell"]).distance_to(Vector2(cell)) < 20.0):
			continue
		sites.append({"id": sites.size() + 1, "cell": cell, "reward": rng.randi_range(0, (cfg["rewards"] as Array).size() - 1), "discovered": false, "looted": false})


func update() -> void:
	for site in sites:
		if site["discovered"] or not village.fog.is_visible(site["cell"]):
			continue
		site["discovered"] = true
		village.raise_alert("ruin", Texts.t("alert_ruin_found"), site["cell"])
		var task := JobTask.new()
		task.type = "investigate"
		task.cell = site["cell"]
		task.work_needed = float(cfg["investigate_minutes"])
		task.extra["ruin"] = site["id"]
		village.tasks.add(task)


func site(id: int) -> Dictionary:
	for s in sites:
		if int(s["id"]) == id:
			return s
	return {}


## 調べ終えたら詰め合わせをその場に置く(倉庫へは運搬で運ばれる)。2回目はない
func loot(id: int, at: Vector2i) -> void:
	var s: Dictionary = site(id)
	if s.is_empty() or s["looted"]:
		return
	s["looted"] = true
	var reward: Dictionary = cfg["rewards"][int(s["reward"])]
	for item: String in reward:
		village.drop_on_ground(at, item, int(reward[item]))
	village.raise_alert("ruin_looted", Texts.t("alert_ruin_looted"), s["cell"])


func to_dict() -> Array:
	var list: Array = []
	for s in sites:
		list.append({"id": s["id"], "cell": [s["cell"].x, s["cell"].y], "reward": s["reward"], "discovered": s["discovered"], "looted": s["looted"]})
	return list


func from_dict(list: Array) -> void:
	sites.clear()
	for entry: Dictionary in list:
		sites.append({"id": int(entry["id"]), "cell": Vector2i(int(entry["cell"][0]), int(entry["cell"][1])), "reward": int(entry["reward"]), "discovered": bool(entry["discovered"]), "looted": bool(entry["looted"])})
