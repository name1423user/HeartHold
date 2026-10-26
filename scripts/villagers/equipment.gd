class_name Equipment
extends RefCounted
## 道具と武器の2枠(AC-037, AC-038, AC-046)。数値は data/equipment.json(元は ITEMS.md)。


static func cfg() -> Dictionary:
	return GameData.get_dict("equipment")


static func def(item: String) -> Dictionary:
	return cfg()["items"].get(item, {})


static func is_equipment(item: String) -> bool:
	return not def(item).is_empty()


## 今の時代で使える装備か(素材の段階: 石 → 鉄 → 鋼。MVP は石のみ)
## 今の時代で使える装備か(素材の段階: 石 → 鉄 → 鋼)
static func is_available(item: String, era: String = "") -> bool:
	var current: String = era if not era.is_empty() else str(cfg()["current_era"])
	return Era.index_of(str(def(item).get("era", "stone"))) <= Era.index_of(current)


## 装備する。前の物を返す(空なら "")
static func equip(v: Villager, item: String) -> String:
	var d: Dictionary = def(item)
	var slot: String = str(d["slot"])
	var previous: String = equipped(v, slot)
	v.equipment[slot] = {"id": item, "durability": int(d["durability"])}
	return previous


static func insulation(v: Villager) -> float:
	var clothes: String = equipped(v, "clothes")
	return float(def(clothes).get("insulation", 0.0)) if not clothes.is_empty() else 0.0


static func equipped(v: Villager, slot: String) -> String:
	return str((v.equipment.get(slot, {}) as Dictionary).get("id", ""))


## 作業の種類 kind に効く道具の速度倍率。合わなければ素手(×1.0)
static func speed(v: Villager, kind: String) -> float:
	var tool: String = equipped(v, "tool")
	if not tool.is_empty() and (def(tool).get("works", []) as Array).has(kind):
		return float(def(tool)["speed"])
	return float(cfg()["bare"]["speed"])


static func attack(v: Villager) -> float:
	var weapon: String = equipped(v, "weapon")
	return float(def(weapon)["attack"]) if not weapon.is_empty() else float(cfg()["bare"]["attack"])


static func attack_range(v: Villager, on_tower: bool = false) -> float:
	var weapon: String = equipped(v, "weapon")
	if weapon.is_empty():
		return float(cfg()["bare"]["range"])
	var d: Dictionary = def(weapon)
	return float(d["range"]) * (float(d.get("tower_range_multiplier", 1.0)) if on_tower else 1.0)


static func is_ranged(v: Villager) -> bool:
	var weapon: String = equipped(v, "weapon")
	return not weapon.is_empty() and str(def(weapon).get("kind", "")) == "ranged"


## 使うたびに耐久を1減らす。0で壊れて素手に戻り、警告を出す。壊れたら true
static func wear(village: Village, v: Villager, slot: String, kind: String = "") -> bool:
	var entry: Dictionary = v.equipment.get(slot, {})
	if entry.is_empty():
		return false
	if slot == "tool" and not (def(str(entry["id"])).get("works", []) as Array).has(kind):
		return false
	if int(entry["durability"]) < 0:
		return false
	entry["durability"] = int(entry["durability"]) - 1
	if int(entry["durability"]) > 0:
		return false
	var item_name: String = str(village.item_def(str(entry["id"])).get("name", entry["id"]))
	v.equipment[slot] = {}
	village.raise_alert("tool_broken", Texts.t("alert_tool_broken", {"name": v.display_name, "item": item_name}), v.cell())
	return true


## 役職に合う装備のうち、空いた枠に入れられて倉庫にあるもの
static func wanted_item(village: Village, v: Villager) -> String:
	var wanted: Array = (cfg()["wanted"].get(v.job, []) as Array) + (cfg().get("wanted_all", []) as Array)
	for item: String in wanted:
		var d: Dictionary = def(item)
		var slot: String = str(d["slot"])
		if not is_available(item, village.era()) or village.stock_count(item) <= 0:
			continue
		if d.has("requires_job") and v.job != str(d["requires_job"]):
			continue
		var current: String = equipped(v, slot)
		# 空いている枠か、今のより良い物(リストの前にある物)なら取りに行く
		if current.is_empty() or wanted.find(item) < wanted.find(current):
			return item
	return ""
