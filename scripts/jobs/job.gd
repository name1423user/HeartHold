class_name Job
extends RefCounted
## 役職(採集係・建築係・狩人・衛兵)。定義は data/jobs.json。役職の仕事を先に拾う(AC-005)。


static func ids() -> Array[String]:
	var result: Array[String] = []
	for key: String in GameData.get_dict("jobs"):
		if key != "shared":
			result.append(key)
	return result


static func display_name(job: String) -> String:
	return str(GameData.get_dict("jobs").get(job, {}).get("name", job))


## いま選べる役職(時代と建物で解放される、M8-T03)
static func available(village: Village) -> Array[String]:
	var result: Array[String] = []
	for job in ids():
		if unlock_error(village, job).is_empty():
			result.append(job)
	return result


## 解放されていない理由の文言。解放済みなら空
static func unlock_error(village: Village, job: String) -> String:
	var def: Dictionary = GameData.get_dict("jobs").get(job, {})
	if not Era.allows(def, village.era()):
		return Texts.t("locked_era", {"era": Era.display_name(str(def.get("era", "stone")))})
	var needed: String = str(def.get("requires_building", ""))
	if not needed.is_empty() and village.nearest_building(Vector2(village.world.start), [needed]) == null:
		return Texts.t("locked_building", {"name": GameData.get_dict("buildings")[needed]["name"]})
	return ""


## 役職を変える。今の仕事は手放して、次から新しい役職の順で拾う
static func assign(village: Village, v: Villager, job: String) -> bool:
	if not ids().has(job) or v.is_chief or LifeCycle.is_child(v) or not unlock_error(village, job).is_empty():
		return false
	if v.job != job and v.plan_kind == "task":
		village.release_plan(v)
	v.job = job
	return true
