class_name RaidDirector
extends RefCounted
## 襲撃の発生(AC-016, AC-017, AC-035)。最初の5日間は来ない。前回からゲーム内3日未満なら来ない。
## 規模は村の豊かさ(倉庫の資源量+建物数)から計算する。数値は data/raids.json。

signal raid_started(count: int)
signal raid_ended

var village: Village
var cfg: Dictionary = {}
var monsters: Array[Monster] = []
var active: bool = false
var last_raid_at: float = -1.0
var next_monster_id: int = 1
var warned: bool = false


func _init(target: Village) -> void:
	village = target
	cfg = GameData.get_dict("raids")


func wealth() -> float:
	var buildings: int = 0
	for b: Building in village.buildings.values():
		if b.is_complete():
			buildings += 1
	return village.total_stock() + buildings * float(cfg["size"]["per_building"])


## 豊かさから魔物の数を出す(式は data/raids.json の size)
func monster_count_for(value: float) -> int:
	var size: Dictionary = cfg["size"]
	return mini(int(size["max"]), int(size["base"]) + floori(value / float(size["wealth_per_monster"])))


func can_start() -> bool:
	var now: float = village.clock.minutes
	if active or now < float(cfg["grace_days"]) * GameClock.MINUTES_PER_DAY:
		return false
	return last_raid_at < 0.0 or now - last_raid_at >= float(cfg["min_cooldown_days"]) * GameClock.MINUTES_PER_DAY


func update(dt: float) -> void:
	if active:
		_update_raid(dt)
		return
	# 襲撃でないときも、巣の守りの魔物は動く
	for m in monsters.duplicate():
		if m.hp > 0.0:
			m.update(village, dt)
	if not can_start():
		return
	var chance: float = 1.0 - pow(1.0 - float(cfg["chance_per_hour"]) * nest_multiplier(), dt / 60.0)
	if village.rng.randf() < chance:
		start_raid()


func start_raid() -> void:
	if not can_start():
		return
	var count: int = monster_count_for(wealth())
	var origin: Vector2i = _spawn_origin()
	for i in count:
		var m := Monster.new()
		m.id = next_monster_id
		next_monster_id += 1
		m.setup(pick_monster_type())
		m.pos = Vector2(_near_walkable(origin + Vector2i(i % 3, i / 3))) + Vector2(0.5, 0.5)
		monsters.append(m)
	active = true
	warned = false
	last_raid_at = village.clock.minutes
	raid_started.emit(count)


## 時代ごとの魔物の組み合わせ(data/raids.json の composition)から1体ぶんの種類を選ぶ
func pick_monster_type() -> String:
	var table: Dictionary = cfg["composition"].get(village.era(), cfg["composition"]["stone"])
	var roll: float = village.rng.randf()
	for type: String in table:
		roll -= float(table[type])
		if roll <= 0.0:
			return type
	return str(table.keys()[0])


## 魔物の巣が残っている割合で襲撃の起こりやすさが変わる(巣を潰すと減る、M9-T03)
func nest_multiplier() -> float:
	var nests: Nests = village.system("nests") as Nests
	if nests == null or nests.sites.is_empty():
		return 1.0
	return maxf(float(cfg["nest_raid_multiplier_min"]), float(nests.active_count()) / nests.sites.size())


func _update_raid(dt: float) -> void:
	for m in monsters.duplicate():
		if m.hp <= 0.0:
			monsters.erase(m)
			continue
		m.update(village, dt)
	var too_long: bool = village.clock.minutes - last_raid_at >= float(cfg["max_duration_hours"]) * 60.0
	if raiders().is_empty() or too_long:
		end_raid()


## 襲撃に来た魔物(巣の守りは除く)
func raiders() -> Array[Monster]:
	var result: Array[Monster] = []
	result.assign(monsters.filter(func(m: Monster) -> bool: return not m.has_meta("nest")))
	return result


func end_raid() -> void:
	monsters.assign(monsters.filter(func(m: Monster) -> bool: return m.has_meta("nest")))
	active = false
	village.raise_alert("raid_end", Texts.t("alert_raid_end"), village.world.start)
	raid_ended.emit()


## 村の境界の半径。建物がある範囲 + 余白(最低 min_village_radius)
func village_radius() -> float:
	var radius: float = float(cfg["min_village_radius"])
	for b: Building in village.buildings.values():
		radius = maxf(radius, b.center().distance_to(Vector2(village.world.start)) + float(cfg["village_margin"]))
	return radius


func is_inside_village(pos: Vector2) -> bool:
	return pos.distance_to(Vector2(village.world.start)) <= village_radius()


func _spawn_origin() -> Vector2i:
	var start: Vector2i = village.world.start
	# 巣が残っていれば、そのどれかから来る
	var nests: Nests = village.system("nests") as Nests
	if nests != null and nests.active_count() > 0:
		var active: Array = nests.sites.filter(func(n: Dictionary) -> bool: return not n["destroyed"])
		var nest: Dictionary = active[village.rng.randi_range(0, active.size() - 1)]
		if village.pathing.is_reachable(_near_walkable(nest["cell"]), start):
			return nest["cell"]
	var distance: int = int(cfg["spawn_distance"])
	for attempt in 32:
		var angle: float = village.rng.randf() * TAU
		var cell: Vector2i = start + Vector2i(roundi(cos(angle) * distance), roundi(sin(angle) * distance))
		if village.world.is_walkable(cell) and village.pathing.is_reachable(cell, start):
			return cell
	return start + Vector2i(distance, 0)


func _near_walkable(cell: Vector2i) -> Vector2i:
	for radius in 6:
		for dz in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				var c: Vector2i = cell + Vector2i(dx, dz)
				if village.world.is_walkable(c):
					return c
	return cell


func to_dict() -> Dictionary:
	var list: Array = []
	for m in monsters:
		list.append(m.to_dict())
	return {"active": active, "last_raid_at": last_raid_at, "next_monster_id": next_monster_id, "warned": warned, "monsters": list}


func from_dict(data: Dictionary) -> void:
	active = bool(data["active"])
	last_raid_at = float(data["last_raid_at"])
	next_monster_id = int(data["next_monster_id"])
	warned = bool(data.get("warned", false))
	monsters.clear()
	for entry: Dictionary in data["monsters"]:
		monsters.append(Monster.from_dict(entry))
