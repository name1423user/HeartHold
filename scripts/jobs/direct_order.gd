class_name DirectOrder
extends RefCounted
## 個人への命令(AC-006, AC-007)。今の仕事を中断して地点へ行き、着いたら役職の仕事へ戻る。


static func move(village: Village, v: Villager, target: Vector2i) -> Dictionary:
	if v.is_chief:
		return {"ok": false, "message": Texts.t("order_chief")}
	if not v.is_active():
		return {"ok": false, "message": Texts.t("order_cannot_move")}
	if not village.world.is_walkable(target) or not village.pathing.is_reachable(v.cell(), target):
		return {"ok": false, "message": Texts.t("order_unreachable")}
	village.release_plan(v)
	var steps: Array[Dictionary] = [{"op": "goto", "target": target, "adjacent": false}]
	if v.carry_count > 0:
		steps.push_front({"op": "store_carry"})
	v.plan = steps
	v.plan_kind = "order"
	return {"ok": true}
