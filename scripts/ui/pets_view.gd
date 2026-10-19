class_name PetsView
extends RefCounted
## Вкладка «Друзья»: призыв (бесплатно раз в день, приманки, алмазы), три слота, коллекция из 12 питомцев со звёздами.
## Карточка питомца ставит его в слот или убирает (сигнал pet_toggle), призыв — сигнал pet_summon.

const GRID_COLUMNS := 3


static func effect_text(id: String, state: ClickerState) -> String:
	var pet := Pets.data(id)
	var stars := maxi(1, state.pets.stars(id))
	var value := int(round(float(Pets.RARITY_STEP[int(pet["rarity"])]) * stars * 100.0))
	return Tr.t(str(pet["text"])) % value


static func build(parent: VBoxContainer, state: ClickerState, journal: JournalScreen) -> void:
	var pets := state.pets
	var head := PanelContainer.new()
	head.add_theme_stylebox_override("panel", UiTheme.panel_style(UiTheme.FELT, UiTheme.BRASS_DIM, 2, 18, 16))
	parent.add_child(head)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", UiTheme.SPACE_S)
	head.add_child(column)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", UiTheme.SPACE_M)
	column.add_child(top)
	top.add_child(Icon.new().setup("pet_bait", Color.WHITE, 72))
	var bait_label := UiTheme.make_label(Tr.t("Приманки: %d") % pets.baits, 30, UiTheme.TEXT, true)
	bait_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(bait_label)
	top.add_child(UiTheme.make_label(Tr.t("Призыв ур. %d") % pets.summon_level(), 28, UiTheme.BRASS, true))
	var to_next := pets.pulls_to_next_level()
	if to_next > 0:
		var level := pets.summon_level()
		var span := float(Pets.SUMMON_LEVELS[level] - Pets.SUMMON_LEVELS[level - 1])
		column.add_child(UiTheme.make_bar(1.0 - to_next / span, UiTheme.BRASS, 10))
		column.add_child(UiTheme.make_text(Tr.t("До следующего уровня призыва: %d") % to_next, 22, UiTheme.MUTE))
	column.add_child(UiTheme.make_text(odds_text(pets.summon_level()), 22, UiTheme.MUTE))
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", UiTheme.SPACE_S)
	column.add_child(buttons)
	if pets.free_available():
		var free := UiTheme.make_key(Tr.t("Бесплатно"), 26, "ember")
		free.custom_minimum_size = Vector2(0, 88)
		free.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		free.pressed.connect(func() -> void: journal.pet_summon.emit(1))
		buttons.add_child(free)
	for count in [1, 10]:
		var paid := maxi(0, count - pets.baits - (1 if pets.free_available() else 0))
		var cost := Pets.PULL10_COST if count == 10 and paid == 10 else Pets.PULL_COST * paid
		var label := Tr.t("Призыв ×%d") % count + ("  · %d" % cost if cost > 0 else "")
		var key := UiTheme.make_key(label, 24, "brass")
		key.custom_minimum_size = Vector2(0, 88)
		key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		key.disabled = state.diamonds < cost
		if cost > 0:
			for style_name in ["normal", "hover", "focus", "pressed", "disabled"]:
				(key.get_theme_stylebox(style_name) as StyleBoxFlat).content_margin_left = 48
			var gem := Icon.new().setup("gem", Color(0.55, 0.86, 0.90), 30)
			gem.outline = UiTheme.DARK_ON_BRASS
			gem.position = Vector2(14, 26)
			key.add_child(gem)
		key.pressed.connect(func() -> void: journal.pet_summon.emit(count))
		buttons.add_child(key)

	parent.add_child(UiTheme.make_label(Tr.t("В слотах") + "  %d / %d" % [pets.equipped.size(), Pets.SLOTS], 30, UiTheme.BRASS, true))
	var slots := HBoxContainer.new()
	slots.add_theme_constant_override("separation", UiTheme.SPACE_S)
	parent.add_child(slots)
	for i in Pets.SLOTS:
		var slot := PanelContainer.new()
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot.custom_minimum_size.y = 150
		var id := str(pets.equipped[i]) if i < pets.equipped.size() else ""
		var rarity := int(Pets.data(id)["rarity"]) if id != "" else 0
		slot.add_theme_stylebox_override("panel", UiTheme.panel_style(UiTheme.SURFACE, TripView.RARITY_COLORS[rarity] if id != "" else UiTheme.LINE, 2, 14, 8))
		var box := VBoxContainer.new()
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		slot.add_child(box)
		if id == "":
			var empty := UiTheme.make_label(Tr.t("пусто"), 24, UiTheme.MUTE)
			empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			box.add_child(empty)
		else:
			var icon := Icon.new().setup("pet_" + id, Color.WHITE, 88)
			icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			box.add_child(icon)
			var effect := UiTheme.make_text(effect_text(id, state), 18, UiTheme.BRASS)
			effect.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			box.add_child(effect)
		slots.add_child(slot)
	parent.add_child(UiTheme.make_text(Tr.t("Сила всех питомцев в башне: %d") % pets.power(), 22, UiTheme.MUTE))

	var grid := GridContainer.new()
	grid.columns = GRID_COLUMNS
	grid.add_theme_constant_override("h_separation", UiTheme.SPACE_S)
	grid.add_theme_constant_override("v_separation", UiTheme.SPACE_S)
	parent.add_child(grid)
	for pet in Pets.PETS:
		grid.add_child(_pet_card(str(pet["id"]), state, journal))


static func odds_text(level: int) -> String:
	var odds: Array = Pets.SUMMON_ODDS[level - 1]
	var parts: Array[String] = []
	for r in odds.size():
		if float(odds[r]) > 0.0:
			parts.append("%s %d%%" % [Tr.t(str(Retention.RARITIES[r]["name"])), int(odds[r])])
	return Tr.t("Шансы") + ": " + " · ".join(parts)


static func _pet_card(id: String, state: ClickerState, journal: JournalScreen) -> Control:
	var pets := state.pets
	var pet := Pets.data(id)
	var rarity := int(pet["rarity"])
	var owned := pets.owned(id)
	var on := pets.equipped.has(id)
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0, 300)
	var edge: Color = TripView.RARITY_COLORS[rarity]
	var fill := (edge as Color).darkened(0.72) if on else UiTheme.SURFACE
	var style := UiTheme.panel_style(fill, edge if owned else UiTheme.LINE, 4 if on else 2, 14, 8)
	for state_name in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state_name, style)
	button.disabled = not owned
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 8
	box.offset_right = -8
	box.offset_top = 8
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(box)
	var icon := Icon.new().setup("pet_" + id, Color(1, 1, 1, 1.0 if owned else 0.18), 112)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(icon)
	var name := UiTheme.make_text(Tr.t(str(pet["name"])) if owned else "???", 20, UiTheme.TEXT if owned else UiTheme.MUTE)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(name)
	var stars := UiTheme.pip_row(pets.stars(id), Pets.STAR_TOTALS.size(), 14)
	stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(stars)
	var effect := UiTheme.make_text(effect_text(id, state), 17, UiTheme.BRASS if owned else UiTheme.MUTE)
	effect.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	effect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(effect)
	if owned and pets.copies_to_next(id) > 0:
		var next := UiTheme.make_text(Tr.t("до звезды: %d") % pets.copies_to_next(id), 16, UiTheme.MUTE)
		next.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		next.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(next)
	if on:
		var mark := Icon.new().setup("check", UiTheme.BRASS, 32)
		mark.position = Vector2(8, 8)
		button.add_child(mark)
	button.pressed.connect(func() -> void: journal.pet_toggle.emit(id))
	return button


## Окно итога призыва: питомцы появляются по одному, новые подписаны.
static func show_summon(host: Control, state: ClickerState, ids: Array, new_ids: Dictionary) -> void:
	var modal := Modal.new()
	modal.body.add_child(UiTheme.make_label(Tr.t("Призыв") + " ×%d" % ids.size(), 46, UiTheme.TEXT, true))
	var grid := GridContainer.new()
	grid.columns = 5 if ids.size() > 3 else ids.size()
	grid.add_theme_constant_override("h_separation", UiTheme.SPACE_S)
	grid.add_theme_constant_override("v_separation", UiTheme.SPACE_S)
	modal.body.add_child(grid)
	for i in ids.size():
		var id := str(ids[i])
		var rarity := int(Pets.data(id)["rarity"])
		var cell := PanelContainer.new()
		cell.custom_minimum_size = Vector2(156, 190)
		cell.add_theme_stylebox_override("panel", UiTheme.panel_style((TripView.RARITY_COLORS[rarity] as Color).darkened(0.7), TripView.RARITY_COLORS[rarity], 4 if rarity >= 2 else 2, 12, 6))
		var box := VBoxContainer.new()
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		cell.add_child(box)
		var icon := Icon.new().setup("pet_" + id, Color.WHITE, 96)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(icon)
		if new_ids.has(id) and int(new_ids[id]) == i:
			var tag := UiTheme.make_label(Tr.t("Новый!"), 18, UiTheme.BRASS, true)
			tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			box.add_child(tag)
		else:
			box.add_child(UiTheme.pip_row(state.pets.stars(id), Pets.STAR_TOTALS.size(), 12))
		grid.add_child(cell)
		cell.modulate.a = 0.0
		cell.pivot_offset = Vector2(78, 95)
		cell.scale = Vector2(0.6, 0.6)
		var tween := cell.create_tween().set_parallel(true)
		tween.tween_property(cell, "modulate:a", 1.0, 0.16).set_delay(0.08 * i + 0.15)
		tween.tween_property(cell, "scale", Vector2.ONE, 0.22).set_delay(0.08 * i + 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var close := UiTheme.make_button("Отлично", true, 32)
	close.pressed.connect(modal.close)
	modal.body.add_child(close)
	host.add_child(modal)
