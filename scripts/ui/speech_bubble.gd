class_name SpeechBubble
extends RefCounted
## 不満の一言(AC-040)。欲求が閾値を下回るか、住む家がないとき、理由の一言を頭上と村人パネルに出す。
## 閾値と優先順は data/complaints.json、文言は data/texts.json。


static func complaint(village: Village, v: Villager) -> String:
	if v.state != Villager.State.NORMAL:
		return ""
	var cfg: Dictionary = GameData.get_dict("complaints")
	var below: Dictionary = cfg["below"]
	for reason: String in cfg["order"]:
		if reason == "home":
			if v.home_id == -1 or not village.buildings.has(v.home_id):
				return Texts.t("complaint_home")
		elif v.needs.get_value(reason) < float(below[reason]):
			return Texts.t("complaint_" + reason)
	return ""
