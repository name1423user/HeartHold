class_name TradePanel
extends VillageSystemPanel
## 交易・探索パネル(M9, M10): 評判・銀貨・交易相手、来ている定期便や行商人との売り買い、申し出、
## 視察隊(村人を選んで行き先をクリック)、遠見、見つけた巣、物語。


func refresh(game: Game) -> void:
	for child in get_children():
		child.queue_free()
	var village: Village = game.village
	var trade: Trade = village.system("trade") as Trade
	var rep: Reputation = village.system("reputation") as Reputation
	_label(Texts.t("reputation_label", {"value": roundi(rep.value)}))
	_label(Texts.t("trade_coins", {"coins": trade.coins()}))
	_label(Texts.t("partners_label", {"count": trade.unlocked.size()}) + " " + "、".join(trade.unlocked.map(func(id: String) -> String: return trade.partner_name(id))))
	if not trade.orders.is_empty():
		_label(Texts.t("orders_label", {"count": trade.orders.size()}))
	if not trade.proposal.is_empty():
		var p: Dictionary = trade.proposal
		_label(Texts.t("proposal_text", {"name": trade.partner_name(p["partner"]), "give": _items_text(village, p["give"]), "get": _items_text(village, p["get"])}))
		var row := HBoxContainer.new()
		add_child(row)
		_button(Texts.t("accept"), func() -> void:
			var result: Dictionary = trade.accept_proposal()
			game.hud.toast(str(result.get("message", "")))
			refresh(game), row)
		_button(Texts.t("decline"), func() -> void:
			trade.decline_proposal()
			refresh(game), row)
	var reachable: Array = trade.reachable_partners()
	if reachable.is_empty():
		_label(Texts.t("trade_none"))
	for partner: String in reachable:
		var partner_label: String = Texts.t("peddler_name") if partner == "peddler" else trade.partner_name(partner)
		_label(Texts.t("trade_partner", {"name": partner_label}))
		for item: String in trade.goods(partner):
			_button(Texts.t("trade_buy", {"item": village.item_def(item).get("name", item), "price": trade.buy_price(partner, item)}), func() -> void:
				var result: Dictionary = trade.buy(partner, item, 1)
				game.hud.toast(str(result.get("message", "")))
				refresh(game))
		if partner != "peddler":
			for item: String in Trade.partners()[partner]["buys"]:
				if village.stock_count(item) > 0:
					_button(Texts.t("trade_sell", {"item": village.item_def(item).get("name", item), "price": trade.sell_price(partner, item)}), func() -> void:
						var result: Dictionary = trade.sell(partner, item, 1)
						game.hud.toast(str(result.get("message", "")))
						refresh(game))

	_label(Texts.t("expedition_tool"))
	for v in village.living_villagers():
		if not village.can_work(v):
			continue
		var check := CheckBox.new()
		check.text = "%s(%s)" % [v.display_name, Job.display_name(v.job)]
		check.button_pressed = game.expedition_members.has(v.id)
		check.toggled.connect(func(on: bool) -> void:
			if on and not game.expedition_members.has(v.id):
				game.expedition_members.append(v.id)
			elif not on:
				game.expedition_members.erase(v.id))
		add_child(check)
	_button(Texts.t("expedition_tool"), func() -> void: game.set_tool("expedition"))
	var magic_ready: bool = village.living_villagers().any(func(v: Villager) -> bool: return Magic.is_mage(v))
	if magic_ready:
		_button(Texts.t("farsight_tool"), func() -> void: game.set_tool("farsight"))
	var nests: Nests = village.system("nests") as Nests
	for s in nests.sites:
		if s["discovered"]:
			_button("%s %s" % [Texts.t("alert_nest_found"), Texts.t("alert_nest_destroyed") if s["destroyed"] else ""], func() -> void: game.focus_cell(s["cell"]))
	var story: Story = village.system("story") as Story
	for chapter: Dictionary in Story.chapters():
		if story.done.has(chapter["id"]):
			_button(str(chapter["title"]), func() -> void: game.hud.show_story(chapter))


func _items_text(village: Village, items: Dictionary) -> String:
	var parts: Array[String] = []
	for item: String in items:
		parts.append("%s%d" % [village.item_def(item).get("name", item), int(items[item])])
	return "、".join(parts)
