class_name VillageSystemPanel
extends VBoxContainer
## サイドバーのパネルの共通部分(ラベルとボタンを足す)。


func _label(text: String, parent: Control = self) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)


func _button(text: String, action: Callable, parent: Control = self) -> Button:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.clip_text = true
	button.pressed.connect(action)
	parent.add_child(button)
	return button
