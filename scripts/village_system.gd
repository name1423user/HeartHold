class_name VillageSystem
extends RefCounted
## 村に差し込む仕組みの共通の形(季節・病気・農業・交易など)。
## Village が毎ステップ・村人ごとの更新・行動の選択・手順の実行・仕事の完了・セーブで呼ぶ。
## 使わない口はそのままでよい。

## 行動を選ぶ段: "urgent"(救護の次)/ "need"(欲求の次)/ "work"(仕事の前)/ "idle"(運搬の前)
var plan_stage: String = ""
var village: Village


func _init(target: Village) -> void:
	village = target


## セーブで使う名前
func key() -> String:
	return ""


func update(_dt: float) -> void:
	pass


## 動ける村人ごとに、欲求の更新のあとで呼ぶ
func update_villager(_v: Villager, _dt: float) -> void:
	pass


## plan_stage の段で行動を決めたら true
func choose_plan(_v: Villager) -> bool:
	return false


## 自分の手順なら使った時間を返す。知らない手順なら NAN
func execute_step(_v: Villager, _step: Dictionary, _budget: float) -> float:
	return NAN


## 自分の仕事なら手順を返す。知らないなら空
func plan_for_task(_v: Villager, _task: JobTask) -> Array[Dictionary]:
	return []


## 自分の仕事の素材置き場。知らないなら空
func supply_site(_task: JobTask) -> Dictionary:
	return {}


## 自分の仕事を完了したら true
func complete_task(_v: Villager, _task: JobTask) -> bool:
	return false


func work_speed(_v: Villager, _kind: String) -> float:
	return 1.0


func mood_rate(_v: Villager) -> float:
	return 1.0


func on_building_completed(_b: Building) -> void:
	pass


func to_dict() -> Dictionary:
	return {}


func from_dict(_data: Dictionary) -> void:
	pass
