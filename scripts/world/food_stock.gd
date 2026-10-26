class_name FoodStock
extends RefCounted
## 食料があと何日分あるか(AC-041)。倉庫の食料の総量 ÷ 1日の消費量(切り捨て)。


static func total_food(village: Village) -> float:
	var total: float = 0.0
	for s: Building in village.stockpiles():
		for item: String in s.inventory:
			var d: Dictionary = village.item_def(item)
			if d.get("category", "") == "food":
				total += float(d.get("food", 0.0)) * int(s.inventory[item])
	return total


## 村人1人が1日に減らす食事の量 × 生きている人数
static func daily_consumption(village: Village) -> float:
	var per_person: float = float(village.needs_cfg["decay_per_hour"]["food"]) * 24.0
	return per_person * village.living_villagers().size()


static func days_left(village: Village) -> int:
	var daily: float = daily_consumption(village)
	if daily <= 0.0:
		return 0
	return floori(total_food(village) / daily)
