class_name Monster
extends RefCounted
## 魔物1体(MVP はゴブリン、data/monsters.json)。村へ向かい、見つけた村人を襲う。夜は強い(UD-003)。

var id: int = 0
var type: String = ""
var pos: Vector2 = Vector2.ZERO
var hp: float = 0.0
var cooldown: float = 0.0
var path: Array[Vector2i] = []
var repath_timer: float = 0.0
## 罠で動けない残り時間
var stunned: float = 0.0
var _last_cell: Vector2i = Vector2i(-1, -1)


func def() -> Dictionary:
	return GameData.get_dict("monsters")[type]


func setup(monster_type: String) -> void:
	type = monster_type
	hp = float(def()["hp"])


func cell() -> Vector2i:
	return Vector2i(floori(pos.x), floori(pos.y))


func attack_power(village: Village) -> float:
	var power: float = float(def()["attack"])
	if village.clock.is_night():
		power *= float(def()["night_attack_multiplier"])
	return power


func take_damage(amount: float) -> void:
	hp -= amount


## 武器の系統ごとの効き(相性 M9-T01)
func affinity(weapon_kind: String) -> float:
	return float(def().get("affinity", {}).get(weapon_kind, 1.0))


func update(village: Village, dt: float) -> void:
	cooldown = maxf(0.0, cooldown - dt)
	if stunned > 0.0:
		stunned -= dt
		return
	if cell() != _last_cell:
		_last_cell = cell()
		(village.system("traps") as Traps).step_on(self)
	if bool(def().get("targets_buildings", false)) and _attack_buildings(village):
		return
	if int(def().get("steals", 0)) > 0 and _steal(village):
		return
	var target: Villager = _nearest_target(village)
	if target != null and pos.distance_to(target.pos) <= float(def()["range"]):
		if cooldown <= 0.0:
			cooldown = float(def()["attack_interval_minutes"])
			village.damage_villager(target, attack_power(village))
		return
	var goal: Vector2i = target.cell() if target != null else village.world.start
	# 巣の守りは巣のそばを離れない
	if target == null and has_meta("home"):
		goal = get_meta("home")
		if pos.distance_to(Vector2(goal)) < 3.0:
			return
	repath_timer -= dt
	if path.is_empty() or repath_timer <= 0.0:
		repath_timer = 5.0
		path = village.pathing.find_path(cell(), goal)
		if path.is_empty():
			path = village.pathing.find_path(cell(), village.pathing.nearest_standable(cell(), goal))
		if not path.is_empty():
			path.pop_front()
	if path.is_empty():
		# 道がなければ、近くの道をふさぐ建物(柵・壁・門)を叩く
		_attack_obstacle(village)
		return
	if village.world.blocked.has(path[0]):
		# 歩いている間に建物が建った。道を探し直す
		path.clear()
		return
	var gate: Building = _gate_at(village, path[0])
	if gate != null:
		_hit_building(village, gate)
		return
	var next_pos: Vector2 = Vector2(path[0]) + Vector2(0.5, 0.5)
	var step: float = float(def()["speed_blocks_per_minute"]) * dt
	if pos.distance_to(next_pos) <= step:
		pos = next_pos
		path.pop_front()
	else:
		pos = pos.move_toward(next_pos, step)


## トロルは建物を壊しに来る
func _attack_buildings(village: Village) -> bool:
	var best: Building = null
	var best_distance: float = INF
	for b: Building in village.buildings.values():
		if b.state != Building.State.COMPLETE or b.broken:
			continue
		var distance: float = pos.distance_to(b.center())
		if distance < best_distance:
			best = b
			best_distance = distance
	if best == null:
		return false
	for c in best.cells():
		if pos.distance_to(Vector2(c) + Vector2(0.5, 0.5)) <= float(BuildingDamage.cfg()["monster_attack_reach"]):
			_hit_building(village, best)
			return true
	_walk_toward(village, Vector2i(best.center()), 0.0)
	return true


## 盗賊は倉庫に着いたら物を盗る
func _steal(village: Village) -> bool:
	for s: Building in village.stockpiles():
		for c in s.cells():
			if pos.distance_to(Vector2(c) + Vector2(0.5, 0.5)) <= 1.6:
				if cooldown <= 0.0 and not s.inventory.is_empty():
					cooldown = float(def()["attack_interval_minutes"]) * 3.0
					var item: String = s.inventory.keys()[village.rng.randi_range(0, s.inventory.size() - 1)]
					village.take_from({"kind": "building", "id": s.id}, item, int(def()["steals"]))
					village.raise_alert("stolen", Texts.t("alert_stolen", {"item": village.item_def(item).get("name", item)}), s.cell)
				return true
	return false


func _walk_toward(village: Village, goal: Vector2i, dt_override: float) -> void:
	if path.is_empty() or path[-1] != goal:
		path = village.pathing.find_path(cell(), village.pathing.nearest_standable(cell(), goal))
		if not path.is_empty():
			path.pop_front()
	if path.is_empty():
		_attack_obstacle(village)
		return
	var next_pos: Vector2 = Vector2(path[0]) + Vector2(0.5, 0.5)
	var step: float = float(def()["speed_blocks_per_minute"]) * (dt_override if dt_override > 0.0 else 1.0)
	if pos.distance_to(next_pos) <= step:
		pos = next_pos
		path.pop_front()
	else:
		pos = pos.move_toward(next_pos, step)


func _gate_at(village: Village, cell: Vector2i) -> Building:
	for b: Building in village.buildings.values():
		if bool(b.def().get("gate", false)) and b.cell == cell and b.state == Building.State.COMPLETE:
			return b
	return null


func _attack_obstacle(village: Village) -> void:
	var reach: float = float(BuildingDamage.cfg()["monster_attack_reach"])
	var best: Building = null
	var best_distance: float = INF
	for b: Building in village.buildings.values():
		if b.state != Building.State.COMPLETE:
			continue
		for c in b.cells():
			var distance: float = pos.distance_to(Vector2(c) + Vector2(0.5, 0.5))
			if distance <= reach and distance < best_distance:
				best = b
				best_distance = distance
	if best != null:
		_hit_building(village, best)
	else:
		# まわりにもないときは、村の中心へまっすぐ近づける所まで歩く
		var toward: Vector2i = cell() + Vector2i(signi(village.world.start.x - cell().x), signi(village.world.start.y - cell().y))
		if village.world.is_walkable(toward):
			pos = pos.move_toward(Vector2(toward) + Vector2(0.5, 0.5), float(def()["speed_blocks_per_minute"]))


func _hit_building(village: Village, b: Building) -> void:
	if cooldown > 0.0:
		return
	cooldown = float(def()["attack_interval_minutes"])
	(village.system("building_damage") as BuildingDamage).damage(b, attack_power(village) * float(def().get("building_damage", 1.0)))


func _nearest_target(village: Village) -> Villager:
	var best: Villager = null
	var best_distance: float = float(def()["vision"])
	for v in village.villagers:
		if v.state != Villager.State.NORMAL or village.is_sheltered(v):
			continue
		var distance: float = pos.distance_to(v.pos)
		if distance <= best_distance:
			best = v
			best_distance = distance
	return best


func to_dict() -> Dictionary:
	var data: Dictionary = {"id": id, "type": type, "pos": [pos.x, pos.y], "hp": hp, "stunned": stunned}
	if has_meta("nest"):
		data["nest"] = get_meta("nest")
		data["home"] = [get_meta("home").x, get_meta("home").y]
	return data


static func from_dict(data: Dictionary) -> Monster:
	var m := Monster.new()
	m.id = int(data["id"])
	m.type = str(data["type"])
	m.pos = Vector2(float(data["pos"][0]), float(data["pos"][1]))
	m.hp = float(data["hp"])
	m.stunned = float(data.get("stunned", 0.0))
	if data.has("nest"):
		m.set_meta("nest", int(data["nest"]))
		m.set_meta("home", Vector2i(int(data["home"][0]), int(data["home"][1])))
	return m
