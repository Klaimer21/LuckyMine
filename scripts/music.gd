class_name Music
extends Node
## Фоновая музыка по зонам: семь бесшовных петель assets/audio/music_N.wav (tools/make_audio.py). При смене зоны новая
## петля плавно сменяет прежнюю. Два плеера: пока один затухает, второй нарастает. Громкость — шина «Music».

const FADE := 3.0
const QUIET_DB := -80.0
const PLAY_DB := -6.0

var _players: Array[AudioStreamPlayer] = []
var _active := 0
var _zone := -1


func _ready() -> void:
	Sfx.ensure_buses()
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.bus = Sfx.BUS_MUSIC
		player.volume_db = QUIET_DB
		add_child(player)
		_players.append(player)


## Включает музыку зоны. instant — без плавной смены (при запуске).
func play_zone(zone: int, instant := false) -> void:
	if zone == _zone:
		return
	var path := "res://assets/audio/music_%d.wav" % zone
	if not ResourceLoader.exists(path):
		return
	var stream := load(path) as AudioStreamWAV
	if stream == null:
		return
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = stream.data.size() / 2        # 16 бит, моно: два байта на отсчёт
	_zone = zone
	var old := _players[_active]
	_active = 1 - _active
	var player := _players[_active]
	player.stream = stream
	player.volume_db = PLAY_DB if instant else QUIET_DB
	player.play()
	var tween := create_tween()
	tween.set_parallel(true)
	if not instant:
		tween.tween_property(player, "volume_db", PLAY_DB, FADE)
	tween.tween_property(old, "volume_db", QUIET_DB, 0.01 if instant else FADE)
	tween.chain().tween_callback(old.stop)
