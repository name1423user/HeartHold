class_name Trade
extends VillageSystem
## 交易(M10-T01 で中身を入れる)。

var unlocked: Array = []


func key() -> String:
	return "trade"


func unlock_partner() -> String:
	return ""


func partner_name(_id: String) -> String:
	return ""
