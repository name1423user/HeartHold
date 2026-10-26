class_name TerrainGenerator
extends RefCounted
## シードから草原・森・岩山・川のある地形を作る(AC-001, AC-002)。数値は data/terrain.json。


static func generate(seed: int) -> WorldData:
	var cfg: Dictionary = GameData.get_dict("terrain")
	var world := WorldData.new()
	world.seed = seed
	var s: Array = cfg["size"]
	world.size = Vector3i(int(s[0]), int(s[1]), int(s[2]))
	world.start = Vector2i(world.size.x / 2, world.size.z / 2)

	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var river: Dictionary = cfg["river"]
	var mountain: Dictionary = cfg["mountain"]
	var forest: Dictionary = cfg["forest"]

	var side: int = 1 if rng.randi_range(0, 1) == 0 else -1
	var river_x: float = world.start.x + side * rng.randi_range(int(river["min_offset"]), int(river["max_offset"]))
	var river_phase: float = rng.randf() * TAU
	var mountain_center := Vector2(
		world.start.x - side * rng.randi_range(int(mountain["min_distance"]), int(mountain["max_distance"])),
		world.start.y + rng.randi_range(-40, 40))
	var forest_side: int = 1 if rng.randi_range(0, 1) == 0 else -1
	var forest_center := Vector2(
		world.start.x + rng.randi_range(-20, 20),
		world.start.y + forest_side * rng.randi_range(int(forest["min_distance"]), int(forest["max_distance"])))

	var hill_noise := FastNoiseLite.new()
	hill_noise.seed = seed
	hill_noise.frequency = float(cfg["hill_frequency"])
	var forest_noise := FastNoiseLite.new()
	forest_noise.seed = seed + 1
	forest_noise.frequency = float(forest["frequency"])
	var tree_rng := RandomNumberGenerator.new()
	tree_rng.seed = seed + 2

	var base: int = int(cfg["base_height"])
	var water_level: int = base - 1
	var start_radius: float = float(cfg["start_radius"])
	var stone_above: float = float(mountain["stone_above"])
	var ids: Dictionary = cfg["blocks"]
	var grass: int = int(ids["grass"])
	var stone: int = int(ids["stone"])
	var sand: int = int(ids["sand"])
	var templates: Dictionary = {}
	var column_count: int = world.size.x * world.size.z
	world.biomes.resize(column_count)
	world.top.resize(column_count)

	for z in world.size.z:
		for x in world.size.x:
			var cell := Vector2i(x, z)
			var pos := Vector2(x, z)
			var height: float = base + hill_noise.get_noise_2d(x, z) * float(cfg["hill_amplitude"])
			var biome: int = WorldData.Biome.GRASSLAND
			var top_block: int = grass
			var water_top: int = -1

			var mountain_distance: float = pos.distance_to(mountain_center)
			var mountain_radius: float = float(mountain["radius"])
			if mountain_distance < mountain_radius:
				var falloff: float = 1.0 - mountain_distance / mountain_radius
				var bump: float = float(mountain["peak_height"]) * falloff * falloff
				bump += absf(hill_noise.get_noise_2d(x * 3, z * 3)) * float(mountain["noise_amplitude"]) * falloff
				height += bump
				if bump > stone_above:
					biome = WorldData.Biome.MOUNTAIN
					top_block = stone

			var center_x: float = river_x + float(river["amplitude"]) * sin(z * float(river["frequency"]) + river_phase)
			var on_river: bool = absf(x - center_x) <= float(river["half_width"])
			if on_river:
				biome = WorldData.Biome.RIVER
				height = minf(height, base) - float(river["depth"])
				top_block = sand
				water_top = water_level

			if pos.distance_to(Vector2(world.start)) <= start_radius:
				height = base
				biome = WorldData.Biome.GRASSLAND
				top_block = grass
				water_top = -1
			elif biome == WorldData.Biome.GRASSLAND:
				var forested: bool = forest_noise.get_noise_2d(x, z) > float(forest["threshold"])
				if forested or pos.distance_to(forest_center) <= float(forest["seed_center_radius"]):
					biome = WorldData.Biome.FOREST
					if tree_rng.randf() < float(forest["tree_chance"]):
						world.trees[cell] = true

			var h: int = clampi(roundi(height), 1, world.size.y - 2)
			var key := Vector3i(h, top_block, water_top)
			if not templates.has(key):
				templates[key] = _column(cfg, world.size.y, h, top_block, water_top)
			world.blocks.append_array(templates[key])
			var column: int = world.column_index(x, z)
			world.biomes[column] = biome
			world.top[column] = maxi(h, water_top)

	world.original_top = world.top.duplicate()
	return world


static func _column(cfg: Dictionary, height_limit: int, h: int, top_block: int, water_top: int) -> PackedByteArray:
	var ids: Dictionary = cfg["blocks"]
	var column := PackedByteArray()
	column.resize(height_limit)
	var dirt_from: int = h - int(cfg["dirt_depth"])
	for y in height_limit:
		var id: int = int(ids["air"])
		if y < dirt_from:
			id = int(ids["stone"])
		elif y < h:
			id = int(ids["stone"]) if top_block == int(ids["stone"]) else int(ids["dirt"])
		elif y == h:
			id = top_block
		elif y <= water_top:
			id = int(ids["water"])
		column[y] = id
	return column
