class_name WorldVoxelGenerator
extends VoxelGeneratorScript
## WorldData の写し(VoxelBuffer)から VoxelTerrain のブロックを埋める。

var source: VoxelBuffer


func _init(world: WorldData) -> void:
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
	var size: Vector3i = source.get_size()
	var block_max: Vector3i = origin + out_buffer.get_size()
	var src_min: Vector3i = origin.clamp(Vector3i.ZERO, size)
	var src_max: Vector3i = block_max.clamp(Vector3i.ZERO, size)
	if src_min.x >= src_max.x or src_min.y >= src_max.y or src_min.z >= src_max.z:
		return
	out_buffer.copy_channel_from_area(source, src_min, src_max, src_min - origin, VoxelBuffer.CHANNEL_TYPE)
