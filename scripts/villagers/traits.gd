class_name Traits
extends VillageSystem
## 村人の個性(M7-T04): 怠け者・働き者・勇敢・臆病など。生まれたときに1〜2個つく。
## 効果は data/traits.json。一言セリフ(US-017)もここで出す。

func key() -> String:
	return "traits"


static func cfg() -> Dictionary:
	return GameData.get_dict("traits")


static func def(trait_id: String) -> Dictionary:
	return cfg()["traits"].get(trait_id, {})


static func names(v: Villager) -> Array:
	return v.traits.map(func(t: String) -> String: return str(def(t).get("name", t)))


## 個性を引く(両立しない組は避ける)
static func roll(rng: RandomNumberGenerator) -> Array:
	var ids: Array = cfg()["traits"].keys()
	var range_count: Array = cfg()["per_villager"]
	var count: int = rng.randi_range(int(range_count[0]), int(range_count[1]))
	var picked: Array = []
	var guard: int = 0
	while picked.size() < count and guard < 50:
		guard += 1
		var t: String = ids[rng.randi_range(0, ids.size() - 1)]
		if picked.has(t) or _conflicts(picked, t):
			continue
		picked.append(t)
	return picked


static func _conflicts(picked: Array, t: String) -> bool:
	for pair: Array in cfg()["exclusive"]:
		if pair.has(t):
			for other: String in pair:
				if other != t and picked.has(other):
					return true
	return false


static func product(v: Villager, key_name: String) -> float:
	var value: float = 1.0
	for t: String in v.traits:
		value *= float(def(t).get(key_name, 1.0))
	return value


## 欲求の減り方の倍率
static func need_decay(v: Villager) -> Dictionary:
	return {
		"food": product(v, "food_decay"), "fun": product(v, "fun_decay"), "social": product(v, "social_decay"),
		"calm": product(v, "calm_decay"), "cold": product(v, "cold_loss"),
	}


## 一言セリフ(US-017)。ときどき、状況や個性に合ったことを言う
func update_villager(v: Villager, dt: float) -> void:
	var cfg_lines: Dictionary = GameData.get_dict("lines")
	if float(v.timers.get("line_until", 0.0)) < village.clock.minutes:
		v.line = ""
	if village.rng.randf() >= float(cfg_lines["chance_per_hour"]) * dt / 60.0:
		return
	var pool: Array = []
	var lines: Dictionary = cfg_lines["lines"]
	var situation: String = "task" if v.plan_kind == "task" else "idle"
	if village.raid_alarm:
		situation = "raid"
	elif not Illness.disease_of(v).is_empty():
		situation = "sick"
	elif village.calendar().weather in ["rain", "storm"]:
		situation = "rain"
	elif village.calendar().weather == "snow":
		situation = "snow"
	pool.append_array(lines.get(situation, []))
	for t: String in v.traits:
		pool.append_array(lines.get(t, []))
	if pool.is_empty():
		return
	v.line = str(pool[village.rng.randi_range(0, pool.size() - 1)])
	v.timers["line_until"] = village.clock.minutes + float(cfg_lines["show_minutes"])


func work_speed(v: Villager, kind: String) -> float:
	return product(v, "work_speed") if kind != "combat" else 1.0


func mood_rate(v: Villager) -> float:
	return product(v, "mood_rate")
