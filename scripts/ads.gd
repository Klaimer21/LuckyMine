class_name Ads
extends RefCounted
## Места под рекламу за награду. Сейчас вместо настоящего ролика показывается окно-заглушка с таймером;
## настоящий SDK (AdMob и т.п.) подключается в `_show_video()`: после просмотра вызвать `finish.call()`.
## Игроку без рекламы (`state.ads_removed`, будет покупкой) награда выдаётся сразу.

const STUB_SECONDS := 3.0
## Места: id -> {пауза между показами в секундах}. Награды выдаёт main (`_grant_ad_reward`).
const PLACEMENTS := {
	"offline": {"cooldown": 0.0},      # ×2 к монетам за время офлайна
	"rush": {"cooldown": 3600.0},      # золотая лихорадка ×7 на 5 минут
	"diamonds": {"cooldown": 900.0},   # алмазы
	"dynamite": {"cooldown": 1800.0},  # динамит
	"expedition": {"cooldown": 0.0},   # дособрать поход сразу
}

var host: Control
var state: ClickerState
var _busy := false                   # ролик уже идёт: второе нажатие (двойной тап) не запускает второй показ и вторую награду


func setup(host_node: Control, game_state: ClickerState) -> void:
	host = host_node
	state = game_state


## Показывает рекламу и по окончании вызывает on_reward. Закрытие раньше времени награды не даёт.
func is_busy() -> bool:
	return _busy


func request(placement: String, on_reward: Callable) -> void:
	if not PLACEMENTS.has(placement) or _busy:
		return
	if state.ads_removed:
		on_reward.call()
		return
	_busy = true
	_show_video(func() -> void:
			state.ads_watched += 1
			state.ad_mark(placement)
			on_reward.call(),
			func() -> void: _busy = false)


func _show_video(finish: Callable, on_closed: Callable) -> void:
	var modal := Modal.new()
	modal.body.add_child(UiTheme.make_label("Реклама", 50, UiTheme.TEXT, true))
	var note := UiTheme.make_label(Tr.t("Здесь будет рекламный ролик. Это заглушка для разработки."), 28, UiTheme.MUTE)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal.body.add_child(note)
	var bar := UiTheme.make_bar(0.0, UiTheme.BRASS, 14)
	modal.body.add_child(bar)
	var close_button := UiTheme.make_button("Закрыть", false, 30)
	close_button.pressed.connect(modal.close)
	modal.body.add_child(close_button)
	host.add_child(modal)
	var tween := modal.create_tween()
	tween.tween_property(bar, "value", 1.0, STUB_SECONDS)
	tween.tween_callback(func() -> void:
			modal.close()
			finish.call())
	modal.closed.connect(tween.kill)
	modal.closed.connect(on_closed)
