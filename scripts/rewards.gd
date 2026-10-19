class_name Rewards
extends RefCounted
## Награды и покупки: экспедиции, реклама за награду, достижения, навыки, мета-улучшения, лавка за алмазы, динамит.
## Меняет состояние (ClickerState), даёт обратную связь (звук, вибрация, подсказка) и просит интерфейс обновиться.

var host: Control
var state: ClickerState
var offline_earned := 0.0             # монеты за время офлайна: по ним считается «×2 за рекламу»

var _settings: Settings
var _sfx: Sfx
var _table: FieldTable
var _viewport: Viewport
var _toast: Callable
var _refresh: Callable
var _rebuild_journal: Callable
var _on_dynamite_changed: Callable
var _biome: Callable
var _ads := Ads.new()
var _store := Store.new()
var _offline_doubled := false


func setup(host_node: Control, game_state: ClickerState, game_settings: Settings, sound: Sfx, mine_table: FieldTable,
		view: Viewport, show_toast: Callable, refresh: Callable, rebuild_journal: Callable, on_dynamite_changed: Callable,
		current_biome: Callable) -> Rewards:
	host = host_node
	state = game_state
	_settings = game_settings
	_sfx = sound
	_table = mine_table
	_viewport = view
	_toast = show_toast
	_refresh = refresh
	_rebuild_journal = rebuild_journal
	_on_dynamite_changed = on_dynamite_changed
	_biome = current_biome
	_ads.setup(host_node, game_state)
	return self


func offline_doubled() -> bool:
	return _offline_doubled


## Отправить поход по предложению с доски.
func on_expedition_start(offer: int) -> void:
	if state.start_offer(offer):
		_sfx.play("tick", -4.0)
		state.save()


func on_expedition_claim(slot: int) -> void:
	var result := state.claim_expedition(slot)
	if result.is_empty():
		return
	state.save()
	_sfx.play("claim", -4.0)
	var modal := Modal.new()
	var back := Companion.portrait(240.0, "tired")
	if back != null:
		back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		modal.body.add_child(back)
	modal.body.add_child(UiTheme.make_label("Экспедиция вернулась", 50, UiTheme.TEXT, true))
	var rarity := int(result.get("rarity", 0))
	if rarity > 0:
		modal.body.add_child(UiTheme.make_label(Tr.t("Поход: %s") % Tr.t(str(Retention.RARITIES[rarity]["name"])), 30, TripView.RARITY_COLORS[rarity]))
	modal.body.add_child(UiTheme.make_label(Tr.t("Монеты: +%s") % NumberFormat.short(float(result["coins"])), 34, UiTheme.BRASS))
	if int(result["diamonds"]) > 0:
		modal.body.add_child(UiTheme.make_label(Tr.t("Алмазы: +%d") % int(result["diamonds"]), 34, UiTheme.TEXT))
	if int(result["dynamite"]) > 0:
		modal.body.add_child(UiTheme.make_label(Tr.t("Динамит +%d") % int(result["dynamite"]), 34, UiTheme.TEXT))
	if int(result.get("tickets", 0)) > 0:
		modal.body.add_child(UiTheme.make_label(Tr.t("Жетоны узкоколейки +%d") % int(result["tickets"]), 30, UiTheme.TEXT))
	var found: Dictionary = result["found"]
	var names := ["Медь", "Железо", "Золото", "Алмаз"]
	var ore_icons := ["ore_copper", "ore_iron", "ore_gold", "ore_diamond"]
	for ore in found:
		if int(found[ore]) > 0:
			var line := HBoxContainer.new()
			line.add_theme_constant_override("separation", 12)
			line.alignment = BoxContainer.ALIGNMENT_CENTER
			line.add_child(Icon.new().setup(ore_icons[int(ore) - 1], Color.WHITE, 48))
			line.add_child(UiTheme.make_label("%s: +%d" % [Tr.t(names[int(ore) - 1]), int(found[ore])], 28, UiTheme.MUTE))
			modal.body.add_child(line)
	# изредка шахтёры приносят диковинку: просто приятная картинка (в журнал и экономику не пишется)
	if str(result.get("relic", "")) != "":
		var relic: Array = [Relics.icon(str(result["relic"])), Relics.name_of(str(result["relic"]))]
		modal.body.add_child(UiTheme.make_label("Шахтёры принесли диковинку", 26, UiTheme.BRASS))
		var relic_row := HBoxContainer.new()
		relic_row.add_theme_constant_override("separation", 12)
		relic_row.alignment = BoxContainer.ALIGNMENT_CENTER
		relic_row.add_child(Icon.new().setup(str(relic[0]), Color.WHITE, 96))
		relic_row.add_child(UiTheme.make_label(str(relic[1]), 28, UiTheme.TEXT))
		modal.body.add_child(relic_row)
	var close := UiTheme.make_button("Закрыть", true, 34)
	close.pressed.connect(modal.close)
	modal.body.add_child(close)
	host.add_child(modal)


## Реклама за награду: ролик (пока заглушка) и выдача награды по месту.
func on_ad_requested(placement: String) -> void:
	if state.ad_remaining(placement) > 0.0:
		return
	_ads.request(placement, func() -> void: grant_ad_reward(placement))


func grant_ad_reward(placement: String) -> void:
	match placement:
		"offline":
			if _offline_doubled:
				return
			_offline_doubled = true
			state.add_coins(offline_earned)
			_toast.call(Tr.t("Офлайн-доход ×2: +%s") % NumberFormat.short(offline_earned))
		"rush":
			state.start_rush(ClickerState.RUSH_LONG_SECONDS)
			_toast.call(Tr.t("Золотая лихорадка ×%d") % int(ClickerState.BOOST_FACTOR))
		"dynamite":
			award_dynamite(2)
		"diamonds":
			var gems := state.ad_diamonds()
			state.diamonds += gems
			_toast.call(Tr.t("Алмазы: +%d") % gems)
		"machines":
			state.machine_boost_time = state.machine_boost_seconds()
			_toast.call(Tr.t("Машины ×2 на 5 минут"))
		"expedition":
			if not state.expedition_hurry(3600.0):
				return
			_toast.call(Tr.t("Поход ускорен на 1 час"))
		"trip_offers":
			state.reroll_offers()
			_toast.call(Tr.t("Новые предложения походов"))
		"research":
			if not state.workshop.hurry(Workshop.AD_HURRY):
				return
			_toast.call(Tr.t("Исследование ускорено на 30 минут"))
		"dungeon":
			state.dungeons.add_keys(1)
			_toast.call(Tr.t("Ещё по ключу в каждое подземелье"))
		"tower":
			state.tower.attempts += 1
			_toast.call(Tr.t("Ещё одна попытка в башне"))
		"tickets":
			state.railway.tickets += Railway.AD_TICKETS
			_toast.call(Tr.t("Жетоны узкоколейки +%d") % Railway.AD_TICKETS)
		"picks":
			state.quarry.picks += Quarry.AD_PICKS
			_toast.call(Tr.t("Кирки +%d") % Quarry.AD_PICKS)
		"junk":
			state.quarry.junk_reroll(state, false)
			_toast.call(Tr.t("Старьёвщик принёс новый товар"))
	_sfx.play("claim", -4.0)
	_settings.vibrate(30)
	state.save()
	_refresh.call()
	_rebuild_journal.call()


func on_achievement_claim_all() -> void:
	var count := 0
	for achievement in Retention.ACHIEVEMENTS:
		if not state.claim_achievement(achievement).is_empty():
			count += 1
	if count > 0:
		state.save()
		_sfx.play("claim", -4.0)
		_settings.vibrate(30)
		_toast.call(Tr.t("Наград получено") + ": %d" % count)


func on_achievement_claim(id: String) -> void:
	for achievement in Retention.ACHIEVEMENTS:
		if str(achievement["id"]) == id:
			if state.claim_achievement(achievement).is_empty():
				return
			state.save()
			_sfx.play("claim", -4.0)
			_settings.vibrate(30)
			_toast.call(Tr.t("Награда получена") + ": " + Tr.t(str(achievement["name"])))
			return


func on_meta_purchase(id: String) -> void:
	if state.buy_meta(id):
		_sfx.play("coin", -5.0)
		_settings.vibrate(20)
		state.save()
		_refresh.call()


func on_skill_purchase(branch: String) -> void:
	if state.buy_skill(branch):
		_sfx.play("coin", -5.0)
		_settings.vibrate(20)
		state.save()
		_refresh.call()


func on_respec() -> void:
	var cost := state.shop_cost("respec")
	if state.diamonds < cost:
		return
	state.diamonds -= cost
	state.respec()
	_sfx.play("tick", -4.0)
	state.save()
	_refresh.call()


func on_shop_purchase(item: String) -> void:
	var cost := state.shop_cost(item)
	if state.diamonds < cost or not state.shop_available(item):
		return
	match item:
		"golden":
			if not _table.summon_golden():
				_toast.call(Tr.t("Золотая глыба уже на поле"))
				return
			state.diamonds -= cost
		"boss":
			if not _table.summon_boss(_biome.call()):
				_toast.call(Tr.t("Хранитель уже на поле"))
				return
			state.diamonds -= cost
		"expedition_skip":
			state.diamonds -= cost
			state.expedition_hurry(INF)
			_toast.call(Tr.t("Шахтёры вернулись!"))
		"trip_offers":
			state.diamonds -= cost
			state.reroll_offers()
		"research_skip":
			state.diamonds -= cost
			state.workshop.hurry(INF)
		"skill_point":
			state.diamonds -= cost
			state.skill_points += 1
			state.skill_points_bought += 1
			_toast.call(Tr.t("Очко навыков +1"))
		"rush":
			if state.rush_remaining() > 0.0:
				return
			state.diamonds -= cost
			state.rush_ready_at = ClickerState.now() + ClickerState.RUSH_COOLDOWN
			state.start_rush(ClickerState.RUSH_LONG_SECONDS)
			_toast.call(Tr.t("Золотая лихорадка ×%d") % int(ClickerState.BOOST_FACTOR))
		"dynamite":
			state.diamonds -= cost
			award_dynamite(3)
		_:
			if item.begins_with("style_"):
				var style_index := int(item.substr(6))
				state.diamonds -= cost
				state.styles_bought.append(style_index)
				_settings.rock_style = style_index
				_settings.save()
				_settings.apply(_viewport, _table)
				_toast.call(Tr.t("Новая порода: ") + Tr.t(Settings.STYLE_NAMES[style_index]))
	_sfx.play("coin", -5.0)
	_settings.vibrate(20)
	state.save()


## Выдаёт динамит на склад и сообщает об этом (сколько влезло).
func award_dynamite(amount: int) -> void:
	var added := state.add_dynamite(amount)
	if added > 0:
		_toast.call(Tr.t("Динамит +%d") % added)
	else:
		_toast.call(Tr.t("Склад динамита полон"))
	_on_dynamite_changed.call()


# ---------- Забой, старьёвщик, наряд дня (quarry.gd) ----------

func on_quarry_dig(index: int) -> void:
	var result := state.quarry.dig(index, state)
	if result.is_empty():
		return
	if not bool(result["opened"]):
		_sfx.crack(false)
		_settings.vibrate(10)
	else:
		_sfx.crack(true)
		_settings.vibrate(25)
		var text := _quarry_loot_text(result)
		if text != "":
			_sfx.play("coin", -6.0)
			_toast.call(text)
	state.save()
	_refresh.call()
	_rebuild_journal.call()


func on_quarry_descend() -> void:
	var result := state.quarry.descend(state)
	if result.is_empty():
		return
	_sfx.play("claim", -4.0)
	_settings.vibrate(30)
	var text := Tr.t("Ярус %d") % int(result["layer"])
	if result.has("kind"):
		text += " · " + Tr.t("Сундук!") + " " + _quarry_loot_text(result)
	_toast.call(text)
	state.save()
	_refresh.call()
	_rebuild_journal.call()


## Текст добычи клетки или сундука: «Монеты: +…», «Алмазы: +…» и т.д.
func _quarry_loot_text(result: Dictionary) -> String:
	var parts: Array[String] = []
	if result.has("coins"):
		parts.append(Tr.t("Монеты: +%s") % NumberFormat.short(float(result["coins"])))
	if result.has("diamonds"):
		parts.append(Tr.t("Алмазы: +%d") % int(result["diamonds"]))
	if result.has("count") and result.has("ore"):
		parts.append(Tr.t("Находки: +%d") % int(result["count"]))
	if int(result.get("dynamite", 0)) > 0:
		parts.append(Tr.t("Динамит +%d") % int(result["dynamite"]))
		_on_dynamite_changed.call()
	if result.has("picks"):
		parts.append(Tr.t("Кирки +%d") % int(result["picks"]))
	if str(result.get("kind", "")) == "exit":
		parts.append(Tr.t("Лаз на ярус ниже!"))
	return ", ".join(parts)


func on_junk_buy(slot: int) -> void:
	var result := state.quarry.junk_buy(slot, state)
	if result.is_empty():
		return
	_sfx.play("coin", -5.0)
	_settings.vibrate(20)
	if str(result["item"]) == "dynamite":
		_on_dynamite_changed.call()
	_toast.call(Tr.t("Куплено у старьёвщика"))
	state.save()
	_refresh.call()
	_rebuild_journal.call()


func on_junk_reroll() -> void:
	if not state.quarry.junk_reroll(state):
		return
	_sfx.play("tick", -4.0)
	state.save()
	_rebuild_journal.call()


func on_rush_claim(step: int) -> void:
	var result := state.quarry.rush_claim(step, state)
	if result.is_empty():
		return
	_sfx.play("claim", -4.0)
	_settings.vibrate(30)
	_toast.call(Tr.t("Сундук наряда") + ": " + _quarry_loot_text(result))
	state.save()
	_refresh.call()
	_rebuild_journal.call()


# ---------- Мастерская и узкоколейка ----------

func on_research_start(id: String) -> void:
	if not state.workshop.start(id, state):
		return
	_sfx.play("tick", -4.0)
	state.save()
	_refresh.call()
	_rebuild_journal.call()


func on_research_claim() -> void:
	var id := state.finish_research()
	if id == "":
		return
	_sfx.play("claim", -4.0)
	_settings.vibrate(30)
	var entry := Workshop.entry_of(id)
	_toast.call(Tr.t("Исследование готово") + ": " + Tr.t(str(entry["name"])) + " " + Tr.t("ур. %d") % state.workshop.level(id))
	_on_dynamite_changed.call()
	state.save()
	_refresh.call()
	_rebuild_journal.call()


## Бросок кубика: состояние меняется сразу, вагонетку по кольцу проводит интерфейс (railway.animate_pending).
func on_cart_roll() -> void:
	var result := state.railway.roll(state)
	if result.is_empty():
		return
	_sfx.play("tick", -2.0)
	_settings.vibrate(20)
	if int(result.get("dynamite", 0)) > 0:
		_on_dynamite_changed.call()
	state.save()
	_refresh.call()
	_rebuild_journal.call()


# ---------- Сундук удачи и пропуск шахтёра ----------


func open_lucky() -> void:
	if not state.lucky.open():
		return
	state.save()
	_sfx.play("claim", -6.0)
	LuckyView.show(host, state, self)


func on_lucky_take(index: int) -> void:
	var result := state.lucky.take(index, state)
	if result.is_empty():
		return
	_sfx.play("coin", -4.0)
	_settings.vibrate(30)
	var name := Tr.t(str(Lucky.KINDS[str(result["kind"])]["name"]))
	var parts: Array[String] = []
	if result.has("coins"):
		parts.append(Tr.t("Монеты: +%s") % NumberFormat.short(float(result["coins"])))
	if result.has("diamonds"):
		parts.append(Tr.t("Алмазы: +%d") % int(result["diamonds"]))
	if result.has("picks"):
		parts.append(Tr.t("Кирки +%d") % int(result["picks"]))
	if result.has("tickets"):
		parts.append(Tr.t("Жетоны узкоколейки +%d") % int(result["tickets"]))
	if int(result.get("dynamite", 0)) > 0:
		parts.append(Tr.t("Динамит +%d") % int(result["dynamite"]))
		_on_dynamite_changed.call()
	if result.has("points"):
		parts.append(Tr.t("Очко навыков +1"))
	_toast.call(name + (": " + ", ".join(parts) if not parts.is_empty() else ""))
	state.save()
	_refresh.call()
	_rebuild_journal.call()


func on_lucky_reroll() -> void:
	if state.lucky.reroll(state):
		state.save()
		_sfx.play("tick", -4.0)
	LuckyView.show(host, state, self)


func on_pass_claim(track: String, level: int) -> void:
	if state.miner_pass.claim(track, level, state).is_empty():
		return
	_after_pass_claim()


func on_pass_claim_all() -> void:
	var total := state.miner_pass.claim_all(state)
	if total.is_empty():
		return
	_after_pass_claim()
	_toast.call(Tr.t("Награды пропуска") + ": " + PassView.reward_text(total).replace("+", "+"))


func _after_pass_claim() -> void:
	_sfx.play("claim", -4.0)
	_settings.vibrate(30)
	state.save()
	_refresh.call()
	_rebuild_journal.call()


func on_pass_buy() -> void:
	if state.miner_pass.has_premium():
		return
	_store.setup(host)
	_store.request(MinerPass.PRODUCT, func() -> void:
			state.miner_pass.unlock_premium()
			_toast.call(Tr.t("Золотой пропуск открыт до конца сезона"))
			_after_pass_claim())


# ---------- Питомцы и башня ----------

func on_pet_summon(count: int) -> void:
	var before := {}
	for id in state.pets.copies:
		before[id] = int(state.pets.copies[id])
	var ids := state.pets.summon(count, state, true)
	if ids.is_empty():
		return
	# «Новый!» — первая копия питомца, которого раньше не было (номер позиции в списке)
	var new_ids := {}
	for i in ids.size():
		var id := str(ids[i])
		if int(before[id]) == 0 and not new_ids.has(id):
			new_ids[id] = i
	state.apply_research()
	state.save()
	_sfx.play("claim", -4.0)
	_settings.vibrate(30)
	PetsView.show_summon(host, state, ids, new_ids)
	_refresh.call()
	_rebuild_journal.call()


func on_pet_toggle(id: String) -> void:
	if not state.pets.toggle(id):
		if state.pets.owned(id):
			_toast.call(Tr.t("Все слоты заняты: сначала уберите питомца"))
		return
	state.apply_research()              # «Крот Копуша» меняет время кирки
	state.save()
	_sfx.play("tick", -4.0)
	_refresh.call()
	_rebuild_journal.call()


func on_tower_fight() -> void:
	if not state.tower.can_fight():
		return
	_sfx.play("tick", -2.0)
	var fight := TowerFight.new().setup(state, func(won: bool) -> void: _on_tower_done(won))
	host.add_child(fight)


func _on_tower_done(won: bool) -> void:
	var result := state.tower.finish(won, state)
	state.save()
	var modal := Modal.new()
	if won:
		_sfx.play("claim", -2.0)
		_settings.vibrate(60)
		modal.body.add_child(UiTheme.make_label(Tr.t("Этаж %d пройден!") % int(result["floor"]), 48, UiTheme.BRASS, true))
		var parts: Array[String] = [Tr.fmt("+%d алмазов", [int(result["diamonds"])]), Tr.t("Приманки: %d") % int(result["baits"])]
		if result.has("golden"):
			parts.append(Tr.t("Золотой сундук ×%d") % int(result["golden"]))
		if result.has("shards"):
			parts.append(shards_text(result["shards"]))
		if result.has("points"):
			parts.append(Tr.t("Очко навыков +1"))
		var text := UiTheme.make_text(", ".join(parts), 30, UiTheme.TEXT)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		modal.body.add_child(text)
	else:
		_sfx.play("tick", -6.0)
		modal.body.add_child(UiTheme.make_label(Tr.t("Глыба устояла"), 48, UiTheme.TEXT, true))
		var hint := UiTheme.make_text(Tr.t("Сильнее бьют питомцы (все собранные), исследования мастерской и глубина. Попыток осталось: %d") % state.tower.attempts_left(), 26, UiTheme.MUTE)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		modal.body.add_child(hint)
	var close := UiTheme.make_button("Дальше", true, 32)
	close.pressed.connect(modal.close)
	modal.body.add_child(close)
	host.add_child(modal)
	_refresh.call()
	_on_dynamite_changed.call()
	_rebuild_journal.call()



# ---------- Артефакты и подземелья ----------

## «Осколки: Кирка первого шахтёра ×2, …»
static func shards_text(got: Dictionary) -> String:
	var parts: Array[String] = []
	for id in got:
		parts.append("%s ×%d" % [Tr.t(str(Artifacts.data(str(id))["name"])), int(got[id])])
	return Tr.t("Осколки") + ": " + ", ".join(parts)


func on_artifact_upgrade(id: String) -> void:
	if not state.artifacts.upgrade(id):
		return
	_sfx.play("claim", -4.0)
	_settings.vibrate(30)
	var level := state.artifacts.level(id)
	_toast.call(Tr.t(str(Artifacts.data(id)["name"])) + ": " + (Tr.t("открыт") if level == 1 else Tr.t("ур. %d") % level))
	_on_dynamite_changed.call()
	state.save()
	_refresh.call()
	_rebuild_journal.call()


func on_dungeon_fight(id: String) -> void:
	if state.dungeons.keys_left(id) <= 0:
		return
	var level := state.dungeons.next_level(id)
	var rule := Dungeons.rule()
	var rules := {"text": Tr.t("Правило дня") + ": " + Tr.t(str(rule["text"]))}
	if rule.has("dynamite"):
		rules["dynamite"] = float(rule["dynamite"])
	if rule.has("crit_every"):
		rules["crit_every"] = int(rule["crit_every"])
	var title := Tr.t(str(Dungeons.data(id)["name"])) + " · " + Tr.t("Уровень %d") % level
	_sfx.play("tick", -2.0)
	var fight := TowerFight.new().configure(state, title, UiTheme.TEXT, Dungeons.hp_for(level), Dungeons.seconds(), rules,
			func(won: bool) -> void: _show_dungeon_result(state.dungeons.finish(id, won, state)))
	host.add_child(fight)


func on_dungeon_sweep(id: String) -> void:
	var result := state.dungeons.sweep(id, state)
	if result.is_empty():
		return
	_show_dungeon_result(result)


func _show_dungeon_result(result: Dictionary) -> void:
	if result.is_empty():
		return
	state.save()
	var modal := Modal.new()
	if bool(result.get("won", false)):
		_sfx.play("claim", -2.0)
		_settings.vibrate(50)
		modal.body.add_child(UiTheme.make_label(Tr.t("Уровень %d пройден!") % int(result["level"]), 46, UiTheme.BRASS, true))
		var parts: Array[String] = []
		if result.has("coins"):
			parts.append(Tr.t("Монеты: +%s") % NumberFormat.short(float(result["coins"])))
		if result.has("picks"):
			parts.append(Tr.t("Кирки +%d") % int(result["picks"]))
		if result.has("diamonds"):
			parts.append(Tr.t("Алмазы: +%d") % int(result["diamonds"]))
		if result.has("baits"):
			parts.append(Tr.t("Приманки: %d") % int(result["baits"]))
		if result.has("shards"):
			parts.append(shards_text(result["shards"]))
		var text := UiTheme.make_text("\n".join(parts), 28, UiTheme.TEXT)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		modal.body.add_child(text)
	else:
		_sfx.play("tick", -6.0)
		modal.body.add_child(UiTheme.make_label(Tr.t("Глыба устояла"), 46, UiTheme.TEXT, true))
		var hint := UiTheme.make_text(Tr.t("Ключ не потрачен. Сильнее бьют питомцы, артефакт «Сердце горы», исследования и глубина."), 26, UiTheme.MUTE)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		modal.body.add_child(hint)
	var close := UiTheme.make_button("Дальше", true, 32)
	close.pressed.connect(modal.close)
	modal.body.add_child(close)
	host.add_child(modal)
	_refresh.call()
	_on_dynamite_changed.call()
	_rebuild_journal.call()
