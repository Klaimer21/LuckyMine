"""Превращает картинки (нарисованные, сгенерированные нейросетью) в пиксель-арт под палитру LuckyMine.

Примеры:
    python tools/pixelize.py input.png -o assets/pixel/crusher_wood.png --size 48
    python tools/pixelize.py sheet.png --grid 3x2 --size 48 -o assets/pixel/machines/ --names crusher,conveyor,lab,blaster,winch,cart
    python tools/pixelize.py bork.png --size 96 --bg none -o assets/pixel/bork.png

Что делает: убирает фон (по цвету угла или чистому маджентовому #FF00FF), обрезает по контуру, масштабирует до нужного размера
(по большей стороне, пропорции сохраняются, сглаживание только при уменьшении), сводит цвета к палитре, делает прозрачность
строго 0/255 (без полупрозрачных краёв), по желанию добавляет тёмную обводку в 1 пиксель. Рядом с результатом пишет
предпросмотр крупным планом (*_preview.png: исходник слева, результат справа, x6).
"""
import argparse
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))


def load_palette(path):
    colors = []
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            colors.append(tuple(int(line[i:i + 2], 16) for i in (0, 2, 4)))
    return colors


def remove_background(img, mode, tolerance):
    """Возвращает RGBA с прозрачным фоном. mode: none, magenta, auto (цвет угла)."""
    img = img.convert("RGBA")
    if mode == "none":
        return img
    w, h = img.size
    px = img.load()
    key = (255, 0, 255) if mode == "magenta" else px[0, 0][:3]
    keys = [key]
    if mode == "checker":
        # «шахматка» вместо прозрачности (нарисованная картинкой): два главных цвета по краю кадра
        counts = {}
        for x, y in [(x, y) for x in range(w) for y in (0, 1, h - 2, h - 1)] + [(x, y) for y in range(h) for x in (0, 1, w - 2, w - 1)]:
            c = px[x, y][:3]
            if max(c) - min(c) < 36:
                k = tuple(v // 8 * 8 for v in c)
                counts[k] = counts.get(k, 0) + 1
        keys = sorted(counts, key=counts.get, reverse=True)[:2]
        keys = [tuple(v + 4 for v in k) for k in keys]

    if mode == "checker":
        lo, hi = min(k[0] for k in keys) - 24, max(k[0] for k in keys) + 24

        def close(c):
            # любой почти серый оттенок между двумя клетками шахматки (в том числе размытые стыки)
            return max(c[:3]) - min(c[:3]) < 34 and lo <= c[0] <= hi
    else:
        def close(c):
            return any(sum(abs(c[i] - k[i]) for i in range(3)) <= tolerance for k in keys)

    # заливка от краёв: фон соединён с границей кадра, внутренние пятна того же цвета остаются
    seen = bytearray(w * h)
    stack = [(x, y) for x in range(w) for y in (0, h - 1)] + [(x, y) for y in range(h) for x in (0, w - 1)]
    while stack:
        x, y = stack.pop()
        if x < 0 or y < 0 or x >= w or y >= h or seen[y * w + x]:
            continue
        if not close(px[x, y]):
            continue
        seen[y * w + x] = 1
        px[x, y] = (0, 0, 0, 0)
        stack.extend(((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))
    if mode == "magenta":
        # замкнутые пятна фона (между ножками, трубами) и розово-фиолетовая кайма от сглаживания краёв: любой «маджентовый» оттенок
        for y in range(h):
            for x in range(w):
                r, g, b, a = px[x, y]
                if a > 0 and r - g > 50 and b - g > 50 and abs(r - b) < 90:
                    px[x, y] = (0, 0, 0, 0)
    return img


def crop_to_content(img):
    box = img.getchannel("A").getbbox()
    return img.crop(box) if box is not None else img


def fit(img, size):
    """Вписывает в квадрат size x size по большей стороне, по центру; низ прижат к краю (спрайты стоят на земле)."""
    scale = min(size / img.width, size / img.height)
    w, h = max(1, round(img.width * scale)), max(1, round(img.height * scale))
    # уменьшение с усреднением даёт аккуратные пиксели; увеличение: ближайший сосед
    method = Image.LANCZOS if scale < 1.0 else Image.NEAREST
    small = img.resize((w, h), method)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.paste(small, ((size - w) // 2, size - h), small)
    return out


def fit_mode(img, size, palette, alpha_threshold, block=4):
    """Вписывает в квадрат, беря для каждого пикселя самый частый цвет палитры в блоке block x block исходных точек.
    Даёт ровные плоские области и чёткие границы (лучше усреднения для пиксель-арта)."""
    scale = min(size / img.width, size / img.height)
    w, h = max(1, round(img.width * scale)), max(1, round(img.height * scale))
    big = img.resize((w * block, h * block), Image.LANCZOS)
    big = quantize(big, palette, alpha_threshold)
    bp = big.load()
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    op = out.load()
    ox, oy = (size - w) // 2, size - h
    for y in range(h):
        for x in range(w):
            counts = {}
            solid = 0
            for dy in range(block):
                for dx in range(block):
                    c = bp[x * block + dx, y * block + dy]
                    if c[3] > 0:
                        solid += 1
                        counts[c] = counts.get(c, 0) + 1
            if solid * 2 >= block * block:
                op[ox + x, oy + y] = max(counts, key=counts.get)
    return out


def quantize(img, palette, alpha_threshold):
    px = img.load()
    cache = {}
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            if a < alpha_threshold:
                px[x, y] = (0, 0, 0, 0)
                continue
            key = (r >> 2, g >> 2, b >> 2)
            if key not in cache:
                cache[key] = min(palette, key=lambda c: (c[0] - r) ** 2 * 0.30 + (c[1] - g) ** 2 * 0.59 + (c[2] - b) ** 2 * 0.11)
            px[x, y] = cache[key] + (255,)
    return img


def outline(img, color):
    w, h = img.size
    src = img.copy()
    sp = src.load()
    op = img.load()
    for y in range(h):
        for x in range(w):
            if sp[x, y][3] == 0:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h and sp[nx, ny][3] > 0:
                        op[x, y] = color + (255,)
                        break
    return img


def process(img, args, palette):
    img = remove_background(img, args.bg, args.tolerance)
    if args.fixed:
        # кадры анимации: один общий масштаб, без обрезки по содержимому (размеры кадров между собой сохраняются)
        side = max(img.width, img.height)
        square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
        square.paste(img, ((side - img.width) // 2, (side - img.height) // 2))
        img = square
    else:
        img = crop_to_content(img)
    inner = args.size - (2 if args.outline else 0)
    if args.method == "mode":
        sprite = fit_mode(img, inner, palette, args.alpha_threshold)
    else:
        sprite = quantize(fit(img, inner), palette, args.alpha_threshold)
    if args.outline:
        padded = Image.new("RGBA", (args.size, args.size), (0, 0, 0, 0))
        padded.paste(sprite, (1, 1), sprite)
        sprite = outline(padded, tuple(int(args.outline[i:i + 2], 16) for i in (0, 2, 4)))
    return sprite


def preview(original, result, path, zoom=6):
    original = original.convert("RGBA")
    scale = result.height * zoom / original.height
    left = original.resize((max(1, round(original.width * scale)), result.height * zoom), Image.LANCZOS)
    right = result.resize((result.width * zoom, result.height * zoom), Image.NEAREST)
    sheet = Image.new("RGBA", (left.width + right.width + 24, right.height), (21, 34, 29, 255))
    sheet.paste(left, (0, 0), left)
    sheet.paste(right, (left.width + 24, 0), right)
    sheet.save(path)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("input")
    parser.add_argument("-o", "--output", required=True, help="файл (или папка для --grid)")
    parser.add_argument("--size", type=int, default=48, help="сторона готового спрайта в пикселях")
    parser.add_argument("--palette", default=os.path.join(HERE, "palette.hex"))
    parser.add_argument("--bg", choices=["auto", "magenta", "checker", "none"], default="auto", help="как убирать фон")
    parser.add_argument("--tolerance", type=int, default=60, help="допуск цвета фона (сумма отличий по RGB)")
    parser.add_argument("--alpha-threshold", type=int, default=128)
    parser.add_argument("--outline", default="", help="цвет обводки (hex, например 0b1210); пусто: без обводки")
    parser.add_argument("--grid", default="", help="лист из нескольких картинок, например 3x2 (колонки x строки)")
    parser.add_argument("--names", default="", help="имена ячеек через запятую (для --grid)")
    parser.add_argument("--method", choices=["mode", "average"], default="mode", help="mode: самый частый цвет в блоке (чётче); average: усреднение")
    parser.add_argument("--inset", type=int, default=0, help="срезать столько пикселей по краям каждой ячейки листа (линии сетки)")
    parser.add_argument("--fixed", action="store_true", help="не обрезать по содержимому, общий масштаб для кадров анимации")
    parser.add_argument("--no-preview", action="store_true")
    args = parser.parse_args()
    palette = load_palette(args.palette)
    source = Image.open(args.input).convert("RGBA")
    if args.grid:
        cols, rows = (int(v) for v in args.grid.lower().split("x"))
        names = [n for n in args.names.split(",") if n]
        os.makedirs(args.output, exist_ok=True)
        cw, ch = source.width // cols, source.height // rows
        for r in range(rows):
            for c in range(cols):
                index = r * cols + c
                name = names[index] if index < len(names) else "cell_%d" % index
                cell = source.crop((c * cw + args.inset, r * ch + args.inset, (c + 1) * cw - args.inset, (r + 1) * ch - args.inset))
                result = process(cell, args, palette)
                path = os.path.join(args.output, name + ".png")
                result.save(path)
                if not args.no_preview:
                    preview(cell, result, os.path.join(args.output, name + "_preview.png"))
                print("готово:", path)
        return
    result = process(source, args, palette)
    os.makedirs(os.path.dirname(os.path.abspath(args.output)), exist_ok=True)
    result.save(args.output)
    if not args.no_preview:
        preview(source, result, os.path.splitext(args.output)[0] + "_preview.png")
    print("готово:", args.output)


if __name__ == "__main__":
    sys.exit(main())
