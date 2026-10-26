class_name Reputation
extends VillageSystem
## 評判(M10-T02 で中身を広げる)。0〜100。

signal changed(value: float, reason: String)

var value: float = 50.0


func key() -> String:
	return "reputation"


func change(amount: float, reason: String) -> void:
	value = clampf(value + amount, 0.0, 100.0)
	changed.emit(value, reason)


func to_dict() -> Dictionary:
	return {"value": value}


func from_dict(data: Dictionary) -> void:
	value = float(data.get("value", 50.0))
