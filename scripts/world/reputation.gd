class_name Reputation
extends VillageSystem
## 評判(M10-T02)。0〜100。審査の合否・断ったこと・襲撃の結果・死者・祭り・巣を潰す・村の象徴で上下する。
## 高いほど質のよい移住希望者が早く来て、交易の値段がよくなる。上下の量は data/reputation.json。

signal changed(value: float, reason: String)

var value: float = 50.0


func _init(target: Village) -> void:
	super(target)
	village.alert_raised.connect(_on_alert)


func key() -> String:
	return "reputation"


func change(amount: float, reason: String) -> void:
	value = clampf(value + amount, 0.0, 100.0)
	changed.emit(value, reason)


func _on_alert(kind: String, _message: String, _cell: Vector2i) -> void:
	var changes: Dictionary = GameData.get_dict("reputation")["changes"]
	if changes.has(kind):
		change(float(changes[kind]), kind)


func to_dict() -> Dictionary:
	return {"value": value}


func from_dict(data: Dictionary) -> void:
	value = float(data.get("value", 50.0))
