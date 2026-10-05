class_name Music
extends Node
## Фоновая музыка: семь бесшовных петель по зонам assets/audio/music_N.wav и по одной петле на сезон (music_winter.wav и т. д.,
## tools/make_audio.py). Пока включён сезон, играет его петля во всех зонах. Смена петли плавная: два плеера, пока один
## затухает, второй нарастает. Громкость — шина «Music».

const FADE := 3.0
const QUIET_DB := -80.0
const PLAY_DB := -6.0

var _players: Array[AudioStreamPlayer] = []
var _active := 0
var _zone := -1
var _season := ""
var _path := ""


func _ready() -> void:
	Sfx.ensure_buses()
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.bus = Sfx.BUS_MUSIC
		player.volume_db = QUIET_DB
		add_child(player)
		_players.append(player)


## Включает музыку зоны (если не идёт сезонная). instant — без плавной смены (при запуске).
func play_zone(zone: int, instant := false) -> void:
	_zone = zone
	_refresh(instant)


## Сезонная музыка поверх зон; "none" или пустое — обычная музыка зоны.
func set_season(id: String, instant := false) -> void:
	_season = "" if id == Seasons.NONE else id
	_refresh(instant)


func _refresh(instant: bool) -> void:
	var path := Seasons.music_path(_season) if _season != "" else ""
	if path == "" or not ResourceLoader.exists(path):
		path = "res://assets/audio/music_%d.wav" % _zone if _zone >= 0 else ""
	if path == "" or path == _path or not ResourceLoader.exists(path):
		return
	var stream := load(path) as AudioStreamWAV
	if stream == null:
		return
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = stream.data.size() / 2        # 16 бит, моно: два байта на отсчёт
	_path = path
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
