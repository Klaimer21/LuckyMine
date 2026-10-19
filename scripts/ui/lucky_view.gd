class_name LuckyView
extends RefCounted
## Окно «Сундука удачи»: три карты на выбор (цвет рамки — редкость), переброс за алмазы один раз, «Позже» оставляет выбор.

const ICONS := {"coins": "px_coins", "gems": "gem", "picks": "px_pickaxe", "tokens": "rail_token", "dynamite": "px_bomb",
		"frenzy": "px_potion", "gamble": "px_crown", "point": "px_scroll"}
const CURSE_COLOR := Color(0.85, 0.36, 0.30)


## Описание карты: что даст (с числами по редкости).
static func card_text(card: Dictionary, state: ClickerState) -> String:
	var value := Lucky.value_of(card)
	var zone := Biomes.index_for(state.total_earned, state.planet_scale())
	match str(card["kind"]):
		"coins":
			return Tr.t("%d минут дохода сразу") % value
		"gems":
			return Tr.fmt("+%d алмазов", [value + zone])
		"picks":
			return Tr.t("Кирки +%d") % value
		"tokens":
			return Tr.t("Жетоны узкоколейки +%d") % value
		"dynamite":
			return Tr.fmt("+%d динамита", [value])
		"frenzy":
			return Tr.t("Доход ×2 на %s") % _seconds_text(value)
		"gamble":
			return Tr.t("%d минут дохода сразу") % value + "\n" + Tr.t("но доход ×0.5 на %s") % _seconds_text(int(Lucky.CURSE_SECONDS[int(card["rarity"])]))
		"point":
			return Tr.t("Очко навыков +1")
	return ""


static func _seconds_text(seconds: int) -> String:
	if seconds >= 60 and seconds % 60 == 0:
		return Tr.t("%d мин") % int(seconds / 60.0)
	return Tr.t("%d с") % seconds


## Показывает окно выбора (сундук уже открыт: state.lucky.offer не пуст).
static func show(host: Control, state: ClickerState, rewards: Rewards) -> Modal:
	var modal := Modal.new()
	var lucky := state.lucky
	var head := HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_theme_constant_override("separation", UiTheme.SPACE_M)
	modal.body.add_child(head)
	head.add_child(Icon.new().setup("chest", Color.WHITE, 96))
	head.add_child(UiTheme.make_label("Золотой сундук" if lucky.offer_golden else "Сундук удачи", 46, UiTheme.BRASS if lucky.offer_golden else UiTheme.TEXT, true))
	modal.body.add_child(UiTheme.make_text("Выберите одну карту.", 26, UiTheme.MUTE))
	for index in lucky.offer.size():
		var card: Dictionary = lucky.offer[index]
		var rarity := int(card["rarity"])
		var color: Color = TripView.RARITY_COLORS[rarity]
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 150)
		button.focus_mode = Control.FOCUS_NONE
		var normal := UiTheme.panel_style(color.darkened(0.78), color, 4 if rarity >= 2 else 2, 16, 14)
		var hover := UiTheme.panel_style(color.darkened(0.62), color.lightened(0.2), 4, 16, 14)
		for state_name in ["normal", "focus", "disabled"]:
			button.add_theme_stylebox_override(state_name, normal)
		button.add_theme_stylebox_override("hover", hover)
		button.add_theme_stylebox_override("pressed", hover)
		var row := HBoxContainer.new()
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		row.offset_left = 18
		row.offset_right = -18
		row.add_theme_constant_override("separation", 18)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(row)
		var icon := Icon.new().setup(str(ICONS.get(str(card["kind"]), "chest")), Color.WHITE, 96)
		row.add_child(icon)
		var texts := VBoxContainer.new()
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.alignment = BoxContainer.ALIGNMENT_CENTER
		texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(texts)
		var title_row := HBoxContainer.new()
		title_row.add_theme_constant_override("separation", UiTheme.SPACE_S)
		title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		texts.add_child(title_row)
		var title := UiTheme.make_label(Tr.t(str(Lucky.KINDS[str(card["kind"])]["name"])), 30, UiTheme.TEXT)
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title_row.add_child(title)
		var badge := TripView.rarity_badge(rarity)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title_row.add_child(badge)
		var info := UiTheme.make_text(card_text(card, state), 24, CURSE_COLOR if str(card["kind"]) == "gamble" else UiTheme.MUTE)
		info.mouse_filter = Control.MOUSE_FILTER_IGNORE
		texts.add_child(info)
		button.pressed.connect(func() -> void:
				modal.close()
				rewards.on_lucky_take(index))
		modal.body.add_child(button)
		# карты появляются по очереди
		button.modulate.a = 0.0
		var tween := button.create_tween()
		tween.tween_interval(0.12 * index + 0.1)
		tween.tween_property(button, "modulate:a", 1.0, 0.18)
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", UiTheme.SPACE_M)
	modal.body.add_child(row2)
	var cost := lucky.reroll_cost(state)
	var reroll := UiTheme.make_key(Tr.t("Перебросить за %d") % cost if not lucky.rerolled else Tr.t("Уже переброшено"), 26, "dark")
	reroll.custom_minimum_size.y = 84
	reroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reroll.disabled = lucky.rerolled or state.diamonds < cost
	reroll.pressed.connect(func() -> void:
			modal.close()
			rewards.on_lucky_reroll())
	row2.add_child(reroll)
	var later := UiTheme.make_key("Позже", 26, "felt")
	later.custom_minimum_size = Vector2(200, 84)
	later.pressed.connect(modal.close)
	row2.add_child(later)
	host.add_child(modal)
	return modal
