class_name SaveDialogs
extends RefCounted
## Окна работы с сохранением: копирование кода, импорт кода, сброс прогресса.

var host: Control
var state: ClickerState
var _toast: Callable


func setup(host_node: Control, game_state: ClickerState, show_toast: Callable) -> SaveDialogs:
	host = host_node
	state = game_state
	_toast = show_toast
	return self


func export_code() -> void:
	state.save()
	DisplayServer.clipboard_set(state.export_code())
	_toast.call(Tr.t("Код скопирован в буфер обмена"))


## Код берётся из буфера обмена; текущий прогресс заменяется только после подтверждения.
func import_code() -> void:
	_confirm("Заменить прогресс?", "Текущий прогресс будет заменён кодом из буфера обмена. Запасная копия сохранится на устройстве.", "Заменить",
			func(modal: Modal) -> void:
				state.save()                      # текущее сохранение уйдёт в запасную копию при импорте
				if ClickerState.import_code(DisplayServer.clipboard_get()):
					_reload()
				else:
					modal.close()
					_toast.call(Tr.t("Код не подходит или повреждён")))


## В облаке прогресс больше: предложить загрузить. remote — сводка (CloudSave.summary_of), text — само сохранение.
func offer_cloud(remote: Dictionary, text: String, on_decline: Callable) -> void:
	var modal := Modal.new()
	modal.body.add_child(UiTheme.make_label("Найден прогресс в облаке", 50, UiTheme.TEXT, true))
	var local := CloudSave.summary_of(state.serialize())
	var note := UiTheme.make_label(Tr.t("В облаке: заработано %s, планета %d.") % [NumberFormat.short(float(remote["lifetime"])), int(remote["planet"]) + 1], 30, UiTheme.BRASS)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal.body.add_child(note)
	var here := UiTheme.make_label(Tr.t("На этом устройстве: заработано %s, планета %d.") % [NumberFormat.short(float(local["lifetime"])), int(local["planet"]) + 1], 30, UiTheme.MUTE)
	here.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal.body.add_child(here)
	var warn := UiTheme.make_label("Загрузка заменит прогресс на этом устройстве. Запасная копия сохранится.", 26, UiTheme.MUTE)
	warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal.body.add_child(warn)
	var load_button := UiTheme.make_key("Загрузить из облака", 34, "brass")
	load_button.custom_minimum_size.y = 96
	load_button.pressed.connect(func() -> void:
			load_button.disabled = true
			state.save()                              # текущее уйдёт в запасную копию
			if ClickerState.import_save_text(text):
				_reload()
			else:
				modal.close()
				_toast.call(Tr.t("Облачное сохранение повреждено")))
	modal.body.add_child(load_button)
	var keep := UiTheme.make_button("Оставить это устройство", false, 30)
	keep.pressed.connect(func() -> void:
			on_decline.call()
			modal.close())
	modal.body.add_child(keep)
	host.add_child(modal)


func reset_progress() -> void:
	_confirm("Сбросить прогресс?", "Все монеты и улучшения будут удалены. Это нельзя отменить.", "Сбросить",
			func(_modal: Modal) -> void:
				ClickerState.delete_save()
				_reload())


## Перезагрузка сцены: старое состояние больше не должно записываться поверх нового сохранения.
func _reload() -> void:
	state.saving_enabled = false
	host.get_tree().reload_current_scene()


func _confirm(title: String, text: String, ok_text: String, on_ok: Callable) -> void:
	var modal := Modal.new()
	modal.body.add_child(UiTheme.make_label(title, 50, UiTheme.TEXT, true))
	var note := UiTheme.make_label(text, 30, UiTheme.MUTE)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal.body.add_child(note)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiTheme.SPACE_M)
	modal.body.add_child(row)
	var cancel := UiTheme.make_button("Отмена", false, 32)
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(modal.close)
	row.add_child(cancel)
	var ok := UiTheme.make_button(ok_text, true, 32)
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ok.pressed.connect(func() -> void:
			ok.disabled = true               # двойной тап не должен выполнить действие дважды
			on_ok.call(modal))
	row.add_child(ok)
	host.add_child(modal)
