class_name Combat
extends RefCounted
## 迎撃と避難(AC-015)。魔物が村の境界に入ったら、衛兵は迎え撃ち、他の村人は家か救護室へ避難する。

static func cfg() -> Dictionary:
	return GameData.get_dict("combat")


## 攻撃力 = 武器 × 特技「槍の心得」 × 村長の方針「守り」
static func attack_damage(village: Village, v: Villager) -> float:
	return Equipment.attack(v) * Specialty.speed(v, "combat") * village.chief.guard_attack(v)


## 衛兵に見えている一番近い魔物
static func visible_monster(village: Village, v: Villager) -> Monster:
	var best: Monster = null
	var best_distance: float = float(cfg()["guard_vision"])
	for m in village.raids.monsters:
		if m.hp <= 0.0:
			continue
		var distance: float = v.pos.distance_to(m.pos)
		if distance <= best_distance:
			best = m
			best_distance = distance
	return best


## 衛兵の戦いの手順。使った時間を返す
static func step_fight(village: Village, v: Villager, budget: float) -> float:
	if not village.raids.active:
		v.plan.pop_front()
		return 0.0
	var on_tower: bool = village.is_on_watchtower(v)
	var target: Monster = visible_monster(village, v)
	if on_tower:
		target = village.watchtower_target(v)
	v.timers["attack_cooldown"] = maxf(0.0, float(v.timers.get("attack_cooldown", 0.0)) - budget)
	if target == null:
		if not on_tower:
			# 見えていなければ村の中心へ寄って探す
			village.chase(v, village.world.start, budget)
		return budget
	# 台の上からは台の中心から測る
	var origin: Vector2 = Watchtower.tower_of(village, v).center() if on_tower else v.pos
	var distance: float = origin.distance_to(target.pos)
	var reach: float = Equipment.attack_range(v, on_tower)
	if distance <= reach:
		if Equipment.is_ranged(v) and not on_tower and distance < float(cfg()["ranged_min_distance"]):
			# 遠距離の武器は距離を取る
			var away: Vector2 = v.pos + (v.pos - target.pos).normalized() * 2.0
			village.chase(v, Vector2i(floori(away.x), floori(away.y)), budget)
			return budget
		if float(v.timers["attack_cooldown"]) <= 0.0:
			v.timers["attack_cooldown"] = float(cfg()["attack_interval_minutes"])
			target.take_damage(attack_damage(village, v))
			Equipment.wear(village, v, "weapon")
			village.gain_experience(v, "combat", float(cfg()["attack_interval_minutes"]))
		return budget
	if not on_tower:
		village.chase(v, target.cell(), budget)
	return budget


## 避難先(自分の家、なければ一番近い家か救護室)
static func shelter_for(village: Village, v: Villager) -> Building:
	var home: Building = village.buildings.get(v.home_id) as Building
	if home != null and home.is_complete():
		return home
	var best: Building = null
	var best_distance: float = INF
	for b: Building in village.buildings.values():
		if b.is_complete() and (cfg()["shelter_types"] as Array).has(b.type):
			var distance: float = v.pos.distance_to(b.center())
			if distance < best_distance:
				best = b
				best_distance = distance
	return best
