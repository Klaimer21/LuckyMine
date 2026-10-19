class_name QuarryView
extends RefCounted
## Части журнала для quarry.gd: вкладка «Забой» (поле глыб под кирку), «Старьёвщик» в лавке, «Наряд дня» в наградах.
## Кнопки только сообщают журналу (его сигналы quarry_*), награды выдаёт Rewards.

const CELL := 168                     # сторона клетки забоя (5 клеток во всю ширину экрана)
## Значок и цвет рамки содержимого открытой клетки: цвет — «редкость» (от простого к ценному).
const LOOT_LOOK := {
	"": ["", Color(0, 0, 0, 0)],
	"coins": ["coin", Color(0.55, 0.74, 0.40)],
	"finds": ["px_bag", Color(0.45, 0.64, 0.86)],
	"diamonds": ["gem", Color(0.55, 0.86, 0.90)],
	"dynamite": ["dynamite", Color(0.72, 0.52, 0.88)],
	"chest": ["chest", Color(0.95, 0.78, 0.32)],
	"exit": ["px_rope", Color(0.95, 0.78, 0.32)],
}
const ROCK_TINTS := [Color(1, 1, 1), Color(0.78, 0.72, 0.66), Color(0.56, 0.50, 0.50)]     # значок глыбы по крепости 1, 2, 3
const ROCK_FILL := Color(0.16, 0.15, 0.14)
const JUNK_ICONS := {"baits": "pet_bait", "tickets": "rail_token", "picks": "px_pickaxe", "dynamite": "px_bomb", "finds": "ore_copper", "coins": "px_coins",
		"rush": "px_potion", "skill_point": "px_scroll"}
const ORE_ICONS := {1: "ore_copper", 2: "ore_iron", 3: "ore_gold"}
const ORE_NAMES := {1: "медь", 2: "железо", 3: "золото"}


## Шапка с кирками и таймером: таймер обновляет журнал (возвращается метка таймера).
static func build_dig(parent: VBoxContainer, state: ClickerState, journal: JournalScreen) -> Label:
	var quarry := state.quarry
	quarry.tick_picks(ClickerState.now())
	var note := UiTheme.make_text("Бейте глыбы кирками сверху вниз. Под ними добыча, а где-то лаз на ярус ниже: из открытой клетки рядом с ним тянет сквозняком.", 24, UiTheme.MUTE)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(note)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", UiTheme.SPACE_M)
	parent.add_child(head)
	head.add_child(Icon.new().setup("px_pickaxe", Color.WHITE, 72))
	head.add_child(UiTheme.make_label(str(quarry.picks), 56, UiTheme.TEXT, true))
	var timer := UiTheme.make_label("", 26, UiTheme.MUTE)
	timer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(timer)
	update_timer(timer, state)
	var layer_label := UiTheme.make_label(Tr.t("Ярус %d") % quarry.layer, 34, UiTheme.BRASS, true)
	head.add_child(layer_label)

	var grid := GridContainer.new()
	grid.columns = Quarry.COLS
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	parent.add_child(grid)
	for i in Quarry.COLS * Quarry.ROWS:
		grid.add_child(_cell(i, quarry, journal))

	if quarry.exit_open():
		var down := UiTheme.make_key(Tr.t("Спуститься на ярус %d") % (quarry.layer + 1), 32, "brass")
		down.custom_minimum_size.y = 96
		down.pressed.connect(func() -> void: journal.quarry_descend.emit())
		parent.add_child(down)
	var chest_in := Quarry.CHEST_EVERY - quarry.layer % Quarry.CHEST_EVERY
	parent.add_child(UiTheme.make_text(Tr.t("Сундук на ярусе %d · рекорд: ярус %d") % [quarry.layer + chest_in, quarry.best_layer], 24, UiTheme.MUTE))

	var ad_row := HBoxContainer.new()
	ad_row.add_theme_constant_override("separation", UiTheme.SPACE_M)
	parent.add_child(ad_row)
	var wait := state.ad_remaining("picks")
	var ad := UiTheme.make_key(Tr.t("Кирки +%d (реклама)") % Quarry.AD_PICKS if wait <= 0.0 else JournalScreen._format_time(wait), 28, "felt")
	ad.custom_minimum_size.y = 84
	ad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ad.disabled = wait > 0.0
	ad.pressed.connect(func() -> void: journal.ad_requested.emit("picks"))
	ad_row.add_child(ad)
	return timer


static func update_timer(timer: Label, state: ClickerState) -> void:
	var quarry := state.quarry
	quarry.tick_picks(ClickerState.now())
	if quarry.picks >= quarry.pick_cap:
		timer.text = Tr.t("склад полон")
	else:
		timer.text = Tr.t("+1 через %s") % JournalScreen._format_time(quarry.pick_wait(ClickerState.now()))


static func _cell(i: int, quarry: Quarry, journal: JournalScreen) -> Control:
	var button := Button.new()
	button.custom_minimum_size = Vector2(CELL, CELL)
	button.focus_mode = Control.FOCUS_NONE
	var opened := quarry.is_open(i)
	var diggable := quarry.can_dig(i)
	var style: StyleBoxFlat
	if opened:
		var look: Array = LOOT_LOOK.get(str(quarry.loot[i]), LOOT_LOOK[""])
		var edge: Color = look[1] if str(quarry.loot[i]) != "" else UiTheme.LINE
		style = UiTheme.panel_style(UiTheme.BG, edge, 2, 12, 8)
	else:
		style = UiTheme.panel_style(ROCK_FILL, UiTheme.BRASS if diggable and quarry.picks > 0 else Color(0.10, 0.09, 0.08), 4 if diggable else 2, 12, 8)
	for state_name in ["normal", "hover", "pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(state_name, style)
	button.disabled = opened or not diggable or quarry.picks <= 0
	if opened:
		var kind: String = LOOT_LOOK.get(str(quarry.loot[i]), LOOT_LOOK[""])[0]
		if kind != "":
			var icon := Icon.new().setup(kind, Color.WHITE, 96)
			icon.position = Vector2((CELL - 96) * 0.5, (CELL - 96) * 0.5)
			button.add_child(icon)
		if quarry.draft_at(i):
			# сквозняк от закрытого лаза рядом: искры в углу клетки (в пустой — крупно по центру)
			var side := 64 if kind == "" else 40
			var draft := Icon.new().setup("spark", UiTheme.BRASS, side)
			draft.position = Vector2((CELL - side) * 0.5, (CELL - side) * 0.5) if kind == "" else Vector2(8, 8)
			button.add_child(draft)
	else:
		var hardness := clampi(int(quarry.hp[i]), 1, 3)
		var rock := Icon.new().setup("rock", ROCK_TINTS[hardness - 1], 112)
		rock.position = Vector2((CELL - 112) * 0.5, (CELL - 112) * 0.5 - 10)
		button.add_child(rock)
		if not diggable:
			button.modulate = Color(1, 1, 1, 0.45)          # глубже открытых клеток: пока не достать
		# трещины: столько точек, сколько ударов осталось
		var pips := UiTheme.pip_row(int(quarry.hp[i]), int(quarry.hp[i]), 14)
		pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pips.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		pips.position.y -= 26
		button.add_child(pips)
		button.pressed.connect(func() -> void: journal.quarry_dig.emit(i))
	return button


## «Старьёвщик»: четыре товара дня со скидкой, обновление за алмазы или за рекламу.
static func build_junk(parent: VBoxContainer, state: ClickerState, journal: JournalScreen) -> void:
	var quarry := state.quarry
	quarry.junk_refresh_if_new_day()
	var note := UiTheme.make_text("Каждый день новый товар со скидкой. Каждую позицию можно купить один раз.", 24, UiTheme.MUTE)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(note)
	for slot in quarry.junk_slots.size():
		var entry: Dictionary = quarry.junk_slots[slot]
		var card := PanelContainer.new()
		var sold := bool(entry["sold"])
		card.add_theme_stylebox_override("panel", UiTheme.panel_style(UiTheme.SURFACE, UiTheme.LINE, 1, 18, 14))
		parent.add_child(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		card.add_child(row)
		var item := str(entry["item"])
		var icon_kind: String = ORE_ICONS[int(entry["ore"])] if item == "finds" else JUNK_ICONS.get(item, "px_bag")
		var icon := Icon.new().setup(icon_kind, Color(1, 1, 1, 0.35 if sold else 1.0), 96)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(icon)
		var texts := VBoxContainer.new()
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.alignment = BoxContainer.ALIGNMENT_CENTER
		texts.add_theme_constant_override("separation", 0)
		row.add_child(texts)
		texts.add_child(UiTheme.make_label(junk_title(entry), 30, UiTheme.MUTE if sold else UiTheme.TEXT))
		var discount := int(round(float(entry["discount"]) * 100.0))
		texts.add_child(UiTheme.make_label(Tr.t("Скидка %d%% · было %d") % [discount, quarry.junk_full_price(slot, state)], 24, UiTheme.BRASS))
		var price := quarry.junk_price(slot, state)
		var buy := UiTheme.make_key(Tr.t("Куплено") if sold else str(price), 34, "brass")
		buy.custom_minimum_size = Vector2(190, 84)
		buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if not sold:
			for style_name in ["normal", "hover", "focus", "pressed", "disabled"]:
				(buy.get_theme_stylebox(style_name) as StyleBoxFlat).content_margin_left = 58
			var gem := Icon.new().setup("gem", Color(0.55, 0.86, 0.90), 34)
			gem.outline = UiTheme.DARK_ON_BRASS
			gem.position = Vector2(22, 22)
			buy.add_child(gem)
		buy.disabled = sold or state.diamonds < price or (item == "dynamite" and state.dynamite_stock >= state.dynamite_max())
		buy.pressed.connect(func() -> void: journal.junk_buy.emit(slot))
		row.add_child(buy)
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", UiTheme.SPACE_M)
	parent.add_child(row2)
	var cost := quarry.junk_refresh_cost(state)
	var reroll := UiTheme.make_key(Tr.t("Новый товар за %d") % cost, 26, "dark")
	reroll.custom_minimum_size.y = 84
	reroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reroll.disabled = state.diamonds < cost
	reroll.pressed.connect(func() -> void: journal.junk_reroll.emit())
	row2.add_child(reroll)
	var wait := state.ad_remaining("junk")
	var ad := UiTheme.make_key(Tr.t("Реклама") if wait <= 0.0 else JournalScreen._format_time(wait), 26, "felt")
	ad.custom_minimum_size = Vector2(220, 84)
	ad.disabled = wait > 0.0
	ad.pressed.connect(func() -> void: journal.ad_requested.emit("junk"))
	row2.add_child(ad)


static func junk_title(entry: Dictionary) -> String:
	var count := int(entry["count"])
	match str(entry["item"]):
		"picks":
			return Tr.t("Кирки ×%d") % count
		"dynamite":
			return Tr.t("Динамит ×%d") % count
		"finds":
			return Tr.t("Руда: %s ×%d") % [Tr.t(str(ORE_NAMES[int(entry["ore"])])), count]
		"coins":
			return Tr.t("Монеты: %d ч дохода") % count
		"rush":
			return Tr.t("Золотая лихорадка")
		"skill_point":
			return Tr.t("Очко навыков")
		"tickets":
			return Tr.t("Жетоны узкоколейки ×%d") % count
		"baits":
			return Tr.t("Приманки ×%d") % count
	return str(entry["item"])


## «Наряд дня»: тема дня недели, шкала очков и три сундука.
static func build_rush(parent: VBoxContainer, state: ClickerState, journal: JournalScreen) -> void:
	var quarry := state.quarry
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiTheme.panel_style(UiTheme.FELT, UiTheme.BRASS_DIM, 2, 18, 14))
	parent.add_child(card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", UiTheme.SPACE_S)
	card.add_child(column)
	var theme := quarry.rush_theme()
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", UiTheme.SPACE_M)
	column.add_child(head)
	var title := UiTheme.make_label(Tr.t("Наряд дня") + ": " + Tr.t(str(theme["name"])), 32, UiTheme.TEXT, true)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var points := quarry.rush_now_points()
	head.add_child(UiTheme.make_label(str(points), 40, UiTheme.BRASS, true))
	var info := UiTheme.make_text(rush_hint(quarry), 24, UiTheme.MUTE)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(info)
	var goal_max := float(Quarry.RUSH_GOALS[Quarry.RUSH_GOALS.size() - 1])
	column.add_child(UiTheme.make_bar(minf(1.0, points / goal_max), UiTheme.BRASS, 14))
	var chests := HBoxContainer.new()
	chests.add_theme_constant_override("separation", UiTheme.SPACE_S)
	column.add_child(chests)
	for step in Quarry.RUSH_GOALS.size():
		var claimed := quarry.rush_claimed_step(step)
		var ready := quarry.rush_claimable(step)
		var label := Tr.t("Получено") if claimed else str(Quarry.RUSH_GOALS[step])
		var key := UiTheme.make_key(label, 26, "brass" if ready else "dark")
		key.custom_minimum_size.y = 96
		key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		key.disabled = not ready
		var chest := Icon.new().setup("chest", Color(1, 1, 1, 0.4 if claimed else 1.0), 40)
		chest.position = Vector2(12, 26)
		key.add_child(chest)
		key.pressed.connect(func() -> void: journal.rush_claim.emit(step))
		chests.add_child(key)


## Что сегодня даёт очки: действия темы ×3 (в воскресенье всё ×2).
static func rush_hint(quarry: Quarry) -> String:
	var names := {"pick": "удар кирки", "layer": "ярус забоя", "dynamite": "динамит", "golden": "золотая глыба",
			"boss": "хранитель", "expedition": "поход", "junk": "покупка у старьёвщика",
			"cart": "бросок на узкоколейке", "research": "исследование", "tower": "этаж башни"}
	var actions: Array = quarry.rush_theme()["actions"]
	if actions.is_empty():
		return Tr.t("Сегодня все действия дают очки ×%d.") % Quarry.RUSH_SUNDAY_FACTOR
	var parts: Array[String] = []
	for action in actions:
		parts.append(Tr.t(str(names[action])))
	return Tr.t("Очки за всё: кирка, динамит, золотые глыбы, хранители, походы, узкоколейка, исследования. Сегодня ×%d: %s.") % [Quarry.RUSH_THEME_FACTOR, ", ".join(parts)]
