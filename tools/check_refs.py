"""Статическая проверка ссылок между скриптами GDScript без Godot: обращения к несуществующим членам своих классов,
неверное число аргументов, незнакомые функции без объекта. Не заменяет запуск, но ловит опечатки и устаревшие вызовы.
Запуск: python3 tools/check_refs.py  (код возврата 1, если что-то найдено)."""
import sys as _sys

_sys.stdout.reconfigure(encoding="utf-8")   # на Windows консоль по умолчанию не UTF-8
import glob
import os
import re
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
FILES = sorted(glob.glob(os.path.join(ROOT, "scripts", "**", "*.gd"), recursive=True))

# имена, которые есть у любых узлов/объектов движка: их у своих классов не ищем
ENGINE = set("""add_child remove_child queue_free get_children get_child get_parent get_tree get_viewport get_node connect disconnect emit
is_inside_tree is_instance_valid is_queued_for_deletion create_tween create_timer add_theme_color_override add_theme_constant_override add_theme_font_size_override
add_theme_font_override add_theme_stylebox_override get_theme_stylebox set_anchors_and_offsets_preset move_child
get_global_rect get_rect get_combined_minimum_size queue_redraw grab_focus visible modulate scale size position pivot_offset
custom_minimum_size text disabled pressed button_down button_up resized gui_input mouse_filter global_position rotation
size_flags_horizontal size_flags_vertical autowrap_mode horizontal_alignment color value min_value max_value texture
get_global_mouse_position is_connected has_signal set_process visible name process_mode get_window set_script call
tween_property tween_callback set_trans set_ease kill is_valid bind reload_current_scene change_scene_to_file quit
add_to_group is_in_group show hide z_index top_level clip_contents theme_type_variation tooltip_text focus_mode set_deferred
play stop playing stream volume_db pitch_scale bus finished closed timeout""".split())
BUILTIN_FUNCS = set("""print printerr push_error push_warning str int float bool abs absf absi sign signf clamp clampf clampi min max minf maxf
mini maxi floor floori ceil ceili round roundi sqrt pow log exp sin cos tan atan atan2 lerp lerpf lerp_angle smoothstep randf randi
randf_range randi_range randomize range len typeof is_equal_approx is_finite is_zero_approx linear_to_db db_to_linear fmod fposmod posmod
snappedf wrapf wrapi hash load preload assert Vector2 Vector3 Vector2i Color Rect2 Array Dictionary PackedFloat32Array PackedColorArray
PackedStringArray PackedVector2Array PackedVector3Array PackedInt32Array NodePath StringName Callable Transform3D Basis Quaternion AABB
Plane Projection ProjectSettings OS Engine Input DisplayServer RenderingServer AudioServer Time FileAccess ResourceLoader JSON Tween
Control Node Node3D Label Button Timer ColorRect TextureRect PanelContainer VBoxContainer HBoxContainer CenterContainer ScrollContainer
ProgressBar StyleBoxFlat Environment WorldEnvironment Camera3D DirectionalLight3D MeshInstance3D GPUParticles3D CPUParticles2D
ParticleProcessMaterial StandardMaterial3D ShaderMaterial Gradient GradientTexture1D GradientTexture2D NoiseTexture2D FastNoiseLite
ImageTexture Image BoxMesh SphereMesh QuadMesh PlaneMesh ArrayMesh SurfaceTool Label3D CanvasLayer AudioStreamPlayer AudioStreamWAV
RandomNumberGenerator ConfigFile TextServer InputEventKey InputEventMouseButton Viewport Font FontFile SystemFont StyleBox
MarginContainer GridContainer Panel LineEdit Container Control Resource RefCounted Object Texture2D Mesh Material
super _init _ready _process _input _unhandled_input _unhandled_key_input _notification _draw _gui_input _physics_process _exit_tree
Tr tr min_size_of func_ref floorf ceilf roundf draw_circle draw_arc draw_rect draw_line draw_polyline draw_colored_polygon
get_viewport_rect draw_style_box draw_string draw_texture draw_texture_rect draw_polygon draw_multiline warning_ignore else""".split())


class Cls:
    def __init__(self, path, text):
        self.path = path
        self.text = text
        m = re.search(r"^class_name\s+(\w+)", text, re.M)
        self.name = m.group(1) if m else os.path.splitext(os.path.basename(path))[0]
        m = re.search(r"^extends\s+(\w+)", text, re.M)
        self.base = m.group(1) if m else "RefCounted"
        self.funcs = {}      # имя -> (мин. аргументов, макс. аргументов или None)
        self.members = set()
        for m in re.finditer(r"^(?:static\s+)?func\s+(\w+)\s*\(", text, re.M):
            params = [p.strip() for p in split_args(call_args(text, m.end()))]
            required = sum(1 for p in params if "=" not in p)
            variadic = any(p.startswith("...") for p in params)
            self.funcs[m.group(1)] = (required, None if variadic else len(params))
        for m in re.finditer(r"^(?:const|var|signal|enum|static var)\s+(\w+)", text, re.M):
            self.members.add(m.group(1))
        for m in re.finditer(r"^class\s+(\w+)", text, re.M):
            self.members.add(m.group(1))
        # значения enum и пр. нам не нужны; inner-class поля внутри class X extends ... отдельно не разбираем
        self.inner_members = set(re.findall(r"^\t(?:var|const|signal)\s+(\w+)", text, re.M))

    def has(self, name):
        return name in self.funcs or name in self.members


def strip_strings_and_comments(text):
    out = []
    for line in text.split("\n"):
        line = re.sub(r'"(?:[^"\\]|\\.)*"', '""', line)
        line = re.sub(r"'(?:[^'\\]|\\.)*'", "''", line)
        line = line.split("#")[0]
        out.append(line)
    return "\n".join(out)


def split_args(s):
    depth, cur, args = 0, "", []
    for ch in s:
        if ch in "([{":
            depth += 1
        elif ch in ")]}":
            depth -= 1
        if ch == "," and depth == 0:
            args.append(cur)
            cur = ""
        else:
            cur += ch
    if cur.strip():
        args.append(cur)
    return args


def call_args(text, start):
    """Текст аргументов вызова, открывающая скобка в позиции start-1."""
    depth = 1
    i = start
    while i < len(text) and depth:
        if text[i] in "([{":
            depth += 1
        elif text[i] in ")]}":
            depth -= 1
        i += 1
    return text[start:i - 1]


def main():
    classes = {}
    for path in FILES:
        text = open(path, encoding="utf8").read()
        c = Cls(path, text)
        classes[c.name] = c
    problems = []

    def report(c, line_no, msg):
        problems.append(f"{os.path.relpath(c.path, ROOT)}:{line_no}: {msg}")

    for c in classes.values():
        clean = strip_strings_and_comments(c.text)
        lines = clean.split("\n")
        # типы переменных файла: имя -> класс
        types = {}
        for m in re.finditer(r"\bvar\s+(\w+)\s*(?::\s*(\w+))?\s*(?::?=\s*(\w+)\.new\()?", clean):
            t = m.group(2) or m.group(3)
            if t in classes:
                types[m.group(1)] = t
        for m in re.finditer(r"\b(\w+)\s*:\s*(\w+)\s*[,)=]", clean):
            if m.group(2) in classes:
                types.setdefault(m.group(1), m.group(2))
        chain_base = {"state": "ClickerState", "settings": "Settings"}
        for k, v in chain_base.items():
            types.setdefault(k, v)

        for ln, line in enumerate(lines, 1):
            # 1) Класс.член и объект.член для известных типов
            for m in re.finditer(r"\b(\w+)\.(\w+)\s*(\()?", line):
                obj, member, paren = m.group(1), m.group(2), m.group(3)
                cname = obj if obj in classes else types.get(obj)
                if cname is None:
                    continue
                target = classes[cname]
                if obj == "self":
                    continue
                if target.has(member) or member in ENGINE or member in ("new", "size", "keys", "values"):
                    ok = True
                else:
                    ok = False
                    # поле inner-класса или базовый Control/Node: допускаем, если класс наследует не RefCounted
                    if target.base not in ("RefCounted", "Object") and member in target.inner_members:
                        ok = True
                if not ok:
                    # у узлов остаётся шанс, что это встроенный член движка: помечаем отдельно
                    kind = "?" if target.base not in ("RefCounted", "Object") else "!"
                    report(c, ln, f"{kind} {obj}.{member}: нет в {cname}")
                    continue
                if paren and member in target.funcs:
                    start = m.end()
                    # позиция в многострочном тексте
                    pos = sum(len(x) + 1 for x in lines[:ln - 1]) + start
                    args = split_args(call_args(clean, pos))
                    lo, hi = target.funcs[member]
                    if len(args) < lo or (hi is not None and len(args) > hi):
                        report(c, ln, f"! {obj}.{member}(): {len(args)} арг., ожидается {lo}..{hi}")
            # 2) вызовы без объекта: должны быть в этом классе, базовом скрипте или встроенными
            for m in re.finditer(r"(?<![\w.])([a-z_]\w*)\s*\(", line):
                name = m.group(1)
                if name in BUILTIN_FUNCS or name in ("func", "if", "elif", "while", "for", "match", "return", "and", "or", "not", "in", "is", "as", "await"):
                    continue
                if re.match(r"\s*(static\s+)?func\s", line) or re.match(r"\s*signal\s", line):
                    continue
                if name in c.funcs or name in ENGINE:
                    pos = sum(len(x) + 1 for x in lines[:ln - 1]) + m.end()
                    args = split_args(call_args(clean, pos))
                    lo, hi = c.funcs.get(name, (0, None))
                    if name in c.funcs and (len(args) < lo or (hi is not None and len(args) > hi)):
                        report(c, ln, f"! {name}(): {len(args)} арг., ожидается {lo}..{hi}")
                    continue
                # у лямбд и локальных Callable имена бывают произвольные
                if re.search(r"\b(?:var|const)\s+" + re.escape(name) + r"\b", clean):
                    continue
                base = classes.get(c.base)
                if base is not None and base.has(name):
                    continue
                report(c, ln, f"? {name}(): не найдена функция")
    errors = [p for p in problems if ": !" in p]
    maybe = [p for p in problems if ": ?" in p]
    for p in errors:
        print(p)
    print("---- возможно, члены движка (проверить глазами) ----")
    for p in maybe:
        print(p)
    print(f"\nошибок: {len(errors)}, под вопросом: {len(maybe)}")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
