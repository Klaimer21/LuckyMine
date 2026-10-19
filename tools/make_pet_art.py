"""Питомцы «Подземных друзей» и приманка (24x24, палитра tools/palette.hex). Каждый зверь собирается из простых фигур
(тело-эллипс с тенью снизу справа и бликом сверху слева, уши, лапы, хвосты, крылья), потом обводится тёмным контуром.
Запуск: python tools/make_pet_art.py"""
import os
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "assets", "pixel", "pets")
OUTLINE = (11, 18, 16, 255)


def hexc(v):
    return (int(v[0:2], 16), int(v[2:4], 16), int(v[4:6], 16), 255)


class Canvas:
    def __init__(self):
        self.img = Image.new("RGBA", (24, 24), (0, 0, 0, 0))

    def px(self, x, y, c):
        if 0 <= x < 24 and 0 <= y < 24:
            self.img.putpixel((int(x), int(y)), hexc(c) if isinstance(c, str) else c)

    def ellipse(self, cx, cy, rx, ry, base, shade=None, light=None):
        for y in range(24):
            for x in range(24):
                dx, dy = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
                d = dx * dx + dy * dy
                if d <= 1.0:
                    c = base
                    if shade and (dx + dy) > 0.95 and d > 0.35:
                        c = shade
                    if light and (dx + dy) < -1.0 and d > 0.5:
                        c = light
                    self.px(x, y, c)

    def rect(self, x0, y0, x1, y1, c):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.px(x, y, c)

    def line(self, pts, c):
        for x, y in pts:
            self.px(x, y, c)

    def eyes(self, x0, x1, y, white=False, color="0b1210"):
        for x in (x0, x1):
            if white:
                self.px(x, y, "fffbe8")
                self.px(x + 1, y, color)
            else:
                self.px(x, y, color)

    def save(self, name):
        out = self.img.copy()
        for y in range(24):
            for x in range(24):
                if self.img.getpixel((x, y))[3]:
                    continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < 24 and 0 <= ny < 24 and self.img.getpixel((nx, ny))[3] and self.img.getpixel((nx, ny)) != OUTLINE:
                        out.putpixel((x, y), OUTLINE)
                        break
        out.save(os.path.join(OUT, name + ".png"))


def mole():
    c = Canvas()
    c.ellipse(12, 14, 8, 7, "6a5a45", "3a2418", "8a7a5f")
    c.rect(4, 19, 6, 20, "f0c8a0"); c.rect(17, 19, 19, 20, "f0c8a0")       # лапы-лопаты
    c.ellipse(12, 15.5, 2.2, 1.6, "d99a72")
    c.px(11, 15, "c0553f"); c.px(12, 15, "c0553f")                          # розовый нос
    c.eyes(9, 14, 12)
    c.rect(10, 6, 13, 7, "e0b64a")                                           # каска-фонарик
    c.px(11, 5, "fffbe8")
    return c


def bat():
    c = Canvas()
    c.line([(x, 10 + abs(x - 4) // 2) for x in range(1, 9)], "4a2c5e")
    c.line([(x, 10 + abs(x - 19) // 2) for x in range(15, 23)], "4a2c5e")
    for x in range(2, 9):
        for y in range(11 + abs(x - 4) // 2, 15):
            c.px(x, y, "4a2c5e")
    for x in range(15, 22):
        for y in range(11 + abs(x - 19) // 2, 15):
            c.px(x, y, "4a2c5e")
    c.ellipse(12, 13, 4.5, 5, "4a2c5e", "26382f", "7a4d2c")
    c.px(9, 7, "4a2c5e"); c.px(9, 8, "4a2c5e"); c.px(14, 7, "4a2c5e"); c.px(14, 8, "4a2c5e")
    c.eyes(10, 13, 12, color="ffd84a")
    c.px(11, 15, "fffbe8"); c.px(13, 15, "fffbe8")
    return c


def rat():
    c = Canvas()
    c.line([(20, 18), (21, 17), (22, 16), (22, 15), (21, 14)], "d99a72")    # хвост
    c.ellipse(13, 15, 7, 5.5, "7b8896", "4a5560", "aab8c4")
    c.ellipse(6, 12, 4, 3.5, "7b8896", "4a5560", "aab8c4")
    c.ellipse(5, 8, 1.8, 1.8, "d99a72"); c.ellipse(9, 8, 1.8, 1.8, "d99a72")
    c.px(2, 13, "c0553f")
    c.eyes(5, 5, 11)
    c.rect(9, 20, 10, 20, "d99a72"); c.rect(16, 20, 17, 20, "d99a72")
    return c


def firefly():
    c = Canvas()
    c.ellipse(8, 8, 4, 3, "c8f5fa"); c.ellipse(16, 8, 4, 3, "c8f5fa")      # крылья
    c.ellipse(12, 11, 3.5, 3.5, "2c3238", "0b1210", "4a5560")
    c.ellipse(12, 17, 4, 4.5, "ffd84a", "e0b64a", "fffbe8")                 # светящееся брюшко
    c.eyes(10, 13, 10, color="fffbe8")
    c.px(10, 6, "2c3238"); c.px(9, 5, "2c3238"); c.px(14, 6, "2c3238"); c.px(15, 5, "2c3238")
    return c


def lizard():
    c = Canvas()
    c.line([(3, 17), (2, 16), (2, 15), (3, 14), (4, 14), (5, 15)], "2f6b55")
    c.ellipse(11, 15, 7, 4, "4fd44a", "2f6b55", "a6ec7a")
    c.ellipse(18, 12, 3.5, 3, "4fd44a", "2f6b55", "a6ec7a")
    c.px(9, 14, "c78a55"); c.px(12, 16, "c78a55"); c.px(14, 13, "c78a55")     # медные пятнышки
    c.eyes(19, 19, 11)
    c.rect(7, 19, 7, 20, "2f6b55"); c.rect(14, 19, 14, 20, "2f6b55")
    return c


def owl():
    c = Canvas()
    c.ellipse(12, 14, 7, 8, "7a4d2c", "5a3a22", "a86a3d")
    c.ellipse(12, 16, 4, 4.5, "d8c9a8", "b8a98c")
    c.ellipse(9, 11, 2.6, 2.6, "f3d98a"); c.ellipse(15, 11, 2.6, 2.6, "f3d98a")
    c.px(9, 11, "0b1210"); c.px(15, 11, "0b1210")
    c.px(12, 13, "e0b64a")
    c.px(6, 5, "7a4d2c"); c.px(7, 6, "7a4d2c"); c.px(18, 5, "7a4d2c"); c.px(17, 6, "7a4d2c")
    c.rect(10, 22, 11, 22, "e0b64a"); c.rect(13, 22, 14, 22, "e0b64a")
    return c


def crab():
    c = Canvas()
    c.ellipse(4, 10, 2.5, 2.5, "e7794f", "c0553f"); c.ellipse(20, 10, 2.5, 2.5, "e7794f", "c0553f")
    c.px(4, 13, "c0553f"); c.px(5, 14, "c0553f"); c.px(20, 13, "c0553f"); c.px(19, 14, "c0553f")
    c.ellipse(12, 16, 7, 4.5, "e7794f", "c0553f", "f0c8a0")
    c.ellipse(12, 12, 3, 2.2, "7fdbe6", "3a7c8c", "c8f5fa")                # кристалл на панцире
    c.eyes(10, 14, 14)
    for x in (6, 8, 16, 18):
        c.px(x, 21, "c0553f")
    return c


def fox():
    c = Canvas()
    c.ellipse(19, 14, 3.5, 5, "e7794f", "c0553f")                         # хвост
    c.ellipse(20, 10, 1.8, 1.8, "fffbe8")
    c.ellipse(11, 15, 6, 5, "e7794f", "c0553f", "f0c8a0")
    c.ellipse(9, 10, 4, 3.5, "e7794f", "c0553f", "f0c8a0")
    c.line([(6, 7), (6, 6), (7, 5)], "e7794f"); c.line([(11, 6), (12, 5), (12, 7)], "e7794f")
    c.ellipse(8, 12, 2, 1.3, "fffbe8")
    c.px(6, 12, "0b1210")
    c.eyes(8, 10, 9)
    c.px(20, 7, "ffd84a"); c.px(21, 6, "ffd84a")                            # искра на хвосте
    return c


def golem():
    c = Canvas()
    c.rect(6, 9, 17, 20, "7b8896"); c.rect(6, 17, 17, 20, "4a5560"); c.rect(7, 10, 9, 12, "aab8c4")
    c.rect(3, 11, 5, 17, "4a5560"); c.rect(18, 11, 20, 17, "4a5560")       # руки-глыбы
    c.rect(8, 4, 15, 9, "7b8896"); c.rect(9, 5, 10, 6, "aab8c4")
    c.px(10, 7, "7fdbe6"); c.px(13, 7, "7fdbe6")                            # светящиеся глаза
    c.rect(11, 13, 12, 14, "7fdbe6")
    c.rect(7, 21, 9, 22, "4a5560"); c.rect(14, 21, 16, 22, "4a5560")
    return c


def salamander():
    c = Canvas()
    c.line([(2, 13), (3, 14), (4, 15), (5, 16)], "c0553f")
    c.ellipse(11, 15, 7, 4, "c0553f", "8a3d2a", "e7794f")
    c.ellipse(18, 12, 3.5, 3, "c0553f", "8a3d2a", "e7794f")
    for x, y in ((8, 14), (11, 13), (14, 15)):
        c.px(x, y, "ffd84a")
    c.eyes(19, 19, 11, color="ffd84a")
    c.px(12, 9, "ffd84a"); c.px(13, 8, "e7794f"); c.px(11, 8, "ffd84a")       # огонёк над спиной
    return c


def dragon():
    c = Canvas()
    c.ellipse(5, 11, 4, 4, "c9a45c", "7d6a3e")                            # крыло
    c.ellipse(12, 15, 6, 5, "e0b64a", "c9a45c", "f3d98a")
    c.ellipse(16, 9, 4, 3.5, "e0b64a", "c9a45c", "f3d98a")
    c.line([(15, 5), (14, 4)], "fffbe8"); c.line([(18, 5), (19, 4)], "fffbe8")   # рожки
    c.eyes(17, 17, 8)
    c.px(19, 10, "0b1210")
    c.line([(6, 19), (5, 20), (4, 20), (3, 19)], "c9a45c")
    c.ellipse(12, 16, 2.5, 3, "f3d98a")
    c.px(13, 13, "7fdbe6")                                                 # самоцвет на груди
    return c


def serpent():
    c = Canvas()
    c.ellipse(12, 17, 8, 4, "7fdbe6", "3a7c8c", "c8f5fa")
    c.ellipse(12, 17, 4.5, 2, "24408f")
    c.ellipse(12, 12, 5, 3.5, "7fdbe6", "3a7c8c", "c8f5fa")
    c.ellipse(15, 7, 3.5, 3, "7fdbe6", "3a7c8c", "c8f5fa")
    c.eyes(15, 17, 6, color="4a2c5e")
    c.px(18, 8, "c0553f"); c.px(19, 9, "c0553f")
    c.px(10, 11, "fffbe8"); c.px(7, 16, "fffbe8"); c.px(16, 17, "fffbe8")   # блики-грани
    return c


def bait():
    c = Canvas()
    c.ellipse(12, 15, 6, 6, "a86a3d", "7a4d2c", "c78a55")                  # гриб-приманка на шляпке
    c.ellipse(12, 10, 8, 4.5, "c0553f", "8a3d2a", "e7794f")
    c.px(9, 9, "fffbe8"); c.px(14, 8, "fffbe8"); c.px(16, 11, "fffbe8"); c.px(10, 11, "fffbe8")
    c.rect(10, 15, 14, 20, "d8c9a8")
    c.rect(10, 18, 14, 20, "b8a98c")
    return c


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, fn in (("mole", mole), ("bat", bat), ("rat", rat), ("firefly", firefly), ("lizard", lizard), ("owl", owl),
                     ("crab", crab), ("fox", fox), ("golem", golem), ("salamander", salamander), ("dragon", dragon),
                     ("serpent", serpent), ("bait", bait)):
        fn().save(name)
    print("saved 13 sprites")


if __name__ == "__main__":
    main()
