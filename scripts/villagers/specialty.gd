class_name Specialty
extends RefCounted
## 特技(AC-033)。合格した希望者が持ち込む。作業の速度倍率として熟練度・道具と重なる。


static func def(specialty: String) -> Dictionary:
	return GameData.get_dict("specialties").get(specialty, {})


static func display_name(specialty: String) -> String:
	return str(def(specialty).get("name", ""))


static func speed(v: Villager, kind: String) -> float:
	var d: Dictionary = def(v.specialty)
	if not d.is_empty() and str(d["skill"]) == kind:
		return float(d["speed"])
	return 1.0
