class_name Traps
extends VillageSystem
## 罠(M9-T02)。杭の罠は踏んだ魔物を傷つけ、落とし穴はしばらく動けなくする。使える回数を使い切ると壊れ、
## 建築係が直すと(修理)また使える。罠の上は村人も歩ける。

## 建物ID -> 残りの回数
var uses: Dictionary = {}


func key() -> String:
	return "traps"


func on_building_completed(b: Building) -> void:
	if b.def().has("trap"):
		uses[b.id] = int(b.def()["trap"]["uses"])


func trap_at(cell: Vector2i) -> Building:
	for b: Building in village.buildings.values():
		if b.def().has("trap") and b.cell == cell and b.is_complete():
			return b
	return null


func step_on(m: Monster) -> void:
	var b: Building = trap_at(m.cell())
	if b == null:
		return
	if int(uses.get(b.id, int(b.def()["trap"]["uses"]))) <= 0:
		return
	var trap: Dictionary = b.def()["trap"]
	m.take_damage(float(trap["damage"]))
	m.stunned = maxf(m.stunned, float(trap["stun_minutes"]))
	uses[b.id] = int(uses.get(b.id, int(trap["uses"]))) - 1
	if int(uses[b.id]) <= 0:
		# 使い切った罠は壊れた扱いにし、修理で使える回数を戻す
		b.hp = 0.0
		b.broken = true
		village.building_changed.emit(b)


func update(_dt: float) -> void:
	for id: int in uses.keys():
		var b: Building = village.buildings.get(id) as Building
		if b == null:
			uses.erase(id)
		elif not b.broken and int(uses[id]) <= 0:
			uses[id] = int(b.def()["trap"]["uses"])


func to_dict() -> Dictionary:
	var out: Dictionary = {}
	for id: int in uses:
		out[str(id)] = uses[id]
	return {"uses": out}


func from_dict(data: Dictionary) -> void:
	uses.clear()
	for id: String in data.get("uses", {}):
		uses[int(id)] = int(data["uses"][id])
