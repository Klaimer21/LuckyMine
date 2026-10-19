class_name PassView
extends RefCounted
## «Пропуск шахтёра» во вкладке «Награды»: уровень и опыт сезона, золотой пропуск, 30 уровней в две дорожки
## (бесплатная слева, золотая справа). Кнопки шлют сигналы журнала pass_*.

const REWARD_ICONS := {"picks": "px_pickaxe", "coins": "px_coins", "tokens": "rail_token", "diamonds": "gem", "chest": "chest",
		"golden": "chest", "points": "px_scroll"}
const GOLD := Color(0.98, 0.78, 0.30)


static func reward_text(reward: Dictionary) -> String:
	var parts: Array[String] = []
	for key in reward:
		var value := int(reward[key])
		match str(key):
			"picks":
				parts.append(Tr.t("Кирки +%d") % value)
			"coins":
				parts.append(Tr.t("%d мин дохода") % value)
			"tokens":
				parts.append(Tr.t("Жетоны +%d") % value)
			"diamonds":
				parts.append(Tr.fmt("+%d алмазов", [value]))
			"chest":
				parts.append(Tr.t("Сундук удачи ×%d") % value)
			"golden":
				parts.append(Tr.t("Золотой сундук ×%d") % value)
			"points":
				parts.append(Tr.fmt("+%d очков навыков", [value]))
	return ", ".join(parts)


static func build(parent: VBoxContainer, state: ClickerState, journal: JournalScreen) -> void:
	var pass_data := state.miner_pass
	var level := pass_data.level()
	var xp := pass_data.current_xp()
	var head := PanelContainer.new()
	head.add_theme_stylebox_override("panel", UiTheme.panel_style(UiTheme.FELT, GOLD if pass_data.has_premium() else UiTheme.BRASS_DIM, 2, 18, 16))
	parent.add_child(head)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", UiTheme.SPACE_S)
	head.add_child(column)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", UiTheme.SPACE_M)
	column.add_child(title_row)
	title_row.add_child(Icon.new().setup("px_helmet", Color.WHITE, 72))
	var title := UiTheme.make_label(Tr.t("Пропуск шахтёра"), 36, UiTheme.TEXT, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	title_row.add_child(UiTheme.make_label(Tr.t("ур. %d") % level, 40, UiTheme.BRASS, true))
	var days := ceili(MinerPass.season_left() / 86400.0)
	column.add_child(UiTheme.make_text(Tr.t("Сезон %d · осталось %d дн.") % [MinerPass.season_number(), days], 24, UiTheme.MUTE))
	var note := UiTheme.make_text("Опыт — это очки наряда дня. Каждые 200 очков — уровень и награда; золотая дорожка богаче в 3–4 раза. После 30-го уровня каждые 200 очков дают сундук удачи.", 22, UiTheme.MUTE)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(note)
	var in_level := xp - level * MinerPass.XP_PER_LEVEL if level < MinerPass.LEVELS else (xp - MinerPass.LEVELS * MinerPass.XP_PER_LEVEL) % MinerPass.XP_PER_LEVEL
	column.add_child(UiTheme.make_bar(float(in_level) / MinerPass.XP_PER_LEVEL, UiTheme.BRASS, 14))
	column.add_child(UiTheme.make_label("%d / %d" % [in_level, MinerPass.XP_PER_LEVEL], 22, UiTheme.MUTE))
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", UiTheme.SPACE_M)
	column.add_child(actions)
	var waiting := pass_data.claimable_count()
	var claim_all := UiTheme.make_key(Tr.t("Забрать всё") + (" (%d)" % waiting if waiting > 0 else ""), 26, "brass")
	claim_all.custom_minimum_size.y = 84
	claim_all.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	claim_all.disabled = waiting == 0
	claim_all.pressed.connect(func() -> void: journal.pass_claim_all.emit())
	actions.add_child(claim_all)
	if not pass_data.has_premium():
		var buy := UiTheme.make_key(Tr.t("Золотой пропуск"), 26, "ember")
		buy.custom_minimum_size = Vector2(320, 84)
		buy.pressed.connect(func() -> void: journal.pass_buy.emit())
		actions.add_child(buy)

	var legend := HBoxContainer.new()
	legend.add_theme_constant_override("separation", 8)
	parent.add_child(legend)
	var spacer := Control.new()
	spacer.custom_minimum_size.x = 76
	legend.add_child(spacer)
	for entry in [[Tr.t("Бесплатно"), UiTheme.MUTE], [Tr.t("Золотой"), GOLD]]:
		var label := UiTheme.make_label(str(entry[0]), 24, entry[1], true)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		legend.add_child(label)
	for lvl in range(1, MinerPass.LEVELS + 1):
		_level_row(parent, state, journal, lvl, level)


static func _level_row(parent: VBoxContainer, state: ClickerState, journal: JournalScreen, lvl: int, level: int) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var badge := PanelContainer.new()
	badge.custom_minimum_size = Vector2(76, 0)
	badge.add_theme_stylebox_override("panel", UiTheme.panel_style(UiTheme.BRASS if lvl <= level else UiTheme.SURFACE, UiTheme.LINE_STRONG, 2, 10, 4))
	var number := UiTheme.make_label(str(lvl), 28, UiTheme.DARK_ON_BRASS if lvl <= level else UiTheme.MUTE, true)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(number)
	row.add_child(badge)
	for track in ["free", "gold"]:
		row.add_child(_reward_cell(state, journal, track, lvl, level))


static func _reward_cell(state: ClickerState, journal: JournalScreen, track: String, lvl: int, level: int) -> Control:
	var pass_data := state.miner_pass
	var reward := MinerPass.reward(track, lvl)
	var ready := pass_data.claimable(track, lvl)
	var taken := pass_data.claimed(track, lvl)
	var locked := track == "gold" and not pass_data.has_premium()
	var edge: Color = GOLD if track == "gold" else UiTheme.LINE_STRONG
	if ready:
		edge = UiTheme.BRASS
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0, 104)
	var fill := UiTheme.FELT if ready else UiTheme.SURFACE
	var style := UiTheme.panel_style(fill, edge, 4 if ready else 2, 14, 8)
	for state_name in ["normal", "hover", "pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(state_name, style)
	button.disabled = not ready
	if ready:
		Juice.add_brackets(button)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 10
	row.offset_right = -10
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(row)
	var first_key := str(reward.keys()[0])
	var alpha := 0.35 if taken or locked or lvl > level else 1.0
	var icon := Icon.new().setup(str(REWARD_ICONS.get(first_key, "chest")), Color(1, 1, 1, alpha), 64)
	row.add_child(icon)
	var text := UiTheme.make_text(reward_text(reward), 20, UiTheme.TEXT if alpha > 0.5 else UiTheme.MUTE)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)
	if taken:
		row.add_child(Icon.new().setup("check", UiTheme.BRASS, 32))
	elif locked:
		row.add_child(Icon.new().setup("lock", UiTheme.MUTE, 28))
	button.pressed.connect(func() -> void: journal.pass_claim.emit(track, lvl))
	return button
