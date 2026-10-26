class_name Tutorial
extends RefCounted
## くわしいチュートリアル(M11-T02)。手順ごとに条件(data/tutorial.json)を満たすと次へ進む。
## 条件のない説明の手順は「次へ」で進む。いつでもやめられる。

var village: Village
var step: int = 0
var active: bool = false


func _init(target: Village) -> void:
	village = target


static func steps() -> Array:
	return GameData.get_dict("tutorial")["steps"]


func is_finished() -> bool:
	return not active or step >= steps().size()


func current() -> Dictionary:
	return {} if is_finished() else steps()[step]


func needs_next_button() -> bool:
	return not is_finished() and current().get("cond") == null


func next() -> void:
	step += 1


func stop() -> void:
	active = false


func update() -> void:
	while not is_finished():
		var cond: Variant = current().get("cond")
		if cond == null or not Conditions.check(village, cond):
			return
		step += 1
