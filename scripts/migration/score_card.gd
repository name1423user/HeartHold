class_name ScoreCard
extends RefCounted
## 審査の採点(AC-012, AC-013, AC-014, AC-032)。5項目を各100点で採点し、希望者の重みで加重平均。
## 60点以上で合格。数値は data/scoring.json。

const ITEMS: Array[String] = ["food", "housing", "safety", "facilities", "satisfaction"]


static func cfg() -> Dictionary:
	return GameData.get_dict("scoring")


## 加重平均(重みの合計は1.0)
static func weighted_total(scores: Dictionary, weights: Dictionary) -> float:
	var total := 0.0
	for key in weights:
		total += float(scores.get(key, 0)) * float(weights[key])
	return total


## 合格ラインに届かなかった原因の項目。加重後の失点が大きい順に最大2つ
static func weak_items(scores: Dictionary, weights: Dictionary) -> Array[String]:
	var keys: Array[String] = []
	for key: String in weights:
		if float(scores.get(key, 0)) < 100.0:
			keys.append(key)
	var loss := func(key: String) -> float: return (100.0 - float(scores.get(key, 0))) * float(weights[key])
	keys.sort_custom(func(a: String, b: String) -> bool: return loss.call(a) > loss.call(b))
	return keys.slice(0, int(cfg()["max_weak_items"]))


static func evaluate(village: Village, applicant: Applicant) -> Dictionary:
	var scores: Dictionary = score_village(village)
	var weights: Dictionary = applicant.weights()
	var total: float = weighted_total(scores, weights)
	var passed: bool = total >= float(cfg()["pass_score"])
	return {
		"applicant": applicant.id, "name": applicant.display_name, "scores": scores, "weights": weights,
		"total": total, "passed": passed, "weak": weak_items(scores, weights) if not passed else [],
	}


static func score_village(village: Village) -> Dictionary:
	return {
		"food": food_score(village),
		"housing": housing_score(village),
		"safety": safety_score(village),
		"facilities": facilities_score(village),
		"satisfaction": satisfaction_score(village),
	}


static func food_score(village: Village) -> float:
	return minf(100.0, FoodStock.days_left(village) * 100.0 / float(cfg()["food"]["full_score_days"]))


## 新しい住人が入る寝床がなければ0点(SPEC 5章エッジケース)
static func housing_score(village: Village) -> float:
	var c: Dictionary = cfg()["housing"]
	var beds: int = 0
	var bonus: float = 0.0
	for b: Building in village.houses():
		beds += int(b.def().get("residents", 0))
		bonus += BuildingFixture.sum_effect(b, "housing_score")
	var free: int = beds - village.living_villagers().size()
	if free < 1:
		return 0.0
	return minf(100.0, float(c["base"]) + float(c["per_extra_bed"]) * (free - 1) + bonus)


static func safety_score(village: Village) -> float:
	var c: Dictionary = cfg()["safety"]
	var score: float = float(c["base"])
	for v in village.living_villagers():
		if v.job == "guard":
			score += float(c["per_guard"])
			if not Equipment.equipped(v, "weapon").is_empty():
				score += float(c["per_armed_guard"])
	for b: Building in village.buildings.values():
		if not b.is_complete():
			continue
		if b.type == "fence":
			score += float(c["per_fence"])
		elif b.type == "watchtower":
			score += float(c["per_watchtower"])
	return minf(100.0, score)


static func facilities_score(village: Village) -> float:
	var c: Dictionary = cfg()["facilities"]
	var seen: Dictionary = {}
	for b: Building in village.buildings.values():
		if b.is_complete() and c.has(b.type):
			seen[b.type] = float(c[b.type])
	var score: float = 0.0
	for value: float in seen.values():
		score += value
	return minf(100.0, score)


static func satisfaction_score(village: Village) -> float:
	var living: Array[Villager] = village.living_villagers()
	if living.is_empty():
		return 0.0
	var total: float = 0.0
	for v in living:
		total += v.needs.get_value("mood")
	return total / living.size()


static func item_name(key: String) -> String:
	return str(cfg()["items"][key])
