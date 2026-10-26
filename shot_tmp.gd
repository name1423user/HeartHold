extends SceneTree
## 使い方: godot -s shot_tmp.gd -- <out.png> <frames> [panel] [zoom]
func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	Game.pending_seed = 12345
	var game: Game = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	var village: Village = game.village
	village.add_building("storage", village.world.start + Vector2i(4, 4), true)
	village.add_building("house", village.world.start + Vector2i(-7, -6), true)
	village.add_building("workbench", village.world.start + Vector2i(5, -4), true)
	village.add_building("watchtower", village.world.start + Vector2i(-2, -10), true)
	village.add_building("fence", village.world.start + Vector2i(8, 0), true)
	village.add_building("fence", village.world.start + Vector2i(8, 1), true)
	village.plan_building("infirmary", village.world.start + Vector2i(-7, 4))
	Job.assign(village, village.villagers[1], "guard")
	Job.assign(village, village.villagers[2], "hunter")
	if args.size() > 2 and int(args[2]) >= 0:
		game.hud.show_panel(int(args[2]))
	if args.size() > 3:
		game.camera.distance = float(args[3])
		game.camera.zoom(1.0)
	for i in int(args[1]):
		await process_frame
		if args.size() > 4:
			var v: Villager = village.villagers[int(args[4])]
			game.camera.focus_on(Vector3(v.pos.x, village.world.top_y(v.cell()) + 1.0, v.pos.y))
	root.get_viewport().get_texture().get_image().save_png(args[0])
	quit()
