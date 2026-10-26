class_name Calendar
extends VillageSystem
## 季節と天候(M7-T01)。1季節 = days_per_season 日、4季節で1年。天候は数時間ごとに変わる。
## 気温は季節・天候・夜で決まり、体温の欲求(M7-T02)や作物の育ち(M7-T08)が使う。数値は data/seasons.json。

signal weather_changed(weather: String)
signal season_changed(season: String)

var weather: String = "clear"
var _weather_timer: float = 0.0
var _last_season: int = -1


func key() -> String:
	return "calendar"


func cfg() -> Dictionary:
	return GameData.get_dict("seasons")


func days_per_year() -> int:
	return int(cfg()["days_per_season"]) * (cfg()["seasons"] as Array).size()


func season_index() -> int:
	return int((village.clock.day() - 1) / int(cfg()["days_per_season"])) % (cfg()["seasons"] as Array).size()


func season() -> Dictionary:
	return cfg()["seasons"][season_index()]


func season_id() -> String:
	return str(season()["id"])


func year() -> int:
	return int((village.clock.day() - 1) / days_per_year()) + 1


func weather_def() -> Dictionary:
	return cfg()["weathers"][weather]


func temperature() -> float:
	var t: float = float(season()["temperature"]) + float(weather_def()["temperature"])
	if village.clock.is_night():
		t -= float(cfg()["night_temperature_drop"])
	return t


func growth() -> float:
	return float(season()["growth"])


func label() -> String:
	return Texts.t("calendar_label", {"year": year(), "season": season()["name"], "weather": weather_def()["name"], "temp": roundi(temperature())})


func update(dt: float) -> void:
	var index: int = season_index()
	if index != _last_season:
		var first: bool = _last_season == -1
		_last_season = index
		if not first:
			village.raise_alert("season", Texts.t("alert_season", {"season": season()["name"]}), village.world.start)
			season_changed.emit(season_id())
		_roll_weather()
	_weather_timer -= dt
	if _weather_timer <= 0.0:
		_roll_weather()


func _roll_weather() -> void:
	_weather_timer = float(cfg()["weather_change_hours"]) * 60.0
	var chances: Dictionary = season()["weather"]
	var roll: float = village.rng.randf()
	var next: String = str(chances.keys()[0])
	for w: String in chances:
		roll -= float(chances[w])
		if roll <= 0.0:
			next = w
			break
	if next != weather:
		weather = next
		weather_changed.emit(weather)


func update_villager(v: Villager, dt: float) -> void:
	var drop: float = float(weather_def()["mood_per_hour"])
	if drop != 0.0 and not village.is_indoors(v):
		v.needs.add("mood", drop * dt / 60.0)


## 外の仕事は天候で遅くなる
func work_speed(_v: Villager, kind: String) -> float:
	if (cfg()["outdoor_kinds"] as Array).has(kind):
		return float(weather_def()["work_speed"])
	return 1.0


func to_dict() -> Dictionary:
	return {"weather": weather, "weather_timer": _weather_timer, "last_season": _last_season}


func from_dict(data: Dictionary) -> void:
	weather = str(data.get("weather", "clear"))
	_weather_timer = float(data.get("weather_timer", 0.0))
	_last_season = int(data.get("last_season", -1))
