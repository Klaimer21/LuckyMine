"""Исправления кириллицы в Pixelify Sans (assets/fonts/PixelifySans-*.ttf). Запуск: python tools/fix_pixel_font.py [папка_вывода]
- строчные ы, ь, ъ в оригинале высотой с заглавные (слово «Новые» читалось как «НовЫе»): строятся из заглавных Ы, Ь, Ъ,
  сжатых по высоте до строчных (по пиксельной сетке: верх заглавной → верх строчной, нижние детали на месте);
- строчные в и д в оригинале — маленькие «В» и «Д» с вырезом, на телефоне читались как латинские «e» и «a»: строятся
  из заглавных В и Д, равномерно сжатых до высоты строчных (хвостики «д» под строкой остаются);
- у заглавной К лишний второй контур над буквой (выглядела как «Ќ»): остаётся только сама буква.
Скрипт идемпотентный: повторный запуск ничего не портит."""
import os
import sys

from fontTools.ttLib import TTFont

HERE = os.path.dirname(os.path.abspath(__file__))
FONTS = ["PixelifySans-Body.ttf", "PixelifySans-Display.ttf"]
LOWER_FROM_UPPER = {"uni044B": "uni042B", "uni044C": "uni042C", "uni044A": "uni042A"}   # ы ь ъ ← Ы Ь Ъ
SCALED_FROM_UPPER = {"uni0432": "uni0412", "uni0434": "uni0414"}                     # в д ← В Д (сжатие по высоте)


def squash_y(y, cap, xh, bowl_top):
    """Верх заглавной (cap) переезжает на высоту строчных (xh); всё, что ниже верха «брюшка» (bowl_top), остаётся."""
    if y <= bowl_top:
        return y
    return int(round(bowl_top + (y - bowl_top) * (xh - bowl_top) / float(cap - bowl_top)))


def fix(path, out_path):
    font = TTFont(path)
    glyf = font["glyf"]
    cap = font["OS/2"].sCapHeight if font["OS/2"].sCapHeight < 690 else None
    xh = font["OS/2"].sxHeight
    for lower, upper in LOWER_FROM_UPPER.items():
        src = glyf[upper]
        coords, ends, flags = src.getCoordinates(glyf)
        top = max(y for _, y in coords)
        # верх «брюшка» мягкого знака — самая высокая горизонталь ниже 60% высоты
        bowl_top = max(y for _, y in coords if y < top * 0.6)
        new = [(x, squash_y(y, top, xh, bowl_top)) for x, y in coords]
        glyph = glyf[lower]
        glyph.__dict__.clear()
        import copy
        glyph.__dict__.update(copy.deepcopy(src.__dict__))
        glyph.coordinates = type(coords)(new)
        glyph.recalcBounds(glyf)
        font["hmtx"][lower] = font["hmtx"][upper]
    for lower, upper in SCALED_FROM_UPPER.items():
        src = glyf[upper]
        coords, ends, flags = src.getCoordinates(glyf)
        top = max(y for _, y in coords)
        new = [(x, int(round(y * xh / float(top))) if y > 0 else y) for x, y in coords]
        import copy
        glyph = glyf[lower]
        glyph.__dict__.clear()
        glyph.__dict__.update(copy.deepcopy(src.__dict__))
        glyph.coordinates = type(coords)(new)
        glyph.recalcBounds(glyf)
        font["hmtx"][lower] = font["hmtx"][upper]
    # К: оставить один контур (саму букву), убрать лишний над ней
    k = glyf["uni041A"]
    if k.numberOfContours > 1:
        coords, ends, flags = k.getCoordinates(glyf)
        start = 0
        keep = None
        for end in ends:
            pts = coords[start:end + 1]
            if max(y for _, y in pts) <= 700:
                keep = (start, end)
            start = end + 1
        if keep is not None:
            s, e = keep
            k.coordinates = type(coords)(list(coords[s:e + 1]))
            k.flags = k.flags[s:e + 1]
            k.endPtsOfContours = [e - s]
            k.numberOfContours = 1
            k.program = k.program if hasattr(k, "program") else None
            k.recalcBounds(glyf)
    font.save(out_path)


def main():
    out_dir = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "..", "assets", "fonts")
    for name in FONTS:
        fix(os.path.join(HERE, "..", "assets", "fonts", name), os.path.join(out_dir, name))
        print("fixed", name)


if __name__ == "__main__":
    main()
