class_name Designation
extends RefCounted
## 範囲指示(伐る・掘る・建てる)。範囲から仕事を作ってキューに積む(AC-003, AC-004)。


## 範囲内の木をすべて「伐る」予約にする。戻り値は作った数
static func chop_area(village: Village, area: Rect2i) -> int:
	var created: int = 0
	var work: float = float(GameData.get_dict("resources")["work_minutes"]["chop"])
	for cell: Vector2i in village.world.trees:
		if area.has_point(cell) and not village.tasks.has_type_at("chop", cell):
			var task := JobTask.new()
			task.type = "chop"
			task.cell = cell
			task.work_needed = work
			village.tasks.add(task)
			created += 1
	return created


## 範囲内の各列の一番上を1段「掘る」予約にする。
## 戻り値: {"created": 作った数, "message": 断ったときの文言(なければ空)}
static func dig_area(village: Village, area: Rect2i) -> Dictionary:
	var created: int = 0
	var message: String = ""
	for z in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			var cell := Vector2i(x, z)
			if not village.world.in_bounds_2d(cell):
				continue
			var result: Dictionary = dig_block(village, Vector3i(x, village.world.top_y(cell), z))
			if result["ok"]:
				created += 1
			elif message.is_empty():
				message = result["message"]
	return {"created": created, "message": message if created == 0 else ""}


## 1ブロックを掘る予約。深すぎるときは予約せず文言を返す
static func dig_block(village: Village, pos: Vector3i) -> Dictionary:
	var error: String = village.editor.break_error(pos)
	if not error.is_empty():
		return {"ok": false, "message": Texts.t(error)}
	var cell := Vector2i(pos.x, pos.z)
	for task: JobTask in village.tasks.of_type("dig"):
		if task.pos == pos:
			return {"ok": false, "message": ""}
	var task := JobTask.new()
	task.type = "dig"
	task.cell = cell
	task.pos = pos
	task.work_needed = float(GameData.get_dict("resources")["work_minutes"]["dig"])
	village.tasks.add(task)
	return {"ok": true}


## 建てる予約(M2-T07 の建物と建設)
static func build(village: Village, type: String, cell: Vector2i) -> Dictionary:
	return village.plan_building(type, cell)


## 保留中の仕事の表示文言(到達できない → 「行けません」)
static func status_text(task: JobTask) -> String:
	return "" if task.blocked_reason.is_empty() else Texts.t("task_" + task.blocked_reason)
