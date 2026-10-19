class_name TowerView
extends Control
## «Башня испытаний»: во вкладке «Забой» — столб этажей (пройденные снизу, текущий подсвечен), сила удара, попытки,
## награда и кнопка штурма. Сам бой — окно поверх игры (TowerFight).

const FLOOR_H := 64.0
const SHOWN := 7                            # этажей в столбе


## Карточка башни в журнале.
static func build(parent: VBoxContainer, state: ClickerState, journal: JournalScreen) -> void:
	var tower := state.tower
	var note := UiTheme.make_text("Глыбу этажа нужно разбить касаниями за 20 секунд. Каждый 5-й этаж — хранитель. Сила удара растёт от питомцев (всех собранных), исследований и глубины.", 22, UiTheme.MUTE)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(note)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiTheme.SPACE_M)
	parent.add_child(row)
	var column_view := TowerView.new()
	column_view.state = state
	column_view.custom_minimum_size = Vector2(300, FLOOR_H * SHOWN + 40.0)
	row.add_child(column_view)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", UiTheme.SPACE_S)
	row.add_child(info)
	var floor_number := tower.next_floor
	var boss := Tower.is_boss(floor_number)
	info.add_child(UiTheme.make_label(Tr.t("Этаж %d") % floor_number, 44, UiTheme.BRASS if boss else UiTheme.TEXT, true))
	if boss:
		info.add_child(UiTheme.make_label(Tr.t("Хранитель этажа"), 26, Color(0.98, 0.72, 0.25), true))
	var hp := Tower.hp_for(floor_number)
	var damage := Tower.tap_damage(state)
	info.add_child(UiTheme.make_text(Tr.t("Прочность: %s") % NumberFormat.short(hp), 24, UiTheme.TEXT))
	info.add_child(UiTheme.make_text(Tr.t("Удар: %s") % NumberFormat.short(damage), 24, UiTheme.TEXT))
	var taps := ceili(hp / damage)
	var taps_label := UiTheme.make_text(Tr.t("Нужно касаний: ≈%d") % taps, 24, UiTheme.MUTE if taps <= 120 else Color(0.85, 0.36, 0.30))
	taps_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(taps_label)
	var reward := UiTheme.make_text(Tr.t("Награда") + ": " + reward_preview(floor_number, state), 22, UiTheme.BRASS)
	reward.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(reward)
	info.add_child(UiTheme.make_text(Tr.t("Рекорд: этаж %d") % tower.best, 22, UiTheme.MUTE))
	var attempts := tower.attempts_left()
	parent.add_child(UiTheme.make_label(Tr.t("Попыток сегодня: %d") % attempts, 28, UiTheme.TEXT))
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", UiTheme.SPACE_M)
	parent.add_child(buttons)
	var go := UiTheme.make_key(Tr.t("Штурмовать"), 32, "ember")
	go.custom_minimum_size.y = 96
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	go.disabled = attempts <= 0
	go.pressed.connect(func() -> void: journal.tower_fight.emit())
	buttons.add_child(go)
	var wait := state.ad_remaining("tower")
	var ad := UiTheme.make_key(Tr.t("+1 попытка (реклама)") if wait <= 0.0 else JournalScreen._format_time(wait), 22, "felt")
	JournalScreen.track_ad(ad, "tower", Tr.t("+1 попытка (реклама)"))
	ad.custom_minimum_size = Vector2(300, 96)
	ad.disabled = wait > 0.0
	ad.pressed.connect(func() -> void: journal.ad_requested.emit("tower"))
	buttons.add_child(ad)
	parent.add_child(UiTheme.make_text("Победа не тратит попытку, поражение тратит. Три попытки каждый день.", 20, UiTheme.MUTE))


static func reward_preview(floor_number: int, state: ClickerState) -> String:
	var parts: Array[String] = [Tr.fmt("+%d алмазов", [2 + floori(floor_number / 5.0)])]
	parts.append(Tr.t("Приманки: %d") % (3 if Tower.is_boss(floor_number) else 1))
	if Tower.is_boss(floor_number):
		parts.append(Tr.t("Золотой сундук ×%d") % 1)
	if floor_number % 25 == 0:
		parts.append(Tr.t("Очко навыков +1"))
	return ", ".join(parts)


# ---------- Столб этажей (рисуется в _draw) ----------

var state: ClickerState


func _draw() -> void:
	var next := state.tower.next_floor
	var top_floor := maxi(next + 2, SHOWN)        # текущий этаж третий сверху; внизу столба всегда первый этаж или ниже
	var font := UiTheme.text_font(true)
	for i in SHOWN:
		var number := top_floor - i
		if number < 1:
			continue
		var rect := Rect2(Vector2(40.0, 20.0 + i * FLOOR_H), Vector2(size.x - 80.0, FLOOR_H - 6.0))
		var boss := Tower.is_boss(number)
		var fill := Color(0.13, 0.15, 0.14)
		var edge := UiTheme.LINE_STRONG
		if number < next:
			fill = Color(0.18, 0.24, 0.17)              # пройден
		if number == next:
			fill = Color(0.24, 0.19, 0.08)
			edge = UiTheme.BRASS
		if boss:
			edge = Color(0.98, 0.72, 0.25) if number >= next else edge
		draw_style_box(UiTheme.panel_style(fill, edge, 4 if number == next else 2, 8, 0), rect)
		var text := str(number)
		var color := UiTheme.TEXT if number >= next else UiTheme.MUTE
		draw_string(font, rect.position + Vector2(18.0, FLOOR_H * 0.62), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, color)
		if boss and number >= next:
			var crown := Icon.sprite_for("px_crown")
			if crown != null:
				draw_texture_rect(crown, Rect2(rect.position + Vector2(rect.size.x - 56.0, 6.0), Vector2(44, 44)), false)
		if number < next:
			var check := Icon.sprite_for("check")
			if check != null:
				draw_texture_rect(check, Rect2(rect.position + Vector2(rect.size.x - 52.0, 10.0), Vector2(36, 36)), false)
	# основание и крыша
	draw_rect(Rect2(Vector2(28.0, size.y - 22.0), Vector2(size.x - 56.0, 10.0)), Color(0.36, 0.23, 0.13))
