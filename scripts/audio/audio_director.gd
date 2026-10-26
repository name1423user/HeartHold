class_name AudioDirector
extends Node
## 音(AC-049)。警告の種類ごとの音、伐採・採掘・建設完了の効果音、昼と夜の BGM、
## 全体・BGM・効果音の音量。音の素材は assets/audio(tools/make_audio.py で自作)、対応は data/audio.json。

var village: Village
var bgm_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
var current_bgm: String = ""
## 最後に鳴らした音の名前(確認用)
var last_sound: String = ""
var _next_player: int = 0


static func cfg() -> Dictionary:
	return GameData.get_dict("audio")


## バスがなければ作り、設定の音量をかける
static func apply_volumes() -> void:
	ensure_buses()
	for bus: String in Settings.volumes:
		var index: int = AudioServer.get_bus_index(bus)
		if index >= 0:
			AudioServer.set_bus_volume_db(index, linear_to_db(maxf(float(Settings.volumes[bus]), 0.0001)))


static func ensure_buses() -> void:
	for bus: String in cfg()["buses"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var index: int = AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus)
			AudioServer.set_bus_send(index, "Master")


func setup(target: Village, alerts: AlertLog) -> void:
	village = target
	apply_volumes()
	bgm_player = AudioStreamPlayer.new()
	bgm_player.bus = "BGM"
	add_child(bgm_player)
	for i in int(cfg()["sfx_players"]):
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		sfx_players.append(player)
	alerts.added.connect(func(entry: Dictionary) -> void: play(alerts.sound(str(entry["kind"]))))
	village.sound_event.connect(play)
	update_bgm()


func play(sound: String) -> void:
	var path: String = str(cfg()["sounds"].get(sound, ""))
	if path.is_empty():
		return
	var player: AudioStreamPlayer = sfx_players[_next_player]
	_next_player = (_next_player + 1) % sfx_players.size()
	player.stream = load(path)
	player.play()
	last_sound = sound


## 昼と夜で BGM を切り替える
func update_bgm() -> void:
	var wanted: String = "night" if village.clock.is_night() else "day"
	if wanted == current_bgm:
		return
	current_bgm = wanted
	var stream: AudioStreamWAV = load(str(cfg()["bgm"][wanted])) as AudioStreamWAV
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = int(stream.get_length() * stream.mix_rate)
	bgm_player.stream = stream
	bgm_player.play()


func _process(_delta: float) -> void:
	if village != null:
		update_bgm()
