class_name Inspection
extends RefCounted
## 移住希望者の来訪と見回り(AC-011, AC-031, AC-033)。ゲーム内5〜7日ごとに1人来て、
## 家・倉庫・救護室を順に見て回ってから採点表を出す。襲撃中は村の外で待つ。

signal applicant_arrived(applicant: Applicant)
signal inspection_finished(result: Dictionary)

var village: Village
var cfg: Dictionary = {}
var next_visit_at: float = 0.0
var current: Applicant
## 見回り中の状態: "walking" / "waiting"(襲撃中で村の外)
var phase: String = ""
var rejected: Array = []
var accepted: Array = []
var results: Array = []
## 今の希望者が見た建物の種類(順番どおり)
var tour_log: Array = []
## 合格者を迎えるか断るかをプレイヤーが選ぶ(双方向の審査 M10-T02)。画面のあるゲームでは true
var require_decision: bool = false
## 決めるのを待っている合格者: {"result", "until"}
var pending: Dictionary = {}
## 襲撃中か(M3-T03 の RaidDirector が入れる)
var is_raid_active: Callable = func() -> bool: return false


func _init(target: Village) -> void:
	village = target
	cfg = GameData.get_dict("applicants")
	schedule_next()


func schedule_next() -> void:
	var interval: Array = cfg["visit_interval_days"]
	var days: float = village.rng.randf_range(float(interval[0]), float(interval[1]))
	# 評判が高いほど早く来る
	var rep: VillageSystem = village.system("reputation")
	if rep != null:
		var factor: Dictionary = cfg["reputation_interval"]
		days *= lerpf(float(factor["low"]), float(factor["high"]), (rep as Reputation).value / 100.0)
	next_visit_at = village.clock.minutes + days * GameClock.MINUTES_PER_DAY


## まだ来ていない(不合格でも合格でもない)希望者
func candidates() -> Array:
	var result: Array = []
	for entry: Dictionary in cfg["applicants"]:
		var applicant_id: String = str(entry["id"])
		if not rejected.has(applicant_id) and not accepted.has(applicant_id):
			result.append(entry)
	return result


func update(dt: float) -> void:
	if not pending.is_empty():
		if village.clock.minutes >= float(pending["until"]):
			decide(true)
		return
	if current == null:
		if village.clock.minutes >= next_visit_at:
			arrive()
		return
	if is_raid_active.call():
		phase = "waiting"
		return
	if phase == "waiting":
		phase = "walking"
		current.body.clear_plan()
		_plan_route()
	village.run_plan(current.body, dt)
	if not current.body.plan.is_empty():
		var step: Dictionary = current.body.plan[0]
		if step.has("visit") and not step.get("logged", false):
			step["logged"] = true
			tour_log.append(step["visit"])
	if current.body.plan.is_empty():
		finish()


## 評判が高いほど、質のよい(quality の高い)希望者が来やすい
func _pick(pool: Array) -> Dictionary:
	var rep: float = (village.system("reputation") as Reputation).value if village.system("reputation") != null else 50.0
	var weights: Array = pool.map(func(e: Dictionary) -> float: return 1.0 + (float(e.get("quality", 1)) - 1.0) * rep / 50.0)
	var total: float = 0.0
	for w: float in weights:
		total += w
	var roll: float = village.rng.randf() * total
	for i in pool.size():
		roll -= float(weights[i])
		if roll <= 0.0:
			return pool[i]
	return pool[-1]


func arrive() -> void:
	var pool: Array = candidates()
	if pool.is_empty():
		schedule_next()
		return
	current = Applicant.from_data(_pick(pool))
	tour_log.clear()
	current.body.place_at(_entry_cell())
	phase = "walking"
	_plan_route()
	if is_raid_active.call():
		phase = "waiting"
	village.raise_alert("applicant", current.introduction(), current.body.cell())
	applicant_arrived.emit(current)


## 見回りの順路。ない建物は飛ばす
func _plan_route() -> void:
	var steps: Array[Dictionary] = []
	for type: String in cfg["route"]:
		for b: Building in village.buildings.values():
			if b.type == type and b.is_complete():
				steps.append({"op": "goto", "target": b.cell, "adjacent": true, "building": b.id, "optional": true})
				steps.append({"op": "wait", "minutes": float(cfg["stop_minutes"]), "visit": type})
				break
	current.body.plan = steps
	current.body.plan_kind = "inspect"


## 村の外(開始地点から spawn_distance 離れた、歩ける所)
func _entry_cell() -> Vector2i:
	var start: Vector2i = village.world.start
	var distance: int = int(cfg["spawn_distance"])
	for attempt in 32:
		var angle: float = village.rng.randf() * TAU
		var cell: Vector2i = start + Vector2i(roundi(cos(angle) * distance), roundi(sin(angle) * distance))
		if village.world.is_walkable(cell) and village.pathing.is_reachable(cell, start):
			return cell
	return start


func finish() -> void:
	var result: Dictionary = ScoreCard.evaluate(village, current)
	results.append(result)
	if result["passed"] and require_decision:
		pending = {"result": result, "until": village.clock.minutes + float(cfg["decision_minutes"])}
		inspection_finished.emit(result)
		return
	_conclude(result)


## 合格者を迎える(true)か断る(false)。断ると評判が下がり、その人は二度と来ない
func decide(accept: bool) -> void:
	if pending.is_empty():
		return
	var result: Dictionary = pending["result"]
	pending = {}
	if not accept:
		rejected.append(current.id)
		village.raise_alert("refused", Texts.t("alert_refused", {"name": current.display_name}), current.body.cell())
		current = null
		phase = ""
		schedule_next()
		return
	_conclude(result, false)


func _conclude(result: Dictionary, emit: bool = true) -> void:
	if result["passed"]:
		accepted.append(current.id)
		var v: Villager = village.add_villager(current.display_name, current.body.cell())
		v.specialty = current.specialty
		v.traits = Traits.roll(village.rng)
		village.raise_alert("accepted", Texts.t("alert_accepted", {"name": current.display_name}), v.cell())
	else:
		rejected.append(current.id)
		village.raise_alert("rejected", Texts.t("alert_rejected", {"name": current.display_name}), current.body.cell())
	current = null
	phase = ""
	schedule_next()
	if emit:
		inspection_finished.emit(result)


func to_dict() -> Dictionary:
	var data: Dictionary = {"next_visit_at": next_visit_at, "rejected": rejected.duplicate(), "accepted": accepted.duplicate(), "results": results.duplicate(true), "pending": pending.duplicate(true)}
	if current != null:
		data["current"] = {"id": current.id, "pos": [current.body.pos.x, current.body.pos.y], "phase": phase}
	return data


func from_dict(data: Dictionary) -> void:
	next_visit_at = float(data["next_visit_at"])
	rejected = (data["rejected"] as Array).duplicate()
	accepted = (data["accepted"] as Array).duplicate()
	results = (data.get("results", []) as Array).duplicate(true)
	pending = (data.get("pending", {}) as Dictionary).duplicate(true)
	current = null
	if data.has("current"):
		current = Applicant.from_data(Applicant.find(str(data["current"]["id"])))
		current.body.pos = Vector2(float(data["current"]["pos"][0]), float(data["current"]["pos"][1]))
		phase = "waiting"
