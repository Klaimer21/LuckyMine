class_name ArtifactsView
extends RefCounted
## «Артефакты» во вкладке «Друзья»: восемь древностей с осколками, уровнем и бонусом. Улучшение — сигнал artifact_upgrade.

static func effect_text(id: String, level: int) -> String:
	var entry := Artifacts.data(id)
	return Tr.t(str(entry["text"])) % int(round(float(entry["step"]) * maxi(1, level) * 100.0))


static func build(parent: VBoxContainer, state: ClickerState, journal: JournalScreen) -> void:
	var artifacts := state.artifacts
	journal.intro(parent, "artifacts", "Осколки артефактов дают «Склеп древних» в подземельях дня и хранители башни. Бонус открытого артефакта действует всегда и не сбрасывается.", 22)
	for entry in Artifacts.LIST:
		var id := str(entry["id"])
		var rarity := int(entry["rarity"])
		var level := artifacts.level(id)
		var have := int(artifacts.shards.get(id, 0))
		var cost := artifacts.cost_next(id)
		var card := PanelContainer.new()
		var edge: Color = TripView.RARITY_COLORS[rarity]
		card.add_theme_stylebox_override("panel", UiTheme.panel_style(UiTheme.SURFACE, edge if level > 0 else UiTheme.LINE, 2 if level < Artifacts.MAX_LEVEL else 4, 18, 12))
		parent.add_child(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		card.add_child(row)
		var holder := PanelContainer.new()
		holder.add_theme_stylebox_override("panel", UiTheme.panel_style(edge.darkened(0.72), edge, 2, 12, 6))
		holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		holder.add_child(Icon.new().setup("art_" + id, Color(1, 1, 1, 1.0 if level > 0 else 0.3), 96))
		row.add_child(holder)
		var texts := VBoxContainer.new()
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.add_theme_constant_override("separation", 2)
		row.add_child(texts)
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", UiTheme.SPACE_S)
		texts.add_child(head)
		var name_label := UiTheme.make_label(Tr.t(str(entry["name"])), 26, UiTheme.TEXT if level > 0 else UiTheme.MUTE)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		head.add_child(name_label)
		head.add_child(UiTheme.make_label(Tr.t("ур. %d") % level if level > 0 else Tr.t("закрыт"), 24, edge if level > 0 else UiTheme.MUTE, true))
		texts.add_child(TripView.rarity_badge(rarity))
		var effect := UiTheme.make_text(effect_text(id, level) + ("" if level > 0 else "  " + Tr.t("(на 1-м уровне)")), 22, UiTheme.BRASS if level > 0 else UiTheme.MUTE)
		effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		texts.add_child(effect)
		if cost > 0:
			texts.add_child(UiTheme.make_bar(minf(1.0, float(have) / cost), edge, 10))
			texts.add_child(UiTheme.make_text(Tr.t("Осколки: %d / %d") % [have, cost], 20, UiTheme.MUTE))
			var key := UiTheme.make_key(Tr.t("Открыть") if level == 0 else Tr.t("Улучшить"), 24, "brass")
			key.custom_minimum_size = Vector2(170, 80)
			key.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			key.disabled = have < cost
			key.pressed.connect(func() -> void: journal.artifact_upgrade.emit(id))
			row.add_child(key)
		else:
			row.add_child(Icon.new().setup("check", UiTheme.BRASS, 40))
