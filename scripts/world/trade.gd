class_name Trade
extends VillageSystem
## 交易(M10-T01)。相手の村はマップの外にあり、最大5つ(物語と手がかりで増える)。お金は銀貨。
## ・定期便: 数日おきに相手の荷馬車が来て、いる間は売り買いできる
## ・取引所: 建てるといつでも注文でき、品は往復の日数のあとに届く
## ・提案: 相手から割のよい取り引きの申し出が来る(受けるか断る)
## ・行商人: 相手がいなくても、ときどき少しだけ品を持って来る
## 値段は品の値打ち(items.json の value)× 相手の倍率 × 評判。数値は data/trade.json。

var unlocked: Array = []
## 来ている荷馬車/行商人: {"kind": "caravan"/"peddler", "partner", "until", "stock": {}}
var visitor: Dictionary = {}
var next_caravan_at: float = 0.0
## 取引所の注文: [{"partner", "arrive_at", "items": {}, "coins": int}]
var orders: Array = []
## 相手からの提案: {"partner", "give": {item: n}, "get": {item: n}, "until"}
var proposal: Dictionary = {}
var _next_proposal_at: float = 0.0
var _last_day: int = 0


func _init(target: Village) -> void:
	super(target)
	for i in int(cfg()["start_partners"]):
		unlock_partner()
	_schedule_caravan()
	_next_proposal_at = village.clock.minutes + float(cfg()["proposal_days"]) * GameClock.MINUTES_PER_DAY


func key() -> String:
	return "trade"


static func cfg() -> Dictionary:
	return GameData.get_dict("trade")


static func partners() -> Dictionary:
	return cfg()["partners"]


func partner_name(id: String) -> String:
	return str(partners().get(id, {}).get("name", ""))


## 次の相手を解放する(最大5つ)。解放した相手のID、もういなければ空
func unlock_partner() -> String:
	if unlocked.size() >= int(cfg()["max_partners"]):
		return ""
	for id: String in partners():
		if not unlocked.has(id):
			unlocked.append(id)
			return id
	return ""


func _schedule_caravan() -> void:
	var range_days: Array = cfg()["caravan_days"]
	next_caravan_at = village.clock.minutes + village.rng.randf_range(float(range_days[0]), float(range_days[1])) * GameClock.MINUTES_PER_DAY


## 評判による値段の倍率(評判が高いほど安く買えて高く売れる)
func reputation_factor() -> float:
	var rep: Reputation = village.system("reputation") as Reputation
	var t: float = (rep.value if rep != null else 50.0) / 100.0
	var r: Dictionary = cfg()["reputation_price"]
	return lerpf(float(r["low"]), float(r["high"]), t)


func _discount() -> float:
	var mult: float = 1.0
	if village.living_villagers().any(func(v: Villager) -> bool: return v.job == "merchant"):
		mult *= float(cfg()["merchant_discount"])
	for b: Building in village.buildings.values():
		if b.is_complete():
			mult *= float(b.def().get("effects", {}).get("trade_price", 1.0))
	return mult


func buy_price(partner: String, item: String) -> int:
	var value: float = float(village.item_def(item).get("value", 1))
	var mult: float = float(cfg()["peddler_markup"]) if partner == "peddler" else float(partners()[partner]["sells"].get(item, 1.0))
	return maxi(1, roundi(value * mult * reputation_factor() * _discount()))


func sell_price(partner: String, item: String) -> int:
	var value: float = float(village.item_def(item).get("value", 1))
	var buys: Dictionary = partners().get(partner, {}).get("buys", {})
	var mult: float = float(buys.get(item, cfg()["default_sell_multiplier"]))
	return maxi(0, roundi(value * mult / reputation_factor()))


## 今すぐ取り引きできる相手(来ている荷馬車・行商人)と、取引所から注文できる相手
func reachable_partners() -> Array:
	var result: Array = []
	if not visitor.is_empty():
		result.append(str(visitor["partner"]))
	if has_trading_post():
		for id in unlocked:
			if not result.has(id):
				result.append(id)
	return result


func has_trading_post() -> bool:
	return village.nearest_building(Vector2(village.world.start), ["trading_post"]) != null


## 相手が売ってくれる品
func goods(partner: String) -> Array:
	if partner == "peddler" or (not visitor.is_empty() and visitor["partner"] == partner and visitor.has("stock") and not (visitor["stock"] as Dictionary).is_empty()):
		return (visitor["stock"] as Dictionary).keys()
	return (partners()[partner]["sells"] as Dictionary).keys()


func coins() -> int:
	return village.stock_count(str(cfg()["currency"]))


func buy(partner: String, item: String, count: int) -> Dictionary:
	if not reachable_partners().has(partner):
		return {"ok": false, "message": Texts.t("trade_unreachable")}
	if not goods(partner).has(item):
		return {"ok": false, "message": Texts.t("trade_not_sold")}
	var cost: int = buy_price(partner, item) * count
	if coins() < cost:
		return {"ok": false, "message": Texts.t("trade_no_coins")}
	village.consume_stock({str(cfg()["currency"]): cost})
	if not visitor.is_empty() and visitor["partner"] == partner:
		if visitor.has("stock") and (visitor["stock"] as Dictionary).has(item):
			visitor["stock"][item] = int(visitor["stock"][item]) - count
			if int(visitor["stock"][item]) <= 0:
				(visitor["stock"] as Dictionary).erase(item)
		_deliver({item: count}, 0)
	else:
		orders.append({"partner": partner, "arrive_at": village.clock.minutes + float(partners()[partner]["travel_days"]) * GameClock.MINUTES_PER_DAY, "items": {item: count}, "coins": 0})
	return {"ok": true}


func sell(partner: String, item: String, count: int) -> Dictionary:
	if not reachable_partners().has(partner) or partner == "peddler":
		return {"ok": false, "message": Texts.t("trade_unreachable")}
	if village.stock_count(item) < count:
		return {"ok": false, "message": Texts.t("trade_not_enough")}
	var earned: int = sell_price(partner, item) * count
	village.consume_stock({item: count})
	if not visitor.is_empty() and visitor["partner"] == partner:
		_deliver({}, earned)
	else:
		orders.append({"partner": partner, "arrive_at": village.clock.minutes + float(partners()[partner]["travel_days"]) * GameClock.MINUTES_PER_DAY, "items": {}, "coins": earned})
	return {"ok": true, "coins": earned}


## 届いた品と銀貨を倉庫(なければ取引所か村の中心の地面)へ
func _deliver(items: Dictionary, coin_count: int) -> void:
	var all: Dictionary = items.duplicate()
	if coin_count > 0:
		all[str(cfg()["currency"])] = int(all.get(str(cfg()["currency"]), 0)) + coin_count
	for item: String in all:
		var left: int = int(all[item])
		var s: Building = village.best_stockpile_for(item, left)
		if s != null:
			left -= village.store(s, item, left)
		if left > 0:
			var post: Building = village.nearest_building(Vector2(village.world.start), ["trading_post"])
			village.drop_on_ground(post.cell if post != null else village.world.start, item, left)


func update(dt: float) -> void:
	var now: float = village.clock.minutes
	for order in orders.duplicate():
		if float(order["arrive_at"]) <= now:
			_deliver(order["items"], int(order["coins"]))
			orders.erase(order)
			village.raise_alert("trade_arrived", Texts.t("alert_trade_arrived", {"name": partner_name(str(order["partner"]))}), village.world.start)
	if not visitor.is_empty() and float(visitor["until"]) <= now:
		visitor = {}
	if visitor.is_empty() and not unlocked.is_empty() and now >= next_caravan_at:
		var partner: String = unlocked[village.rng.randi_range(0, unlocked.size() - 1)]
		visitor = {"kind": "caravan", "partner": partner, "until": now + float(cfg()["caravan_stay_minutes"]), "stock": {}}
		village.raise_alert("caravan", Texts.t("alert_caravan", {"name": partner_name(partner)}), village.world.start)
		_schedule_caravan()
	var day: int = village.clock.day()
	if day != _last_day:
		_last_day = day
		if visitor.is_empty() and village.rng.randf() < float(cfg()["peddler_chance_per_day"]):
			visitor = {"kind": "peddler", "partner": "peddler", "until": now + float(cfg()["peddler_stay_minutes"]), "stock": (cfg()["peddler_stock"] as Dictionary).duplicate()}
			village.raise_alert("peddler", Texts.t("alert_peddler"), village.world.start)
	if not proposal.is_empty() and float(proposal["until"]) <= now:
		proposal = {}
	if proposal.is_empty() and not unlocked.is_empty() and now >= _next_proposal_at:
		_next_proposal_at = now + float(cfg()["proposal_days"]) * GameClock.MINUTES_PER_DAY
		_make_proposal()


## 相手が欲しい物を村が持っていれば、割のよい交換を申し出る
func _make_proposal() -> void:
	var partner: String = unlocked[village.rng.randi_range(0, unlocked.size() - 1)]
	var p: Dictionary = partners()[partner]
	for item: String in p["buys"]:
		var have: int = village.stock_count(item)
		if have < 4:
			continue
		var give_count: int = mini(have / 2, 10)
		var worth: float = sell_price(partner, item) * give_count * float(cfg()["proposal_bonus"])
		var wanted: Array = (p["sells"] as Dictionary).keys()
		var get_item: String = wanted[village.rng.randi_range(0, wanted.size() - 1)]
		var get_count: int = maxi(1, floori(worth / maxf(1.0, float(buy_price(partner, get_item)))))
		proposal = {"partner": partner, "give": {item: give_count}, "get": {get_item: get_count}, "until": village.clock.minutes + float(cfg()["proposal_minutes"])}
		village.raise_alert("proposal", Texts.t("alert_proposal", {"name": partner_name(partner)}), village.world.start)
		return


func accept_proposal() -> Dictionary:
	if proposal.is_empty():
		return {"ok": false, "message": ""}
	for item: String in proposal["give"]:
		if village.stock_count(item) < int(proposal["give"][item]):
			return {"ok": false, "message": Texts.t("trade_not_enough")}
	village.consume_stock(proposal["give"])
	orders.append({"partner": proposal["partner"], "arrive_at": village.clock.minutes + float(partners()[proposal["partner"]]["travel_days"]) * GameClock.MINUTES_PER_DAY, "items": proposal["get"], "coins": 0})
	proposal = {}
	return {"ok": true}


func decline_proposal() -> void:
	proposal = {}


func to_dict() -> Dictionary:
	return {"unlocked": unlocked.duplicate(), "visitor": visitor.duplicate(true), "next_caravan_at": next_caravan_at, "orders": orders.duplicate(true),
		"proposal": proposal.duplicate(true), "next_proposal_at": _next_proposal_at, "last_day": _last_day}


func from_dict(data: Dictionary) -> void:
	unlocked = (data.get("unlocked", unlocked) as Array).duplicate()
	visitor = (data.get("visitor", {}) as Dictionary).duplicate(true)
	next_caravan_at = float(data.get("next_caravan_at", next_caravan_at))
	orders = (data.get("orders", []) as Array).duplicate(true)
	proposal = (data.get("proposal", {}) as Dictionary).duplicate(true)
	_next_proposal_at = float(data.get("next_proposal_at", _next_proposal_at))
	_last_day = int(data.get("last_day", 0))
