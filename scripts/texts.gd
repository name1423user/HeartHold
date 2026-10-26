class_name Texts
extends RefCounted
## 表示文言の取り出し口。文言は data/texts.json に集める(将来の翻訳用)。


static func t(key: String, args: Dictionary = {}) -> String:
	var texts: Dictionary = GameData.get_dict("texts")
	var text: String = str(texts.get(key, key))
	return text.format(args) if not args.is_empty() else text
