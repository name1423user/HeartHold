class_name VillageClues
extends VillageSystem
## 他の村の手がかり(M9-T04)。霧の中に置かれ(シードで決まる)、見つけると交易の相手が1つ増える(最大5つ、M10-T01)。

var sites: Array[Dictionary] = []


func _init(target: Village) -> void:
	super(target)
	_generate()


func key() -> String:
	return "village_clues"


static func cfg() -> Dictionary:
	return GameData.get_dict("village_clues")


func _generate() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = village.world.seed + 6
	var range_count: Array = cfg()["count"]
	var count: int = rng.randi_range(int(range_count[0]), int(range_count[1]))
	var world: WorldData = village.world
	var guard: int = 0
	while sites.size() < count and guard < 3000:
		guard += 1
		var cell := Vector2i(rng.randi_range(4, world.size.x - 5), rng.randi_range(4, world.size.z - 5))
		if not world.is_walkable(cell) or Vector2(cell).distance_to(Vector2(world.start)) < float(cfg()["min_distance"]):
			continue
		if village.fog.is_explored(cell) or sites.any(func(s: Dictionary) -> bool: return Vector2(s["cell"]).distance_to(Vector2(cell)) < 25.0):
			continue
		sites.append({"id": sites.size() + 1, "cell": cell, "found": false})


func update(_dt: float) -> void:
	for s in sites:
		if s["found"] or not village.fog.is_visible(s["cell"]):
			continue
		s["found"] = true
		var trade: Trade = village.system("trade") as Trade
		var partner: String = trade.unlock_partner() if trade != null else ""
		var partner_name: String = trade.partner_name(partner) if not partner.is_empty() else ""
		village.raise_alert("clue", Texts.t("alert_clue", {"name": partner_name}) if not partner_name.is_empty() else Texts.t("alert_clue_none"), s["cell"])


func to_dict() -> Dictionary:
	return {"found": sites.map(func(s: Dictionary) -> bool: return s["found"])}


func from_dict(data: Dictionary) -> void:
	var found: Array = data.get("found", [])
	for i in mini(found.size(), sites.size()):
		sites[i]["found"] = bool(found[i])
