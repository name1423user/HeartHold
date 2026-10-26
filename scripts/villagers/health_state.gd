class_name HealthState
extends RefCounted
## 気絶・救護・死亡(AC-020)。気絶した村人はゲーム内半日以内に救護室へ運ばれれば回復し、
## 運ばれなければ死亡して警告が出る。村長は死なずに瀕死になる(AC-019、M3-T06)。
## 村人が0人になってもゲームオーバーにはしない。


static func cfg() -> Dictionary:
	return GameData.get_dict("health")


## 気絶したときに呼ぶ。救護の仕事を積む
static func on_knocked_out(village: Village, v: Villager) -> void:
	v.timers["down_minutes"] = 0.0
	v.timers.erase("carried_by")
	v.timers.erase("waiting_at")
	for other in village.villagers:
		if int(other.timers.get("carried_by", -1)) == v.id:
			other.timers.erase("carried_by")
	var task := JobTask.new()
	task.type = "rescue"
	task.cell = v.cell()
	task.extra["patient"] = v.id
	village.tasks.add(task)


static func rescue_task_for(village: Village, patient: Villager) -> JobTask:
	for task: JobTask in village.tasks.of_type("rescue"):
		if int(task.extra["patient"]) == patient.id:
			return task
	return null


## 救護室のうち空きのあるもの、なければ一番近いもの
static func infirmary_for(village: Village, from: Vector2) -> Building:
	var best: Building = null
	var best_distance: float = INF
	for b: Building in village.buildings.values():
		if b.type != "infirmary" or not b.is_complete():
			continue
		var distance: float = from.distance_to(b.center()) + (0.0 if free_slots(village, b) > 0 else 1000.0)
		if distance < best_distance:
			best = b
			best_distance = distance
	return best


## 同時に治療できる人数(寝台の数)
static func slots(b: Building) -> int:
	return roundi(BuildingFixture.sum_effect(b, "treatment_slots"))


static func free_slots(village: Village, b: Building) -> int:
	var used: int = 0
	for v in village.villagers:
		if v.state == Villager.State.IN_TREATMENT and int(v.timers.get("infirmary", -1)) == b.id:
			used += 1
	return slots(b) - used


## 治療にかかるゲーム内の分。村長は実時間3分(AS-002)。医療器具で短くなる(M3-T09)
static func treatment_minutes(village: Village, v: Villager, b: Building) -> float:
	var minutes: float = float(cfg()["treatment_minutes"])
	if v.is_chief:
		minutes = village.clock.real_to_minutes(float(cfg()["chief_treatment_real_seconds"]))
	return minutes * BuildingFixture.product_effect(b, "treatment_time_multiplier")


## 救護室へ入れる。空きがなければその場で待つ(待っている間は死なない)
static func admit(village: Village, patient: Villager, b: Building) -> void:
	patient.timers.erase("carried_by")
	if free_slots(village, b) <= 0:
		patient.timers["waiting_at"] = b.id
		return
	patient.timers.erase("waiting_at")
	patient.state = Villager.State.IN_TREATMENT
	patient.timers["infirmary"] = b.id
	patient.timers["treatment_left"] = treatment_minutes(village, patient, b)
	var task: JobTask = rescue_task_for(village, patient)
	if task != null:
		village.tasks.remove(task.id)


static func update(village: Village, v: Villager, dt: float) -> void:
	if v.state == Villager.State.IN_TREATMENT:
		v.timers["treatment_left"] = float(v.timers["treatment_left"]) - dt
		if float(v.timers["treatment_left"]) <= 0.0:
			recover(village, v)
		return
	var carrier: Villager = village.get_villager(int(v.timers.get("carried_by", -1)))
	if carrier != null:
		v.pos = carrier.pos
		return
	if v.timers.has("waiting_at"):
		var b: Building = village.buildings.get(int(v.timers["waiting_at"])) as Building
		if b != null:
			admit(village, v, b)
		return
	if v.is_chief:
		return
	v.timers["down_minutes"] = float(v.timers.get("down_minutes", 0.0)) + dt
	if float(v.timers["down_minutes"]) >= float(cfg()["death_minutes"]):
		die(village, v)


static func recover(village: Village, v: Villager) -> void:
	v.state = Villager.State.NORMAL
	v.needs.set_value("health", float(cfg()["recovered_health"]))
	if v.needs.get_value("food") <= 0.0:
		v.needs.set_value("food", float(village.needs_cfg["eat_below"]))
	for key in ["down_minutes", "infirmary", "treatment_left", "waiting_at", "carried_by"]:
		v.timers.erase(key)
	v.clear_plan()
	village.raise_alert("recovered", Texts.t("alert_recovered", {"name": v.display_name}), v.cell())


static func die(village: Village, v: Villager) -> void:
	v.state = Villager.State.DEAD
	v.home_id = -1
	var task: JobTask = rescue_task_for(village, v)
	if task != null:
		village.tasks.remove(task.id)
	village.raise_alert("death", Texts.t("alert_death", {"name": v.display_name}), v.cell())


## 救護の手順: 倒れた人のところへ行き、担いで救護室へ運ぶ
static func plan_rescue(village: Village, task: JobTask) -> Array[Dictionary]:
	var patient: Villager = village.get_villager(int(task.extra["patient"]))
	if patient == null:
		return []
	return [
		{"op": "goto", "target": patient.cell(), "adjacent": false},
		{"op": "pickup"},
		{"op": "carry_to_infirmary"},
	]


static func step_pickup(village: Village, v: Villager) -> void:
	v.plan.pop_front()
	var task: JobTask = village.tasks.get_task(v.task_id)
	if task == null:
		return
	var patient: Villager = village.get_villager(int(task.extra["patient"]))
	if patient == null or patient.state != Villager.State.UNCONSCIOUS:
		v.plan.clear()
		return
	patient.timers["carried_by"] = v.id
	v.plan_kind = "carry_patient"


static func step_carry(village: Village, v: Villager) -> void:
	v.plan.pop_front()
	var task: JobTask = village.tasks.get_task(v.task_id)
	if task == null:
		return
	var patient: Villager = village.get_villager(int(task.extra["patient"]))
	var b: Building = infirmary_for(village, v.pos)
	if patient == null or b == null:
		if patient != null:
			patient.timers.erase("carried_by")
		return
	v.plan.push_front({"op": "admit", "building": b.id})
	v.plan.push_front({"op": "goto", "target": b.cell, "adjacent": true, "building": b.id})


static func step_admit(village: Village, v: Villager, step: Dictionary) -> void:
	v.plan.pop_front()
	var task: JobTask = village.tasks.get_task(v.task_id)
	if task == null:
		return
	var patient: Villager = village.get_villager(int(task.extra["patient"]))
	var b: Building = village.buildings.get(int(step["building"])) as Building
	if patient == null or b == null:
		return
	patient.pos = v.pos
	admit(village, patient, b)
	if village.tasks.get_task(task.id) != null:
		village.tasks.remove(task.id)
	v.task_id = -1
