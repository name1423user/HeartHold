class_name SaveGame
extends RefCounted
## 本番のセーブ・ロード(M5-T01 で中身を入れる)。


static func load_village(_name: String) -> Village:
	return null


static func save_game(_game: Game, _name: String) -> Error:
	return ERR_UNAVAILABLE


static func list_saves() -> Array[String]:
	return []
