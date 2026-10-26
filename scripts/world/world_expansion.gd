class_name WorldExpansion
extends VillageSystem
## 無限の地図の広がり(M11-T04)。村人・魔物・移住希望者・視察隊の行き先のまわりのチャンクを作る。
## カメラのまわりは Game が作る。決まった大きさの地図では何もしない。

var _timer: float = 0.0


func key() -> String:
	return "world_expansion"


func radius() -> int:
	return int(GameData.get_dict("terrain")["infinite"]["generate_radius"])


func update(dt: float) -> void:
	if not village.world.infinite:
		return
	_timer -= dt
	if _timer > 0.0:
		return
	_timer = 5.0
	var r: int = radius()
	for v in village.living_villagers():
		village.world.ensure_area(v.cell(), r)
	for m in village.raids.monsters:
		village.world.ensure_area(m.cell(), r / 2)
	if village.inspection.current != null:
		village.world.ensure_area(village.inspection.current.body.cell(), r / 2)
	var expeditions: Expeditions = village.system("expeditions") as Expeditions
	for p in expeditions.parties:
		village.world.ensure_area(p["target"], r / 2)
