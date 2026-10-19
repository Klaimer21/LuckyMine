class_name DungeonsView
extends RefCounted
## «Подземелья дня» во вкладке «Забой»: правило дня, три подземелья с ключами, следующим уровнем, наградой,
## кнопками «В бой» и «Зачистка». Сигналы журнала dungeon_fight / dungeon_sweep.

static func reward_text(reward: Dictionary) -> String:
	var parts: Array[String] = []
	if reward.has("minutes"):
		parts.append(Tr.t("%d мин дохода") % int(reward["minutes"]))
	if reward.has("picks"):
		parts.append(Tr.t("Кирки +%d") % int(reward["picks"]))
	if reward.has("diamonds"):
		parts.append(Tr.fmt("+%d алмазов", [int(reward["diamonds"])]))
	if reward.has("baits"):
		parts.append(Tr.t("Приманки: %d") % int(reward["baits"]))
	if reward.has("shards"):
		parts.append(Tr.t("Осколки артефактов: %d") % int(reward["shards"]))
	return ", ".join(parts)


static func build(parent: VBoxContainer, state: ClickerState, journal: JournalScreen) -> void:
	var dungeons := state.dungeons
	var rule := Dungeons.rule()
	var banner := PanelContainer.new()
	banner.add_theme_stylebox_override("panel", UiTheme.panel_style(UiTheme.FELT, UiTheme.BRASS, 2, 18, 14))
	parent.add_child(banner)
	var column := VBoxContainer.new()
	banner.add_child(column)
	column.add_child(UiTheme.make_label(Tr.t("Правило дня") + ": " + Tr.t(str(rule["name"])), 30, UiTheme.BRASS, true))
	column.add_child(UiTheme.make_text(Tr.t(str(rule["text"])), 24, UiTheme.TEXT))
	journal.intro(parent, "dungeons", "Два ключа в день на каждое подземелье. Победа открывает следующий уровень, поражение ключ не тратит. Пройденный уровень можно зачистить без боя.", 22)
	parent.add_child(UiTheme.make_text(Tr.t("Удар: %s") % NumberFormat.short(Tower.tap_damage(state)), 24, UiTheme.TEXT))
	for entry in Dungeons.LIST:
		var id := str(entry["id"])
		var keys := dungeons.keys_left(id)
		var level := dungeons.next_level(id)
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", UiTheme.panel_style(UiTheme.SURFACE, UiTheme.LINE_STRONG, 2, 18, 14))
		parent.add_child(card)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", UiTheme.SPACE_S)
		card.add_child(box)
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", UiTheme.SPACE_M)
		box.add_child(head)
		head.add_child(Icon.new().setup(str(entry["icon"]), Color.WHITE, 72))
		var titles := VBoxContainer.new()
		titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(titles)
		titles.add_child(UiTheme.make_label(Tr.t(str(entry["name"])), 30, UiTheme.TEXT, true))
		titles.add_child(UiTheme.make_text(Tr.t(str(entry["text"])), 22, UiTheme.MUTE))
		head.add_child(UiTheme.make_label(Tr.t("Ключи: %d") % keys, 26, UiTheme.BRASS if keys > 0 else UiTheme.MUTE, true))
		var hp := Dungeons.hp_for(level)
		var taps := ceili(hp / Tower.tap_damage(state))
		box.add_child(UiTheme.make_text(Tr.t("Уровень %d") % level + " · " + Tr.t("Прочность: %s") % NumberFormat.short(hp) + " · " + Tr.t("Нужно касаний: ≈%d") % taps, 22, UiTheme.MUTE if taps <= 120 else Color(0.85, 0.36, 0.30)))
		var reward := UiTheme.make_text(Tr.t("Награда") + ": " + reward_text(Dungeons.reward_for(id, level)), 22, UiTheme.BRASS)
		reward.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(reward)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", UiTheme.SPACE_M)
		box.add_child(row)
		var fight := UiTheme.make_key(Tr.t("В бой"), 28, "ember")
		fight.custom_minimum_size.y = 84
		fight.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fight.disabled = keys <= 0
		fight.pressed.connect(func() -> void: journal.dungeon_fight.emit(id))
		row.add_child(fight)
		var best := int(dungeons.best.get(id, 0))
		var sweep := UiTheme.make_key(Tr.t("Зачистка ур. %d") % best if best > 0 else Tr.t("Зачистка"), 24, "brass")
		sweep.custom_minimum_size = Vector2(300, 84)
		sweep.disabled = keys <= 0 or best <= 0
		sweep.pressed.connect(func() -> void: journal.dungeon_sweep.emit(id))
		row.add_child(sweep)
	var wait := state.ad_remaining("dungeon")
	var ad := UiTheme.make_key(Tr.t("+1 ключ в каждое (реклама)") if wait <= 0.0 else JournalScreen._format_time(wait), 24, "felt")
	JournalScreen.track_ad(ad, "dungeon", Tr.t("+1 ключ в каждое (реклама)"))
	ad.custom_minimum_size.y = 84
	ad.disabled = wait > 0.0
	ad.pressed.connect(func() -> void: journal.ad_requested.emit("dungeon"))
	parent.add_child(ad)
