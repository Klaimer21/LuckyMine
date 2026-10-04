class_name Sfx
extends Node
## Звуки из assets/audio/sfx_*.wav (их делает tools/make_audio.py). Игровые звуки идут через шину «SFX», музыка — через
## «Music» (см. music.gd); общая громкость и выключение — на «Master» (Settings.apply). Нет файла — звук просто не играет.

const NAMES := ["crack1", "crack2", "crack3", "ore1", "ore2", "ore3", "ore4", "boom", "boss_hit", "boss_break",
		"golden", "rush", "gong", "zone", "coin", "claim", "tick"]
const VOICES := 12
const BUS_SFX := "SFX"
const BUS_MUSIC := "Music"

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _last_crack := 0.0
var _last_ore := 0.0


## Создаёт шины «SFX» и «Music», если их ещё нет (макет шин не хранится в файле проекта).
static func ensure_buses() -> void:
	for bus_name in [BUS_SFX, BUS_MUSIC]:
		if AudioServer.get_bus_index(bus_name) < 0:
			AudioServer.add_bus()
			var index := AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus_name)
			AudioServer.set_bus_send(index, "Master")


func _ready() -> void:
	ensure_buses()
	for sound_name in NAMES:
		var path := "res://assets/audio/sfx_%s.wav" % sound_name
		if ResourceLoader.exists(path):
			_streams[sound_name] = load(path)
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		player.bus = BUS_SFX
		add_child(player)
		_players.append(player)


func play(sound_name: String, volume_db := 0.0, pitch := 1.0) -> void:
	if not _streams.has(sound_name):
		return
	var player := _players[_next]
	_next = (_next + 1) % VOICES
	player.stream = _streams[sound_name]
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.play()


## Удар камня: один из трёх вариантов, не чаще раза в 45 мс. Высота не меняется: случайные «ноты» сбивали с толку.
func crack(heavy := false) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_crack < 0.045:
		return
	_last_crack = now
	play("crack%d" % (1 + randi() % 3), -9.0 if not heavy else -4.0, 0.8 if heavy else 1.0)


## Подобрана находка: свой звук у каждой руды (1 медь, 2 железо, 3 золото, 4 алмаз); частые находки гасим.
func ore(kind: int) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var gap := 0.18 if kind < 3 else 0.08
	if now - _last_ore < gap:
		return
	_last_ore = now
	play("ore%d" % clampi(kind, 1, 4), -10.0 if kind < 3 else -7.0)
