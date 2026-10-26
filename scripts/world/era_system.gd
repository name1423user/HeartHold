class_name EraSystem
extends VillageSystem
## 時代の進行(M8-T01)。研究ツリーは作らず、data/eras.json の節目(村レベル・建物・住人・在庫)を満たすと次の時代へ進む。
## 時代が進むと、その時代の建物・レシピ・装備・役職が使えるようになる。

signal era_changed(era: String)

var current: String = "stone"
var _timer: float = 0.0


func key() -> String:
	return "era"


func next_era() -> String:
	var order: Array = Era.order()
	var i: int = order.find(current)
	return "" if i < 0 or i + 1 >= order.size() else str(order[i + 1])


## 次の時代の条件と達成状況: [{"label", "done"}]
func requirements() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var next: String = next_era()
	if next.is_empty():
		return result
	var req: Dictionary = GameData.get_dict("eras")["eras"][next].get("requires", {})
	if req.has("level"):
		result.append({"label": Texts.t("req_level", {"level": req["level"]}), "done": village.level.level >= int(req["level"])})
	for type: String in req.get("buildings", {}):
		var need: int = int(req["buildings"][type])
		var have: int = village.buildings.values().filter(func(b: Building) -> bool: return b.type == type and b.is_complete()).size()
		result.append({"label": Texts.t("req_building", {"name": GameData.get_dict("buildings")[type]["name"], "count": need}), "done": have >= need})
	if req.has("residents"):
		result.append({"label": Texts.t("req_residents", {"count": req["residents"]}), "done": village.level.residents() >= int(req["residents"])})
	for item: String in req.get("stock", {}):
		result.append({"label": Texts.t("req_stock", {"name": village.item_def(item).get("name", item), "count": req["stock"][item]}), "done": village.stock_count(item) >= int(req["stock"][item])})
	return result


func update(dt: float) -> void:
	_timer -= dt
	if _timer > 0.0:
		return
	_timer = 30.0
	var next: String = next_era()
	if next.is_empty():
		return
	for r in requirements():
		if not r["done"]:
			return
	advance()


func advance() -> void:
	var next: String = next_era()
	if next.is_empty():
		return
	current = next
	village.raise_alert("era", Texts.t("alert_era", {"name": Era.display_name(current)}), village.world.start)
	era_changed.emit(current)


func allows(entry: Dictionary) -> bool:
	return Era.allows(entry, current)


func to_dict() -> Dictionary:
	return {"current": current}


func from_dict(data: Dictionary) -> void:
	current = str(data.get("current", "stone"))
