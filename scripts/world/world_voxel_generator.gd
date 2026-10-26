class_name WorldVoxelGenerator
extends VoxelGeneratorScript
## VoxelTerrain のブロックを埋める。決まった大きさの地図は WorldData の写し(VoxelBuffer)から写す。
## 無限の地図(M11-T04)は TerrainShape で列ごとに計算し、変えたブロックを上からかける
## (このスレッドからは WorldData のチャンクに触らない)。

var source: VoxelBuffer
var world: WorldData
var shape: TerrainShape


func _init(target: WorldData) -> void:
	world = target
	shape = target.shape
	if world.infinite:
		return
	source = VoxelBuffer.new()
	source.create(world.size.x, world.size.y, world.size.z)
	# VoxelTerrain は 16bit で持つので、8bit の並びを Image の変換で 16bit(下位バイト)に広げる
	var count: int = world.blocks.size()
	var image := Image.create_from_data(count / 1024, 1024, false, Image.FORMAT_R8, world.blocks)
	image.convert(Image.FORMAT_RG8)
	source.set_channel_from_byte_array(VoxelBuffer.CHANNEL_TYPE, image.get_data())


func _get_used_channels_mask() -> int:
	return 1 << VoxelBuffer.CHANNEL_TYPE


func _generate_block(out_buffer: VoxelBuffer, origin: Vector3i, lod: int) -> void:
	if world.infinite:
		_generate_infinite(out_buffer, origin)
		return
	var size: Vector3i = source.get_size()
	var block_max: Vector3i = origin + out_buffer.get_size()
	var src_min: Vector3i = origin.clamp(Vector3i.ZERO, size)
	var src_max: Vector3i = block_max.clamp(Vector3i.ZERO, size)
	if src_min.x >= src_max.x or src_min.y >= src_max.y or src_min.z >= src_max.z:
		return
	out_buffer.copy_channel_from_area(source, src_min, src_max, src_min - origin, VoxelBuffer.CHANNEL_TYPE)


func _generate_infinite(out_buffer: VoxelBuffer, origin: Vector3i) -> void:
	var bsize: Vector3i = out_buffer.get_size()
	if origin.y >= shape.height_limit or origin.y + bsize.y <= 0:
		return
	var channel: int = VoxelBuffer.CHANNEL_TYPE
	for lz in bsize.z:
		for lx in bsize.x:
			var info: Dictionary = shape.column(origin.x + lx, origin.z + lz)
			var bytes: PackedByteArray = shape.column_bytes(info)
			# 同じブロックが続く所はまとめて塗る
			var run_start: int = 0
			var run_id: int = -1
			for ly in bsize.y + 1:
				var y: int = origin.y + ly
				var id: int = -2 if ly == bsize.y else (bytes[y] if y >= 0 and y < bytes.size() else 0)
				if id != run_id:
					if run_id > 0:
						out_buffer.fill_area(run_id, Vector3i(lx, run_start, lz), Vector3i(lx + 1, ly, lz + 1), channel)
					run_id = id
					run_start = ly
	var lo: Vector2i = world.chunk_of(Vector2i(origin.x, origin.z))
	var hi: Vector2i = world.chunk_of(Vector2i(origin.x + bsize.x - 1, origin.z + bsize.z - 1))
	for cz in range(lo.y, hi.y + 1):
		for cx in range(lo.x, hi.x + 1):
			var changed: Dictionary = world.edits_in_chunk(Vector2i(cx, cz))
			for pos: Vector3i in changed:
				var local: Vector3i = pos - origin
				if local.x >= 0 and local.y >= 0 and local.z >= 0 and local.x < bsize.x and local.y < bsize.y and local.z < bsize.z:
					out_buffer.set_voxel(int(changed[pos]), local.x, local.y, local.z, channel)
