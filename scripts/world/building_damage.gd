class_name BuildingDamage
extends VillageSystem
## 壊れる建物と修理(M8-T06)。魔物は道をふさぐ柵・壁・門や建物を叩いて傷める。
## 耐久が0になると、柵・壁・門は壊されて消え、ほかの建物は「壊れている」状態で使えなくなる。
## 傷んだ建物は建築係が素材の一部を運んで直す。数値は data/damage.json。


func key() -> String:
	return "building_damage"


static func cfg() -> Dictionary:
	return GameData.get_dict("damage")


func damage(b: Building, amount: float) -> void:
	if b.state != Building.State.COMPLETE or b.broken:
		return
	b.hp = b.current_hp() - amount
	village.building_changed.emit(b)
	if b.hp > 0.0:
		return
	if bool(b.def().get("blocks_monsters", false)) or bool(b.def().get("gate", false)):
		village.raise_alert("destroyed", Texts.t("alert_building_destroyed", {"name": b.display_name()}), b.cell)
		village.remove_building(b)
	else:
		b.hp = 0.0
		b.broken = true
		village.raise_alert("damaged", Texts.t("alert_building_damaged", {"name": b.display_name()}), b.cell)
		if b.def().has("residents"):
			for v in village.residents_of(b):
				v.home_id = -1


func update(_dt: float) -> void:
	for b: Building in village.buildings.values():
		if b.state != Building.State.COMPLETE or b.current_hp() >= b.max_hp() * float(cfg()["repair_below"]):
			continue
		var exists: bool = false
		for task: JobTask in village.tasks.of_type("repair"):
			if task.building_id == b.id:
				exists = true
				break
		if exists:
			continue
		var task := JobTask.new()
		task.type = "repair"
		task.building_id = b.id
		task.cell = b.cell
		task.work_needed = float(cfg()["repair_minutes"])
		village.tasks.add(task)


## 修理の素材 = 建てる素材の一部(切り上げ)
func repair_materials(b: Building) -> Dictionary:
	var out: Dictionary = {}
	var fraction: float = float(cfg()["repair_fraction"])
	for item: String in b.materials():
		out[item] = maxi(1, ceili(int(b.materials()[item]) * fraction))
	return out


func supply_site(task: JobTask) -> Dictionary:
	if task.type != "repair":
		return {}
	var b: Building = village.buildings.get(task.building_id) as Building
	if b == null:
		return {"cell": Village.NO_CELL, "missing": {}, "error": "unreachable"}
	var delivered: Dictionary = task.extra.get("delivered", {})
	var missing: Dictionary = {}
	var needed: Dictionary = repair_materials(b)
	for item: String in needed:
		var lack: int = int(needed[item]) - int(delivered.get(item, 0))
		if lack > 0:
			missing[item] = lack
	return {"cell": b.cell, "missing": missing, "building": b.id}


func complete_task(_v: Villager, task: JobTask) -> bool:
	if task.type != "repair":
		return false
	var b: Building = village.buildings.get(task.building_id) as Building
	if b != null:
		b.hp = b.max_hp()
		b.broken = false
		village.building_changed.emit(b)
		if b.def().has("residents"):
			village.assign_homes()
	return true
