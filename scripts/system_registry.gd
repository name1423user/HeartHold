class_name SystemRegistry
extends RefCounted
## 村に入れる仕組みの一覧(順番に更新される)。


static func classes() -> Array[GDScript]:
	return [EraSystem, Reputation, BuildingEffects, BuildingDamage, Mining, Calendar, Traits, Illness, ExtendedNeeds, Schedule, FoodSpoilage, Regrowth, Farming, Festivals, LifeCycle, Traps, Nests, Expeditions, Trade, VillageClues, Magic, Story]
