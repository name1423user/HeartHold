extends GutTest
## M10: 交易・評判と双方向の審査・物語

var village: Village
var trade: Trade
var storage: Building


func before_each() -> void:
	village = Village.create(12345)
	trade = village.system("trade") as Trade
	storage = village.add_building("storage", village.world.start + Vector2i(4, 4), true)
	storage.inventory = {"smoked_meat": 50, "coin": 100, "fur": 20}


func test_starts_with_one_partner_and_unlocks_up_to_five() -> void:
	assert_eq(trade.unlocked.size(), 1)
	for i in 10:
		trade.unlock_partner()
	assert_eq(trade.unlocked.size(), 5, "最大5つ")


func test_caravan_comes_and_trades_immediately() -> void:
	assert_true(trade.reachable_partners().is_empty(), "定期便も取引所もなければ取り引きできない")
	trade.next_caravan_at = village.clock.minutes
	trade.update(1.0)
	assert_false(trade.visitor.is_empty(), "定期便が来る")
	var partner: String = trade.visitor["partner"]
	var price: int = trade.buy_price(partner, "salt")
	assert_true(trade.buy(partner, "salt", 2)["ok"])
	assert_eq(int(storage.inventory["coin"]), 100 - price * 2)
	assert_eq(int(storage.inventory["salt"]), 2)
	var earned: int = trade.sell(partner, "fur", 5)["coins"]
	assert_gt(earned, 0)
	assert_eq(int(storage.inventory["fur"]), 15)


func test_trading_post_orders_arrive_after_travel() -> void:
	(village.system("era") as EraSystem).current = "medieval"
	village.add_building("trading_post", village.world.start + Vector2i(-8, 4), true)
	var partner: String = trade.unlocked[0]
	assert_true(trade.buy(partner, "wool", 3)["ok"])
	assert_eq(int(storage.inventory.get("wool", 0)), 0, "すぐには届かない")
	village.tick(float(Trade.partners()[partner]["travel_days"]) * 1440.0 + 10.0)
	assert_eq(int(storage.inventory.get("wool", 0)), 3, "往復の日数のあとに届く")


func test_reputation_changes_prices() -> void:
	var rep: Reputation = village.system("reputation") as Reputation
	var partner: String = trade.unlocked[0]
	rep.value = 0.0
	var expensive: int = trade.buy_price(partner, "iron_ingot")
	rep.value = 100.0
	assert_lt(trade.buy_price(partner, "iron_ingot"), expensive, "評判が高いと安い")


func test_proposal_can_be_accepted() -> void:
	trade._make_proposal()
	assert_false(trade.proposal.is_empty(), "相手から申し出が来る")
	assert_true(trade.accept_proposal()["ok"])
	assert_eq(trade.orders.size(), 1)


func test_peddler_visits_without_partners() -> void:
	var cfg: Dictionary = Trade.cfg()
	var chance: float = float(cfg["peddler_chance_per_day"])
	cfg["peddler_chance_per_day"] = 1.0
	trade.next_caravan_at = village.clock.minutes + 1.0e9
	village.tick(10.0)
	cfg["peddler_chance_per_day"] = chance
	assert_eq(trade.visitor.get("kind", ""), "peddler")
	assert_true(trade.buy("peddler", "salt", 1)["ok"])


func test_two_way_inspection_refuse_lowers_reputation() -> void:
	var rep: Reputation = village.system("reputation") as Reputation
	for i in 3:
		village.add_building("house", village.world.start + Vector2i(-12 + i * 4, -10), true)
	village.add_building("workbench", village.world.start + Vector2i(8, -4), true)
	village.add_building("infirmary", village.world.start + Vector2i(-8, 6), true)
	village.inspection.require_decision = true
	var a := Applicant.from_data(Applicant.find("a13"))
	a.body.place_at(village.world.start)
	village.inspection.current = a
	village.inspection.finish()
	assert_true(village.inspection.results[-1]["passed"], str(village.inspection.results[-1]))
	assert_false(village.inspection.pending.is_empty(), "迎えるか断るかを待つ")
	var before: float = rep.value
	var count: int = village.villagers.size()
	village.inspection.decide(false)
	assert_eq(village.villagers.size(), count, "断ったので住人は増えない")
	assert_lt(rep.value, before, "評判が下がる")
	assert_true(village.inspection.rejected.has("a13"))


func test_story_chapters_progress_and_unlock_partners() -> void:
	var story: Story = village.system("story") as Story
	village.tick(1.0)
	assert_true(story.done.has("arrival"), "第1章")
	(village.system("era") as EraSystem).advance()
	village.tick(1.0)
	assert_true(story.done.has("iron_age"))
	assert_eq(trade.unlocked.size(), 2, "物語で交易相手が増える")
