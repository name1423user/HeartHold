class_name UiTheme
extends RefCounted
## 暖色の木と羊皮紙の UI テーマ(SPEC 9章)。色とフォントは data/ui.json。

static var _font: Font


static func color(key: String) -> Color:
	return Color(str(GameData.get_dict("ui")["colors"][key]))


static func font() -> Font:
	if _font == null:
		var file := FontFile.new()
		var data: PackedByteArray = FileAccess.get_file_as_bytes(str(GameData.get_dict("ui")["font"]))
		if data.is_empty():
			return ThemeDB.fallback_font
		file.data = data
		_font = file
	return _font


static func font_size(multiplier: float = 1.0) -> int:
	return roundi(float(GameData.get_dict("ui")["base_font_size"]) * Settings.text_scale() * multiplier)


static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font = font()
	theme.default_font_size = font_size()
	var panel := StyleBoxFlat.new()
	panel.bg_color = color("parchment")
	panel.border_color = color("wood")
	panel.set_border_width_all(2)
	panel.set_corner_radius_all(4)
	panel.set_content_margin_all(8)
	theme.set_stylebox("panel", "PanelContainer", panel)
	theme.set_stylebox("panel", "Panel", panel)
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var box := StyleBoxFlat.new()
		box.bg_color = color("wood") if state != "hover" else color("wood_light")
		if state == "pressed":
			box.bg_color = color("highlight")
		if state == "disabled":
			box.bg_color = color("parchment_dark")
		if state == "focus":
			box.bg_color = Color(0, 0, 0, 0)
			box.border_color = color("highlight")
			box.set_border_width_all(2)
		box.set_corner_radius_all(3)
		box.set_content_margin_all(5)
		theme.set_stylebox(state, "Button", box)
	theme.set_color("font_color", "Button", color("parchment"))
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", color("ink"))
	theme.set_color("font_disabled_color", "Button", color("wood_light"))
	theme.set_color("font_color", "Label", color("ink"))
	theme.set_color("font_color", "CheckBox", color("ink"))
	theme.set_color("font_color", "LineEdit", color("ink"))
	var edit := StyleBoxFlat.new()
	edit.bg_color = Color.WHITE
	edit.border_color = color("wood")
	edit.set_border_width_all(1)
	edit.set_content_margin_all(4)
	theme.set_stylebox("normal", "LineEdit", edit)
	var tooltip := StyleBoxFlat.new()
	tooltip.bg_color = color("ink")
	tooltip.set_content_margin_all(6)
	theme.set_stylebox("panel", "TooltipPanel", tooltip)
	theme.set_color("font_color", "TooltipLabel", color("parchment"))
	return theme
