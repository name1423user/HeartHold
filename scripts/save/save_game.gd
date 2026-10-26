class_name SaveGame
extends RefCounted
## 本番のセーブ・ロード(AC-027, AC-028)。保存先は user://saves/。
## 地形は生成し直した元と違うチャンクだけ VoxelBlockSerializer で圧縮し(<名前>.terrain)、
## それ以外は JSON(<名前>.json)。書くときは一時ファイルに書いてから置き換える。
## 読むときは形式のバージョンと必須項目と地形のハッシュを確かめ、だめなら何も変えずに null を返す。

## テスト用に保存先を差し替える口
static var directory_override: String = ""
static var last_error: String = ""


static func cfg() -> Dictionary:
	return GameData.get_dict("save")


static func directory() -> String:
	return directory_override if not directory_override.is_empty() else str(cfg()["directory"])


static func path(save_name: String, extension: String) -> String:
	return "%s/%s.%s" % [directory(), save_name, extension]


# --- 保存 ---------------------------------------------------------------

static func save_game(game: Game, save_name: String) -> Error:
	return save_village(game.village, save_name, game.extra_state())


static func save_village(village: Village, save_name: String, extra: Dictionary = {}) -> Error:
	var error: Error = DirAccess.make_dir_recursive_absolute(directory())
	if error != OK:
		return error
	var terrain: PackedByteArray = var_to_bytes(_infinite_terrain(village.world) if village.world.infinite else _terrain_chunks(village.world))
	var state: Dictionary = to_state(village, extra)
	state["terrain_sha256"] = _sha256(terrain)
	var json: String = JSON.stringify(state, "", true, true)
	# 一時ファイルに書いてから置き換える(書いている途中で落ちても前のセーブは残る)
	error = _write(path(save_name, "terrain.tmp"), terrain)
	if error == OK:
		error = _write(path(save_name, "json.tmp"), json.to_utf8_buffer())
	if error != OK:
		_remove(path(save_name, "terrain.tmp"))
		_remove(path(save_name, "json.tmp"))
		return error
	error = _replace(path(save_name, "terrain.tmp"), path(save_name, "terrain"))
	if error == OK:
		error = _replace(path(save_name, "json.tmp"), path(save_name, "json"))
	return error


static func to_state(village: Village, extra: Dictionary) -> Dictionary:
	var trees: Array = []
	for cell: Vector2i in village.world.trees:
		trees.append([cell.x, cell.y])
	var villagers: Array = []
	for v in village.villagers:
		villagers.append(v.to_dict())
	var buildings: Array = []
	for b: Building in village.buildings.values():
		buildings.append(b.to_dict())
	var ground: Array = []
	for cell: Vector2i in village.ground_items:
		ground.append([cell.x, cell.y, village.ground_items[cell]])
	var tasks: Array = []
	for task: JobTask in village.tasks.tasks.values():
		tasks.append(task.to_dict())
	return {
		"format_version": int(cfg()["format_version"]),
		"seed": village.world.seed,
		"infinite": village.world.infinite,
		"size": [village.world.size.x, village.world.size.y, village.world.size.z],
		"clock": village.clock.minutes,
		"rng_state": str(village.rng.state),
		"trees": trees,
		"villagers": villagers,
		"next_villager_id": village.next_villager_id,
		"buildings": buildings,
		"next_building_id": village.next_building_id,
		"ground_items": ground,
		"tasks": tasks,
		"next_task_id": village.tasks.next_id,
		"fog": village.fog.to_dict(),
		"inspection": village.inspection.to_dict(),
		"raids": village.raids.to_dict(),
		"wildlife": village.wildlife.to_dict(),
		"chief": village.chief.to_dict(),
		"ruins": village.ruins.to_dict(),
		"level": village.level.level,
		"extra": extra,
		"systems": _systems_state(village),
	}


## 後から足した仕組み(VillageSystem)の状態。形式バージョン2から
static func _systems_state(village: Village) -> Dictionary:
	var out: Dictionary = {}
	for system in village.systems_order:
		out[system.key()] = system.to_dict()
	return out


## 無限の地図: 作ったチャンクの一覧と、変えたブロック(地形は生成し直せる)
static func _infinite_terrain(world: WorldData) -> Dictionary:
	return {"infinite": true, "chunks": world.chunks.keys(), "edits": world.edit_list()}


static func _terrain_chunks(world: WorldData) -> Dictionary:
	var original: WorldData = TerrainGenerator.generate(world.seed)
	var chunk: int = int(cfg()["chunk_size"])
	var chunks: Dictionary = {}
	for cz in ceili(world.size.z / float(chunk)):
		for cx in ceili(world.size.x / float(chunk)):
			for cy in ceili(world.size.y / float(chunk)):
				var origin := Vector3i(cx, cy, cz) * chunk
				var data: PackedByteArray = SavePrototype._chunk_bytes(world, origin)
				if data != SavePrototype._chunk_bytes(original, origin):
					var buffer := VoxelBuffer.new()
					buffer.create(chunk, chunk, chunk)
					buffer.set_channel_depth(VoxelBuffer.CHANNEL_TYPE, VoxelBuffer.DEPTH_8_BIT)
					buffer.set_channel_from_byte_array(VoxelBuffer.CHANNEL_TYPE, data)
					chunks[origin] = VoxelBlockSerializer.serialize_to_byte_array(buffer, VoxelBlockSerializer.COMPRESSION_ZSTD)
	return chunks


# --- 読み込み -------------------------------------------------------------

## 読めなければ null(last_error に文言)。他のセーブには触れない
static func load_village(save_name: String) -> Village:
	last_error = Texts.t("save_corrupt")
	var json_text: String = FileAccess.get_file_as_string(path(save_name, "json"))
	var parser := JSON.new()
	if json_text.is_empty() or parser.parse(json_text) != OK:
		return null
	var state: Variant = parser.data
	if not state is Dictionary or not validate(state):
		return null
	var terrain: PackedByteArray = FileAccess.get_file_as_bytes(path(save_name, "terrain"))
	if terrain.is_empty() or _sha256(terrain) != str(state["terrain_sha256"]):
		return null
	var chunks: Variant = bytes_to_var(terrain)
	if not chunks is Dictionary:
		return null
	if bool(state.get("infinite", false)):
		if not chunks.has("chunks") or not chunks.has("edits"):
			return null
	else:
		for key: Variant in chunks:
			if not key is Vector3i or not chunks[key] is PackedByteArray:
				return null
	last_error = ""
	return from_state(state, chunks)


## 形式のバージョンと必須項目を確かめる
static func validate(state: Dictionary) -> bool:
	var version: int = int(state.get("format_version", -1))
	if not (cfg()["readable_versions"] as Array).any(func(v: Variant) -> bool: return int(v) == version):
		return false
	if state.has("systems") and not state["systems"] is Dictionary:
		return false
	var required: Dictionary = {
		"seed": TYPE_FLOAT, "size": TYPE_ARRAY, "clock": TYPE_FLOAT, "rng_state": TYPE_STRING, "trees": TYPE_ARRAY,
		"villagers": TYPE_ARRAY, "next_villager_id": TYPE_FLOAT, "buildings": TYPE_ARRAY, "next_building_id": TYPE_FLOAT,
		"ground_items": TYPE_ARRAY, "tasks": TYPE_ARRAY, "next_task_id": TYPE_FLOAT, "fog": TYPE_DICTIONARY,
		"inspection": TYPE_DICTIONARY, "raids": TYPE_DICTIONARY, "wildlife": TYPE_DICTIONARY, "chief": TYPE_DICTIONARY,
		"ruins": TYPE_ARRAY, "level": TYPE_FLOAT, "terrain_sha256": TYPE_STRING,
	}
	for key: String in required:
		if not state.has(key) or typeof(state[key]) != required[key]:
			return false
	var size: Array = state["size"]
	var expected: Array = GameData.get_dict("terrain")["size"]
	if size.size() != 3 or int(size[0]) != int(expected[0]) or int(size[1]) != int(expected[1]) or int(size[2]) != int(expected[2]):
		return false
	for v: Variant in state["villagers"]:
		if not _has_keys(v, ["id", "name", "job", "pos", "needs", "state", "is_chief"]) or (v["pos"] as Array).size() != 2:
			return false
		if not v["needs"] is Dictionary:
			return false
	var types: Dictionary = GameData.get_dict("buildings")
	for b: Variant in state["buildings"]:
		if not _has_keys(b, ["id", "type", "cell", "state", "delivered", "progress", "inventory"]) or not types.has(str(b["type"])):
			return false
	for t: Variant in state["tasks"]:
		if not _has_keys(t, ["id", "type", "cell", "pos", "building_id", "recipe", "work_needed", "progress", "blocked_reason", "retry_at"]):
			return false
	for pile: Variant in state["ground_items"]:
		if not pile is Array or (pile as Array).size() != 3 or not pile[2] is Dictionary:
			return false
	return (_has_keys(state["fog"], ["explored", "size"]) or _has_keys(state["fog"], ["chunks"])) \
		and _has_keys(state["inspection"], ["next_visit_at", "rejected", "accepted"]) \
		and _has_keys(state["raids"], ["active", "last_raid_at", "next_monster_id", "monsters"]) \
		and _has_keys(state["wildlife"], ["animals", "next_id", "respawn_timer"]) \
		and _has_keys(state["chief"], ["villager", "policy", "last_change_day"])


static func _has_keys(value: Variant, keys: Array) -> bool:
	if not value is Dictionary:
		return false
	for key: String in keys:
		if not (value as Dictionary).has(key):
			return false
	return true


static func from_state(state: Dictionary, chunks: Dictionary) -> Village:
	var world: WorldData
	if bool(state.get("infinite", false)):
		world = TerrainGenerator.generate_infinite(int(state["seed"]))
		for key: Variant in chunks["chunks"]:
			if key is Vector2i:
				world.ensure_chunk(key)
		world.apply_edit_list(chunks["edits"])
	else:
		world = TerrainGenerator.generate(int(state["seed"]))
		for origin: Vector3i in chunks:
			var buffer := VoxelBuffer.new()
			VoxelBlockSerializer.deserialize_from_byte_array(chunks[origin], buffer, true)
			SavePrototype._apply_chunk(world, origin, buffer.get_channel_as_byte_array(VoxelBuffer.CHANNEL_TYPE))
	world.trees.clear()
	for pair: Array in state["trees"]:
		world.trees[Vector2i(int(pair[0]), int(pair[1]))] = true
	var buildings: Dictionary = {}
	for entry: Dictionary in state["buildings"]:
		var b: Building = Building.from_dict(entry)
		buildings[b.id] = b
		if not bool(b.def().get("walkable", false)):
			for c in b.cells():
				world.blocked[c] = b.id
	# 地形・木・建物を戻してから村を作ると、経路探索もそれに合わせて作られる
	var village := Village.new(world)
	village.buildings = buildings
	village.next_building_id = int(state["next_building_id"])
	village.clock.minutes = float(state["clock"])
	village.rng.state = int(str(state["rng_state"]))
	village.villagers.clear()
	for entry: Dictionary in state["villagers"]:
		village.villagers.append(Villager.from_dict(entry))
	village.next_villager_id = int(state["next_villager_id"])
	village.ground_items.clear()
	for pile: Array in state["ground_items"]:
		var items: Dictionary = {}
		for item: String in pile[2]:
			items[item] = int(pile[2][item])
		village.ground_items[Vector2i(int(pile[0]), int(pile[1]))] = items
	village.tasks.tasks.clear()
	for entry: Dictionary in state["tasks"]:
		var task: JobTask = JobTask.from_dict(entry)
		village.tasks.tasks[task.id] = task
	village.tasks.next_id = int(state["next_task_id"])
	village.fog.from_dict(state["fog"])
	village.inspection.from_dict(state["inspection"])
	village.raids.from_dict(state["raids"])
	village.wildlife.from_dict(state["wildlife"])
	village.chief.from_dict(state["chief"])
	village.ruins.from_dict(state["ruins"])
	village.level.level = int(state["level"])
	village.loaded_extra = state.get("extra", {})
	# バージョン1のセーブには systems がない。その場合は新しく始めた状態のまま
	var systems_state: Dictionary = state.get("systems", {})
	for system in village.systems_order:
		if systems_state.has(system.key()) and systems_state[system.key()] is Dictionary:
			system.from_dict(systems_state[system.key()])
	return village


# --- 一覧・削除 -----------------------------------------------------------

## 新しい順のセーブ名
static func list_saves() -> Array[String]:
	var names: Array[String] = []
	var dir := DirAccess.open(directory())
	if dir == null:
		return names
	for file in dir.get_files():
		if file.ends_with(".json"):
			names.append(file.get_basename())
	names.sort_custom(func(a: String, b: String) -> bool:
		return FileAccess.get_modified_time(path(a, "json")) > FileAccess.get_modified_time(path(b, "json")))
	return names


static func delete_save(save_name: String) -> void:
	_remove(path(save_name, "json"))
	_remove(path(save_name, "terrain"))


static func exists(save_name: String) -> bool:
	return FileAccess.file_exists(path(save_name, "json"))


# --- ファイル ---------------------------------------------------------------

static func _write(file_path: String, data: PackedByteArray) -> Error:
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_buffer(data)
	var error: Error = file.get_error()
	file.close()
	return error


static func _replace(from: String, to: String) -> Error:
	var error: Error = DirAccess.rename_absolute(from, to)
	if error != OK and FileAccess.file_exists(to):
		DirAccess.remove_absolute(to)
		error = DirAccess.rename_absolute(from, to)
	return error


static func _remove(file_path: String) -> void:
	if FileAccess.file_exists(file_path):
		DirAccess.remove_absolute(file_path)


static func _sha256(data: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(data)
	return context.finish().hex_encode()
