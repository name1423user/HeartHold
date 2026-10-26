class_name Proficiency
extends RefCounted
## 作業の種類ごとの熟練度(AC-039)。作業した時間で上がり、速度にかかる。伸び方と上限は data/proficiency.json。
## 速度は Village.speed_modifiers の1つとして掛け合わせるので、特技(M3-T01)とも重なる。


static func cfg() -> Dictionary:
	return GameData.get_dict("proficiency")


static func level(v: Villager, kind: String) -> int:
	var minutes: float = float(v.experience.get(kind, 0.0))
	return mini(int(minutes / float(cfg()["minutes_per_level"])), int(cfg()["max_level"]))


static func speed(v: Villager, kind: String) -> float:
	return 1.0 + level(v, kind) * float(cfg()["speed_per_level"])


## 村人パネル用: [{"name": 表示名, "level": 段}] (経験のある作業だけ)
static func summary(v: Villager) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var names: Dictionary = cfg()["skills"]
	for kind: String in names:
		if float(v.experience.get(kind, 0.0)) > 0.0:
			result.append({"kind": kind, "name": str(names[kind]), "level": level(v, kind)})
	return result
