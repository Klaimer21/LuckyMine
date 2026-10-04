class_name Rewards
extends RefCounted
## Награды и покупки: экспедиции, реклама за награду, достижения, навыки, мета-улучшения, лавка за алмазы, динамит.
## Меняет состояние (ClickerState), даёт обратную связь (звук, вибрация, подсказка) и просит интерфейс обновиться.

var host: Control
var state: ClickerState
var offline_earned := 0.0             # монеты за время офлайна: по ним считается «×2 за рекламу»

var _settings: Settings
var _sfx: Sfx
var _table: MineTable
var _viewport: Viewport
var _toast: Callable
var _refresh: Callable
var _rebuild_journal: Callable
var _on_dynamite_changed: Callable
var _biome: Callable
var _ads := Ads.new()
var _offline_doubled := false


func setup(host_node: Control, game_state: ClickerState, game_settings: Settings, sound: Sfx, mine_table: MineTable,
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


func on_expedition_start(index: int) -> void:
	if state.start_expedition(index):
		_sfx.play("tick", -4.0)
		state.save()


func on_expedition_claim() -> void:
	var result := state.claim_expedition()
	if result.is_empty():
		return
	state.save()
	_sfx.play("claim", -4.0)
	var modal := Modal.new()
	modal.body.add_child(UiTheme.make_label("Экспедиция вернулась", 50, UiTheme.TEXT, true))
	modal.body.add_child(UiTheme.make_label(Tr.t("Монеты: +%s") % NumberFormat.short(float(result["coins"])), 34, UiTheme.BRASS))
	if int(result["diamonds"]) > 0:
		modal.body.add_child(UiTheme.make_label(Tr.t("Алмазы: +%d") % int(result["diamonds"]), 34, UiTheme.TEXT))
	if int(result["dynamite"]) > 0:
		modal.body.add_child(UiTheme.make_label(Tr.t("Динамит +%d") % int(result["dynamite"]), 34, UiTheme.TEXT))
	var found: Dictionary = result["found"]
	var names := ["Медь", "Железо", "Золото", "Алмаз"]
	for ore in found:
		if int(found[ore]) > 0:
			modal.body.add_child(UiTheme.make_label("%s: +%d" % [Tr.t(names[int(ore) - 1]), int(found[ore])], 28, UiTheme.MUTE))
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
		"expedition":
			if not state.expedition_active() or state.expedition_ready():
				return
			state.expedition_end -= 3600.0
			_toast.call(Tr.t("Поход ускорен на 1 час"))
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
				_toast.call(Tr.t("Золотая глыба уже на столе"))
				return
			state.diamonds -= cost
		"boss":
			if not _table.summon_boss(_biome.call()):
				_toast.call(Tr.t("Хранитель уже на столе"))
				return
			state.diamonds -= cost
		"expedition_skip":
			state.diamonds -= cost
			state.expedition_end = Time.get_unix_time_from_system()
			_toast.call(Tr.t("Шахтёры вернулись!"))
		"skill_point":
			state.diamonds -= cost
			state.skill_points += 1
			state.skill_points_bought += 1
			_toast.call(Tr.t("Очко навыков +1"))
		"rush":
			if state.rush_remaining() > 0.0:
				return
			state.diamonds -= cost
			state.rush_ready_at = Time.get_unix_time_from_system() + ClickerState.RUSH_COOLDOWN
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
