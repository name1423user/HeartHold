class_name Conditions
extends RefCounted
## 実績・チュートリアルなどの条件の判定(data の {"type", ...})。


static func check(village: Village, cond: Dictionary, counters: Dictionary = {}) -> bool:
	match str(cond["type"]):
		"building":
			var count: int = 0
			for b: Building in village.buildings.values():
				if b.type == cond["building"] and b.is_complete():
					count += 1
			return count >= int(cond.get("count", 1))
		"buildings_total":
			return village.buildings.values().filter(func(b: Building) -> bool: return b.is_complete()).size() >= int(cond["count"])
		"residents":
			return village.level.residents() >= int(cond["count"])
		"level":
			return village.level.level >= int(cond["value"])
		"era":
			return Era.index_of(village.era()) >= Era.index_of(str(cond["value"]))
		"day":
			return village.clock.day() >= int(cond["value"])
		"year":
			return village.calendar().year() >= int(cond["value"])
		"stock":
			return village.stock_count(str(cond["item"])) >= int(cond["count"])
		"tasks":
			return not village.tasks.of_type(str(cond["task"])).is_empty() or int(counters.get("task_" + str(cond["task"]), 0)) > 0
		"job":
			return village.living_villagers().any(func(v: Villager) -> bool: return v.job == cond["job"])
		"counter":
			return int(counters.get(str(cond["name"]), 0)) >= int(cond["count"])
		"paused":
			return village.clock.paused
		"reputation":
			return (village.system("reputation") as Reputation).value >= float(cond["value"])
		"partners":
			return (village.system("trade") as Trade).unlocked.size() >= int(cond["count"])
		"food_days":
			return FoodStock.days_left(village) >= int(cond["days"])
	return false
