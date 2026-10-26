class_name GameClock
extends RefCounted
## ゲーム内時刻(分)。ゲーム内1日 = 実時間 real_seconds_per_day 秒(AS-004)。

const MINUTES_PER_DAY: float = 1440.0

var minutes: float = 0.0
var paused: bool = false
var cfg: Dictionary = {}


func _init() -> void:
	cfg = GameData.get_dict("time")
	minutes = float(cfg["start_hour"]) * 60.0


## 実時間の秒をゲーム内の分に直す
func real_to_minutes(seconds: float) -> float:
	return seconds * MINUTES_PER_DAY / float(cfg["real_seconds_per_day"])


func minutes_to_real(game_minutes: float) -> float:
	return game_minutes * float(cfg["real_seconds_per_day"]) / MINUTES_PER_DAY


func advance(game_minutes: float) -> void:
	minutes += game_minutes


## 1日目から数える
func day() -> int:
	return int(minutes / MINUTES_PER_DAY) + 1


func hour() -> float:
	return fmod(minutes, MINUTES_PER_DAY) / 60.0


func is_night() -> bool:
	var h: float = hour()
	return h >= float(cfg["night_start_hour"]) or h < float(cfg["night_end_hour"])


func label() -> String:
	var h: float = hour()
	return Texts.t("clock_label", {"day": day(), "hour": "%02d" % int(h), "minute": "%02d" % int(fmod(minutes, 60.0))})
