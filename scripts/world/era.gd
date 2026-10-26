class_name Era
extends RefCounted
## 時代の並び(石と木 → 鉄 → 中世 → 近世、AS-012)。研究ツリーは作らず、節目の課題で進む(M8-T01)。


static func order() -> Array:
	return GameData.get_dict("eras")["order"]


static func index_of(era: String) -> int:
	var i: int = order().find(era)
	return 0 if i < 0 else i


static func display_name(era: String) -> String:
	return str(GameData.get_dict("eras")["eras"][era]["name"])


## データの "era" が今の時代までに入っているか
static func allows(entry: Dictionary, current: String) -> bool:
	return index_of(str(entry.get("era", "stone"))) <= index_of(current)
