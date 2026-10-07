class_name Settings
extends RefCounted
## Настройки игрока: язык, графика, частота кадров, звук, вибрация. Хранятся отдельно от сохранения игры.

const PATH := "user://luckymine_settings.cfg"
const QUALITY_NAMES := ["Низкое", "Среднее", "Высокое"]
## Режимы покупки улучшений: сколько уровней за нажатие (0 — «Макс»).
const BUY_MODES := [1, 5, 10, 100, 0]
const STYLE_NAMES := ["Гранит", "Базальт", "Песчаник", "Мрамор", "Обсидиан", "Лазурит", "Малахит", "Янтарь", "Рубин", "Аметист"]
const FPS_OPTIONS := [30, 60, 90, 120]

var language := "en"
var quality := 1                 # 0 — низкое, 1 — среднее, 2 — высокое
var buy_mode := 0                # индекс BUY_MODES
var keep_awake := true           # не гасить экран на телефоне
var fps_cap := 60
var popups := true
var season := "none"               # сезон оформления: none, auto, winter, halloween (только внешний вид)
var reduce_motion := false       # без тряски камеры, вспышек и «заморозки» кадра: для тех, кого укачивает
var show_fps := false
var cloud_enabled := true         # облачное сохранение (Google Play Игры на Android)
var cloud_declined := 0.0         # время сохранения в облаке, от которого игрок отказался (чтобы не спрашивать снова)
var cloud_last_sync := 0.0        # когда в последний раз записали в облако (unix)
var sound_on := true
var music_volume := 0.7
var sfx_volume := 1.0
var volume := 0.8
var vibration_on := true
var rock_style := 0              # 0 гранит, 1 базальт, 2 песчаник


func load_settings() -> void:
	language = Tr.detect_system_language()
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		# первый запуск: слабому телефону (4 ядра и меньше) сразу низкое качество, остальным среднее
		if OS.has_feature("mobile") and OS.get_processor_count() <= 4:
			quality = 0
		return
	var saved_language := str(config.get_value("main", "language", language))
	if Tr.LANGUAGES.any(func(entry: Array) -> bool: return entry[0] == saved_language):
		language = saved_language
	quality = clampi(int(config.get_value("main", "quality", quality)), 0, 2)
	buy_mode = clampi(int(config.get_value("main", "buy_mode", buy_mode)), 0, BUY_MODES.size() - 1)
	keep_awake = bool(config.get_value("main", "keep_awake", keep_awake))
	fps_cap = int(config.get_value("main", "fps_cap", fps_cap))
	if not fps_cap in FPS_OPTIONS:
		fps_cap = 60
	popups = bool(config.get_value("main", "popups", popups))
	reduce_motion = bool(config.get_value("main", "reduce_motion", reduce_motion))
	var saved_season := str(config.get_value("main", "season", season))
	season = saved_season if Seasons.CHOICES.has(saved_season) else "none"
	show_fps = bool(config.get_value("main", "show_fps", show_fps))
	cloud_enabled = bool(config.get_value("main", "cloud_enabled", cloud_enabled))
	cloud_declined = float(config.get_value("main", "cloud_declined", cloud_declined))
	cloud_last_sync = float(config.get_value("main", "cloud_last_sync", cloud_last_sync))
	sound_on = bool(config.get_value("main", "sound_on", sound_on))
	music_volume = clampf(float(config.get_value("main", "music_volume", music_volume)), 0.0, 1.0)
	sfx_volume = clampf(float(config.get_value("main", "sfx_volume", sfx_volume)), 0.0, 1.0)
	volume = clampf(float(config.get_value("main", "volume", volume)), 0.0, 1.0)
	vibration_on = bool(config.get_value("main", "vibration_on", vibration_on))
	rock_style = clampi(int(config.get_value("main", "rock_style", rock_style)), 0, STYLE_NAMES.size() - 1)


func save() -> void:
	var config := ConfigFile.new()
	config.set_value("main", "language", language)
	config.set_value("main", "quality", quality)
	config.set_value("main", "buy_mode", buy_mode)
	config.set_value("main", "keep_awake", keep_awake)
	config.set_value("main", "fps_cap", fps_cap)
	config.set_value("main", "popups", popups)
	config.set_value("main", "reduce_motion", reduce_motion)
	config.set_value("main", "season", season)
	config.set_value("main", "show_fps", show_fps)
	config.set_value("main", "cloud_enabled", cloud_enabled)
	config.set_value("main", "cloud_declined", cloud_declined)
	config.set_value("main", "cloud_last_sync", cloud_last_sync)
	config.set_value("main", "sound_on", sound_on)
	config.set_value("main", "music_volume", music_volume)
	config.set_value("main", "sfx_volume", sfx_volume)
	config.set_value("main", "volume", volume)
	config.set_value("main", "vibration_on", vibration_on)
	config.set_value("main", "rock_style", rock_style)
	config.save(PATH)


## Применяет настройки к движку и сцене. Качество (2D-поле): сколько глыб, крошки и руды рисуется одновременно.
func apply(_viewport: Viewport, table: FieldTable) -> void:
	Tr.set_language(language)
	Engine.max_fps = fps_cap
	DisplayServer.screen_set_keep_on(keep_awake)
	# на телефоне без вертикальной синхронизации ограничение FPS действительно работает (и на 90/120 Гц тоже);
	# на компьютере оставляем её включённой: нет разрывов кадров и лишнего нагрева
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED if OS.has_feature("mobile") else DisplayServer.VSYNC_ENABLED)
	if table != null:
		table.set_quality(quality)
		table.show_popups = popups
		table.reduce_motion = reduce_motion
		table.set_style(rock_style)
	Sfx.ensure_buses()
	var sfx_bus := AudioServer.get_bus_index(Sfx.BUS_SFX)
	AudioServer.set_bus_volume_db(sfx_bus, linear_to_db(maxf(sfx_volume, 0.0001)))
	var music_bus := AudioServer.get_bus_index(Sfx.BUS_MUSIC)
	AudioServer.set_bus_mute(music_bus, music_volume <= 0.001)
	AudioServer.set_bus_volume_db(music_bus, linear_to_db(maxf(music_volume, 0.0001)))
	var master := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(master, not sound_on)
	AudioServer.set_bus_volume_db(master, linear_to_db(maxf(volume, 0.0001)))


func vibrate(milliseconds: int) -> void:
	if vibration_on:
		Input.vibrate_handheld(milliseconds)

