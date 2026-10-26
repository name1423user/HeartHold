class_name Village
extends RefCounted
## 村全体のシミュレーション。村人は plan(手順の列)を1つずつこなす。
## 画面を持たないので、テストからそのまま進められる。

signal alert_raised(kind: String, message: String, cell: Vector2i)
signal block_changed(pos: Vector3i, id: int)
signal trees_changed
signal building_changed(building: Building)
signal villager_added(villager: Villager)

const MAX_STEP_MINUTES: float = 1.0
const NO_CELL := Vector2i(-1, -1)

var world: WorldData
var editor: TerrainEditor
var pathing: Pathing
var clock := GameClock.new()
var tasks := TaskQueue.new()
var villagers: Array[Villager] = []
var buildings: Dictionary = {}
## 地面に置かれた物。Vector2i -> {item: count}
var ground_items: Dictionary = {}
## 運搬中で予約済みの地面の山。Vector2i -> 村人ID
var ground_reserved: Dictionary = {}
var rng := RandomNumberGenerator.new()
var next_villager_id: int = 1
var next_building_id: int = 1
var villager_cfg: Dictionary = {}
var needs_cfg: Dictionary = {}

## 作業速度などにかける倍率を足すための口(装備・熟練度・特技・村長の方針)
var speed_modifiers: Array[Callable] = []
var wildlife: Wildlife
var inspection: Inspection
var raids: RaidDirector
## 魔物が村の境界に入っている(迎撃・避難の合図)
var raid_alarm: bool = false
var chief: Chief


func _init(target: WorldData) -> void:
	world = target
	editor = TerrainEditor.new(world)
	pathing = Pathing.new(world)
	editor.block_changed.connect(_on_block_changed)
	villager_cfg = GameData.get_dict("villagers")
	needs_cfg = GameData.get_dict("needs")
	rng.seed = world.seed
	wildlife = Wildlife.new(self)
	speed_modifiers.append(Equipment.speed)
	speed_modifiers.append(Proficiency.speed)
	speed_modifiers.append(Specialty.speed)
	inspection = Inspection.new(self)
	raids = RaidDirector.new(self)
	inspection.is_raid_active = func() -> bool: return raids.active
	chief = Chief.new(self)


static func create(seed: int) -> Village:
	return Village.new(TerrainGenerator.generate(seed))


# --- 村人 ---------------------------------------------------------------

func add_villager(display_name: String, at: Vector2i = NO_CELL) -> Villager:
	var v := Villager.new()
	v.id = next_villager_id
	next_villager_id += 1
	v.display_name = display_name
	v.place_at(_free_cell_near(world.start if at == NO_CELL else at))
	villagers.append(v)
	assign_homes()
	villager_added.emit(v)
	return v


func get_villager(id: int) -> Villager:
	for v in villagers:
		if v.id == id:
			return v
	return null


func living_villagers() -> Array[Villager]:
	var result: Array[Villager] = []
	for v in villagers:
		if v.state != Villager.State.DEAD:
			result.append(v)
	return result


func _free_cell_near(target: Vector2i) -> Vector2i:
	for radius in 8:
		for dz in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				var cell: Vector2i = target + Vector2i(dx, dz)
				if world.is_walkable(cell):
					return cell
	return target


# --- 時間を進める ---------------------------------------------------------

func tick(minutes: float) -> void:
	if clock.paused:
		return
	var remaining: float = minutes
	while remaining > 0.0:
		var dt: float = minf(remaining, MAX_STEP_MINUTES)
		remaining -= dt
		clock.advance(dt)
		_before_villagers(dt)
		for v in villagers.duplicate():
			_update_villager(v, dt)
		_after_villagers(dt)


## 村人より先に動かす仕組み(獲物・襲撃・審査など)
func _before_villagers(dt: float) -> void:
	wildlife.update(dt)
	raids.update(dt)
	_update_alarm()
	inspection.update(dt)


func _after_villagers(_dt: float) -> void:
	pass


func _update_villager(v: Villager, dt: float) -> void:
	if v.state == Villager.State.DEAD:
		return
	if v.state != Villager.State.NORMAL:
		_update_incapacitated(v, dt)
		return
	v.needs.tick(dt, v.sleeping, _sleep_multiplier(v), mood_rate(v))
	if v.needs.get_value("health") <= 0.0:
		knock_out(v)
		return
	if v.plan.is_empty():
		_choose_plan(v)
	_run_step(v, dt)


## 気絶・治療中の更新
func _update_incapacitated(v: Villager, dt: float) -> void:
	HealthState.update(self, v, dt)


func knock_out(v: Villager) -> void:
	_abort_plan(v, "")
	v.state = Villager.State.UNCONSCIOUS
	HealthState.on_knocked_out(self, v)
	var key: String = "alert_chief_dying" if v.is_chief else "alert_faint"
	raise_alert("faint", Texts.t(key, {"name": v.display_name}), v.cell())


## 魔物などから受けた傷。体力0で気絶する
func damage_villager(v: Villager, amount: float) -> void:
	v.needs.add("health", -amount)
	if v.needs.get_value("health") <= 0.0 and v.state == Villager.State.NORMAL:
		knock_out(v)


## 家や救護室に避難して、魔物に狙われない状態か(M3-T04)
func is_sheltered(v: Villager) -> bool:
	return v.plan_kind == "shelter" and not v.plan.is_empty() and str(v.plan[0]["op"]) == "wait"


func raise_alert(kind: String, message: String, cell: Vector2i) -> void:
	alert_raised.emit(kind, message, cell)


# --- 行動の選び方 -------------------------------------------------------

func _choose_plan(v: Villager) -> void:
	if raid_alarm and _choose_raid_plan(v):
		return
	if v.carry_count > 0:
		_set_plan(v, "store", [{"op": "store_carry"}])
		return
	if _choose_rescue_plan(v):
		return
	if _choose_need_plan(v):
		return
	if _choose_equipment_plan(v):
		return
	if _choose_task_plan(v):
		return
	if _choose_haul_plan(v):
		return
	_set_plan(v, "idle", [{"op": "wander"}, {"op": "wait", "minutes": 10.0}])


## 倒れた人がいれば最優先で救護室へ運ぶ
func _choose_rescue_plan(v: Villager) -> bool:
	if v.is_chief:
		return false
	var task: JobTask = tasks.find_for(["rescue"], v.cell(), clock.minutes)
	if task == null or HealthState.infirmary_for(self, v.pos) == null:
		return false
	task.assigned = v.id
	v.task_id = task.id
	_set_plan(v, "task", HealthState.plan_rescue(self, task))
	return true


## 襲撃中: 衛兵は迎え撃ち、他は避難する
func _choose_raid_plan(v: Villager) -> bool:
	if v.job == "guard" and not v.is_chief:
		_set_plan(v, "fight", [{"op": "fight"}])
		return true
	var shelter: Building = Combat.shelter_for(self, v)
	var steps: Array[Dictionary] = []
	if shelter != null:
		steps.append({"op": "goto", "target": shelter.cell, "adjacent": true, "building": shelter.id})
	steps.append({"op": "wait", "minutes": 1.0e9})
	_set_plan(v, "shelter", steps)
	return true


## 魔物が境界に入ったら合図を出し、全員の行動を切り替える。襲撃が終われば元に戻す
func _update_alarm() -> void:
	var inside: bool = false
	if raids.active:
		for m in raids.monsters:
			if raids.is_inside_village(m.pos):
				inside = true
				break
	if inside and not raid_alarm:
		raid_alarm = true
		if not raids.warned:
			raids.warned = true
			raise_alert("raid", Texts.t("alert_raid"), raids.monsters[0].cell())
		for v in villagers:
			if v.is_active() and v.plan_kind != "carry_patient":
				release_plan(v)
	elif not raids.active and raid_alarm:
		raid_alarm = false
		for v in villagers:
			if v.plan_kind == "shelter" or v.plan_kind == "fight":
				release_plan(v)


## 見張り台の上にいるか(M3-T08)
func is_on_watchtower(_v: Villager) -> bool:
	return false


func watchtower_target(_v: Villager) -> Monster:
	return null


## 目的の列へ向かって少し進む(追いかけ用)
func chase(v: Villager, target: Vector2i, budget: float) -> void:
	if v.cell() == target:
		return
	if v.path.is_empty() or v.path[-1] != target:
		v.path = pathing.find_path(v.cell(), target)
		if v.path.is_empty():
			var near: Vector2i = pathing.nearest_standable(v.cell(), target)
			if near != NO_CELL:
				v.path = pathing.find_path(v.cell(), near)
		if not v.path.is_empty():
			v.path.pop_front()
	var step: float = walk_speed(v) * budget
	while step > 0.0 and not v.path.is_empty():
		var next_pos: Vector2 = Vector2(v.path[0]) + Vector2(0.5, 0.5)
		var distance: float = v.pos.distance_to(next_pos)
		if distance <= step:
			v.pos = next_pos
			v.path.pop_front()
			step -= distance
		else:
			v.pos = v.pos.move_toward(next_pos, step)
			step = 0.0


func _choose_need_plan(v: Villager) -> bool:
	if v.needs.get_value("food") < float(needs_cfg["eat_below"]):
		var source: Dictionary = find_food_source(v.cell())
		if not source.is_empty():
			_set_plan(v, "eat", [
				{"op": "goto", "target": source["cell"], "adjacent": source["kind"] == "building"},
				{"op": "take", "source": source, "item": source["item"], "count": 1},
				{"op": "eat"},
			])
			return true
	var sleep_below: float = float(needs_cfg["night_sleep_below"]) if clock.is_night() else float(needs_cfg["sleep_below"])
	if v.needs.get_value("sleep") < sleep_below:
		var home: Building = buildings.get(v.home_id) as Building
		var steps: Array[Dictionary] = []
		if home != null and home.is_complete():
			steps.append({"op": "goto", "target": home.cell, "adjacent": true, "building": home.id})
		steps.append({"op": "sleep", "building": home.id if home != null and home.is_complete() else -1})
		_set_plan(v, "sleep", steps)
		return true
	return false


## 役職に合う装備が倉庫にあれば、自分で取りに行く(AC-038)
func _choose_equipment_plan(v: Villager) -> bool:
	if v.is_chief:
		return false
	var item: String = Equipment.wanted_item(self, v)
	if item.is_empty():
		return false
	var source: Dictionary = find_item_source(item, v.cell())
	if source.is_empty() or source["kind"] != "building":
		return false
	_set_plan(v, "equip", [
		{"op": "goto", "target": source["cell"], "adjacent": true, "building": source["id"]},
		{"op": "take", "source": source, "item": item, "count": 1},
		{"op": "equip"},
	])
	return true


## 役職の優先順位(data/jobs.json)で仕事を拾う
func _choose_task_plan(v: Villager) -> bool:
	if v.is_chief:
		return false
	var task: JobTask = tasks.find_for(task_types_for(v), v.cell(), clock.minutes)
	if task == null:
		return false
	task.assigned = v.id
	task.blocked_reason = ""
	v.task_id = task.id
	_set_plan(v, "task", plan_for_task(v, task))
	return true


func task_types_for(v: Villager) -> Array:
	var jobs: Dictionary = GameData.get_dict("jobs")
	var job: Dictionary = jobs.get(v.job, {})
	var types: Array = (job.get("priority", []) as Array).duplicate()
	for type: String in jobs.get("shared", []):
		if not types.has(type):
			types.append(type)
	return types


func plan_for_task(_v: Villager, task: JobTask) -> Array[Dictionary]:
	match task.type:
		"chop":
			return [{"op": "goto", "target": task.cell, "adjacent": true}, {"op": "work"}]
		"dig":
			return [{"op": "goto", "target": task.cell, "adjacent": true}, {"op": "work"}]
		"build", "fixture", "craft":
			return [{"op": "supply"}]
		"hunt":
			return [{"op": "hunt"}]
	return [{"op": "goto", "target": task.cell, "adjacent": true}, {"op": "work"}]


func _choose_haul_plan(v: Villager) -> bool:
	if v.is_chief:
		return false
	for cell: Vector2i in ground_items:
		if ground_reserved.has(cell):
			continue
		var pile: Dictionary = ground_items[cell]
		for item: String in pile:
			if best_stockpile_for(item, 1) == null:
				continue
			ground_reserved[cell] = v.id
			_set_plan(v, "haul", [
				{"op": "goto", "target": cell, "adjacent": false},
				{"op": "take", "source": {"kind": "ground", "cell": cell}, "item": item, "count": int(pile[item])},
				{"op": "store_carry"},
			])
			return true
	return false


func _set_plan(v: Villager, kind: String, steps: Array[Dictionary]) -> void:
	v.plan = steps
	v.plan_kind = kind
	v.path.clear()


## 今の行動をやめる。reason があれば仕事を保留にする
func _abort_plan(v: Villager, reason: String) -> void:
	if v.task_id != -1:
		var task: JobTask = tasks.get_task(v.task_id)
		if task != null:
			task.assigned = -1
			if not reason.is_empty():
				task.blocked_reason = reason
				task.retry_at = clock.minutes + float(villager_cfg["blocked_retry_minutes"])
	for cell: Vector2i in ground_reserved.keys():
		if ground_reserved[cell] == v.id:
			ground_reserved.erase(cell)
	# 担いでいた人はその場に降ろす
	for other in villagers:
		if int(other.timers.get("carried_by", -1)) == v.id:
			other.timers.erase("carried_by")
			var rescue: JobTask = HealthState.rescue_task_for(self, other)
			if rescue != null:
				rescue.cell = other.cell()
	v.clear_plan()


## 外から今の行動をやめさせる(役職変更・個人命令など)。持ち物は次の行動で片付ける
func release_plan(v: Villager) -> void:
	_abort_plan(v, "")


func _finish_plan(v: Villager) -> void:
	_abort_plan(v, "")


# --- 手順の実行 ---------------------------------------------------------

## 村人でない体(移住希望者など)の手順を進める
func run_plan(body: Villager, dt: float) -> void:
	var budget: float = dt
	var guard: int = 0
	while not body.plan.is_empty() and budget > 0.0 and guard < 16:
		guard += 1
		var used: float = _execute(body, body.plan[0], budget)
		if used < 0.0:
			if not body.plan.is_empty():
				body.plan.pop_front()
			continue
		budget -= used

func _run_step(v: Villager, dt: float) -> void:
	var budget: float = dt
	var guard: int = 0
	while not v.plan.is_empty() and budget > 0.0 and guard < 16:
		guard += 1
		var step: Dictionary = v.plan[0]
		var used: float = _execute(v, step, budget)
		if used < 0.0:
			return
		budget -= used
	if v.plan.is_empty() and v.plan_kind != "":
		_finish_plan(v)


## 手順を実行し、使った時間(分)を返す。手順が終われば plan から外す。
## 失敗で plan をやめたときは -1
func _execute(v: Villager, step: Dictionary, budget: float) -> float:
	match str(step["op"]):
		"goto":
			return _step_goto(v, step, budget)
		"work":
			return _step_work(v, budget)
		"take":
			_step_take(v, step)
			return 0.0
		"store_carry":
			_step_store_carry(v)
			return 0.0
		"put":
			_step_put(v, step)
			return 0.0
		"deliver":
			_step_deliver(v)
			return 0.0
		"supply":
			_step_supply(v)
			return 0.0
		"eat":
			_step_eat(v)
			return 0.0
		"sleep":
			return _step_sleep(v, step, budget)
		"wait":
			var left: float = float(step["minutes"]) - budget
			if left <= 0.0:
				v.plan.pop_front()
				return float(step["minutes"])
			step["minutes"] = left
			return budget
		"wander":
			var radius: int = int(villager_cfg["wander_radius"])
			var target: Vector2i = v.cell() + Vector2i(rng.randi_range(-radius, radius), rng.randi_range(-radius, radius))
			v.plan[0] = {"op": "goto", "target": target, "adjacent": false, "optional": true}
			return 0.0
	return _execute_extra(v, step, budget)


## そのほかの手順(狩り・戦い・運ぶ人を担ぐ など)
func _execute_extra(v: Villager, step: Dictionary, budget: float) -> float:
	match str(step["op"]):
		"pickup":
			HealthState.step_pickup(self, v)
			return 0.0
		"carry_to_infirmary":
			HealthState.step_carry(self, v)
			return 0.0
		"admit":
			HealthState.step_admit(self, v, step)
			return 0.0
		"fight":
			return Combat.step_fight(self, v, budget)
		"equip":
			v.plan.pop_front()
			if v.carry_count > 0 and Equipment.is_equipment(v.carry_item):
				Equipment.equip(v, v.carry_item)
				v.carry_count -= 1
				if v.carry_count <= 0:
					v.carry_item = ""
			return 0.0
		"hunt":
			var task: JobTask = tasks.get_task(v.task_id)
			if task == null:
				v.plan.pop_front()
				return 0.0
			var used: float = wildlife.step_hunt(v, task, budget)
			if used < 0.0:
				_fail(v, "unreachable")
			return used
	v.plan.pop_front()
	return 0.0


func _step_goto(v: Villager, step: Dictionary, budget: float) -> float:
	if not step.has("dest"):
		var target: Vector2i = step["target"]
		var dest: Vector2i = target
		if step.get("adjacent", false):
			dest = _adjacent_stand_cell(v.cell(), target, step.get("building", -1))
		if dest == NO_CELL or (dest != v.cell() and not pathing.is_reachable(v.cell(), dest)):
			if step.get("optional", false):
				v.plan.pop_front()
				return 0.0
			_fail(v, "unreachable")
			return -1.0
		step["dest"] = dest
		v.path = pathing.find_path(v.cell(), dest)
		if not v.path.is_empty():
			v.path.pop_front()
	var speed: float = walk_speed(v)
	var used: float = 0.0
	while used < budget:
		if v.path.is_empty():
			v.place_at(step["dest"])
			v.plan.pop_front()
			return used
		var next_cell: Vector2i = v.path[0]
		if not world.is_walkable(next_cell):
			step.erase("dest")
			return used
		var target_pos: Vector2 = Vector2(next_cell) + Vector2(0.5, 0.5)
		var distance: float = v.pos.distance_to(target_pos)
		var time_needed: float = distance / speed
		if time_needed <= budget - used:
			v.pos = target_pos
			used += time_needed
			v.path.pop_front()
		else:
			v.pos = v.pos.move_toward(target_pos, speed * (budget - used))
			used = budget
	return used


## 建物の周りや木の隣など、対象に触れられる立ち位置
func _adjacent_stand_cell(from: Vector2i, target: Vector2i, building_id: int) -> Vector2i:
	var targets: Array[Vector2i] = [target]
	var building: Building = buildings.get(building_id) as Building
	if building != null:
		targets = building.cells()
	if building == null and world.is_walkable(target) and (from == target or pathing.is_reachable(from, target)):
		return target
	var best: Vector2i = NO_CELL
	var best_length: int = 1 << 30
	for t in targets:
		for offset in Pathing.NEIGHBORS:
			var cell: Vector2i = t + offset
			if not world.is_walkable(cell):
				continue
			if cell == from:
				return cell
			var path: Array[Vector2i] = pathing.find_path(from, cell)
			if not path.is_empty() and path.size() < best_length:
				best = cell
				best_length = path.size()
	return best


func _fail(v: Villager, reason: String) -> void:
	if v.plan_kind == "task":
		var task: JobTask = tasks.get_task(v.task_id)
		if task != null:
			raise_alert("blocked", Texts.t("task_" + reason), task.cell)
	_abort_plan(v, reason)


func _step_work(v: Villager, budget: float) -> float:
	var task: JobTask = tasks.get_task(v.task_id)
	if task == null:
		v.plan.pop_front()
		return 0.0
	var skill: String = task_skill(task)
	var speed: float = work_speed(v, skill)
	var left: float = task.work_needed - task.progress
	var time_needed: float = left / speed
	if time_needed <= budget:
		task.progress = task.work_needed
		v.plan.pop_front()
		gain_experience(v, skill, time_needed)
		_complete_task(v, task)
		return time_needed
	task.progress += speed * budget
	gain_experience(v, skill, budget)
	return budget


## 熟練度の経験値を足す(M2-T10)
func gain_experience(v: Villager, kind: String, minutes: float) -> void:
	v.experience[kind] = float(v.experience.get(kind, 0.0)) + minutes


func _complete_task(v: Villager, task: JobTask) -> void:
	match task.type:
		"chop":
			world.trees.erase(task.cell)
			pathing.update_cell(task.cell)
			trees_changed.emit()
			_give(v, "log", int(GameData.get_dict("resources").get("logs_per_tree", 1)))
			wear_tool(v, "chop")
		"dig":
			var id: int = world.get_block(task.pos)
			var result: Dictionary = editor.break_block(task.pos)
			if result["ok"]:
				var drops: Dictionary = GameData.get_dict("resources").get("block_drops", {})
				var item: String = str(drops.get(_block_name(id), ""))
				if not item.is_empty():
					_give(v, item, 1)
			wear_tool(v, "dig")
		_:
			_complete_task_extra(v, task)
	tasks.remove(task.id)
	v.task_id = -1
	if v.carry_count > 0:
		v.plan.push_front({"op": "store_carry"})


## 建設・加工・狩りなどの完了処理
func _complete_task_extra(v: Villager, task: JobTask) -> void:
	match task.type:
		"craft":
			Crafting.complete(self, v, task)
			wear_tool(v, task_skill(task))
		"fixture":
			BuildingFixture.complete(self, task)
		"build":
			var b: Building = buildings.get(task.building_id) as Building
			if b != null:
				b.state = Building.State.COMPLETE
				_on_building_completed(b)
				building_changed.emit(b)
				raise_alert("built", Texts.t("alert_built", {"name": b.display_name()}), b.cell)


## 道具の耐久を減らす。合う道具でなければ減らない
func wear_tool(v: Villager, kind: String) -> void:
	Equipment.wear(self, v, "tool", kind)


## 仕事の種類から、速度や熟練度に使う作業の種類を出す(加工はレシピの種類)
func task_skill(task: JobTask) -> String:
	if task.type == "craft":
		return str(Crafting.recipe(task.recipe).get("skill", "craft"))
	return task.type


func _block_name(id: int) -> String:
	var ids: Dictionary = GameData.get_dict("terrain")["blocks"]
	for block_name: String in ids:
		if int(ids[block_name]) == id:
			return block_name
	return ""


func _give(v: Villager, item: String, count: int) -> void:
	if v.carry_count > 0 and v.carry_item != item:
		drop_on_ground(v.cell(), v.carry_item, v.carry_count)
		v.carry_count = 0
	v.carry_item = item
	v.carry_count += count


func _step_take(v: Villager, step: Dictionary) -> void:
	v.plan.pop_front()
	var taken: int = take_from(step["source"], str(step["item"]), int(step["count"]))
	if taken > 0:
		_give(v, str(step["item"]), taken)


func _step_store_carry(v: Villager) -> void:
	v.plan.pop_front()
	if v.carry_count <= 0:
		return
	var stockpile: Building = best_stockpile_for(v.carry_item, 1)
	if stockpile == null:
		var accepting: bool = _has_stockpile_accepting(v.carry_item)
		var key: String = "alert_storage_full" if accepting else "alert_no_storage"
		if not stockpiles().is_empty():
			raise_alert("storage", Texts.t(key), v.cell())
		drop_on_ground(v.cell(), v.carry_item, v.carry_count)
		v.carry_count = 0
		v.carry_item = ""
		return
	v.plan.push_front({"op": "put", "building": stockpile.id})
	v.plan.push_front({"op": "goto", "target": stockpile.cell, "adjacent": true, "building": stockpile.id})


func _step_put(v: Villager, step: Dictionary) -> void:
	v.plan.pop_front()
	var stockpile: Building = buildings.get(int(step["building"])) as Building
	if stockpile == null or v.carry_count <= 0:
		return
	var stored: int = store(stockpile, v.carry_item, v.carry_count)
	v.carry_count -= stored
	if v.carry_count > 0:
		v.plan.push_front({"op": "store_carry"})
	else:
		v.carry_item = ""


func _step_eat(v: Villager) -> void:
	v.plan.pop_front()
	if v.carry_count <= 0:
		return
	var item: Dictionary = item_def(v.carry_item)
	if item.get("category", "") != "food":
		return
	v.needs.add("food", float(item.get("food", 0.0)))
	v.carry_count -= 1
	if v.carry_count <= 0:
		v.carry_item = ""


func _step_sleep(v: Villager, _step: Dictionary, budget: float) -> float:
	v.sleeping = true
	var full: float = float(needs_cfg["max"]) * 0.95
	if v.needs.get_value("sleep") >= full:
		v.sleeping = false
		v.plan.pop_front()
		return 0.0
	return budget


## 建設・設備・加工の素材を集めてから作業する
func _step_supply(v: Villager) -> void:
	v.plan.pop_front()
	var task: JobTask = tasks.get_task(v.task_id)
	if task == null:
		return
	var site: Dictionary = supply_site(task)
	if site.has("error"):
		_abort_plan(v, str(site["error"]))
		return
	var missing: Dictionary = site["missing"]
	if missing.is_empty():
		v.plan.push_front({"op": "work"})
		v.plan.push_front({"op": "goto", "target": site["cell"], "adjacent": true, "building": site.get("building", -1)})
		return
	for item: String in missing:
		var source: Dictionary = find_item_source(item, v.cell())
		if source.is_empty():
			continue
		var count: int = mini(int(missing[item]), int(source["count"]))
		v.plan.push_front({"op": "supply"})
		v.plan.push_front({"op": "deliver"})
		v.plan.push_front({"op": "goto", "target": site["cell"], "adjacent": true, "building": site.get("building", -1)})
		v.plan.push_front({"op": "take", "source": source, "item": item, "count": count})
		v.plan.push_front({"op": "goto", "target": source["cell"], "adjacent": source["kind"] == "building", "building": source.get("id", -1)})
		return
	raise_alert("material", Texts.t("alert_missing_materials"), task.cell)
	var short: Building = buildings.get(task.building_id) as Building
	if short != null and task.type == "build":
		short.short = true
		building_changed.emit(short)
	_abort_plan(v, "missing_materials")


## 仕事ごとの素材置き場と不足
func supply_site(task: JobTask) -> Dictionary:
	match task.type:
		"craft":
			return Crafting.supply_site(self, task)
		"fixture":
			return BuildingFixture.supply_site(self, task)
		"build":
			var b: Building = buildings.get(task.building_id) as Building
			if b == null:
				return {"cell": NO_CELL, "missing": {}, "error": "unreachable"}
			return {"cell": b.cell, "missing": b.missing_materials(), "building": b.id}
	return {"cell": task.cell, "missing": {}}


## 運んできた素材を現場に納める
func _step_deliver(v: Villager) -> void:
	v.plan.pop_front()
	var task: JobTask = tasks.get_task(v.task_id)
	if task == null or v.carry_count <= 0:
		return
	deliver_to_site(task, v.carry_item, v.carry_count)
	v.carry_count = 0
	v.carry_item = ""


func deliver_to_site(task: JobTask, item: String, count: int) -> void:
	if task.type == "build":
		var b: Building = buildings.get(task.building_id) as Building
		if b != null:
			b.delivered[item] = int(b.delivered.get(item, 0)) + count
			b.state = Building.State.BUILDING
			building_changed.emit(b)
		return
	var delivered: Dictionary = task.extra.get("delivered", {})
	delivered[item] = int(delivered.get(item, 0)) + count
	task.extra["delivered"] = delivered


# --- 建物 ---------------------------------------------------------------

## 建物を置けない理由の文言キー。置けるなら空
func building_error(type: String, cell: Vector2i) -> String:
	var def: Dictionary = GameData.get_dict("buildings").get(type, {})
	if def.is_empty():
		return "cannot_build_here"
	var probe := Building.new()
	probe.type = type
	probe.cell = cell
	var height: int = -1
	for c in probe.cells():
		if not world.is_walkable(c):
			return "cannot_build_here"
		if height == -1:
			height = world.top_y(c)
		elif absi(world.top_y(c) - height) > int(GameData.get_dict("terrain")["max_step"]):
			return "cannot_build_here"
	return ""


## 建物を置く。complete なら完成した状態で置く(開始時やテスト用)
func add_building(type: String, cell: Vector2i, complete: bool = false) -> Building:
	var b := Building.new()
	b.id = next_building_id
	next_building_id += 1
	b.type = type
	b.cell = cell
	b.state = Building.State.COMPLETE if complete else Building.State.PLANNED
	buildings[b.id] = b
	for c in b.cells():
		world.blocked[c] = b.id
		pathing.update_cell(c)
	if complete:
		_on_building_completed(b)
	building_changed.emit(b)
	return b


## 建設予約。予約 → 建設中(素材が届き始めた)→ 完成。素材が足りなければ保留になる
func plan_building(type: String, cell: Vector2i) -> Dictionary:
	var error: String = building_error(type, cell)
	if not error.is_empty():
		return {"ok": false, "message": Texts.t(error)}
	var b: Building = add_building(type, cell)
	for v in villagers:
		if world.blocked.get(v.cell(), -1) == b.id:
			v.place_at(_free_cell_near(v.cell()))
			v.path.clear()
			for step in v.plan:
				step.erase("dest")
	var task := JobTask.new()
	task.type = "build"
	task.building_id = b.id
	task.cell = b.cell
	task.work_needed = float(b.def().get("work", 60.0))
	tasks.add(task)
	return {"ok": true, "building": b}


func _on_building_completed(b: Building) -> void:
	b.short = false
	BuildingFixture.install_initial(b)
	if b.def().has("residents"):
		assign_homes()


## 家のない村人を、空きのある家に住まわせる
func assign_homes() -> void:
	for v in living_villagers():
		if v.home_id != -1 and buildings.has(v.home_id):
			continue
		for b: Building in buildings.values():
			if b.is_complete() and residents_of(b).size() < int(b.def().get("residents", 0)):
				v.home_id = b.id
				break


func residents_of(b: Building) -> Array[Villager]:
	var result: Array[Villager] = []
	for v in living_villagers():
		if v.home_id == b.id:
			result.append(v)
	return result


func houses() -> Array[Building]:
	var result: Array[Building] = []
	for b: Building in buildings.values():
		if b.is_complete() and b.def().has("residents"):
			result.append(b)
	return result


# --- 物と倉庫 -----------------------------------------------------------

func item_def(item: String) -> Dictionary:
	return GameData.get_dict("items").get(item, {})


func stockpiles() -> Array[Building]:
	var result: Array[Building] = []
	for b: Building in buildings.values():
		if b.is_complete() and b.capacity() > 0:
			result.append(b)
	return result


func accepts(stockpile: Building, item: String) -> bool:
	return stockpile.filter.is_empty() or stockpile.filter.has(str(item_def(item).get("category", "")))


func _has_stockpile_accepting(item: String) -> bool:
	for s in stockpiles():
		if accepts(s, item):
			return true
	return false


## 置ける倉庫のうち優先度が高いもの(同じなら番号が小さいもの)
func best_stockpile_for(item: String, count: int) -> Building:
	var best: Building = null
	for s in stockpiles():
		if not accepts(s, item) or s.free_space() < mini(count, 1):
			continue
		if best == null or s.priority > best.priority or (s.priority == best.priority and s.id < best.id):
			best = s
	return best


func store(stockpile: Building, item: String, count: int) -> int:
	var stored: int = mini(count, stockpile.free_space())
	if stored > 0 and accepts(stockpile, item):
		stockpile.inventory[item] = int(stockpile.inventory.get(item, 0)) + stored
		return stored
	return 0


func drop_on_ground(cell: Vector2i, item: String, count: int) -> void:
	if count <= 0:
		return
	var pile: Dictionary = ground_items.get(cell, {})
	pile[item] = int(pile.get(item, 0)) + count
	ground_items[cell] = pile


func stock_count(item: String) -> int:
	var total: int = 0
	for s in stockpiles():
		total += int(s.inventory.get(item, 0))
	return total


func total_stock() -> int:
	var total: int = 0
	for s in stockpiles():
		total += s.stored_total()
	return total


## 物の取り出し元(倉庫か地面)のうち一番近いもの
func find_item_source(item: String, from: Vector2i) -> Dictionary:
	var best: Dictionary = {}
	var best_distance: float = INF
	for s in stockpiles():
		var count: int = int(s.inventory.get(item, 0))
		if count > 0:
			var distance: float = Vector2(from).distance_to(s.center())
			if distance < best_distance:
				best = {"kind": "building", "id": s.id, "cell": s.cell, "count": count, "item": item}
				best_distance = distance
	for cell: Vector2i in ground_items:
		var count: int = int((ground_items[cell] as Dictionary).get(item, 0))
		if count > 0 and not ground_reserved.has(cell):
			var distance: float = Vector2(from).distance_to(Vector2(cell))
			if distance < best_distance:
				best = {"kind": "ground", "cell": cell, "count": count, "item": item}
				best_distance = distance
	return best


func find_food_source(from: Vector2i) -> Dictionary:
	var best: Dictionary = {}
	var items: Dictionary = GameData.get_dict("items")
	# 腹持ちのよい食べ物から探す
	var foods: Array = items.keys().filter(func(k: String) -> bool: return items[k].get("category", "") == "food")
	foods.sort_custom(func(a: String, b: String) -> bool: return float(items[a]["food"]) > float(items[b]["food"]))
	for item: String in foods:
		best = find_item_source(item, from)
		if not best.is_empty():
			return best
	return best


func take_from(source: Dictionary, item: String, count: int) -> int:
	if source["kind"] == "building":
		var b: Building = buildings.get(int(source["id"])) as Building
		if b == null:
			return 0
		var taken: int = mini(count, int(b.inventory.get(item, 0)))
		_remove_inventory(b.inventory, item, taken)
		return taken
	var cell: Vector2i = source["cell"]
	ground_reserved.erase(cell)
	if not ground_items.has(cell):
		return 0
	var pile: Dictionary = ground_items[cell]
	var taken_ground: int = mini(count, int(pile.get(item, 0)))
	_remove_inventory(pile, item, taken_ground)
	if pile.is_empty():
		ground_items.erase(cell)
	return taken_ground


func _remove_inventory(inventory: Dictionary, item: String, count: int) -> void:
	var left: int = int(inventory.get(item, 0)) - count
	if left > 0:
		inventory[item] = left
	else:
		inventory.erase(item)


## 倉庫からまとめて取り除く(加工の素材など)。足りなければ何もしないで false
func consume_stock(items: Dictionary) -> bool:
	for item: String in items:
		if stock_count(item) < int(items[item]):
			return false
	for item: String in items:
		var left: int = int(items[item])
		for s in stockpiles():
			var taken: int = mini(left, int(s.inventory.get(item, 0)))
			_remove_inventory(s.inventory, item, taken)
			left -= taken
	return true


# --- 速度と倍率 ---------------------------------------------------------

func walk_speed(_v: Villager) -> float:
	return float(villager_cfg["walk_blocks_per_minute"])


## 作業速度。装備・熟練度・特技・村長の方針の倍率をかける
func work_speed(v: Villager, kind: String) -> float:
	var speed: float = 1.0
	for modifier in speed_modifiers:
		speed *= float(modifier.call(v, kind))
	return speed


func _sleep_multiplier(v: Villager) -> float:
	var home: Building = buildings.get(v.home_id) as Building
	if v.plan_kind == "sleep" and not v.plan.is_empty() and int(v.plan[0].get("building", -1)) != -1 and home != null:
		return BuildingFixture.bed_multiplier_for(self, home, v)
	return float(needs_cfg["ground_sleep_multiplier"])


## 気分の回復倍率。家の飾りの分だけ上がる(村長の方針は M3-T06)
func mood_rate(v: Villager) -> float:
	var rate: float = 1.0
	var home: Building = buildings.get(v.home_id) as Building
	if home != null and home.is_complete():
		rate += BuildingFixture.sum_effect(home, "mood_rate_bonus")
	return rate * chief.mood_rate()


func _on_block_changed(pos: Vector3i, id: int) -> void:
	pathing.update_cell(Vector2i(pos.x, pos.z))
	block_changed.emit(pos, id)
