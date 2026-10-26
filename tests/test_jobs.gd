extends GutTest

var village: Village


func before_each() -> void:
	village = Village.create(12345)


func _task(type: String, cell: Vector2i) -> JobTask:
	var task := JobTask.new()
	task.type = type
	task.cell = cell
	task.work_needed = 10.0
	return village.tasks.add(task)


func test_builder_takes_build_before_chop() -> void:
	var a: Villager = village.add_villager("ハンス")
	assert_true(Job.assign(village, a, "builder"))
	# 伐採の方が近くても建設を先に拾う
	_task("chop", a.cell() + Vector2i(1, 0))
	var build: JobTask = _task("build", a.cell() + Vector2i(10, 0))
	var picked: JobTask = village.tasks.find_for(village.task_types_for(a), a.cell(), village.clock.minutes)
	assert_eq(picked, build)


func test_gatherer_takes_chop_before_build() -> void:
	var a: Villager = village.add_villager("アンナ")
	Job.assign(village, a, "gatherer")
	_task("build", a.cell() + Vector2i(1, 0))
	var chop: JobTask = _task("chop", a.cell() + Vector2i(10, 0))
	assert_eq(village.tasks.find_for(village.task_types_for(a), a.cell(), village.clock.minutes), chop)


func test_hunter_and_guard_keep_shared_work() -> void:
	var a: Villager = village.add_villager("クララ")
	Job.assign(village, a, "hunter")
	assert_eq(village.task_types_for(a)[0], "hunt")
	assert_true(village.task_types_for(a).has("chop"))


func test_unknown_job_is_rejected() -> void:
	var a: Villager = village.add_villager("オットー")
	assert_false(Job.assign(village, a, "wizard"))
	for job in ["gatherer", "builder", "hunter", "guard"]:
		assert_has(Job.ids(), job)
