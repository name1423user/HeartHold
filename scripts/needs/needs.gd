class_name Needs
extends RefCounted
## 欲求4つ(食事・睡眠・気分・体力)。値は 0〜max。数値は data/needs.json(AC-009)。

const KEYS: Array[String] = ["food", "sleep", "mood", "health"]
## 後から足した欲求(M7-T02)。値が低いほど困っている
const EXTRA_KEYS: Array[String] = ["fun", "social", "hygiene", "warmth", "calm"]
const ALL_KEYS: Array[String] = ["food", "sleep", "mood", "health", "fun", "social", "hygiene", "warmth", "calm"]

var values: Dictionary = {}
var cfg: Dictionary = {}


func _init() -> void:
	cfg = GameData.get_dict("needs")
	values = (cfg["start"] as Dictionary).duplicate()


func get_value(key: String) -> float:
	return float(values[key])


func set_value(key: String, value: float) -> void:
	values[key] = clampf(value, 0.0, float(cfg["max"]))


func add(key: String, amount: float) -> void:
	set_value(key, get_value(key) + amount)


func ratio(key: String) -> float:
	return get_value(key) / float(cfg["max"])


## minutes 分ぶん進める。sleeping なら睡眠が回復する。mood_rate は気分の回復倍率
func tick(minutes: float, sleeping: bool, sleep_multiplier: float = 1.0, mood_rate: float = 1.0) -> void:
	var hours: float = minutes / 60.0
	var decay: Dictionary = cfg["decay_per_hour"]
	add("food", -float(decay["food"]) * hours)
	if sleeping:
		add("sleep", float(cfg["sleep_recovery_per_hour"]) * sleep_multiplier * hours)
	else:
		add("sleep", -float(decay["sleep"]) * hours)

	var low: float = float(cfg["low_need_for_mood"])
	if get_value("food") < low or get_value("sleep") < low:
		add("mood", -float(cfg["mood_drop_per_hour_when_low"]) * hours)
	elif get_value("mood") < float(cfg["mood_baseline"]):
		add("mood", float(cfg["mood_recovery_per_hour"]) * mood_rate * hours)

	if get_value("food") <= 0.0:
		add("health", -float(cfg["starving_health_loss_per_hour"]) * hours)
	else:
		add("health", float(cfg["health_recovery_per_hour"]) * hours)


func is_low(key: String) -> bool:
	return get_value(key) < float(cfg["warning_below"])


func to_dict() -> Dictionary:
	return values.duplicate()


func from_dict(data: Dictionary) -> void:
	for key in ALL_KEYS:
		set_value(key, float(data.get(key, values.get(key, cfg["start"].get(key, 50.0)))))
