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


func work_speed(v: Villager, kind: String) -> float:
	return product(v, "work_speed") if kind != "combat" else 1.0


func mood_rate(v: Villager) -> float:
	return product(v, "mood_rate")
