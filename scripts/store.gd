class_name Store
extends RefCounted
## Покупки за деньги. Сейчас вместо магазина показывается окно-заглушка: «Купить (тест)» сразу выдаёт покупку.
## Настоящая оплата (Google Play Billing / StoreKit) подключается в `_show_checkout()`: после успешной оплаты вызвать `finish.call()`.

## Товары: id -> название и цена для показа (настоящую цену даст магазин).
const PRODUCTS := {
	"miner_pass": {"name": "Золотой пропуск", "price": "4.99 $"},
}

var host: Control
var _busy := false


func setup(host_node: Control) -> void:
	host = host_node


func request(product: String, on_bought: Callable) -> void:
	if not PRODUCTS.has(product) or _busy:
		return
	_busy = true
	_show_checkout(product, on_bought, func() -> void: _busy = false)


func _show_checkout(product: String, finish: Callable, on_closed: Callable) -> void:
	var modal := Modal.new()
	var info: Dictionary = PRODUCTS[product]
	modal.body.add_child(UiTheme.make_label(Tr.t(str(info["name"])), 48, UiTheme.TEXT, true))
	modal.body.add_child(UiTheme.make_label(str(info["price"]), 36, UiTheme.BRASS))
	var note := UiTheme.make_label(Tr.t("Здесь будет оплата в магазине. Это заглушка для разработки."), 28, UiTheme.MUTE)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal.body.add_child(note)
	var buy := UiTheme.make_button("Купить (тест)", true, 32)
	buy.pressed.connect(func() -> void:
			finish.call()
			modal.close())
	modal.body.add_child(buy)
	var cancel := UiTheme.make_button("Отмена", false, 30)
	cancel.pressed.connect(modal.close)
	modal.body.add_child(cancel)
	modal.closed.connect(on_closed)
	host.add_child(modal)
