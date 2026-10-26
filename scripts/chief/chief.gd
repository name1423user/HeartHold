class_name Chief
extends RefCounted
## 村長(AC-018, AC-019, AC-036)。直接は動かせない。プレイヤーは方針(勤勉/守り/安らぎ)を選び、
## 村長が生きていて治療中でない間だけ、方針のバフがかかる。方針の変更はゲーム内1日に1回まで。
## 体力0で死なずに瀕死になり、救護室で実時間3分の治療を受けて復帰する(HealthState)。

var village: Village
var villager: Villager
var policy: String = ""
var last_change_day: int = 0


func _init(target: Village) -> void:
	village = target
	var cfg: Dictionary = GameData.get_dict("chief")
	policy = str(cfg["default_policy"])
	village.speed_modifiers.append(_work_speed)


func cfg() -> Dictionary:
	return GameData.get_dict("chief")


## 開始時に村長を置く
func spawn() -> Villager:
	villager = village.add_villager(str(cfg()["name"]))
	villager.is_chief = true
	villager.job = ""
	return villager


## バフがかかっているか(生存・治療中でない)
func is_buff_active() -> bool:
	return villager != null and villager.state == Villager.State.NORMAL


func can_change_policy() -> bool:
	return last_change_day != village.clock.day()


func set_policy(new_policy: String) -> Dictionary:
	if not cfg()["policies"].has(new_policy):
		return {"ok": false, "message": ""}
	if new_policy == policy:
		return {"ok": true}
	if not can_change_policy():
		return {"ok": false, "message": Texts.t("chief_policy_once_a_day")}
	policy = new_policy
	last_change_day = village.clock.day()
	return {"ok": true}


func effect(key: String) -> float:
	if not is_buff_active():
		return 1.0
	return float(cfg()["policies"][policy][key])


func policy_name(policy_id: String = "") -> String:
	return str(cfg()["policies"][policy if policy_id.is_empty() else policy_id]["name"])


func _work_speed(_v: Villager, _kind: String) -> float:
	return effect("work_speed")


func guard_attack(v: Villager) -> float:
	return effect("guard_attack") if v.job == "guard" else 1.0


func mood_rate() -> float:
	return effect("mood_rate")


func to_dict() -> Dictionary:
	return {"villager": villager.id if villager != null else -1, "policy": policy, "last_change_day": last_change_day}


func from_dict(data: Dictionary) -> void:
	villager = village.get_villager(int(data["villager"]))
	policy = str(data["policy"])
	last_change_day = int(data["last_change_day"])
