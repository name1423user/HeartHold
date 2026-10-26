class_name AudioDirector
extends Node
## 音(M6-T05 で中身を入れる)。音量の設定をバスに反映する。


static func apply_volumes() -> void:
	for bus: String in Settings.volumes:
		var index: int = AudioServer.get_bus_index(bus)
		if index >= 0:
			AudioServer.set_bus_volume_db(index, linear_to_db(maxf(float(Settings.volumes[bus]), 0.0001)))
