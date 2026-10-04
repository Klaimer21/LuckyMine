class_name Tr
extends RefCounted
## Перевод интерфейса (кликер). Исходные строки в коде написаны по-русски и служат ключами; t() возвращает
## перевод на текущий язык (en, ru, zh). Строки с числами (%d, %s, %.1f) сопоставляются как шаблоны,
## поэтому t() можно вызывать уже на готовом тексте: Tr.t("Стадия 28") -> "Stage 28".

const LANGUAGES := [["en", "English"], ["ru", "Русский"], ["zh", "简体中文"]]

static var language := "en"
static var _templates: Dictionary = {}       # язык -> Array шаблонов {regex, translation}
static var _cache: Dictionary = {}           # (язык + текст) -> перевод


static func set_language(code: String) -> void:
	language = code
	_cache.clear()


static func detect_system_language() -> String:
	var system := OS.get_locale_language()
	if system == "zh":
		return "zh"
	if system == "ru":
		return "ru"
	return "en"


static func t(text: String) -> String:
	if language == "ru" or not _has_cyrillic(text):
		return text
	var key := language + "|" + text
	if _cache.has(key):
		return _cache[key]
	var result := _translate(text)
	_cache[key] = result
	return result


## Слова, которые в русском тексте стоят после числа и склоняются: ключ — форма «5 …» из исходной строки,
## значение — формы для 1, 2–4 и 5+ (21 — как 1, 12–14 — как 5).
const RU_PLURALS := {
	"алмазов": ["алмаз", "алмаза", "алмазов"],
	"жил": ["жила", "жилы", "жил"],
	"очков": ["очко", "очка", "очков"],
	"находок": ["находка", "находки", "находок"],
	"глыб": ["глыба", "глыбы", "глыб"],
	"динамита": ["динамит", "динамита", "динамита"],
	"монет": ["монета", "монеты", "монет"],
}
static var _placeholder: RegEx


## Перевод строки с числами сразу с подстановкой: Tr.fmt("+%d алмазов", [3]) -> "+3 алмаза" (ru), "+3 diamonds" (en).
## Исходные строки остаются ключами перевода, русские существительные склоняются по числу.
static func fmt(key: String, args: Array) -> String:
	var template := t(key)
	if language == "ru":
		template = _pluralize_ru(template, args)
	return template % args


static func ru_form(n: int, forms: Array) -> String:
	var tail := absi(n) % 100
	if tail >= 11 and tail <= 14:
		return forms[2]
	match tail % 10:
		1:
			return forms[0]
		2, 3, 4:
			return forms[1]
	return forms[2]


## Заменяет слово после %d на форму для соответствующего аргумента (аргументы идут по порядку всех %d, %s, %.Nf).
static func _pluralize_ru(template: String, args: Array) -> String:
	if _placeholder == null:
		_placeholder = RegEx.new()
		_placeholder.compile("%(?:%|\\.\\d+f|[ds])(?:\\s+([А-Яа-яЁё]+))?")
	var out := ""
	var last := 0
	var index := 0
	for found in _placeholder.search_all(template):
		var token := found.get_string()
		if token.begins_with("%%"):
			continue
		var word := found.get_string(1)
		if token.contains("d") and RU_PLURALS.has(word) and index < args.size():
			var space_end := found.get_start(1)
			out += template.substr(last, space_end - last) + ru_form(int(args[index]), RU_PLURALS[word])
			last = found.get_end(1)
		index += 1
	return out + template.substr(last)


static func _translate(text: String) -> String:
	var table: Dictionary = Translations.table(language)
	if table.has(text):
		return table[text]
	for tpl in _get_templates(table, language):
		var found: RegExMatch = tpl["regex"].search(text)
		if found != null:
			return _fill(tpl["translation"], found)
	return text


static func _get_templates(table: Dictionary, lang: String) -> Array:
	if _templates.has(lang):
		return _templates[lang]
	var list: Array = []
	for source in table:
		var src: String = source
		if not src.contains("%"):
			continue
		var regex := RegEx.new()
		if regex.compile("^" + _pattern(src) + "$") == OK:
			list.append({"regex": regex, "translation": table[source]})
	_templates[lang] = list
	return list


## Превращает строку с %d/%s/%.1f в регулярное выражение.
static func _pattern(source: String) -> String:
	var out := ""
	var i := 0
	while i < source.length():
		var c := source[i]
		if c == "%" and i + 1 < source.length():
			var n := source[i + 1]
			if n == "%":
				out += "%"
				i += 2
				continue
			if n == "d":
				out += "(-?\\d+)"
				i += 2
				continue
			if n == "s":
				out += "(.+?)"
				i += 2
				continue
			if n == "." and i + 3 < source.length() and source[i + 3] == "f":
				out += "(-?\\d+\\.\\d+)"
				i += 4
				continue
		if ".^$*+?()[]{}|\\".contains(c):
			out += "\\"
		out += c
		i += 1
	return out


## Подставляет найденные значения в шаблон перевода; текстовые значения переводятся рекурсивно.
static func _fill(translation: String, found: RegExMatch) -> String:
	var out := ""
	var group := 1
	var i := 0
	while i < translation.length():
		var c := translation[i]
		if c == "%" and i + 1 < translation.length():
			var n := translation[i + 1]
			if n == "%":
				out += "%"
				i += 2
				continue
			if n == "d" or n == "s":
				out += t(found.get_string(group)) if n == "s" else found.get_string(group)
				group += 1
				i += 2
				continue
			if n == "." and i + 3 < translation.length() and translation[i + 3] == "f":
				out += found.get_string(group)
				group += 1
				i += 4
				continue
		out += c
		i += 1
	return out


static func _has_cyrillic(text: String) -> bool:
	for i in text.length():
		var code := text.unicode_at(i)
		if code >= 0x400 and code <= 0x4FF:
			return true
	return false
