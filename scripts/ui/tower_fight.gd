class_name TowerFight
extends Control
## Бой на этаже башни: глыба этажа, шкала прочности, таймер, динамит (−25% прочности). Касание по глыбе — удар
## силой Tower.tap_damage(). По окончании вызывает on_done(won) и закрывается.

var state: ClickerState
var on_done: Callable
var _hp := 1.0
var _max_hp := 1.0
var _damage := 1.0
var _time := Tower.FIGHT_SECONDS
var _over := false
var _rock: Button
var _rock_icon: Icon
var _bar: ProgressBar
var _hp_label: Label
var _timer: Label
var _dynamite: Button


func setup(p_state: ClickerState, done: Callable) -> TowerFight:
	state = p_state
	on_done = done
	var floor_number := state.tower.next_floor
	_max_hp = Tower.hp_for(floor_number)
	_hp = _max_hp
	_damage = Tower.tap_damage(state)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.05, 0.04, 0.95)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 60
	column.offset_right = -60
	column.offset_top = 160
	column.offset_bottom = -120
	column.add_theme_constant_override("separation", UiTheme.SPACE_M)
	add_child(column)
	var boss := Tower.is_boss(floor_number)
	var title := UiTheme.make_label((Tr.t("Хранитель этажа") + " · " if boss else "") + Tr.t("Этаж %d") % floor_number, 52, UiTheme.BRASS if boss else UiTheme.TEXT, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	_timer = UiTheme.make_label("", 64, UiTheme.TEXT, true)
	_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_timer)
	_bar = UiTheme.make_bar(1.0, Color(0.85, 0.36, 0.30), 28)
	column.add_child(_bar)
	_hp_label = UiTheme.make_label("", 30, UiTheme.MUTE)
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_hp_label)
	_rock = Button.new()
	_rock.flat = true
	_rock.focus_mode = Control.FOCUS_NONE
	_rock.custom_minimum_size = Vector2(0, 760)
	_rock.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_rock)
	_rock_icon = Icon.new().setup("rock", Color.WHITE, 520)
	_rock.add_child(_rock_icon)
	_rock.resized.connect(func() -> void:
			_rock_icon.position = (_rock.size - Vector2(520, 520)) * 0.5
			_rock_icon.pivot_offset = Vector2(260, 260))
	_rock.button_down.connect(_hit)
	var hint := UiTheme.make_label(Tr.t("Бейте по глыбе!"), 30, UiTheme.MUTE)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(hint)
	_dynamite = UiTheme.make_key(Tr.t("Динамит ×%d") % state.dynamite_stock, 30, "ember")
	_dynamite.custom_minimum_size.y = 110
	_dynamite.disabled = state.dynamite_stock <= 0
	_dynamite.pressed.connect(_blast)
	column.add_child(_dynamite)
	_refresh()
	return self


func _process(delta: float) -> void:
	if _over:
		return
	_time = maxf(0.0, _time - delta)
	_refresh()
	if _time <= 0.0:
		_end(false)


func _refresh() -> void:
	_timer.text = "%.1f" % _time
	_timer.add_theme_color_override("font_color", Color(0.85, 0.36, 0.30) if _time < 5.0 else UiTheme.TEXT)
	_bar.value = _hp / _max_hp
	_hp_label.text = "%s / %s" % [NumberFormat.short(ceilf(_hp)), NumberFormat.short(_max_hp)]


func _hit() -> void:
	_deal(_damage, false)


func _blast() -> void:
	if _over or not state.use_dynamite():
		return
	_dynamite.text = Tr.t("Динамит ×%d") % state.dynamite_stock
	_dynamite.disabled = state.dynamite_stock <= 0
	_deal(_max_hp * Tower.DYNAMITE_SHARE, true)


func _deal(amount: float, big: bool) -> void:
	if _over:
		return
	_hp = maxf(0.0, _hp - amount)
	# толчок глыбы и всплывающее число
	var tween := _rock_icon.create_tween()
	_rock_icon.scale = Vector2(0.92, 0.92) if not big else Vector2(0.8, 0.8)
	_rock_icon.rotation = randf_range(-0.06, 0.06)
	tween.tween_property(_rock_icon, "scale", Vector2.ONE, 0.12)
	var pop := UiTheme.make_label("-" + NumberFormat.short(amount), 44 if big else 34, UiTheme.BRASS if big else UiTheme.TEXT, true)
	pop.position = _rock.position + _rock.size * 0.5 + Vector2(randf_range(-180, 140), randf_range(-220, 60))
	pop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pop)
	var float_up := pop.create_tween().set_parallel(true)
	float_up.tween_property(pop, "position:y", pop.position.y - 90.0, 0.5)
	float_up.tween_property(pop, "modulate:a", 0.0, 0.5)
	float_up.chain().tween_callback(pop.queue_free)
	_refresh()
	if _hp <= 0.0:
		_end(true)


func _end(won: bool) -> void:
	if _over:
		return
	_over = true
	var tween := create_tween()
	if won:
		tween.tween_property(_rock_icon, "scale", Vector2(1.3, 1.3), 0.12)
		tween.tween_property(_rock_icon, "modulate:a", 0.0, 0.2)
	tween.tween_interval(0.25)
	tween.tween_callback(func() -> void:
			on_done.call(won)
			queue_free())
