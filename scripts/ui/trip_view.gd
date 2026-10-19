class_name TripView
extends RefCounted
## Вкладка «Походы»: шахтёры в пути (несколько слотов), доска найма из трёх предложений разной редкости и «Мастерская»
## (исследования за монеты и время). Таймеры обновляет журнал через функции из updaters, кнопки шлют его сигналы.

## Редкость: серый → синий → фиолетовый → золотой (рамка, плашка, подпись).
const RARITY_COLORS := [Color(0.62, 0.66, 0.62), Color(0.42, 0.66, 0.95), Color(0.72, 0.52, 0.92), Color(0.98, 0.72, 0.25)]
const TRIP_ICONS := ["trip_scout", "trip_descent", "trip_deep"]


## Строит вкладку; в updaters добавляет функции, которые раз в полсекунды обновляют таймеры.
static func build(parent: VBoxContainer, state: ClickerState, journal: JournalScreen, updaters: Array) -> void:
	state.ensure_offers()
	var note := UiTheme.make_text("Шахтёры уходят в поход и возвращаются с добычей. Чем реже поход, тем богаче добыча; новые слоты открываются в глубоких зонах.", 24, UiTheme.MUTE)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(note)

	_section(parent, Tr.t("В пути") + "  %d / %d" % [state.expeditions.size(), state.expedition_slots()])
	if state.expeditions.is_empty():
		parent.add_child(UiTheme.make_text("Все шахтёры дома: выберите поход на доске ниже.", 24, UiTheme.MUTE))
	for slot in state.expeditions.size():
		_trip_card(parent, state, journal, slot, updaters)
	if state.expedition_soonest_running() >= 0:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", UiTheme.SPACE_M)
		parent.add_child(row)
		var cost := state.shop_cost("expedition_skip")
		var finish := _gem_key(Tr.t("Закончить за %d") % cost, 26)
		finish.disabled = state.diamonds < cost
		finish.pressed.connect(func() -> void: journal.purchase.emit("expedition_skip"))
		row.add_child(finish)
		var ad := UiTheme.make_key(Tr.t("−1 ч (реклама)"), 26, "felt")
		ad.custom_minimum_size = Vector2(240, 80)
		ad.pressed.connect(func() -> void: journal.ad_requested.emit("expedition"))
		row.add_child(ad)
	var next_slot := _next_slot_text(state)
	if next_slot != "":
		parent.add_child(UiTheme.make_text(next_slot, 22, UiTheme.MUTE))

	_section(parent, Tr.t("Доска найма"))
	var free := state.expeditions.size() < state.expedition_slots()
	for offer in state.expedition_offers.size():
		_offer_card(parent, state, journal, offer, free)
	var reroll_row := HBoxContainer.new()
	reroll_row.add_theme_constant_override("separation", UiTheme.SPACE_M)
	parent.add_child(reroll_row)
	var reroll_cost := state.shop_cost("trip_offers")
	var reroll := _gem_key(Tr.t("Новые предложения за %d") % reroll_cost, 24)
	reroll.disabled = state.diamonds < reroll_cost
	reroll.pressed.connect(func() -> void: journal.purchase.emit("trip_offers"))
	reroll_row.add_child(reroll)
	var wait := state.ad_remaining("trip_offers")
	var ad_offers := UiTheme.make_key(Tr.t("Реклама") if wait <= 0.0 else JournalScreen._format_time(wait), 24, "felt")
	ad_offers.custom_minimum_size = Vector2(200, 80)
	ad_offers.disabled = wait > 0.0
	ad_offers.pressed.connect(func() -> void: journal.ad_requested.emit("trip_offers"))
	reroll_row.add_child(ad_offers)

	_build_workshop(parent, state, journal, updaters)


static func _next_slot_text(state: ClickerState) -> String:
	var slots := state.expedition_slots()
	if slots >= 3:
		return ""
	var zone := 2 if slots == 1 else 4
	return Tr.t("Следующий слот откроется в зоне «%s»") % Tr.t(str(Biomes.LIST[zone]["name"]))


static func _section(parent: VBoxContainer, title: String) -> void:
	parent.add_child(UiTheme.hairline())
	parent.add_child(UiTheme.make_label(title, 38, UiTheme.BRASS, true))


## Кнопка с ценой в алмазах (значок слева от текста).
static func _gem_key(text: String, size: int) -> Button:
	var key := UiTheme.make_key(text, size, "brass")
	key.custom_minimum_size.y = 80
	key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for style_name in ["normal", "hover", "focus", "pressed", "disabled"]:
		(key.get_theme_stylebox(style_name) as StyleBoxFlat).content_margin_left = 56
	var gem := Icon.new().setup("gem", Color(0.55, 0.86, 0.90), 32)
	gem.outline = UiTheme.DARK_ON_BRASS
	gem.position = Vector2(18, 22)
	key.add_child(gem)
	return key


static func _rarity_card(parent: VBoxContainer, rarity: int) -> PanelContainer:
	var card := PanelContainer.new()
	var edge: Color = RARITY_COLORS[rarity]
	card.add_theme_stylebox_override("panel", UiTheme.panel_style(UiTheme.SURFACE, edge if rarity > 0 else UiTheme.LINE_STRONG, 2 if rarity < 3 else 4, 18, 14))
	parent.add_child(card)
	return card


## Плашка редкости: цветной прямоугольник с подписью.
static func rarity_badge(rarity: int) -> PanelContainer:
	var badge := PanelContainer.new()
	var color: Color = RARITY_COLORS[rarity]
	badge.add_theme_stylebox_override("panel", UiTheme.panel_style(color.darkened(0.55), color, 2, 8, 4))
	badge.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var label := UiTheme.make_label(Tr.t(str(Retention.RARITIES[rarity]["name"])), 20, color.lightened(0.2))
	badge.add_child(label)
	return badge


static func _trip_icon(type: int, rarity: int) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(96, 96)
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var glow := Panel.new()
	glow.add_theme_stylebox_override("panel", UiTheme.panel_style((RARITY_COLORS[rarity] as Color).darkened(0.7), Color(0, 0, 0, 0), 0, 12, 0))
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(glow)
	var icon := Icon.new().setup(TRIP_ICONS[mini(type, TRIP_ICONS.size() - 1)], Color.WHITE, 96)
	holder.add_child(icon)
	return holder


static func _trip_card(parent: VBoxContainer, state: ClickerState, journal: JournalScreen, slot: int, updaters: Array) -> void:
	var trip: Dictionary = state.expeditions[slot]
	var type := int(trip["type"])
	var rarity := int(trip["rarity"])
	var card := _rarity_card(parent, rarity)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	card.add_child(row)
	row.add_child(_trip_icon(type, rarity))
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 4)
	row.add_child(texts)
	texts.add_child(UiTheme.make_label(Tr.t(str(Retention.EXPEDITIONS[type]["name"])), 32, UiTheme.TEXT))
	texts.add_child(rarity_badge(rarity))
	if state.expedition_ready(slot):
		Juice.add_brackets(card)
		texts.add_child(UiTheme.make_label("Шахтёры вернулись!", 26, UiTheme.BRASS))
		var claim := UiTheme.make_key("Забрать", 28, "brass")
		claim.custom_minimum_size = Vector2(190, 84)
		claim.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		claim.pressed.connect(func() -> void: journal.expedition_claim.emit(slot))
		row.add_child(claim)
		return
	var timer := UiTheme.make_label("", 26, UiTheme.BRASS)
	texts.add_child(timer)
	var bar := UiTheme.make_bar(0.0, RARITY_COLORS[rarity], 10)
	texts.add_child(bar)
	var update := func() -> void:
		if slot >= state.expeditions.size():
			return
		var remaining := state.expedition_remaining(slot)
		timer.text = Tr.t("Осталось: %s") % JournalScreen._format_time(remaining)
		bar.value = 1.0 - remaining / state.expedition_total_seconds(type)
	update.call()
	updaters.append(update)


static func _offer_card(parent: VBoxContainer, state: ClickerState, journal: JournalScreen, offer: int, free: bool) -> void:
	var entry: Dictionary = state.expedition_offers[offer]
	var type := int(entry["type"])
	var rarity := int(entry["rarity"])
	var data: Dictionary = Retention.EXPEDITIONS[type]
	var card := _rarity_card(parent, rarity)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	card.add_child(row)
	row.add_child(_trip_icon(type, rarity))
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 2)
	row.add_child(texts)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", UiTheme.SPACE_S)
	texts.add_child(head)
	head.add_child(UiTheme.make_label(Tr.t(str(data["name"])), 30, UiTheme.TEXT))
	head.add_child(rarity_badge(rarity))
	var detail := UiTheme.make_text(_hours_text(float(data["hours"]) * state.expedition_time_factor()) + " · " + loot_text(state, type, rarity), 22, UiTheme.MUTE)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texts.add_child(detail)
	var go := UiTheme.make_key("Отправить", 26, "brass")
	go.custom_minimum_size = Vector2(190, 80)
	go.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	go.disabled = not free
	go.pressed.connect(func() -> void: journal.expedition_start.emit(offer))
	row.add_child(go)


static func _hours_text(hours: float) -> String:
	if is_equal_approx(hours, roundf(hours)):
		return Tr.t("%d ч") % int(hours)
	return Tr.t("%s ч") % ("%.1f" % hours)


## Ожидаемая добыча (как её выдаст claim_expedition): монеты, алмазы, находки, жетоны.
static func loot_text(state: ClickerState, type: int, rarity: int) -> String:
	var data: Dictionary = Retention.EXPEDITIONS[type]
	var info: Dictionary = Retention.RARITIES[rarity]
	var bonus := state.expedition_bonus() * float(info["loot"])
	var coins := maxf(100.0, state.income_per_second() * float(data["hours"]) * 3600.0 * float(data["coins"])) * bonus
	var gems := int(round(float(data["diamonds"]) * bonus)) + int(info["diamonds"])
	return Tr.fmt("≈%s монет · %d алмазов · %d находок", [NumberFormat.short(coins), gems, int(round(float(data["finds"]) * bonus))]) \
			+ " · " + Tr.fmt("%d жетонов", [int(info["tickets"])])


# ---------- Мастерская ----------

static func _build_workshop(parent: VBoxContainer, state: ClickerState, journal: JournalScreen, updaters: Array) -> void:
	var workshop := state.workshop
	var now := ClickerState.now()
	_section(parent, Tr.t("Мастерская"))
	var note := UiTheme.make_text("Исследования стоят монеты и время, а уровни остаются навсегда, даже после «Новой шахты» и новой планеты. Одно исследование за раз.", 24, UiTheme.MUTE)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(note)
	if workshop.busy():
		var entry := Workshop.entry_of(workshop.active)
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", UiTheme.panel_style(UiTheme.FELT, UiTheme.BRASS, 2, 18, 14))
		parent.add_child(card)
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", UiTheme.SPACE_S)
		card.add_child(column)
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 16)
		column.add_child(head)
		head.add_child(Icon.new().setup(str(entry["icon"]), Color.WHITE, 72))
		var name_label := UiTheme.make_label(Tr.t(str(entry["name"])) + "  " + Tr.t("ур. %d") % (workshop.level(workshop.active) + 1), 30, UiTheme.TEXT, true)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		head.add_child(name_label)
		if workshop.ready(now):
			var claim := UiTheme.make_key("Готово: забрать", 30, "brass")
			claim.custom_minimum_size.y = 88
			claim.pressed.connect(func() -> void: journal.research_claim.emit())
			Juice.add_brackets(claim)
			column.add_child(claim)
		else:
			var timer := UiTheme.make_label("", 26, UiTheme.BRASS)
			column.add_child(timer)
			var bar := UiTheme.make_bar(0.0, UiTheme.BRASS, 12)
			column.add_child(bar)
			var update := func() -> void:
				var remaining := workshop.remaining(ClickerState.now())
				timer.text = Tr.t("Осталось: %s") % JournalScreen._format_time(remaining)
				bar.value = 1.0 - remaining / maxf(1.0, workshop.active_total)
			update.call()
			updaters.append(update)
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", UiTheme.SPACE_M)
			column.add_child(row)
			var cost := state.shop_cost("research_skip")
			var finish := _gem_key(Tr.t("Закончить за %d") % cost, 26)
			finish.disabled = state.diamonds < cost
			finish.pressed.connect(func() -> void: journal.purchase.emit("research_skip"))
			row.add_child(finish)
			var wait := state.ad_remaining("research")
			var ad := UiTheme.make_key(Tr.t("−30 мин (реклама)") if wait <= 0.0 else JournalScreen._format_time(wait), 24, "felt")
			ad.custom_minimum_size = Vector2(260, 80)
			ad.disabled = wait > 0.0
			ad.pressed.connect(func() -> void: journal.ad_requested.emit("research"))
			row.add_child(ad)
	for entry in Workshop.RESEARCH:
		_research_card(parent, state, journal, entry)


static func _research_card(parent: VBoxContainer, state: ClickerState, journal: JournalScreen, entry: Dictionary) -> void:
	var workshop := state.workshop
	var id := str(entry["id"])
	var level := workshop.level(id)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiTheme.panel_style(UiTheme.SURFACE, UiTheme.LINE, 1, 18, 14))
	parent.add_child(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	card.add_child(row)
	var icon := Icon.new().setup(str(entry["icon"]), Color.WHITE, 72)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 2)
	row.add_child(texts)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", UiTheme.SPACE_M)
	texts.add_child(head)
	var name_label := UiTheme.make_label(Tr.t(str(entry["name"])), 28, UiTheme.TEXT)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_label)
	head.add_child(UiTheme.pip_row(level, int(entry["max"]), 14))
	var detail := UiTheme.make_text(Tr.t(str(entry["text"])), 22, UiTheme.MUTE)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texts.add_child(detail)
	if workshop.maxed(id):
		row.add_child(Icon.new().setup("check", UiTheme.BRASS, 40))
		return
	var cost := workshop.cost_for(id, state)
	texts.add_child(UiTheme.make_label(NumberFormat.short(cost) + " · " + _duration(workshop.seconds_for(id)), 22, UiTheme.BRASS))
	var go := UiTheme.make_key("Изучить", 26, "brass")
	go.custom_minimum_size = Vector2(170, 76)
	go.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	go.disabled = workshop.busy() or state.coins < cost
	go.pressed.connect(func() -> void: journal.research_start.emit(id))
	row.add_child(go)


static func _duration(seconds: float) -> String:
	if seconds < 3600.0:
		return Tr.t("%d мин") % int(round(seconds / 60.0))
	return _hours_text(seconds / 3600.0)
