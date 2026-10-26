class_name Nests
extends VillageSystem
## 魔物の巣(M9-T03)。生成時に霧の中に置かれ(シードで決まる)、襲撃は残っている巣から来る。
## 視察隊が巣を潰すと襲撃が減る。

## [{"id", "cell", "hp", "destroyed", "discovered", "defenders_spawned"}]
var sites: Array[Dictionary] = []


func _init(target: Village) -> void:
	super(target)
	_generate()


func key() -> String:
	return "nests"


static func cfg() -> Dictionary:
	return GameData.get_dict("nests")


func _generate() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = village.world.seed + 5
	var range_count: Array = cfg()["count"]
	var count: int = rng.randi_range(int(range_count[0]), int(range_count[1]))
	var world: WorldData = village.world
	var guard: int = 0
	while sites.size() < count and guard < 3000:
		guard += 1
		var cell := Vector2i(rng.randi_range(4, world.size.x - 5), rng.randi_range(4, world.size.z - 5))
		if not world.is_walkable(cell) or Vector2(cell).distance_to(Vector2(world.start)) < float(cfg()["min_distance"]):
			continue
		if not village.pathing.is_reachable(cell, world.start):
			continue
		if sites.any(func(s: Dictionary) -> bool: return Vector2(s["cell"]).distance_to(Vector2(cell)) < 30.0):
			continue
		sites.append({"id": sites.size() + 1, "cell": cell, "hp": float(cfg()["hp"]), "destroyed": false, "discovered": false, "defenders_spawned": false})


func active_count() -> int:
	return sites.filter(func(s: Dictionary) -> bool: return not s["destroyed"]).size()


func nest_at(cell: Vector2i, radius: float = 3.0) -> Dictionary:
	for s in sites:
		if not s["destroyed"] and Vector2(s["cell"]).distance_to(Vector2(cell)) <= radius:
			return s
	return {}


func update(_dt: float) -> void:
	for s in sites:
		if not s["discovered"] and village.fog.is_visible(s["cell"]):
			s["discovered"] = true
			village.raise_alert("nest", Texts.t("alert_nest_found"), s["cell"])


## 視察隊が近づいたら守りの魔物が出てくる
func spawn_defenders(s: Dictionary) -> void:
	if s["defenders_spawned"]:
		return
	s["defenders_spawned"] = true
	for i in int(cfg()["defenders"]):
		var m := Monster.new()
		m.id = village.raids.next_monster_id
		village.raids.next_monster_id += 1
		m.setup(str(cfg()["defender"]))
		m.pos = Vector2(s["cell"]) + Vector2(0.5 + i % 2, 0.5 + i / 2)
		m.set_meta("nest", s["id"])
		m.set_meta("home", s["cell"])
		village.raids.monsters.append(m)


func damage(s: Dictionary, amount: float) -> void:
	s["hp"] = float(s["hp"]) - amount
	if float(s["hp"]) <= 0.0 and not s["destroyed"]:
		s["destroyed"] = true
		village.raise_alert("nest_destroyed", Texts.t("alert_nest_destroyed"), s["cell"])
		(village.system("reputation") as Reputation).change(5.0, "nest")


func to_dict() -> Dictionary:
	var list: Array = []
	for s in sites:
		list.append({"id": s["id"], "cell": [s["cell"].x, s["cell"].y], "hp": s["hp"], "destroyed": s["destroyed"], "discovered": s["discovered"], "defenders_spawned": s["defenders_spawned"]})
	return {"sites": list}


func from_dict(data: Dictionary) -> void:
	if not data.has("sites"):
		return
	sites.clear()
	for e: Dictionary in data["sites"]:
		sites.append({"id": int(e["id"]), "cell": Vector2i(int(e["cell"][0]), int(e["cell"][1])), "hp": float(e["hp"]), "destroyed": bool(e["destroyed"]), "discovered": bool(e["discovered"]), "defenders_spawned": bool(e["defenders_spawned"])})
