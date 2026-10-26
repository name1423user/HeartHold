extends SceneTree
## 使い方: godot -s shot_tmp.gd -- <out.png> <frames> [panel]
func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	Game.pending_seed = 12345
	var game: Game = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	var village: Village = game.village
	village.add_building("storage", village.world.start + Vector2i(4, 4), true)
	village.add_building("house", village.world.start + Vector2i(-7, -6), true)
	village.plan_building("infirmary", village.world.start + Vector2i(-7, 4))
	village.villagers[2].needs.set_value("food", 10.0)
	if args.size() > 2:
		game.hud.show_panel(int(args[2]))
	for i in int(args[1]):
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(args[0])
	quit()
