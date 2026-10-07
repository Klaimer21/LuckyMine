class_name ProgressionDialogs
extends RefCounted
## Окна сброса забега: «Новая шахта» (жилы), «Новая планета» и конец шахты у Ядра. Меняют состояние и стол;
## то, чем владеет интерфейс (счётчик, цвет пыли, пометки пересчёта), main делает в обратных вызовах.

var host: Control
var state: ClickerState

var _table: FieldTable
var _sfx: Sfx
var _music: Music
var _settings: Settings
var _toast: Callable
var _on_prestige_done: Callable    # забег сброшен («Новая шахта»): main обнуляет счётчик и пометки
var _on_planet_arrived: Callable   # прилетели на новую планету: main сбрасывает зону, цвет пыли, закрывает журнал


func setup(host_node: Control, game_state: ClickerState, mine_table: FieldTable, sound: Sfx, music_player: Music,
		game_settings: Settings, show_toast: Callable, on_prestige_done: Callable, on_planet_arrived: Callable) -> ProgressionDialogs:
	host = host_node
	state = game_state
	_table = mine_table
	_sfx = sound
	_music = music_player
	_settings = game_settings
	_toast = show_toast
	_on_prestige_done = on_prestige_done
	_on_planet_arrived = on_planet_arrived
	return self


func show_prestige() -> void:
	var pending := state.pending_veins()
	if pending < 1:
		return
	var modal := Modal.new()
	var cheer := Companion.portrait(240.0, "cheer")
	if cheer != null:
		cheer.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		modal.body.add_child(cheer)
	modal.body.add_child(UiTheme.make_label("Новая шахта", 54, UiTheme.TEXT, true))
	var after := 1.0 + state.vein_step() * (state.veins + pending)
	var gain_text := UiTheme.make_label(Tr.fmt("Вы получите %d жил: доход ×%.1f → ×%.1f", [pending, state.vein_multiplier(), after]), 32, UiTheme.BRASS)
	gain_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal.body.add_child(gain_text)
	var reset_text := UiTheme.make_label("Сбросятся монеты и улучшения. Останутся глубина, зона и жилы.", 28, UiTheme.MUTE)
	reset_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal.body.add_child(reset_text)
	if not state.prestige_recommended():
		var wait_text := UiTheme.make_label(Tr.fmt("Лучше подождать: стоит от +%d жил.", [maxi(ClickerState.PRESTIGE_GOOD_MIN, int(0.7 * state.veins))]), 26, UiTheme.MUTE)
		wait_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		modal.body.add_child(wait_text)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiTheme.SPACE_M)
	modal.body.add_child(row)
	var cancel := UiTheme.make_button("Отмена", false, 32)
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(modal.close)
	row.add_child(cancel)
	var ok := UiTheme.make_button("Начать заново", true, 32)
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ok.pressed.connect(func() -> void:
			ok.disabled = true               # двойной тап не должен сбросить забег дважды
			var gained := state.prestige()
			_table.clear_field()
			_on_prestige_done.call()
			state.save()
			_toast.call(Tr.fmt("Новая шахта! +%d жил", [gained]) + "  ·  " + Tr.t("очков навыков: %d") % state.skill_points)
			_sfx.play("gong", -3.0)
			_settings.vibrate(60)
			_table.celebrate()
			modal.close())
	row.add_child(ok)
	host.add_child(modal)


func show_planet() -> void:
	if not state.planet_ready():
		return
	var modal := Modal.new()
	modal.body.add_child(UiTheme.make_label("Новая планета", 54, UiTheme.TEXT, true))
	var world := Biomes.planet_picture(state.planet + 1, 192.0)
	if world != null:
		world.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		modal.body.add_child(world)
	var next_name := Tr.t(Biomes.planet_name(state.planet + 1))
	var gain_text := UiTheme.make_label(Tr.t("Вы полетите на планету: %s. Звёздной пыли: +%d") % [next_name, state.planet_gain()], 32, UiTheme.BRASS)
	gain_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal.body.add_child(gain_text)
	var perk_text := UiTheme.make_label(Tr.t("Особенность планеты") + ": " + Tr.t(Biomes.planet_mod_text(state.planet + 1)), 26, UiTheme.TEXT)
	perk_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal.body.add_child(perk_text)
	var reset_text := UiTheme.make_label("Сбросятся монеты, улучшения, жилы и глубина. Останутся навыки, коллекция, алмазы, достижения и мета-улучшения.", 28, UiTheme.MUTE)
	reset_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal.body.add_child(reset_text)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiTheme.SPACE_M)
	modal.body.add_child(row)
	var cancel := UiTheme.make_button("Отмена", false, 32)
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(modal.close)
	row.add_child(cancel)
	var ok := UiTheme.make_button("Лететь", true, 32)
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ok.pressed.connect(func() -> void:
			ok.disabled = true               # двойной тап не должен лететь дважды
			var gained := state.new_planet()
			if gained <= 0:
				return
			_table.clear_field()
			_table.set_planet(state.planet)
			_table.set_biome(0)
			_table.celebrate()
			_music.play_zone(0)
			_on_planet_arrived.call()
			state.save()
			_toast.call(Tr.t(Biomes.planet_name(state.planet)) + ": " + Tr.t("звёздной пыли +%d") % gained)
			_sfx.play("gong", -2.0)
			_settings.vibrate(80)
			modal.close())
	row.add_child(ok)
	host.add_child(modal)


func show_ending() -> void:
	var modal := Modal.new()
	modal.body.add_child(UiTheme.make_label("Вы достигли Ядра", 54, UiTheme.TEXT, true))
	var text := UiTheme.make_label(Tr.t("Глубина %d м. Глубже шахты нет: дальше только бесконечный спуск. Откройте журнал → «Планета»: «Новая планета» даст звёздную пыль и новые улучшения.") % Biomes.depth_m(state.total_earned, state.planet_scale()), 30, UiTheme.MUTE)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal.body.add_child(text)
	var go_on := UiTheme.make_button("Продолжить", true, 34)
	go_on.pressed.connect(modal.close)
	modal.body.add_child(go_on)
	host.add_child(modal)
