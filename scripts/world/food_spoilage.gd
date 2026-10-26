class_name FoodSpoilage
extends VillageSystem
## 腐る食料と保存食、食事の種類(M7-T06)。食べ物には傷むまでの日数があり、倉庫の樽・冬の寒さで長持ちし、
## 地面に置くと早く傷む。燻製・塩漬けは長持ちする。いろいろ食べると気分が上がり、同じ物ばかりだと下がる。

var _timer: float = 0.0
## 場所と品目ごとの、傷みかけの端数
var _fraction: Dictionary = {}
var spoiled_today: int = 0


func _init(target: Village) -> void:
	super(target)
	village.ate.connect(_on_ate)


func key() -> String:
	return "food_spoilage"


func cfg() -> Dictionary:
	return GameData.get_dict("food")


func update(dt: float) -> void:
	_timer += dt
	var step: float = float(cfg()["check_minutes"])
	while _timer >= step:
		_timer -= step
		_spoil(step)


func _spoil(minutes: float) -> void:
	var season_mult: float = float(cfg()["winter_spoil_multiplier"]) if village.calendar().season_id() == "winter" else 1.0
	for b: Building in village.stockpiles():
		var mult: float = season_mult * pow(float(cfg()["barrel_spoil_multiplier"]), b.fixtures.count("barrel"))
		_spoil_inventory("b%d" % b.id, b.inventory, minutes, mult)
	for cell: Vector2i in village.ground_items.keys():
		var pile: Dictionary = village.ground_items[cell]
		_spoil_inventory("g%s" % cell, pile, minutes, season_mult * float(cfg()["ground_spoil_multiplier"]))
		if pile.is_empty():
			village.ground_items.erase(cell)


## 1日で 1/spoil_days ずつ傷む(端数は持ち越す)
func _spoil_inventory(place: String, inventory: Dictionary, minutes: float, mult: float) -> void:
	for item: String in inventory.keys():
		var days: float = float(village.item_def(item).get("spoil_days", 0.0))
		if days <= 0.0:
			continue
		var key_name: String = place + ":" + item
		var amount: float = float(_fraction.get(key_name, 0.0)) + int(inventory[item]) * mult * minutes / (days * GameClock.MINUTES_PER_DAY)
		var lost: int = mini(floori(amount), int(inventory[item]))
		_fraction[key_name] = amount - lost
		if lost > 0:
			spoiled_today += lost
			var left: int = int(inventory[item]) - lost
			if left > 0:
				inventory[item] = left
			else:
				inventory.erase(item)
				_fraction.erase(key_name)


func _on_ate(v: Villager, item: String) -> void:
	v.diet.append(item)
	while v.diet.size() > int(cfg()["diet_memory"]):
		v.diet.pop_front()
	var kinds: Dictionary = {}
	for food: String in v.diet:
		kinds[food] = true
	var recent: Array = v.diet.slice(-int(cfg()["monotony_count"]))
	if recent.size() >= int(cfg()["monotony_count"]) and recent.all(func(f: String) -> bool: return f == item):
		v.needs.add("mood", float(cfg()["monotony_mood"]))
	elif kinds.size() >= int(cfg()["variety_count"]):
		v.needs.add("mood", float(cfg()["variety_mood"]))


func to_dict() -> Dictionary:
	return {"timer": _timer, "fraction": _fraction.duplicate()}


func from_dict(data: Dictionary) -> void:
	_timer = float(data.get("timer", 0.0))
	_fraction = (data.get("fraction", {}) as Dictionary).duplicate()
