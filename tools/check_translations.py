"""Проверка перевода: находит русские строки в коде и данных, для которых нет записи в EN или ZH (scripts/translations.gd),
и ключи с дублями. Запуск: python3 tools/check_translations.py   (код возврата 1, если есть пропуски)."""
import sys as _sys

_sys.stdout.reconfigure(encoding="utf-8")   # на Windows консоль по умолчанию не UTF-8
import glob
import os
import re
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
CYR = re.compile(r"[А-Яа-яЁё]")
LITERAL = re.compile(r'"((?:[^"\\]|\\.)*)"')


def table_keys(text, name):
    block = re.search(r"const %s := \{\n(.*?)\n\}" % name, text, re.S).group(1)
    return re.findall(r'^\t"((?:[^"\\]|\\.)*)": ', block, re.M)


def main():
    tr_path = os.path.join(ROOT, "scripts", "translations.gd")
    text = open(tr_path, encoding="utf-8").read()
    en, zh = table_keys(text, "EN"), table_keys(text, "ZH")
    problems = 0
    for name, keys in (("EN", en), ("ZH", zh)):
        dups = {k for k in keys if keys.count(k) > 1}
        if dups:
            problems += len(dups)
            print(f"{name}: дубли ключей:", sorted(dups))
    have_en, have_zh = set(en), set(zh)
    missing = {}
    for path in glob.glob(os.path.join(ROOT, "scripts", "**", "*.gd"), recursive=True):
        if path.endswith("translations.gd") or path.endswith("tr.gd"):
            continue
        for number, line in enumerate(open(path, encoding="utf-8").read().split("\n"), 1):
            stripped = line.strip()
            if stripped.startswith("#") or stripped.startswith("##"):
                continue
            code = line.split("#")[0] if "#" in line and '"' not in line.split("#")[0][-1:] else line
            for m in LITERAL.finditer(code):
                s = m.group(1)
                if not CYR.search(s):
                    continue
                key = s.replace('\\"', '"')
                # технические строки: пути, id, формат без смысла
                if key.startswith("res://") or key.startswith("user://"):
                    continue
                if key not in have_en or key not in have_zh:
                    where = "EN+ZH" if key not in have_en and key not in have_zh else ("EN" if key not in have_en else "ZH")
                    missing.setdefault(key, (where, os.path.relpath(path, ROOT), number))
    for key, (where, path, number) in sorted(missing.items(), key=lambda kv: kv[1][1:]):
        print(f"нет перевода [{where}] {path}:{number}: {key}")
    problems += len(missing)
    print(f"\nключей: EN {len(en)}, ZH {len(zh)}; без перевода: {len(missing)}")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
