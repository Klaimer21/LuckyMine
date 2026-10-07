class_name CloudSave
extends Node
## Облачное сохранение в Google Play Играх (Saved Games): прогресс привязан к аккаунту игрока, переслать его другому нельзя.
## Работает только на Android с плагином GodotPlayGameServices (addons/GodotPlayGameServices); на ПК и в редакторе слой пустой
## (`available()` ложно), а прогресс переносится кодом (ClickerState.export_code). Проект и шаги настройки: docs/CLOUD_SAVE.md.
##
## Что происходит: при запуске игра входит в Play Игры (молча, если игрок уже вошёл), читает облачное сохранение и сравнивает его с
## локальным по заработанному за всё время (`lifetime_earned`). У кого больше, тот и выигрывает: если больше в облаке, спрашиваем
## игрока (сигнал `remote_found`), если больше на устройстве, записываем в облако. Дальше запись при сворачивании игры, после сброса
## («Новая шахта», «Новая планета») и раз в пять минут. Облако никогда не перезаписывается меньшим прогрессом без согласия игрока.

signal status_changed
signal remote_found(remote: Dictionary, text: String)       # в облаке прогресс больше: main спрашивает игрока
signal synced

const FILE_NAME := "luckymine_save"
const AUTO_SYNC_SECONDS := 300.0
const MARGIN := 1.02                                         # на сколько процентов прогресс должен отличаться, чтобы считаться другим

var state: ClickerState
var settings: Settings
var signed_in := false
var busy := false
var last_error := ""

var _ready_plugin := false
var _sign_in: Node
var _snapshots: Node
var _timer := 0.0
var _manual := false                  # загрузка запущена кнопкой «Синхронизировать»
var _remote_lifetime := 0.0           # прогресс, который сейчас лежит в облаке (известен после первого чтения)
var _resolving := false


## Есть ли облако на этом устройстве (Android и плагин на месте).
static func available() -> bool:
	return OS.get_name() == "Android" and Engine.has_singleton("GodotPlayGameServices")


func setup(game_state: ClickerState, game_settings: Settings) -> CloudSave:
	state = game_state
	settings = game_settings
	return self


## Запуск: вход в Play Игры и первое чтение. Вызывается один раз после загрузки игры.
func start() -> void:
	if not available() or not settings.cloud_enabled:
		return
	# плагин и его клиенты берём по имени и пути, а не по идентификаторам: так скрипт собирается и без плагина (ПК, тесты)
	var autoload := get_node_or_null("/root/GodotPlayGameServices")
	if autoload == null or int(autoload.call("initialize")) != 0:
		last_error = "plugin"
		status_changed.emit()
		return
	_ready_plugin = true
	_sign_in = load("res://addons/GodotPlayGameServices/scripts/sign_in/sign_in_client.gd").new()
	add_child(_sign_in)
	_sign_in.user_authenticated.connect(_on_authenticated)
	_snapshots = load("res://addons/GodotPlayGameServices/scripts/snapshots/snapshots_client.gd").new()
	add_child(_snapshots)
	_snapshots.game_loaded.connect(_on_loaded)
	_snapshots.game_saved.connect(_on_saved)
	_snapshots.conflict_emitted.connect(_on_conflict)
	_sign_in.is_authenticated()


## Войти вручную (кнопка в настройках).
func sign_in() -> void:
	if _ready_plugin:
		_sign_in.sign_in()


## Кнопка «Синхронизировать сейчас»: прочитать облако и выбрать, куда идти данным.
func sync_now() -> void:
	if not (_ready_plugin and signed_in) or busy:
		return
	_manual = true
	busy = true
	status_changed.emit()
	_snapshots.load_game(FILE_NAME, true)


## Записать локальный прогресс в облако (если он не меньше облачного).
func upload() -> void:
	if not (_ready_plugin and signed_in) or busy or not settings.cloud_enabled:
		return
	var text := state.serialize()
	if _remote_lifetime > 0.0 and decide(summary_of(text), {"valid": true, "lifetime": _remote_lifetime, "last_seen": 0.0}) == "ask":
		return                         # в облаке больше: без согласия игрока не затираем
	busy = true
	status_changed.emit()
	_snapshots.save_game(FILE_NAME, "LuckyMine", text.to_utf8_buffer(), int(state.play_seconds * 1000.0), int(log(maxf(state.lifetime_earned, 1.0)) / log(10.0) * 10.0))


func _process(delta: float) -> void:
	if not signed_in:
		return
	_timer += delta
	if _timer >= AUTO_SYNC_SECONDS:
		_timer = 0.0
		upload()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		upload()


# ---------- Обратные вызовы плагина ----------

func _on_authenticated(ok: bool) -> void:
	signed_in = ok
	status_changed.emit()
	if ok:
		busy = true
		_snapshots.load_game(FILE_NAME, true)


func _on_loaded(snapshot) -> void:
	busy = false
	var forced := _manual
	_manual = false
	var text := ""
	if snapshot != null and (snapshot.content as PackedByteArray).size() > 0:
		text = (snapshot.content as PackedByteArray).get_string_from_utf8()
	var remote := summary_of(text)
	var local := summary_of(state.serialize())
	if remote["valid"]:
		_remote_lifetime = float(remote["lifetime"])
	match decide(local, remote):
		"upload":
			upload()
		"ask":
			if forced or float(remote["last_seen"]) > settings.cloud_declined:
				remote_found.emit(remote, text)
		_:
			if forced:
				synced.emit()
	status_changed.emit()


func _on_saved(ok: bool, _name: String, _description: String) -> void:
	busy = false
	if ok:
		settings.cloud_last_sync = ClickerState.now()
		settings.save()
		last_error = ""
		synced.emit()
	else:
		last_error = "save"
	status_changed.emit()


## Конфликт записи (два устройства): остаётся версия с большим прогрессом.
func _on_conflict(conflict) -> void:
	if _resolving:
		return
	var a := summary_of((conflict.conflicting_snapshot.content as PackedByteArray).get_string_from_utf8())
	var b := summary_of((conflict.server_snapshot.content as PackedByteArray).get_string_from_utf8())
	var best: PackedByteArray = conflict.conflicting_snapshot.content
	if decide(a, b) == "ask":
		best = conflict.server_snapshot.content
	_resolving = true
	_snapshots.save_game(FILE_NAME, "LuckyMine", best, int(state.play_seconds * 1000.0), 0)
	get_tree().create_timer(5.0).timeout.connect(func() -> void: _resolving = false)


# ---------- Выбор версии (без плагина, проверяется тестами) ----------

## Что нужно знать о сохранении, чтобы сравнить: годится ли оно и сколько заработано за всё время.
static func summary_of(text: String) -> Dictionary:
	var empty := {"valid": false, "lifetime": 0.0, "last_seen": 0.0, "planet": 0, "total": 0.0}
	if text == "":
		return empty
	var outer = JSON.parse_string(text)
	if typeof(outer) != TYPE_DICTIONARY or typeof(outer.get("payload")) != TYPE_STRING:
		return empty
	if str(outer.get("sig", "")) != ClickerState._sign(outer["payload"]):
		return empty
	var data = JSON.parse_string(outer["payload"])
	if typeof(data) != TYPE_DICTIONARY:
		return empty
	var lifetime := ClickerState._num(data.get("lifetime_earned"), 0.0)
	return {"valid": true, "lifetime": maxf(lifetime, ClickerState._num(data.get("total_earned"), 0.0)),
			"last_seen": ClickerState._num(data.get("last_seen"), 0.0), "planet": int(ClickerState._num(data.get("planet"), 0.0)),
			"total": ClickerState._num(data.get("total_earned"), 0.0)}


## upload — на устройстве больше (или облако пустое), ask — в облаке больше, same — разницы нет.
static func decide(local: Dictionary, remote: Dictionary) -> String:
	if not bool(remote["valid"]):
		return "upload"
	if not bool(local["valid"]):
		return "ask"
	var l := float(local["lifetime"])
	var r := float(remote["lifetime"])
	if r > l * MARGIN + 1.0:
		return "ask"
	if l > r * MARGIN + 1.0:
		return "upload"
	return "same"
