#!/bin/sh
# Статические проверки без Godot: синтаксис GDScript и полнота переводов.
cd "$(dirname "$0")/.." || exit 1
status=0
# python3 на Windows часто называется python
PY=$(command -v python3 || command -v python) || { echo "нужен python3"; exit 1; }
if command -v gdparse >/dev/null 2>&1; then
	for f in scripts/*.gd scripts/*/*.gd tests/*.gd; do
		gdparse "$f" >/dev/null 2>&1 || { echo "gdparse: $f"; status=1; }
	done
else
	echo "gdparse не найден (pip install gdtoolkit): проверка синтаксиса пропущена"
fi
"$PY" tools/check_refs.py >/dev/null || { echo "check_refs: найдены ошибки ссылок"; status=1; }
"$PY" tools/check_names.py | grep -q "под вопросом: 0" || { echo "check_names: есть необъявленные имена"; status=1; }
"$PY" tools/check_translations.py | tail -1
"$PY" tools/check_translations.py | grep -q "без перевода: 0" || status=1
exit $status
