class_name JournalScreen
extends Control
## Журнал: вкладка «Руда» (алмазы, лавка за них, коллекция четырёх руд с вехами, бонус за полный набор)
## и вкладка «Навыки» (дерево из трёх веток, очки даёт «Новая шахта»).

signal back_pressed
signal purchase(item: String)
signal skill_purchase(branch: String)
signal respec_requested
signal expedition_start(index: int)
signal expedition_claim
signal achievement_claim(id: String)
signal achievement_claim_all
signal ad_requested(placement: String)
signal meta_purchase(id: String)
signal planet_requested

const ORE_NAMES := {1: "Медь", 2: "Железо", 3: "Золото", 4: "Алмаз"}
const ORE_ICONS := {1: "rock", 2: "rock", 3: "rock", 4: "gem"}
const ORE_COLORS := {1: Color(0.78, 0.47, 0.30), 2: Color(0.50, 0.58, 0.68), 3: Color(0.92, 0.74, 0.32),
		4: Color(0.55, 0.86, 0.90)}

var state: ClickerState
var _content: VBoxContainer
var _tab := 0                       # 0 — руда, 1 — навыки, 2 — походы, 3 — награды
var _expedition_label: Label
var _expedition_bar: ProgressBar
var _was_ready := false
var _tick := 0.0


func setup(p_state: ClickerState) -> void:
	state = p_state
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(UiTheme.make_background())
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 18)
	scroll.add_child(_content)
	visible = false


func open() -> void:
	var was_visible := visible
	visible = true
	if not was_visible:
		UiTheme.fade_in(self)
	rebuild()


func rebuild() -> void:
	for child in _content.get_children():
		child.queue_free()
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	_content.add_child(header)
	var back := UiTheme.icon_button("back", UiTheme.TEXT, 40, Vector2(84, 84))
	back.pressed.connect(func() -> void:
			visible = false
			back_pressed.emit())
	header.add_child(back)
	var title := UiTheme.make_label("Журнал", 60, UiTheme.TEXT, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 12)
	_content.add_child(tabs)
	var tab_names := ["Руда", "Навыки", "Походы", "Награды", "Планета"]
	for i in tab_names.size():
		var tab_button := UiTheme.make_key(tab_names[i], 24, "felt" if i == _tab else "dark")
		if i != _tab:
			# неактивные вкладки светлее общего «приглушённого» цвета: иначе подписи плохо читаются на телефоне
			for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
				tab_button.add_theme_color_override(color_name, UiTheme.TEXT.darkened(0.25))
		tab_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab_button.custom_minimum_size.y = 80
		tab_button.pressed.connect(func() -> void:
				_tab = i
				rebuild())
		tabs.add_child(tab_button)
	_expedition_label = null
	_expedition_bar = null
	if _tab == 1:
		_build_skills()
		return
	if _tab == 2:
		_build_expeditions()
		return
	if _tab == 3:
		_build_achievements()
		return
	if _tab == 4:
		_build_planet()
		return

	# алмазы и лавка
	var wallet := HBoxContainer.new()
	wallet.add_theme_constant_override("separation", 14)
	_content.add_child(wallet)
	wallet.add_child(Icon.new().setup("gem", ORE_COLORS[4], 48))
	wallet.add_child(UiTheme.make_label(str(state.diamonds), 56, UiTheme.TEXT, true))
	var wallet_note := UiTheme.make_label("Алмазы выпадают из редких находок: чем глубже, тем чаще.", 24, UiTheme.MUTE)
	wallet_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	wallet_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wallet.add_child(wallet_note)

	_section("Бесплатно")
	_ad_card("diamonds", Tr.t("Алмазы: +%d") % state.ad_diamonds(), "за короткую рекламу")
	_ad_card("rush", "Золотая лихорадка", "×7 к добыче на 5 минут за рекламу")
	_ad_card("dynamite", Tr.t("Динамит ×2"), "за короткую рекламу")

	_section("Лавка алмазов")
	_shop_card("rush", "Золотая лихорадка", "×7 к добыче на 5 минут")
	_shop_card("dynamite", "Динамит ×3", "три динамита на склад")
	_shop_card("golden", "Золотая глыба", "вызвать сейчас: коснитесь её, чтобы получить лихорадку ×7 на 15 секунд")
	_shop_card("boss", "Вызвать хранителя", "награда монетами, находки и алмазы")
	_shop_card("expedition_skip", "Закончить поход", "шахтёры вернутся сразу")
	_shop_card("skill_point", "Очко навыков", "цена растёт с каждой покупкой")

	_section("Породы за алмазы")
	for style_index in ClickerState.STYLE_PRICES:
		_shop_card("style_%d" % style_index, Settings.STYLE_NAMES[style_index], "новый цвет камней")

	_section("Коллекция")
	for ore in ClickerState.ORES:
		_ore_card(ore)
	var full := state.full_set_level()
	var set_text := Tr.t("Все руды на уровне %d: ×%.2f") % [full, 1.0 + ClickerState.FULL_SET_STEP * full]
	_content.add_child(UiTheme.make_label(Tr.t("Полный набор") + "  ·  " + set_text, 28, UiTheme.BRASS))
	_content.add_child(UiTheme.make_label(Tr.t("Коллекция даёт навсегда: ×%.2f") % state.collection_multiplier(), 28, UiTheme.MUTE))


func _process(delta: float) -> void:
	if not visible or _tab != 2:
		return
	_tick += delta
	if _tick < 0.5:
		return
	_tick = 0.0
	var finished := state.expedition_ready()
	if finished != _was_ready:
		rebuild()
		return
	if _expedition_label != null and state.expedition_active() and not finished:
		var remaining := state.expedition_remaining()
		_expedition_label.text = Tr.t("Осталось: %s") % _format_time(remaining)
		var total: float = float(Retention.EXPEDITIONS[state.expedition_type]["hours"]) * 3600.0
		_expedition_bar.value = 1.0 - remaining / total


static func _format_time(seconds: float) -> String:
	var total := int(ceilf(seconds))
	var hours := int(total / 3600.0)
	var minutes := int((total % 3600) / 60.0)
	if hours > 0:
		return "%d:%02d:%02d" % [hours, minutes, total % 60]
	return "%d:%02d" % [minutes, total % 60]


## Ожидаемая добыча похода (с бонусом мета-улучшения «Снаряжение походов»), как её выдаст claim_expedition().
func _expedition_loot(data: Dictionary) -> String:
	var bonus := 1.0 + 0.5 * int(state.meta["expedition"])
	var coins := maxf(100.0, state.income_per_second() * float(data["hours"]) * 3600.0 * float(data["coins"])) * bonus
	return Tr.t("≈%s монет · %d алмазов · %d находок") % [NumberFormat.short(coins),
			int(round(float(data["diamonds"]) * bonus)), int(round(float(data["finds"]) * bonus))]


## Вкладка «Походы»: один поход за раз; идёт и по реальному времени (в том числе когда игра закрыта).
func _build_expeditions() -> void:
	var note := UiTheme.make_label("Шахтёры уходят в поход и возвращаются с добычей: монеты, алмазы и находки в журнал.", 26, UiTheme.MUTE)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(note)
	_was_ready = state.expedition_ready()
	if state.expedition_active():
		var data: Dictionary = Retention.EXPEDITIONS[state.expedition_type]
		var card := _card()
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 10)
		card.add_child(column)
		column.add_child(UiTheme.make_label(data["name"], 38, UiTheme.TEXT, true))
		if _was_ready:
			column.add_child(UiTheme.make_label("Шахтёры вернулись!", 30, UiTheme.BRASS))
			var claim := UiTheme.make_key("Забрать добычу", 34, "brass")
			claim.custom_minimum_size.y = 90
			claim.pressed.connect(func() -> void:
					expedition_claim.emit()
					rebuild())
			column.add_child(claim)
		else:
			_expedition_label = UiTheme.make_label("", 30, UiTheme.BRASS)
			column.add_child(_expedition_label)
			_expedition_bar = UiTheme.make_bar(0.0, UiTheme.BRASS, 12)
			column.add_child(_expedition_bar)
			var loot := UiTheme.make_label(Tr.t("Ожидается") + ": " + _expedition_loot(data), 26, UiTheme.MUTE)
			loot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			column.add_child(loot)
			var finish_now := UiTheme.make_key(Tr.t("Закончить за %d") % state.shop_cost("expedition_skip"), 28, "brass")
			finish_now.custom_minimum_size.y = 76
			# цена в алмазах: голубой алмаз с тёмным контуром сразу после числа (текст по центру кнопки)
			var finish_gem := Icon.new().setup("gem", ORE_COLORS[4], 36)
			finish_gem.outline = UiTheme.DARK_ON_BRASS
			finish_now.add_child(finish_gem)
			finish_now.resized.connect(func() -> void:
					var font := finish_now.get_theme_font("font")
					var text_width := font.get_string_size(finish_now.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
					finish_gem.position = Vector2(finish_now.size.x * 0.5 + text_width * 0.5 + 10.0, (finish_now.size.y - 7.0 - 36.0) * 0.5 + 2.0))
			finish_now.disabled = state.diamonds < state.shop_cost("expedition_skip")
			finish_now.pressed.connect(func() -> void:
					purchase.emit("expedition_skip")
					rebuild())
			column.add_child(finish_now)
			var skip := UiTheme.make_key("Минус 1 час (реклама)", 28, "felt")
			skip.custom_minimum_size.y = 76
			skip.pressed.connect(func() -> void: ad_requested.emit("expedition"))
			column.add_child(skip)
			_tick = 1.0
		return
	for i in Retention.EXPEDITIONS.size():
		var data: Dictionary = Retention.EXPEDITIONS[i]
		var card := _card()
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		card.add_child(row)
		var texts := VBoxContainer.new()
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.add_theme_constant_override("separation", 0)
		row.add_child(texts)
		texts.add_child(UiTheme.make_label(data["name"], 34, UiTheme.TEXT))
		var detail := UiTheme.make_label(Tr.t("%d ч") % int(data["hours"]) + " · " + _expedition_loot(data), 24, UiTheme.MUTE)
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		texts.add_child(detail)
		var go := UiTheme.make_key("Отправить", 28, "brass")
		go.custom_minimum_size = Vector2(200, 80)
		go.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		go.pressed.connect(func() -> void:
				expedition_start.emit(i)
				rebuild())
		row.add_child(go)


## Вкладка «Награды»: достижения со шкалой и наградой; косметика (породы) открывается ими.
func _build_achievements() -> void:
	var waiting := state.claimable_achievements()
	if waiting > 1:
		var all := UiTheme.make_key(Tr.t("Забрать всё") + " (%d)" % waiting, 32, "brass")
		all.custom_minimum_size.y = 84
		all.pressed.connect(func() -> void:
				achievement_claim_all.emit()
				rebuild())
		_content.add_child(all)
	for achievement in Retention.ACHIEVEMENTS:
		var done := state.achievement_done(achievement)
		var claimed := state.achievement_claimed(achievement)
		var card := _card()
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		card.add_child(row)
		var texts := VBoxContainer.new()
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.add_theme_constant_override("separation", 2)
		row.add_child(texts)
		texts.add_child(UiTheme.make_label(achievement["name"], 32, UiTheme.TEXT if done else UiTheme.MUTE))
		var info := UiTheme.make_label(achievement["text"], 24, UiTheme.MUTE)
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		texts.add_child(info)
		texts.add_child(UiTheme.make_label(_reward_text(achievement["reward"]), 24, UiTheme.BRASS))
		if not done:
			var goal := float(achievement["goal"])
			texts.add_child(UiTheme.make_bar(state.achievement_value(achievement) / goal, UiTheme.BRASS_DIM, 8))
		if claimed:
			row.add_child(Icon.new().setup("check", UiTheme.BRASS, 40))
		elif done:
			var claim := UiTheme.make_key("Забрать", 26, "brass")
			claim.custom_minimum_size = Vector2(170, 76)
			claim.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			var id: String = achievement["id"]
			claim.pressed.connect(func() -> void:
					achievement_claim.emit(id)
					rebuild())
			row.add_child(claim)
		else:
			row.add_child(Icon.new().setup("lock", UiTheme.MUTE, 36))


## Вкладка «Планета»: второй слой. Звёздная пыль, «Новая планета» (после ядра) и мета-улучшения за пыль.
func _build_planet() -> void:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	_content.add_child(head)
	head.add_child(Icon.new().setup("spark", Color(0.55, 0.86, 0.90), 48))
	head.add_child(UiTheme.make_label(str(state.stardust), 56, UiTheme.TEXT, true))
	var planet_label := UiTheme.make_label(Tr.t("Планета") + ": " + Tr.t(Biomes.planet_name(state.planet)), 30, UiTheme.MUTE)
	planet_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	planet_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(planet_label)

	var feature := UiTheme.make_label(Tr.t("Особенность планеты") + ": " + Tr.t(Biomes.planet_mod_text(state.planet)), 24, UiTheme.BRASS)
	feature.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(feature)

	var card := _card()
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	card.add_child(column)
	column.add_child(UiTheme.make_label("Новая планета", 38, UiTheme.TEXT, true))
	var can_fly := state.planet_ready()
	var info := UiTheme.make_label(
			Tr.t("Лететь на следующую планету можно после ядра. Сбросятся монеты, улучшения, жилы и глубина; останутся навыки, коллекция, алмазы, достижения и мета-улучшения. Пороги зон на новой планете в %d раз выше.") % int(Biomes.PLANET_SCALE),
			24, UiTheme.MUTE)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(info)
	if can_fly:
		column.add_child(UiTheme.make_label(Tr.t("Звёздной пыли за перелёт: +%d") % state.planet_gain(), 30, UiTheme.BRASS))
		var go := UiTheme.make_key("Новая планета", 34, "brass")
		go.custom_minimum_size.y = 90
		go.pressed.connect(func() -> void: planet_requested.emit())
		column.add_child(go)
	else:
		var depth := Biomes.depth_m(state.total_earned, state.planet_scale())
		column.add_child(UiTheme.make_label(Tr.t("До ядра: глубина %d м из %d м") % [depth, int(Biomes.LIST[Biomes.CORE]["depth"])], 28, UiTheme.MUTE))
		column.add_child(UiTheme.make_bar(float(depth) / float(Biomes.LIST[Biomes.CORE]["depth"]), UiTheme.BRASS_DIM, 10))

	_section("Мета-улучшения")
	for entry in ClickerState.META:
		_meta_card(entry)


func _meta_card(entry: Dictionary) -> void:
	var id: String = entry["id"]
	var costs: Array = entry["costs"]
	var level := state.meta_level(id)
	var card := _card()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	card.add_child(row)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 2)
	row.add_child(texts)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	texts.add_child(head)
	var name_label := UiTheme.make_label(entry["name"], 32, UiTheme.TEXT)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_label)
	head.add_child(UiTheme.pip_row(level, costs.size(), 14))
	var detail := UiTheme.make_label(entry["text"], 24, UiTheme.MUTE)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texts.add_child(detail)
	if level >= costs.size():
		row.add_child(Icon.new().setup("check", UiTheme.BRASS, 40))
		return
	var cost := int(costs[level])
	var buy := UiTheme.make_key(str(cost), 32, "brass")
	buy.custom_minimum_size = Vector2(170, 76)
	buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for style_name in ["normal", "hover", "focus", "pressed", "disabled"]:
		(buy.get_theme_stylebox(style_name) as StyleBoxFlat).content_margin_left = 54
	var dust := Icon.new().setup("spark", UiTheme.DARK_ON_BRASS, 30)
	dust.position = Vector2(20, 20)
	buy.add_child(dust)
	buy.disabled = state.stardust < cost
	buy.pressed.connect(func() -> void:
			meta_purchase.emit(id)
			rebuild())
	row.add_child(buy)


func _reward_text(reward: Dictionary) -> String:
	var parts: Array[String] = []
	if reward.has("diamonds"):
		parts.append(Tr.t("+%d алмазов") % int(reward["diamonds"]))
	if reward.has("points"):
		parts.append(Tr.t("+%d очков навыков") % int(reward["points"]))
	if reward.has("dynamite"):
		parts.append(Tr.t("+%d динамита") % int(reward["dynamite"]))
	if reward.has("style"):
		parts.append(Tr.t("порода: %s") % Tr.t(str(Settings.STYLE_NAMES[int(reward["style"])])))
	return ", ".join(parts)


func _card() -> PanelContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiTheme.panel_style(UiTheme.SURFACE, UiTheme.LINE, 1, 18, 14))
	_content.add_child(card)
	return card


## Вкладка «Навыки»: очки, три ветки по четыре навыка, сброс за алмазы.
func _build_skills() -> void:
	var points := HBoxContainer.new()
	points.add_theme_constant_override("separation", 14)
	_content.add_child(points)
	points.add_child(Icon.new().setup("star", UiTheme.BRASS, 48))
	points.add_child(UiTheme.make_label(str(state.skill_points), 56, UiTheme.TEXT, true))
	var note := UiTheme.make_label("Очки навыков даёт «Новая шахта». Навыки в ветке открываются по порядку.", 24, UiTheme.MUTE)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	points.add_child(note)
	for branch in Skills.BRANCHES:
		_branch_card(branch)
	var respec_cost := state.shop_cost("respec")
	var respec := UiTheme.make_key(Tr.t("Сбросить навыки") + "  " + str(respec_cost), 28, "dark")
	respec.custom_minimum_size.y = 84
	respec.disabled = state.diamonds < respec_cost or state.skill_points == _total_points()
	respec.pressed.connect(func() -> void:
			respec_requested.emit()
			rebuild())
	_content.add_child(respec)


func _total_points() -> int:
	var spent := 0
	for branch in state.skills:
		for level in state.skill_level(branch):
			spent += int(Skills.costs_of(str(branch))[level])
	return state.skill_points + spent


func _branch_card(branch: Dictionary) -> void:
	var id: String = branch["id"]
	var level := state.skill_level(id)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiTheme.panel_style(UiTheme.SURFACE, UiTheme.LINE, 1, 18, 14))
	_content.add_child(card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	card.add_child(column)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	column.add_child(head)
	head.add_child(Icon.new().setup(branch["icon"], UiTheme.BRASS, 44))
	var name_label := UiTheme.make_label(branch["name"], 38, UiTheme.TEXT, true)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_label)
	head.add_child(UiTheme.pip_row(level, Skills.MAX_LEVEL, 14))
	var nodes: Array = branch["nodes"]
	for i in nodes.size():
		column.add_child(UiTheme.hairline())
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		column.add_child(row)
		var texts := VBoxContainer.new()
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.add_theme_constant_override("separation", 0)
		row.add_child(texts)
		var owned := i < level
		texts.add_child(UiTheme.make_label(nodes[i][0], 30, UiTheme.TEXT if i <= level else UiTheme.MUTE))
		var detail := UiTheme.make_label(nodes[i][1], 24, UiTheme.BRASS if owned else UiTheme.MUTE)
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		texts.add_child(detail)
		if owned:
			row.add_child(Icon.new().setup("check", UiTheme.BRASS, 40))
		elif i == level:
			var cost := int(Skills.costs_of(id)[i])
			var buy := UiTheme.make_key(str(cost), 32, "brass")
			buy.custom_minimum_size = Vector2(150, 72)
			buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			for style_name in ["normal", "hover", "focus", "pressed", "disabled"]:
				(buy.get_theme_stylebox(style_name) as StyleBoxFlat).content_margin_left = 54
			var star := Icon.new().setup("star", UiTheme.DARK_ON_BRASS, 30)
			star.position = Vector2(20, 20)
			buy.add_child(star)
			buy.disabled = state.skill_points < cost
			buy.pressed.connect(func() -> void:
					skill_purchase.emit(id)
					rebuild())
			row.add_child(buy)
		else:
			row.add_child(Icon.new().setup("lock", UiTheme.MUTE, 36))


func _section(title: String) -> void:
	_content.add_child(UiTheme.hairline())
	_content.add_child(UiTheme.make_label(title, 38, UiTheme.BRASS, true))


## Карточка «смотреть рекламу за награду»; пока идёт пауза, показывает оставшееся время.
func _ad_card(placement: String, title: String, detail: String) -> void:
	var card := _card()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	card.add_child(row)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 0)
	texts.add_child(UiTheme.make_label(title, 32, UiTheme.TEXT))
	var info := UiTheme.make_label(detail, 26, UiTheme.MUTE)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texts.add_child(info)
	row.add_child(texts)
	var wait := state.ad_remaining(placement)
	var go := UiTheme.make_key(Tr.t("Смотреть") if wait <= 0.0 else _format_time(wait), 30, "felt")
	go.custom_minimum_size = Vector2(190, 84)
	go.disabled = wait > 0.0
	go.pressed.connect(func() -> void:
			ad_requested.emit(placement))
	row.add_child(go)


func _shop_card(item: String, title: String, detail: String) -> void:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiTheme.panel_style(UiTheme.SURFACE, UiTheme.LINE, 1, 18, 14))
	_content.add_child(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	card.add_child(row)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.add_theme_constant_override("separation", 0)
	texts.add_child(UiTheme.make_label(title, 32, UiTheme.TEXT))
	texts.add_child(UiTheme.make_label(detail, 26, UiTheme.MUTE))
	row.add_child(texts)
	var cost := state.shop_cost(item)
	var buy := UiTheme.make_key(str(cost), 34, "brass")
	buy.custom_minimum_size = Vector2(190, 84)
	for style_name in ["normal", "hover", "focus", "pressed", "disabled"]:
		(buy.get_theme_stylebox(style_name) as StyleBoxFlat).content_margin_left = 58
	var gem := Icon.new().setup("gem", ORE_COLORS[4], 34)
	gem.outline = UiTheme.DARK_ON_BRASS
	gem.position = Vector2(22, 22)
	buy.add_child(gem)
	buy.disabled = state.diamonds < cost or not state.shop_available(item)
	if item == "rush" and state.rush_remaining() > 0.0:
		buy.text = _format_time(state.rush_remaining())
	elif item.begins_with("style_") and state.styles_bought.has(int(item.substr(6))):
		buy.text = Tr.t("Куплено")
	buy.pressed.connect(func() -> void:
			purchase.emit(item)
			rebuild())
	row.add_child(buy)


func _ore_card(ore: int) -> void:
	var count: int = state.finds[ore]
	var level := state.find_level(ore)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiTheme.panel_style(UiTheme.SURFACE, UiTheme.LINE, 1, 18, 14))
	_content.add_child(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	card.add_child(row)
	var badge := PanelContainer.new()
	badge.add_theme_stylebox_override("panel", UiTheme.panel_style(UiTheme.BG, UiTheme.LINE_STRONG, 1, 14, 10))
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.add_child(Icon.new().setup(ORE_ICONS[ore], ORE_COLORS[ore], 48))
	row.add_child(badge)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 4)
	row.add_child(texts)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	texts.add_child(head)
	var name_label := UiTheme.make_label(ORE_NAMES[ore], 32, UiTheme.TEXT)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_label)
	head.add_child(UiTheme.pip_row(level, ClickerState.MILESTONES.size(), 14))
	var next_need := 0
	var previous := 0
	for need in ClickerState.MILESTONES:
		if count < int(need):
			next_need = int(need)
			break
		previous = int(need)
	if next_need > 0:
		texts.add_child(UiTheme.make_label(Tr.t("Найдено: %d из %d") % [count, next_need], 26, UiTheme.MUTE))
		texts.add_child(UiTheme.make_bar(float(count - previous) / float(next_need - previous), ORE_COLORS[ore], 10))
	else:
		texts.add_child(UiTheme.make_label(Tr.t("Найдено: %d (максимум)") % count, 26, UiTheme.MUTE))
