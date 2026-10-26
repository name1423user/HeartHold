class_name Stockpile
extends RefCounted
## 倉庫の区分け(置ける物の分類)と運ぶ優先度(AC-042)。運ぶ先の選び方は Village.best_stockpile_for。


static func categories() -> Dictionary:
	return GameData.get_dict("stockpile")["categories"]


## 置ける分類を決める。空の配列なら何でも置ける
static func set_filter(b: Building, allowed: Array) -> void:
	b.filter = allowed.filter(func(c: String) -> bool: return categories().has(c))


static func set_priority(b: Building, value: int) -> void:
	var cfg: Dictionary = GameData.get_dict("stockpile")
	b.priority = clampi(value, int(cfg["min_priority"]), int(cfg["max_priority"]))


static func filter_label(b: Building) -> String:
	if b.filter.is_empty():
		return Texts.t("stockpile_all")
	var names: Array = b.filter.map(func(c: String) -> String: return str(categories()[c]))
	return "・".join(names)
