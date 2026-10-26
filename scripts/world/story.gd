class_name Story
extends VillageSystem
## 物語・シナリオ(M10-T03)。日数・建物・出来事・時代をきっかけに章が進み、画面に話が出る。
## 章によっては交易の相手が増える。文は data/story.json。

signal chapter_started(chapter: Dictionary)

var done: Array = []
var _queue: Array = []


func _init(target: Village) -> void:
	super(target)
	village.alert_raised.connect(func(kind: String, _m: String, _c: Vector2i) -> void: _queue.append(kind))


func key() -> String:
	return "story"


static func chapters() -> Array:
	return GameData.get_dict("story")["chapters"]


func update(_dt: float) -> void:
	for chapter: Dictionary in chapters():
		if done.has(chapter["id"]) or not _triggered(chapter["trigger"]):
			continue
		done.append(chapter["id"])
		var trade: Trade = village.system("trade") as Trade
		for i in int(chapter.get("unlock_partners", 0)):
			if trade != null:
				trade.unlock_partner()
		village.raise_alert("story", str(chapter["title"]), village.world.start)
		chapter_started.emit(chapter)
	_queue.clear()


func _triggered(trigger: Dictionary) -> bool:
	match str(trigger["type"]):
		"day":
			return village.clock.day() >= int(trigger["value"])
		"building":
			return village.nearest_building(Vector2(village.world.start), [str(trigger["value"])]) != null
		"alert":
			return _queue.has(str(trigger["value"]))
		"era":
			return Era.index_of(village.era()) >= Era.index_of(str(trigger["value"]))
	return false


func to_dict() -> Dictionary:
	return {"done": done.duplicate()}


func from_dict(data: Dictionary) -> void:
	done = (data.get("done", []) as Array).duplicate()
