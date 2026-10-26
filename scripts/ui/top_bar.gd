class_name TopBar
extends PanelContainer
## 上部バー: 村レベル・資源・食料あと何日分(AC-041)・時刻・一時停止。

const SHOWN_ITEMS: Array[String] = ["log", "plank", "stone", "meat", "meal", "fur"]

var game: Game
var label: Label
var pause_button: Button


func setup(target: Game) -> void:
	game = target
	var box := HBoxContainer.new()
	add_child(box)
	label = Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(label)
	pause_button = Button.new()
	pause_button.custom_minimum_size = Vector2(40, 0)
	pause_button.tooltip_text = Texts.t("tooltip_pause")
	pause_button.pressed.connect(game.toggle_pause)
	box.add_child(pause_button)


func refresh() -> void:
	label.text = text_for(game)
	pause_button.text = Texts.t("resume") if game.village.clock.paused else Texts.t("pause")


static func text_for(target: Game) -> String:
	var village: Village = target.village
	var parts: Array[String] = [Texts.t("village_level", {"level": target.level.level})]
	for item: String in SHOWN_ITEMS:
		parts.append("%s%d" % [village.item_def(item)["name"], village.stock_count(item)])
	parts.append(Texts.t("food_days", {"days": FoodStock.days_left(village)}))
	parts.append(village.clock.label())
	parts.append(village.calendar().label())
	if village.clock.paused:
		parts.append(Texts.t("paused_label"))
	return "   ".join(parts)
