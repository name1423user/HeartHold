class_name Watchtower
extends RefCounted
## 見張り台(AC-034, AC-047)。視界が広く(buildings.json の vision)、視界に魔物が入ると
## 村の境界に着く前に警告を出す。衛兵を1人置くと台の上から攻撃し、投石紐なら射程が50%伸びる。


static func towers(village: Village) -> Array[Building]:
	var result: Array[Building] = []
	for b: Building in village.buildings.values():
		if b.type == "watchtower" and b.is_complete():
			result.append(b)
	return result


static func sees(tower: Building, pos: Vector2) -> bool:
	return pos.distance_to(tower.center()) <= float(tower.def()["vision"]) * (1.0 + BuildingFixture.sum_effect(tower, "vision_bonus"))


## 見張り台の視界に入った魔物がいれば、まだなら警告を出す
static func check_warning(village: Village) -> void:
	if not village.raids.active or village.raids.warned:
		return
	for tower in towers(village):
		for m in village.raids.monsters:
			if sees(tower, m.pos):
				village.raids.warned = true
				village.raise_alert("raid", Texts.t("alert_raid_tower"), m.cell())
				return


## 衛兵を見張り台に置く(1台に1人)
static func station(village: Village, tower: Building, v: Villager) -> Dictionary:
	if tower.type != "watchtower" or not tower.is_complete() or v.job != "guard":
		return {"ok": false, "message": Texts.t("tower_guard_only")}
	for other in village.villagers:
		if other != v and int(other.timers.get("tower", -1)) == tower.id:
			other.timers.erase("tower")
			village.release_plan(other)
	v.timers["tower"] = tower.id
	village.release_plan(v)
	return {"ok": true}


static func tower_of(village: Village, v: Villager) -> Building:
	return village.buildings.get(int(v.timers.get("tower", -1))) as Building


static func is_on_tower(village: Village, v: Villager) -> bool:
	var tower: Building = tower_of(village, v)
	if tower == null or not tower.is_complete():
		return false
	for c in tower.cells():
		if v.pos.distance_to(Vector2(c) + Vector2(0.5, 0.5)) <= 1.5:
			return true
	return false


## 台の上から届く一番近い魔物
static func target(village: Village, v: Villager) -> Monster:
	var reach: float = Equipment.attack_range(v, true)
	var tower: Building = tower_of(village, v)
	var best: Monster = null
	var best_distance: float = INF
	for m in village.raids.monsters:
		var distance: float = m.pos.distance_to(tower.center())
		if m.hp > 0.0 and distance <= reach and distance < best_distance:
			best = m
			best_distance = distance
	return best
