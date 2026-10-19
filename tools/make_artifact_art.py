"""Артефакты (24x24, палитра tools/palette.hex): кирка, каска, компас, фонарь, счёты, огниво, сердце горы, корона.
Рисуются теми же фигурами, что и питомцы (Canvas из make_pet_art.py). Запуск: python tools/make_artifact_art.py"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_pet_art as art  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "pixel", "artifacts")


def pick():
    c = art.Canvas()
    for i in range(13):                                  # рукоять по диагонали снизу слева вверх
        c.px(4 + i, 20 - i, "7a4d2c"); c.px(5 + i, 20 - i, "a86a3d")
    for k in range(-6, 6):                               # железная голова поперёк рукояти, чуть изогнута
        bend = 1 if abs(k) < 3 else 0
        c.px(16 + k, 8 + k - bend, "aab8c4"); c.px(16 + k, 9 + k - bend, "7b8896")
    c.px(10, 2, "d9e4ec"); c.px(21, 13, "d9e4ec")
    c.px(4, 21, "e0b64a"); c.px(5, 21, "e0b64a")         # латунное навершие
    return c


def helmet():
    c = art.Canvas()
    c.ellipse(12, 14, 9, 7, "c9a45c", "7d6a3e", "f3d98a")
    c.rect(2, 15, 21, 18, "7d6a3e"); c.rect(2, 15, 21, 15, "c9a45c")
    for y in range(15, 24):
        for x in range(24):
            if y > 18:
                c.img.putpixel((x, y), (0, 0, 0, 0))
    c.rect(10, 8, 14, 11, "4a5560"); c.ellipse(12, 9.5, 1.6, 1.4, "ffd84a")   # фонарик
    return c


def compass():
    c = art.Canvas()
    c.ellipse(12, 12, 9, 9, "c78a55", "7a4d2c", "f3d98a")
    c.ellipse(12, 12, 7, 7, "efe8d6", "d8c9a8")
    c.line([(12, 6), (12, 7), (12, 8), (12, 9), (12, 10)], "c0553f")
    c.line([(12, 13), (12, 14), (12, 15), (12, 16), (12, 17)], "4a5560")
    c.px(12, 12, "0b1210"); c.rect(11, 2, 13, 3, "c78a55")
    return c


def lamp():
    c = art.Canvas()
    c.rect(9, 2, 15, 3, "4a5560"); c.px(12, 1, "4a5560")
    c.rect(7, 4, 17, 5, "7a4d2c")
    c.rect(8, 6, 16, 17, "ffd84a"); c.rect(9, 7, 11, 16, "fffbe8"); c.rect(14, 6, 16, 17, "e0b64a")
    c.rect(7, 6, 7, 17, "7a4d2c"); c.rect(17, 6, 17, 17, "7a4d2c"); c.rect(12, 6, 12, 17, "a86a3d")
    c.rect(6, 18, 18, 20, "7a4d2c"); c.rect(6, 18, 18, 18, "a86a3d")
    return c


def abacus():
    c = art.Canvas()
    c.rect(3, 3, 20, 5, "7a4d2c"); c.rect(3, 18, 20, 20, "7a4d2c")
    c.rect(3, 3, 4, 20, "5a3a22"); c.rect(19, 3, 20, 20, "5a3a22")
    for row, beads in ((8, (6, 8, 14)), (12, (7, 9, 11, 16)), (16, (6, 13, 15))):
        c.line([(x, row) for x in range(5, 19)], "aab8c4")
        for b in beads:
            c.rect(b, row - 1, b + 1, row + 1, "e0b64a"); c.px(b, row - 1, "f3d98a")
    return c


def flint():
    c = art.Canvas()
    c.ellipse(9, 15, 6, 5, "4a5560", "2c3238", "7b8896")                  # кремень
    c.rect(13, 13, 21, 16, "aab8c4"); c.rect(13, 13, 21, 13, "d9e4ec"); c.rect(19, 12, 21, 17, "7b8896")   # кресало
    for x, y in ((15, 9), (17, 7), (14, 6), (18, 10), (16, 4)):
        c.px(x, y, "ffd84a")
    c.px(16, 8, "e7794f"); c.px(15, 5, "fffbe8")
    return c


def heart():
    c = art.Canvas()
    c.ellipse(8.5, 9.5, 5, 5, "c0553f", "8a3d2a", "e7794f")
    c.ellipse(15.5, 9.5, 5, 5, "c0553f", "8a3d2a", "e7794f")
    for y in range(10, 22):
        half = max(0, 10 - (y - 10))
        for x in range(12 - half, 12 + half):
            c.px(x, y, "c0553f" if x < 14 else "8a3d2a")
    c.rect(10, 8, 13, 13, "7fdbe6"); c.rect(10, 8, 11, 9, "c8f5fa"); c.rect(12, 12, 13, 13, "3a7c8c")   # кристалл в сердце
    return c


def crown():
    c = art.Canvas()
    for cx in (5, 12, 18):                               # зубцы
        for y in range(6, 13):
            half = (y - 6) // 2
            for x in range(cx - half, cx + half + 1):
                c.px(x, y, "e0b64a" if x <= cx else "c9a45c")
        c.px(cx, 5, "ffd84a")
    c.rect(3, 13, 20, 19, "e0b64a"); c.rect(3, 18, 20, 19, "c9a45c"); c.rect(3, 13, 20, 13, "f3d98a")
    c.rect(6, 15, 7, 16, "c0553f"); c.rect(11, 15, 12, 16, "7fdbe6"); c.rect(16, 15, 17, 16, "4fd44a")
    return c


def main():
    os.makedirs(OUT, exist_ok=True)
    art.OUT = OUT
    for name, fn in (("pick", pick), ("helmet", helmet), ("compass", compass), ("lamp", lamp), ("abacus", abacus),
                     ("flint", flint), ("heart", heart), ("crown", crown)):
        fn().save(name)
    print("saved 8 artifacts")


if __name__ == "__main__":
    main()
