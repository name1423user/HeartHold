class_name TerrainShape
extends RefCounted
## 地形の形を列(x, z)ごとに計算する(M11-T04)。シードだけで決まり、計算する順番によらないので、
## 決まった大きさの地図も、チャンク単位で広がる無限の地図も同じ地形になる。
## 開始地点のまわりには岩山・森・川を必ず置き(AC-002)、遠くではノイズで岩山と川が現れる。
## 別のスレッド(VoxelTerrain の生成)からも呼べるよう、作ったあとは中身を変えない。

var seed: int = 0
var cfg: Dictionary = {}
var start: Vector2i = Vector2i.ZERO
var height_limit: int = 64

var _river_x: float = 0.0
var _river_phase: float = 0.0
var _mountain_center: Vector2 = Vector2.ZERO
var _forest_center: Vector2 = Vector2.ZERO
var _hill_noise := FastNoiseLite.new()
var _forest_noise := FastNoiseLite.new()
var _far_mountain_noise := FastNoiseLite.new()
var _far_river_noise := FastNoiseLite.new()
var _ids: Dictionary = {}


func _init(world_seed: int, start_cell: Vector2i) -> void:
	seed = world_seed
	start = start_cell
	cfg = GameData.get_dict("terrain").duplicate(true)
	height_limit = int(cfg["size"][1])
	_ids = cfg["blocks"]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var river: Dictionary = cfg["river"]
	var mountain: Dictionary = cfg["mountain"]
	var forest: Dictionary = cfg["forest"]
	var side: int = 1 if rng.randi_range(0, 1) == 0 else -1
	_river_x = start.x + side * rng.randi_range(int(river["min_offset"]), int(river["max_offset"]))
	_river_phase = rng.randf() * TAU
	_mountain_center = Vector2(
		start.x - side * rng.randi_range(int(mountain["min_distance"]), int(mountain["max_distance"])),
		start.y + rng.randi_range(-40, 40))
	var forest_side: int = 1 if rng.randi_range(0, 1) == 0 else -1
	_forest_center = Vector2(
		start.x + rng.randi_range(-20, 20),
		start.y + forest_side * rng.randi_range(int(forest["min_distance"]), int(forest["max_distance"])))
	_hill_noise.seed = seed
	_hill_noise.frequency = float(cfg["hill_frequency"])
	_forest_noise.seed = seed + 1
	_forest_noise.frequency = float(forest["frequency"])
	var far: Dictionary = cfg["far"]
	_far_mountain_noise.seed = seed + 7
	_far_mountain_noise.frequency = float(far["mountain_frequency"])
	_far_river_noise.seed = seed + 8
	_far_river_noise.frequency = float(far["river_frequency"])


func block(name: String) -> int:
	return int(_ids[name])


## 0〜1 の、列と目的ごとに決まった値(乱数の代わり。順番によらない)
func hash01(x: int, z: int, salt: int) -> float:
	return float(hash(Vector3i(x, z, seed * 31 + salt)) & 0xFFFFFF) / 16777216.0


## 列の情報: {"h", "top", "water_top", "biome", "tree", "ores": {y: id}}
func column(x: int, z: int) -> Dictionary:
	var pos := Vector2(x, z)
	var base: int = int(cfg["base_height"])
	var height: float = base + _hill_noise.get_noise_2d(x, z) * float(cfg["hill_amplitude"])
	var biome: int = WorldData.Biome.GRASSLAND
	var top_block: int = block("grass")
	var water_top: int = -1
	var mountain: Dictionary = cfg["mountain"]
	var stone_above: float = float(mountain["stone_above"])

	var mountain_distance: float = pos.distance_to(_mountain_center)
	var mountain_radius: float = float(mountain["radius"])
	var bump: float = 0.0
	if mountain_distance < mountain_radius:
		var falloff: float = 1.0 - mountain_distance / mountain_radius
		bump = float(mountain["peak_height"]) * falloff * falloff
		bump += absf(_hill_noise.get_noise_2d(x * 3, z * 3)) * float(mountain["noise_amplitude"]) * falloff
	var far: Dictionary = cfg["far"]
	var far_away: bool = pos.distance_to(Vector2(start)) > float(far["from_start"])
	if far_away:
		var n: float = _far_mountain_noise.get_noise_2d(x, z) - float(far["mountain_threshold"])
		if n > 0.0:
			bump = maxf(bump, n / (1.0 - float(far["mountain_threshold"])) * float(far["mountain_height"]) + absf(_hill_noise.get_noise_2d(x * 3, z * 3)) * float(mountain["noise_amplitude"]))
	if bump > 0.0:
		height += bump
		if bump > stone_above:
			biome = WorldData.Biome.MOUNTAIN
			top_block = block("stone")

	var river: Dictionary = cfg["river"]
	var center_x: float = _river_x + float(river["amplitude"]) * sin(z * float(river["frequency"]) + _river_phase)
	var on_river: bool = absf(x - center_x) <= float(river["half_width"])
	if far_away and absf(_far_river_noise.get_noise_2d(x, z)) < float(far["river_width"]):
		on_river = true
	if on_river:
		biome = WorldData.Biome.RIVER
		height = minf(height, base) - float(river["depth"])
		top_block = block("sand")
		water_top = base - 1

	var tree: bool = false
	if pos.distance_to(Vector2(start)) <= float(cfg["start_radius"]):
		height = base
		biome = WorldData.Biome.GRASSLAND
		top_block = block("grass")
		water_top = -1
	elif biome == WorldData.Biome.GRASSLAND:
		var forest: Dictionary = cfg["forest"]
		var forested: bool = _forest_noise.get_noise_2d(x, z) > float(forest["threshold"])
		if forested or pos.distance_to(_forest_center) <= float(forest["seed_center_radius"]):
			biome = WorldData.Biome.FOREST
			tree = hash01(x, z, 2) < float(forest["tree_chance"])

	var h: int = clampi(roundi(height), 1, height_limit - 2)
	var ores: Dictionary = {}
	if biome == WorldData.Biome.MOUNTAIN and cfg.has("ores"):
		var o: Dictionary = cfg["ores"]
		for y in range(maxi(0, h - int(o["depth"])), h):
			var roll: float = hash01(x, z, 100 + y)
			if roll < float(o["iron_ore"]):
				ores[y] = block("iron_ore")
			elif roll < float(o["iron_ore"]) + float(o["coal"]):
				ores[y] = block("coal")
	return {"h": h, "top": top_block, "water_top": water_top, "biome": biome, "tree": tree, "ores": ores}


## 列のブロックの並び(y が下から)
func column_bytes(info: Dictionary) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(height_limit)
	var h: int = int(info["h"])
	var top_block: int = int(info["top"])
	var water_top: int = int(info["water_top"])
	var dirt_from: int = h - int(cfg["dirt_depth"])
	var stone: int = block("stone")
	for y in height_limit:
		var id: int = block("air")
		if y < dirt_from:
			id = stone
		elif y < h:
			id = stone if top_block == stone else block("dirt")
		elif y == h:
			id = top_block
		elif y <= water_top:
			id = block("water")
		bytes[y] = id
	var ores: Dictionary = info["ores"]
	for y: int in ores:
		bytes[y] = int(ores[y])
	return bytes
