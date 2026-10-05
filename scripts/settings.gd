class_name Settings
extends RefCounted
## Настройки игрока: язык, графика, частота кадров, звук, вибрация. Хранятся отдельно от сохранения игры.

const PATH := "user://luckymine_settings.cfg"
const QUALITY_NAMES := ["Низкое", "Среднее", "Высокое"]
## Сглаживание: 0 — по качеству графики, дальше выбор вручную.
const AA_NAMES := ["Авто", "Выкл", "MSAA 2x", "MSAA 4x", "4x+FXAA"]
## Режимы покупки улучшений: сколько уровней за нажатие (0 — «Макс»).
const BUY_MODES := [1, 5, 10, 100, 0]
const RENDER_SCALES := [1.0, 0.85, 0.7, 0.5]
const STYLE_NAMES := ["Гранит", "Базальт", "Песчаник", "Мрамор", "Обсидиан", "Лазурит", "Малахит", "Янтарь", "Рубин", "Аметист"]
const FPS_OPTIONS := [30, 60, 90, 120]

var language := "en"
var quality := 1                 # 0 — низкое, 1 — среднее, 2 — высокое
var antialiasing := 0            # индекс AA_NAMES
var buy_mode := 0                # индекс BUY_MODES
var keep_awake := true           # не гасить экран на телефоне
var render_scale := 1.0          # доля разрешения 3D-сцены
var fps_cap := 60
var popups := true
var season := "none"               # сезон оформления: none, auto, winter, halloween (только внешний вид)
var reduce_motion := false       # без тряски камеры, вспышек и «заморозки» кадра: для тех, кого укачивает
var show_fps := false
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
	antialiasing = clampi(int(config.get_value("main", "antialiasing", antialiasing)), 0, AA_NAMES.size() - 1)
	buy_mode = clampi(int(config.get_value("main", "buy_mode", buy_mode)), 0, BUY_MODES.size() - 1)
	keep_awake = bool(config.get_value("main", "keep_awake", keep_awake))
	render_scale = clampf(float(config.get_value("main", "render_scale", render_scale)), 0.5, 1.0)
	fps_cap = int(config.get_value("main", "fps_cap", fps_cap))
	if not fps_cap in FPS_OPTIONS:
		fps_cap = 60
	popups = bool(config.get_value("main", "popups", popups))
	reduce_motion = bool(config.get_value("main", "reduce_motion", reduce_motion))
	var saved_season := str(config.get_value("main", "season", season))
	season = saved_season if Seasons.CHOICES.has(saved_season) else "none"
	show_fps = bool(config.get_value("main", "show_fps", show_fps))
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
	config.set_value("main", "antialiasing", antialiasing)
	config.set_value("main", "buy_mode", buy_mode)
	config.set_value("main", "keep_awake", keep_awake)
	config.set_value("main", "render_scale", render_scale)
	config.set_value("main", "fps_cap", fps_cap)
	config.set_value("main", "popups", popups)
	config.set_value("main", "reduce_motion", reduce_motion)
	config.set_value("main", "season", season)
	config.set_value("main", "show_fps", show_fps)
	config.set_value("main", "sound_on", sound_on)
	config.set_value("main", "music_volume", music_volume)
	config.set_value("main", "sfx_volume", sfx_volume)
	config.set_value("main", "volume", volume)
	config.set_value("main", "vibration_on", vibration_on)
	config.set_value("main", "rock_style", rock_style)
	config.save(PATH)


## Применяет настройки к движку и сцене.
## Качество: 0 — без теней и сглаживания, мало частиц и глыб; 1 — мягкие тени, MSAA ×2; 2 — тени
## высокого качества, MSAA ×4 и FXAA, максимум частиц. Разрешение рендера уменьшает только 3D (стол и кубики).
func apply(viewport: Viewport, table: MineTable) -> void:
	Tr.set_language(language)
	Engine.max_fps = fps_cap
	DisplayServer.screen_set_keep_on(keep_awake)
	# на телефоне без вертикальной синхронизации ограничение FPS действительно работает (и на 90/120 Гц тоже);
	# на компьютере оставляем её включённой: нет разрывов кадров и лишнего нагрева
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED if OS.has_feature("mobile") else DisplayServer.VSYNC_ENABLED)
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	viewport.scaling_3d_scale = render_scale
	match quality:
		0:
			viewport.msaa_3d = Viewport.MSAA_DISABLED
			viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_HARD)
		1:
			viewport.msaa_3d = Viewport.MSAA_2X
			viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW)
		_:
			viewport.msaa_3d = Viewport.MSAA_4X
			viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH)
	# ручной выбор сглаживания перекрывает то, что выставило качество
	match antialiasing:
		1:
			viewport.msaa_3d = Viewport.MSAA_DISABLED
			viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
		2:
			viewport.msaa_3d = Viewport.MSAA_2X
			viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
		3:
			viewport.msaa_3d = Viewport.MSAA_4X
			viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
		4:
			viewport.msaa_3d = Viewport.MSAA_4X
			viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
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

