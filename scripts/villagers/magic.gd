class_name Magic
extends VillageSystem
## 魔法(M9-T05)。全村人が魔素量を持つが、使えるのは魔術師だけ。魔術師の塔で役職が解放され、塔のそばで魔素が早く回復する。
## 治癒: 救護室の治療を早める。結界: 範囲の村人の受ける傷を減らす(襲撃中は自動)。遠見: 選んだ場所の霧を晴らす。
## 魔法の研究所で上位の結界・遠見が使える。魔法の杖は攻撃のたびに魔素を使う。数値は data/magic.json。

## 張られている結界: [{"cell", "radius", "until", "multiplier"}]
var barriers: Array[Dictionary] = []


func _init(target: Village) -> void:
	super(target)
	plan_stage = "work"


func key() -> String:
	return "magic"


static func cfg() -> Dictionary:
	return GameData.get_dict("magic")


static func spell(id: String) -> Dictionary:
	return cfg()["spells"].get(id, {})


static func is_mage(v: Villager) -> bool:
	return v.job == "mage"


## 魔法の杖は魔素が足りないと撃てない
static func can_use_weapon(v: Villager) -> bool:
	var weapon: String = Equipment.equipped(v, "weapon")
	return weapon.is_empty() or v.mana >= float(Equipment.def(weapon).get("mana_per_attack", 0.0))


static func pay_weapon(v: Villager) -> void:
	var weapon: String = Equipment.equipped(v, "weapon")
	if not weapon.is_empty():
		v.mana -= float(Equipment.def(weapon).get("mana_per_attack", 0.0))


func spell_error(v: Villager, id: String) -> String:
	var s: Dictionary = spell(id)
	if s.is_empty():
		return "?"
	if not is_mage(v):
		return Texts.t("magic_not_mage")
	if village.nearest_building(Vector2(village.world.start), [str(s["needs"])]) == null:
		return Texts.t("locked_building", {"name": GameData.get_dict("buildings")[str(s["needs"])]["name"]})
	if v.mana < float(s["mana"]):
		return Texts.t("magic_no_mana")
	return ""


## 呪文を唱える(画面からも、自動でも)
func cast(v: Villager, id: String, target: Vector2i) -> Dictionary:
	var error: String = spell_error(v, id)
	if not error.is_empty():
		return {"ok": false, "message": error}
	var s: Dictionary = spell(id)
	v.mana -= float(s["mana"])
	village.gain_experience(v, "magic", 30.0)
	if s.has("reveal_radius"):
		village.fog._reveal_circle(target, int(s["reveal_radius"]), true)
		village.fog.explored_changed.emit()
	elif s.has("damage_multiplier"):
		barriers.append({"cell": target, "radius": float(s["radius"]), "until": village.clock.minutes + float(s["minutes"]), "multiplier": float(s["damage_multiplier"])})
	elif s.has("treatment_multiplier"):
		for p in village.villagers:
			if p.state == Villager.State.IN_TREATMENT:
				p.timers["treatment_left"] = float(p.timers["treatment_left"]) * float(s["treatment_multiplier"])
	village.raise_alert("magic", Texts.t("alert_magic", {"name": v.display_name, "spell": s["name"]}), target)
	return {"ok": true}


## 受ける傷の倍率(結界の中なら下がる)
func damage_multiplier(v: Villager) -> float:
	var mult: float = 1.0
	for b in barriers:
		if v.pos.distance_to(Vector2(b["cell"])) <= float(b["radius"]):
			mult = minf(mult, float(b["multiplier"]))
	return mult


func update_villager(v: Villager, dt: float) -> void:
	var c: Dictionary = cfg()
	var regen: float = float(c["mana_regen_per_hour"])
	if is_mage(v) and village.near_building_type(v.pos, "mage_tower", float(c["tower_radius"])):
		regen = float(c["tower_regen_per_hour"])
	v.mana = minf(float(c["max_mana"]), v.mana + regen * dt / 60.0)


func update(_dt: float) -> void:
	barriers.assign(barriers.filter(func(b: Dictionary) -> bool: return float(b["until"]) > village.clock.minutes))


## 魔術師は自分で判断する: 襲撃中は結界、治療中の人がいれば治癒、魔素が少なければ塔で休む
func choose_plan(v: Villager) -> bool:
	if not is_mage(v):
		return false
	if village.raid_alarm and barriers.is_empty():
		var best: String = "ward" if spell_error(v, "ward").is_empty() else "barrier"
		if spell_error(v, best).is_empty():
			cast(v, best, village.world.start)
	var treating: bool = village.villagers.any(func(p: Villager) -> bool: return p.state == Villager.State.IN_TREATMENT and float(p.timers.get("treatment_left", 0.0)) > 30.0)
	if treating and spell_error(v, "heal").is_empty() and v.mana >= float(spell("heal")["mana"]) + float(spell("barrier")["mana"]):
		cast(v, "heal", v.cell())
	var tower: Building = village.nearest_building(v.pos, ["mage_tower"])
	if tower != null and v.mana < float(cfg()["max_mana"]) * 0.8:
		village.set_plan(v, "meditate", [
			{"op": "goto", "target": tower.cell, "adjacent": true, "building": tower.id},
			{"op": "wait", "minutes": 60.0},
		])
		return true
	return false


func to_dict() -> Dictionary:
	var list: Array = []
	for b in barriers:
		list.append({"cell": [b["cell"].x, b["cell"].y], "radius": b["radius"], "until": b["until"], "multiplier": b["multiplier"]})
	return {"barriers": list}


func from_dict(data: Dictionary) -> void:
	barriers.clear()
	for b: Dictionary in data.get("barriers", []):
		barriers.append({"cell": Vector2i(int(b["cell"][0]), int(b["cell"][1])), "radius": float(b["radius"]), "until": float(b["until"]), "multiplier": float(b["multiplier"])})
