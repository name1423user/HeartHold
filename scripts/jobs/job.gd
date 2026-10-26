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


## 役職を変える。今の仕事は手放して、次から新しい役職の順で拾う
static func assign(village: Village, v: Villager, job: String) -> bool:
	if not ids().has(job) or v.is_chief or LifeCycle.is_child(v):
		return false
	if v.job != job and v.plan_kind == "task":
		village.release_plan(v)
	v.job = job
	return true
