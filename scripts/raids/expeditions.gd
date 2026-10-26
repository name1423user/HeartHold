class_name Expeditions
extends VillageSystem
## 視察隊(M9-T03)。選んだ村人を隊にして目的地へ送る。歩きながら霧を晴らし、着いた先が魔物の巣なら
## 守りの魔物と戦って巣を潰す。終わるか、体力が少なくなったら村へ帰る。

## 隊: {"id", "members": [村人ID], "target": Vector2i, "phase": "going"/"fighting"/"returning"}
var parties: Array[Dictionary] = []
var next_id: int = 1


func _init(target: Village) -> void:
	super(target)
	plan_stage = "urgent"


func key() -> String:
	return "expeditions"


static func cfg() -> Dictionary:
	return GameData.get_dict("expeditions")


func party_of(v: Villager) -> Dictionary:
	for p in parties:
		if (p["members"] as Array).has(v.id):
			return p
	return {}


## 隊を出す。行けない場所や人数が合わないときは理由を返す
func send(members: Array[Villager], target: Vector2i) -> Dictionary:
	var c: Dictionary = cfg()
	var usable: Array[Villager] = []
	usable.assign(members.filter(func(v: Villager) -> bool: return v.is_active() and village.can_work(v) and party_of(v).is_empty()))
	if usable.size() < int(c["min_members"]) or usable.size() > int(c["max_members"]):
		return {"ok": false, "message": Texts.t("expedition_members", {"min": c["min_members"], "max": c["max_members"]})}
	var dest: Vector2i = village.pathing.nearest_standable(usable[0].cell(), target)
	if dest == Village.NO_CELL:
		return {"ok": false, "message": Texts.t("order_unreachable")}
	var party: Dictionary = {"id": next_id, "members": usable.map(func(v: Villager) -> int: return v.id), "target": dest, "phase": "going"}
	next_id += 1
	parties.append(party)
	for v in usable:
		village.release_plan(v)
	village.raise_alert("expedition", Texts.t("alert_expedition_sent", {"count": usable.size()}), dest)
	return {"ok": true, "party": party}


func choose_plan(v: Villager) -> bool:
	var party: Dictionary = party_of(v)
	if party.is_empty():
		return false
	match str(party["phase"]):
		"going":
			village.set_plan(v, "expedition", [{"op": "goto", "target": party["target"], "adjacent": false}, {"op": "expedition_arrive"}])
		"fighting":
			village.set_plan(v, "expedition", [{"op": "expedition_fight"}])
		"returning":
			village.set_plan(v, "expedition", [{"op": "goto", "target": village.world.start, "adjacent": false}, {"op": "expedition_home"}])
	return true


func execute_step(v: Villager, step: Dictionary, budget: float) -> float:
	var party: Dictionary = party_of(v)
	match str(step["op"]):
		"expedition_arrive":
			v.plan.pop_front()
			if party.is_empty():
				return 0.0
			var nests: Nests = village.system("nests") as Nests
			var nest: Dictionary = nests.nest_at(party["target"])
			if not nest.is_empty():
				nests.spawn_defenders(nest)
				party["phase"] = "fighting"
				party["nest"] = nest["id"]
			else:
				party["phase"] = "returning"
			return 0.0
		"expedition_fight":
			if party.is_empty():
				v.plan.pop_front()
				return 0.0
			return _fight(v, party, budget)
		"expedition_home":
			v.plan.pop_front()
			if not party.is_empty():
				(party["members"] as Array).erase(v.id)
				if (party["members"] as Array).is_empty():
					parties.erase(party)
					village.raise_alert("expedition_back", Texts.t("alert_expedition_back"), village.world.start)
			return 0.0
	return NAN


func _fight(v: Villager, party: Dictionary, budget: float) -> float:
	if v.needs.get_value("health") < float(cfg()["return_when_health_below"]):
		party["phase"] = "returning"
		v.plan.pop_front()
		return 0.0
	var nests: Nests = village.system("nests") as Nests
	var nest: Dictionary = {}
	for s in nests.sites:
		if int(s["id"]) == int(party.get("nest", -1)):
			nest = s
	var defenders: Array = village.raids.monsters.filter(func(m: Monster) -> bool: return m.has_meta("nest") and int(m.get_meta("nest")) == int(party.get("nest", -1)) and m.hp > 0.0)
	if nest.is_empty() or nest["destroyed"]:
		party["phase"] = "returning"
		v.plan.pop_front()
		return 0.0
	v.timers["attack_cooldown"] = maxf(0.0, float(v.timers.get("attack_cooldown", 0.0)) - budget)
	var target_pos: Vector2 = Vector2(nest["cell"]) + Vector2(0.5, 0.5)
	var target_monster: Monster = null
	if not defenders.is_empty():
		target_monster = defenders[0]
		target_pos = target_monster.pos
	var reach: float = maxf(Equipment.attack_range(v), float(cfg()["attack_range"]))
	if v.pos.distance_to(target_pos) > reach:
		village.chase(v, Vector2i(floori(target_pos.x), floori(target_pos.y)), budget)
		return budget
	if float(v.timers["attack_cooldown"]) <= 0.0:
		v.timers["attack_cooldown"] = float(Combat.cfg()["attack_interval_minutes"])
		if target_monster != null:
			target_monster.take_damage(Combat.attack_damage(village, v, target_monster))
		else:
			nests.damage(nest, Combat.attack_damage(village, v))
		village.gain_experience(v, "combat", budget)
	return budget


func update(_dt: float) -> void:
	# 守りの魔物は巣のそばだけで暴れる。倒れたものは片付ける
	for m in village.raids.monsters.duplicate():
		if m.has_meta("nest") and m.hp <= 0.0:
			village.raids.monsters.erase(m)
	for party in parties.duplicate():
		var alive: Array = (party["members"] as Array).filter(func(id: int) -> bool:
			var member: Villager = village.get_villager(id)
			return member != null and member.state == Villager.State.NORMAL)
		party["members"] = alive
		if alive.is_empty():
			parties.erase(party)


func to_dict() -> Dictionary:
	var list: Array = []
	for p in parties:
		var copy: Dictionary = p.duplicate(true)
		copy["target"] = [p["target"].x, p["target"].y]
		list.append(copy)
	return {"parties": list, "next_id": next_id}


func from_dict(data: Dictionary) -> void:
	parties.clear()
	for p: Dictionary in data.get("parties", []):
		var copy: Dictionary = p.duplicate(true)
		copy["target"] = Vector2i(int(p["target"][0]), int(p["target"][1]))
		copy["members"] = (p["members"] as Array).map(func(id: Variant) -> int: return int(id))
		parties.append(copy)
	next_id = int(data.get("next_id", 1))
