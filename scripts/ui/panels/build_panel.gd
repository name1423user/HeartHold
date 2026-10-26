class_name BuildPanel
extends VBoxContainer
## 建設パネル: 建物の予約、加工の予約、選んだ建物の設備・倉庫の設定・見張り台の衛兵。


static func materials_text(village: Village, materials: Dictionary) -> String:
	var parts: Array[String] = []
	for item: String in materials:
		parts.append("%s%d" % [village.item_def(item).get("name", item), int(materials[item])])
	return Texts.t("materials", {"list": "、".join(parts)})


static func building_tooltip(game: Game, b: Building) -> String:
	var village: Village = game.village
	var lines: Array[String] = [b.display_name()]
	if not b.is_complete():
		lines.append(materials_text(village, b.missing_materials()))
	if not b.fixtures.is_empty():
		var names: Array = b.fixtures.map(func(f: String) -> String: return str(BuildingFixture.def(f)["name"]))
		lines.append("%s: %s" % [Texts.t("fixtures_label"), "、".join(names)])
	if b.capacity() > 0:
		lines.append("%d / %d(%s)" % [b.stored_total(), b.capacity(), Stockpile.filter_label(b)])
	lines.append(Texts.t("tooltip_building_" + b.type))
	return "\n".join(lines)


func refresh(game: Game) -> void:
	for child in get_children():
		child.queue_free()
	var village: Village = game.village
	var defs: Dictionary = GameData.get_dict("buildings")
	for type: String in defs:
		var def: Dictionary = defs[type]
		var button := Button.new()
		var unlock: int = int(def.get("unlock_level", 0))
		var locked: bool = unlock > game.level.level
		button.text = "%s  %s" % [def["name"], Texts.t("locked_level", {"level": unlock}) if locked else materials_text(village, def["materials"])]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.disabled = locked
		button.tooltip_text = Texts.t("tooltip_building_" + type)
		button.pressed.connect(func() -> void: game.set_tool("build:" + type))
		add_child(button)

	_label(Texts.t("craft_label"))
	var recipes: Dictionary = GameData.get_dict("recipes")
	for recipe_id: String in recipes:
		var recipe: Dictionary = recipes[recipe_id]
		var button := Button.new()
		button.text = "%s ← %s" % [recipe["name"], materials_text(village, recipe["inputs"])]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.tooltip_text = Texts.t("tooltip_craft")
		button.pressed.connect(func() -> void:
			Crafting.order(village, recipe_id)
			game.hud.toast(Texts.t("craft_ordered", {"name": recipe["name"]})))
		add_child(button)

	var b: Building = village.buildings.get(game.selected_building) as Building
	if b == null:
		_label(Texts.t("no_building_selected"))
		return
	_label(Texts.t("selected_building", {"name": b.display_name()}))
	for option in BuildingFixture.options(b):
		var button := Button.new()
		button.text = "%s  %s" % [option["name"], materials_text(village, option["materials"]) if option["ok"] else option["reason"]]
		button.disabled = not option["ok"]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.tooltip_text = Texts.t("tooltip_fixture_" + str(option["id"]))
		button.pressed.connect(func() -> void:
			var result: Dictionary = BuildingFixture.order(village, b, option["id"])
			game.hud.toast(Texts.t("craft_ordered", {"name": option["name"]}) if result["ok"] else str(result["message"])))
		add_child(button)
	if b.capacity() > 0 and b.is_complete():
		_stockpile_settings(game, b)
	_farm_settings(game, b)
	if b.type == "watchtower" and b.is_complete():
		var station := Button.new()
		station.text = Texts.t("station_guard")
		station.pressed.connect(func() -> void:
			var v: Villager = village.get_villager(game.selected_villager)
			var result: Dictionary = Watchtower.station(village, b, v) if v != null else {"ok": false, "message": Texts.t("select_villager_first")}
			game.hud.toast(str(result.get("message", "")) if not result["ok"] else ""))
		add_child(station)


func _farm_settings(game: Game, b: Building) -> void:
	var farming: Farming = game.village.system("farming") as Farming
	var cfg: Dictionary = farming.cfg()
	if farming.fields.has(b.id):
		var f: Dictionary = farming.fields[b.id]
		_label(Texts.t("field_status", {"crop": cfg["crops"][f["crop"]]["name"], "stage": Texts.t("stage_" + str(f["stage"]))}))
		var option := OptionButton.new()
		var crops: Array = cfg["crops"].keys()
		for i in crops.size():
			option.add_item(str(cfg["crops"][crops[i]]["name"]), i)
			if crops[i] == f["crop"]:
				option.select(i)
		option.tooltip_text = Texts.t("crop_label")
		option.item_selected.connect(func(index: int) -> void: farming.set_crop(b, crops[index]))
		add_child(option)
	if farming.barns.has(b.id):
		var parts: Array[String] = []
		var animals: Dictionary = farming.barns[b.id]["animals"]
		for species: String in animals:
			parts.append("%s%d" % [cfg["animals"][species]["name"], int(animals[species])])
		_label(Texts.t("barn_status", {"list": "、".join(parts)}))


func _stockpile_settings(game: Game, b: Building) -> void:
	_label(Texts.t("stockpile_label"))
	var categories: Dictionary = Stockpile.categories()
	for category: String in categories:
		var check := CheckBox.new()
		check.text = str(categories[category])
		check.button_pressed = b.filter.is_empty() or b.filter.has(category)
		check.toggled.connect(func(on: bool) -> void:
			var allowed: Array = b.filter.duplicate() if not b.filter.is_empty() else categories.keys()
			if on and not allowed.has(category):
				allowed.append(category)
			elif not on:
				allowed.erase(category)
			Stockpile.set_filter(b, [] if allowed.size() == categories.size() else allowed)
			game.hud.refresh_now())
		add_child(check)
	var row := HBoxContainer.new()
	add_child(row)
	var label := Label.new()
	label.text = Texts.t("priority_label")
	row.add_child(label)
	var spin := SpinBox.new()
	var cfg: Dictionary = GameData.get_dict("stockpile")
	spin.min_value = int(cfg["min_priority"])
	spin.max_value = int(cfg["max_priority"])
	spin.value = b.priority
	spin.value_changed.connect(func(value: float) -> void: Stockpile.set_priority(b, int(value)))
	row.add_child(spin)


func _label(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(label)
