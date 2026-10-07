"""Собирает фоны зон из пиксельных картинок 360x200 (assets/pixel/bg/zone_N.png).

Каждая картинка увеличивается ровно в 3 раза без сглаживания (1080x600, пиксель арта = 3 пикселя холста) и кладётся
полосой за стол на прежний тёмный фон зоны (assets/bg/background_N.jpg); сверху и снизу полоса плавно тает.
Результат: assets/bg/background_N.png (1080x1920), игра выбирает png раньше jpg.

    python tools/make_pixel_bg.py
"""
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# зона игры -> номер картинки (zone_N.png); зоны без картинки остаются прежними
MAPPING = {1: 1, 2: 2, 3: 6, 4: 3, 5: 4, 6: 7}
SCALE = 3
BAND_TOP = 0             # верх полосы на холсте 1080x1920: стол закрывает середину (около 540..1340), видны верх и низ
FADE = 90                # высота плавного края полосы, пикселей


def main() -> int:
    for biome, zone in MAPPING.items():
        base_path = os.path.join(ROOT, "assets/bg/background_%d.jpg" % biome)
        art_path = os.path.join(ROOT, "assets/pixel/bg/zone_%d.png" % zone)
        if not (os.path.exists(base_path) and os.path.exists(art_path)):
            print("пропуск зоны", biome)
            continue
        base = Image.open(base_path).convert("RGBA").resize((1080, 1920), Image.LANCZOS)
        art = Image.open(art_path).convert("RGBA")
        art = art.resize((art.width * SCALE, art.height * SCALE), Image.NEAREST)
        mask = Image.new("L", art.size, 255)
        px = mask.load()
        for y in range(art.height):
            edge = art.height - 1 - y          # тает только нижний край: сверху полоса упирается в край экрана
            a = 255 if edge >= FADE else int(255 * edge / FADE)
            for x in range(art.width):
                px[x, y] = a
        base.paste(art, (0, BAND_TOP), mask)
        out = os.path.join(ROOT, "assets/bg/background_%d.png" % biome)
        base.convert("RGB").save(out)
        print("готово:", out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
