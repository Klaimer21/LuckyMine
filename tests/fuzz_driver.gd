extends SceneTree
## Ломаем игру случайными действиями: godot --headless --path . --script res://tests/fuzz_driver.gd -- <seed> <кадров>
## Каждый кадр жмёт случайные кнопки (иногда по два раза подряд), крутит интерфейс и портит состояние;
## каждые 60 кадров проверяет инварианты. Ошибки движка видны в выводе (SCRIPT ERROR), нарушения — строками BUG.
## Игра пишет сохранение: запускать на копии профиля (прогресс затирается).

var _rng := RandomNumberGenerator.new()
var _main: Node
var _frame := 0
var _frames := 3000
var _bugs := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_rng.seed = int(args[0]) if args.size() > 0 else 1
	if args.size() > 1:
		_frames = int(args[1])
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)
	_main.state.tutorial_done = _rng.randf() < 0.5
	Engine.time_scale = 3.0
	Engine.max_fps = 0                       # без ограничения кадров: прогон идёт быстрее


func _buttons(node: Node, out: Array) -> void:
	# как у настоящего игрока: пока открыто окно, нажимаются только его кнопки (остальное закрыто затемнением)
	var top: Node = null
	for modal in _main.find_children("*", "Modal", true, false):
		if not modal.is_queued_for_deletion():
			top = modal
	if top != null and node == root:
		node = top
	_collect(node, out)


func _collect(node: Node, out: Array) -> void:
	if node is BaseButton and node.is_visible_in_tree() and not node.disabled:
		out.append(node)
	for child in node.get_children():
		_collect(child, out)


func _click(button: BaseButton) -> void:
	button.button_down.emit()
	button.pressed.emit()
	button.button_up.emit()


func _process(_delta: float) -> bool:
	_frame += 1
	if _main == null or not is_instance_valid(_main):
		return false
	for i in _rng.randi_range(1, 4):
		_act()
	if _frame % 60 == 0:
		_check()
	if _frame >= _frames:
		print("DONE frames=%d bugs=%d" % [_frame, _bugs])
		quit()
	return false


func _act() -> void:
	var state: ClickerState = _main.state
	match _rng.randi_range(0, 41):
		0, 1, 2, 3, 4, 5, 6, 7:
			var list: Array = []
			_buttons(root, list)
			if list.is_empty():
				return
			var button: BaseButton = list[_rng.randi() % list.size()]
			_click(button)
			if _rng.randf() < 0.3:
				_click(button)                         # двойное нажатие
			if _rng.randf() < 0.1 and is_instance_valid(button):
				_click(button)
		8:
			_main._sheet.toggle()
			_main._sheet.toggle()
		9:
			_main._on_throw_pressed()
		10:
			_main._on_dynamite_pressed()
		11:
			_main._table.tap(Vector2(_rng.randf_range(0, 1080), _rng.randf_range(0, 1920)))
		12:
			var event := InputEventKey.new()
			event.pressed = true
			event.keycode = [KEY_SPACE, KEY_ESCAPE, KEY_ENTER, KEY_U, KEY_D, KEY_A][_rng.randi() % 6]
			Input.parse_input_event(event)
		13:
			var cancel := InputEventAction.new()
			cancel.action = "ui_cancel"
			cancel.pressed = true
			Input.parse_input_event(cancel)
		14:
			state.add_coins(10.0 ** _rng.randf_range(0.0, 40.0))
		15:
			state.diamonds += _rng.randi_range(0, 500)
			state.skill_points += _rng.randi_range(0, 20)
			state.stardust += _rng.randi_range(0, 50)
		16:
			_main.settings.language = ["en", "ru", "zh"][_rng.randi() % 3]
			_main._on_language_changed()
		17:
			state.save()
			var copy := ClickerState.new()
			copy.load_save()
		18:
			_main._table.summon_golden()
			_main._table.summon_boss(_rng.randi_range(0, 6))
		19:
			_main._table.detonate()
		26, 27:
			_main.settings.season = Seasons.CHOICES[_rng.randi() % Seasons.CHOICES.size()]
			_main.settings.reduce_motion = _rng.randf() < 0.3
			_main._apply_season()
		24, 25:
			state.levels["rain"] = maxi(int(state.levels["rain"]), _rng.randi_range(0, 8))
			state.update_machine_unlocks()
			state.coins += 10.0 ** _rng.randf_range(2.0, 12.0)
			state.buy_machine("crusher", _rng.randi_range(1, 30))
			_main._refresh()
		22, 23:
			# несколько пальцев: случайные касания и отпускания, в том числе по кнопкам, окнам и скольжение между ними
			for i in _rng.randi_range(1, 6):
				var touch := InputEventScreenTouch.new()
				touch.index = _rng.randi_range(0, 4)
				touch.position = Vector2(_rng.randf_range(0, 540), _rng.randf_range(0, 960))
				touch.pressed = _rng.randf() < 0.6
				Input.parse_input_event(touch)
				if _rng.randf() < 0.3:
					var drag := InputEventScreenDrag.new()
					drag.index = touch.index
					drag.position = touch.position + Vector2(_rng.randf_range(-80, 80), _rng.randf_range(-80, 80))
					Input.parse_input_event(drag)
		28:
			var table: FieldTable = _main._table
			table.set_biome(_rng.randi_range(0, 6), _rng.randf() < 0.5)       # смена зоны на лету, в том числе с хранителем на поле
		29:
			var field: FieldTable = _main._table
			field.clear_field()                                               # как после «Новой шахты»
			field.throw_now()
		30:
			var quality_table: FieldTable = _main._table
			quality_table.set_quality(_rng.randi_range(0, 2))
			quality_table.stress_rate = [0.0, 0.0, 50.0, 500.0][_rng.randi() % 4]
			quality_table.auto_throw = _rng.randf() < 0.8
		31:
			for branch in state.skills:
				state.skills[branch] = _rng.randi_range(0, Skills.MAX_LEVEL)    # любые уровни навыков, в том числе новых веток
			if _rng.randf() < 0.2:
				state.respec()
			state.dynamite_stock = mini(state.dynamite_stock, state.dynamite_max())    # как в игре: склад не больше вместимости
		32:
			_main._table.hit_boss(_rng.randi_range(0, 30))
			if _main._table._golden != null:
				_main._table._hit_golden()
		33:
			for i in _rng.randi_range(1, 20):
				_main._table.tap(Vector2(_rng.randf_range(-100, 1200), _rng.randf_range(-100, 2100)))   # и мимо поля
		34, 35:
			# перелёты между планетами и случайные уровни машин (в том числе планетных): ходы ленты растут и убывают
			state.planet = _rng.randi_range(0, 5)
			state.total_earned = maxf(state.total_earned, 10.0 ** _rng.randf_range(0.0, 30.0))
			state.update_machine_unlocks()
			for id in Machines.ids():
				if state.machine_unlocked(id) and _rng.randf() < 0.5:
					state.machines[id] = _rng.randi_range(0, state.machine_max_level(id))
			_main._machines.refresh()
			_main._refresh()
		36, 37:
			# журнал на случайной вкладке и в случайном режиме (забой, узкоколейка, башня, подземелья, пропуск, артефакты)
			var journal: JournalScreen = _main._journal
			journal._tab = _rng.randi_range(0, 7)
			journal._dig_mode = _rng.randi_range(0, 3)
			journal._rewards_mode = _rng.randi_range(0, 1)
			journal._friends_mode = _rng.randi_range(0, 1)
			journal._fade_next = _rng.randf() < 0.5
			journal.open()
		38:
			# новые системы напрямую: забой, узкоколейка, сундук, пропуск, питомцы, мастерская, походы, лавка
			var rewards: Rewards = _main._rewards
			match _rng.randi_range(0, 11):
				0:
					rewards.on_quarry_dig(_rng.randi_range(-2, Quarry.COLS * Quarry.ROWS + 2))
				1:
					rewards.on_quarry_descend()
				2:
					state.railway.tickets += _rng.randi_range(0, 3)
					rewards.on_cart_roll()
				3:
					state.lucky.chests = mini(Lucky.LUCKY_CAP, state.lucky.chests + 1)
					rewards.open_lucky()
				4:
					rewards.on_lucky_take(_rng.randi_range(-1, 3))
				5:
					state.miner_pass.add_xp(_rng.randi_range(0, 2000))
					rewards.on_pass_claim_all()
				6:
					rewards.on_pet_summon([1, 10][_rng.randi() % 2])
				7:
					rewards.on_pet_toggle(str(Pets.PETS[_rng.randi() % Pets.PETS.size()]["id"]))
				8:
					rewards.on_research_start(str(Workshop.RESEARCH[_rng.randi() % Workshop.RESEARCH.size()]["id"]))
					rewards.on_research_claim()
				9:
					rewards.on_expedition_start(_rng.randi_range(-1, 3))
					rewards.on_expedition_claim(_rng.randi_range(-1, 3))
				10:
					rewards.on_junk_buy(_rng.randi_range(-1, 4))
					if _rng.randf() < 0.3:
						rewards.on_junk_reroll()
				11:
					rewards.on_rush_claim(_rng.randi_range(-1, 3))
					rewards.on_artifact_upgrade(str(Artifacts.LIST[_rng.randi() % Artifacts.LIST.size()]["id"]))
		39:
			# бой в башне или подземелье: начать (иногда дважды подряд), бить, взрывать или бросить на середине
			var rewards_fight: Rewards = _main._rewards
			if _rng.randf() < 0.5:
				rewards_fight.on_tower_fight()
			else:
				rewards_fight.on_dungeon_fight(str(Dungeons.LIST[_rng.randi() % Dungeons.LIST.size()]["id"]))
			if _rng.randf() < 0.3:
				rewards_fight.on_tower_fight()
			for fight in _main.find_children("*", "TowerFight", true, false):
				for i in _rng.randi_range(0, 60):
					fight._hit()
				if _rng.randf() < 0.3:
					fight._blast()
		40:
			_main._rewards.on_dungeon_sweep(str(Dungeons.LIST[_rng.randi() % Dungeons.LIST.size()]["id"]))
			state.dungeons.add_keys(_rng.randi_range(0, 1))
			state.tower.attempts += _rng.randi_range(0, 1)
		41:
			# реклама за награду по любому месту (в том числе новые): заглушка выдаёт награду
			var placements: Array = Ads.PLACEMENTS.keys()
			_main._rewards.on_ad_requested(str(placements[_rng.randi() % placements.size()]))
		20, 21:
			# прыжки системных часов: вперёд, назад, на годы; потом игра «просыпается» как после офлайна
			var jumps := [60.0, 3600.0, 86400.0, -3600.0, -86400.0 * 3.0, 86400.0 * 365.0, -86400.0 * 365.0]
			ClickerState.clock_offset += jumps[_rng.randi() % jumps.size()]
			if _rng.randf() < 0.4:
				state.save()
				var woke := ClickerState.new()
				woke.load_save()


func _bug(text: String) -> void:
	_bugs += 1
	print("BUG frame=%d: %s" % [_frame, text])


func _finite(value: float) -> bool:
	return not is_nan(value) and not is_inf(value)


func _check() -> void:
	var s: ClickerState = _main.state
	for pair in [["coins", s.coins], ["total_earned", s.total_earned], ["lifetime_earned", s.lifetime_earned]]:
		if not _finite(float(pair[1])) or float(pair[1]) < 0.0:
			_bug("%s = %s" % [pair[0], pair[1]])
	if s.diamonds < 0 or s.skill_points < 0 or s.stardust < 0 or s.veins < 0:
		_bug("negative currency d=%d sp=%d sd=%d v=%d" % [s.diamonds, s.skill_points, s.stardust, s.veins])
	if s.dynamite_stock < 0 or s.dynamite_stock > maxi(s.dynamite_max(), 99):
		_bug("dynamite_stock %d (max %d)" % [s.dynamite_stock, s.dynamite_max()])
	for key in s.levels:
		if int(s.levels[key]) < 0:
			_bug("level %s = %s" % [key, s.levels[key]])
	if not _finite(s.income_per_second()) or not _finite(s.multiplier()):
		_bug("income/multiplier not finite: %s %s" % [s.income_per_second(), s.multiplier()])
	for slot in s.expeditions.size():
		if s.expedition_remaining(slot) > float(Retention.EXPEDITIONS[int(s.expeditions[slot]["type"])]["hours"]) * 3600.0:
			_bug("expedition remaining longer than its duration")
	if s.expeditions.size() > 3 or s.railway.pos < 0 or s.railway.pos >= Railway.BOARD.size() or s.railway.tickets < 0:
		_bug("trips/railway out of range: %d trips, pos %d, tickets %d" % [s.expeditions.size(), s.railway.pos, s.railway.tickets])
	for placement in Ads.PLACEMENTS:
		if s.ad_remaining(placement) > float(Ads.PLACEMENTS[placement]["cooldown"]) + 1.0 and abs(ClickerState.clock_offset) < 86400.0:
			_bug("ad cooldown %s longer than configured: %s" % [placement, s.ad_remaining(placement)])
	var crusher := s.machine_level("crusher")
	if crusher < 0 or crusher > s.machine_max_level("crusher"):
		_bug("crusher level out of range: %d" % crusher)
	if crusher > 0 and not s.machine_unlocked("crusher"):
		_bug("crusher level without unlock")
	for branch in s.skills:
		if int(s.skills[branch]) < 0 or int(s.skills[branch]) > Skills.MAX_LEVEL:
			_bug("skill %s out of range: %s" % [branch, s.skills[branch]])
	var field: FieldTable = _main._table
	if field.rock_count() > 400:
		_bug("rock pile on the field: %d" % field.rock_count())
	if field.get_child_count() > 300:
		_bug("too many nodes under the field: %d" % field.get_child_count())
	var modals := 0
	for node in _main.find_children("*", "Modal", true, false):
		if not node.is_queued_for_deletion():
			modals += 1
	if modals > 6:
		_bug("modal pile: %d" % modals)
	# новые системы: значения в своих границах
	var q := s.quarry
	if q.picks < 0 or q.hp.size() != Quarry.COLS * Quarry.ROWS or q.loot.count("exit") != 1 or q.layer < 1 or q.best_layer < q.layer:
		_bug("quarry broken: picks %d, cells %d, exits %d, layer %d/%d" % [q.picks, q.hp.size(), q.loot.count("exit"), q.layer, q.best_layer])
	if q.junk_slots.size() > Quarry.JUNK_SLOTS:
		_bug("junk slots: %d" % q.junk_slots.size())
	if s.lucky.chests < 0 or s.lucky.golden < 0 or (not s.lucky.offer.is_empty() and s.lucky.offer.size() != Lucky.CARDS):
		_bug("lucky chest broken: %d %d offer %d" % [s.lucky.chests, s.lucky.golden, s.lucky.offer.size()])
	if s.luck_factor < Lucky.CURSE_FACTOR - 0.001 or s.luck_factor > Lucky.FRENZY_FACTOR + 0.001 or s.luck_time < 0.0:
		_bug("luck out of range: %s for %s" % [s.luck_factor, s.luck_time])
	if s.pets.equipped.size() > Pets.SLOTS or s.pets.baits < 0:
		_bug("pets broken: %d equipped, %d baits" % [s.pets.equipped.size(), s.pets.baits])
	for id in s.pets.equipped:
		if not s.pets.owned(str(id)):
			_bug("pet equipped but not owned: %s" % id)
	for id in s.artifacts.levels:
		if int(s.artifacts.levels[id]) < 0 or int(s.artifacts.levels[id]) > Artifacts.MAX_LEVEL or int(s.artifacts.shards[id]) < 0:
			_bug("artifact %s out of range" % id)
	if s.tower.next_floor < 1 or s.tower.best >= s.tower.next_floor or s.tower.attempts < 0:
		_bug("tower broken: next %d best %d attempts %d" % [s.tower.next_floor, s.tower.best, s.tower.attempts])
	for id in s.dungeons.keys:
		if int(s.dungeons.keys[id]) < 0:
			_bug("dungeon keys negative: %s" % id)
	if s.miner_pass.xp < 0 or s.workshop.remaining(ClickerState.now()) < 0.0:
		_bug("pass/workshop broken")
	var fights := 0
	for node in _main.find_children("*", "TowerFight", true, false):
		if not node.is_queued_for_deletion():
			fights += 1
	if fights > 1:
		_bug("several fights at once: %d" % fights)
