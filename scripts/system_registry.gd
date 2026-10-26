class_name SystemRegistry
extends RefCounted
## 村に入れる仕組みの一覧(順番に更新される)。


static func classes() -> Array[GDScript]:
	return [Calendar, Traits, ExtendedNeeds, Illness]
