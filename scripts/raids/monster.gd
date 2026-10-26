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


func update(village: Village, dt: float) -> void:
	cooldown = maxf(0.0, cooldown - dt)
	var target: Villager = _nearest_target(village)
	if target != null and pos.distance_to(target.pos) <= float(def()["range"]):
		if cooldown <= 0.0:
			cooldown = float(def()["attack_interval_minutes"])
			village.damage_villager(target, attack_power(village))
		return
	var goal: Vector2i = target.cell() if target != null else village.world.start
	repath_timer -= dt
	if path.is_empty() or repath_timer <= 0.0:
		repath_timer = 5.0
		path = village.pathing.find_path(cell(), goal)
		if path.is_empty():
			path = village.pathing.find_path(cell(), village.pathing.nearest_standable(cell(), goal))
		if not path.is_empty():
			path.pop_front()
	if path.is_empty():
		return
	var next_pos: Vector2 = Vector2(path[0]) + Vector2(0.5, 0.5)
	var step: float = float(def()["speed_blocks_per_minute"]) * dt
	if pos.distance_to(next_pos) <= step:
		pos = next_pos
		path.pop_front()
	else:
		pos = pos.move_toward(next_pos, step)


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
	return {"id": id, "type": type, "pos": [pos.x, pos.y], "hp": hp}


static func from_dict(data: Dictionary) -> Monster:
	var m := Monster.new()
	m.id = int(data["id"])
	m.type = str(data["type"])
	m.pos = Vector2(float(data["pos"][0]), float(data["pos"][1]))
	m.hp = float(data["hp"])
	return m
