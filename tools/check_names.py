"""Ищет в функциях GDScript имена, которые нигде не объявлены (опечатки в локальных переменных, забытые переменные).
Эвристика без Godot: имена свойств движка, которых нет в проекте, выводятся как «под вопросом» — смотрите глазами.
Запуск: python3 tools/check_names.py"""
import sys as _sys

_sys.stdout.reconfigure(encoding="utf-8")   # на Windows консоль по умолчанию не UTF-8
import glob
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import check_refs as R  # noqa: E402

KEYWORDS = set("""if elif else while for in match return and or not is as await func var const static class extends class_name signal enum
true false null self pass break continue void int float bool String Array Dictionary Callable Variant PI TAU INF NAN super when preload
load""".split())
# свойства и методы движка, которыми скрипты пользуются без объекта
ENGINE_NAMES = set("""draw_set_transform get_node_or_null position size visible modulate scale rotation text disabled color value min_value max_value texture
custom_minimum_size mouse_filter pivot_offset size_flags_horizontal size_flags_vertical autowrap_mode horizontal_alignment
vertical_alignment anchor_left anchor_right anchor_top anchor_bottom offset_left offset_right offset_top offset_bottom grow_vertical
grow_horizontal global_position bus volume_db pitch_scale stream playing amount lifetime one_shot emitting amount_ratio
process_material draw_pass_1 mesh material_override cast_shadow light_energy rotation_degrees fov size_flags_stretch_ratio
expand_mode stretch_mode name modulate z_index font_size environment shadow_enabled directional_shadow_mode
clip_contents separation theme alignment fill_mode show_percentage step flat self_modulate bg_color border_color""".split())


def declared_in(text):
    names = set(re.findall(r"\b(?:var|const)\s+(\w+)", text))
    names |= set(re.findall(r"\bfor\s+(\w+)\s+in\b", text))
    for params in re.findall(r"\bfunc\s*\w*\s*\(([^)]*)\)", text):
        for p in params.split(","):
            m = re.match(r"\s*(\w+)", p)
            if m:
                names.add(m.group(1))
    names |= set(re.findall(r"\bas\s+(\w+)", text))
    names |= set(re.findall(r"\bmatch\s+.*\n(?:\s*(\w+)\s*:)?", text))
    return names


def main():
    classes = {}
    for path in R.FILES:
        text = open(path, encoding="utf8").read()
        c = R.Cls(path, text)
        classes[c.name] = c
    problems = []
    for c in classes.values():
        clean = R.strip_strings_and_comments(c.text)
        members = set(c.members) | set(c.funcs) | ENGINE_NAMES | KEYWORDS | R.BUILTIN_FUNCS | R.ENGINE | set(classes)
        base = classes.get(c.base)
        while base is not None:
            members |= set(base.members) | set(base.funcs)
            base = classes.get(base.base)
        # перечисления и внутренние классы
        members |= set(re.findall(r"^\t(\w+)\s*[,=]", clean, re.M)) | c.inner_members
        # разбиваем на функции по строкам верхнего уровня
        parts = re.split(r"(?m)^(?=(?:static\s+)?func\s)", clean)
        for part in parts:
            if not re.match(r"(?:static\s+)?func\s", part):
                continue
            local = declared_in(part) | members
            body_start = part.find(":\n")
            first = part.count("\n", 0, 0)
            for m in re.finditer(r"(?<![\w.$@&^])([a-z_]\w*)\b(?!\s*:=)", part):
                name = m.group(1)
                if name in local:
                    continue
                # ключи словарей-литералов "key": обработаны удалением строк; именованные аргументы не используются
                after = part[m.end():m.end() + 2]
                if after.strip().startswith(":") and not after.startswith(":="):
                    # метка match/ключ/тип аннотации — пропускаем
                    continue
                line = clean[:clean.find(part)].count("\n") + part[:m.start()].count("\n") + 1
                problems.append(f"{os.path.relpath(c.path, R.ROOT)}:{line}: ? имя '{name}' не объявлено")
    seen = set()
    for p in problems:
        if p not in seen:
            print(p)
            seen.add(p)
    print(f"\nпод вопросом: {len(seen)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
