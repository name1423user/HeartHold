class_name Autosave
extends RefCounted
## オートセーブ(AC-026)。実時間5分ごとに保存し、直近3つ(auto_1 が一番新しい)を残す。
## 新しいセーブを書き終えてから古いものを順にずらすので、書けなかったときは前のセーブがそのまま残る。

var village: Village
var extra_source: Callable = func() -> Dictionary: return {}
var elapsed: float = 0.0
var cfg: Dictionary = {}


func _init(target: Village) -> void:
	village = target
	cfg = GameData.get_dict("save")


static func slot_name(index: int) -> String:
	return "auto_%d" % index


## 実時間の秒を足し、5分たったら保存する。保存したら true
func update(real_seconds: float) -> bool:
	elapsed += real_seconds
	if elapsed < float(cfg["autosave_seconds"]):
		return false
	elapsed = 0.0
	return save_now() == OK


func save_now() -> Error:
	var keep: int = int(cfg["autosave_keep"])
	var error: Error = SaveGame.save_village(village, "auto_new", extra_source.call())
	if error != OK:
		SaveGame.delete_save("auto_new")
		village.raise_alert("save_failed", Texts.t("save_failed"), village.world.start)
		return error
	SaveGame.delete_save(slot_name(keep))
	for i in range(keep - 1, 0, -1):
		_rename(slot_name(i), slot_name(i + 1))
	_rename("auto_new", slot_name(1))
	return OK


static func _rename(from: String, to: String) -> void:
	for extension in ["terrain", "json"]:
		var source: String = SaveGame.path(from, extension)
		if FileAccess.file_exists(source):
			SaveGame._replace(source, SaveGame.path(to, extension))
