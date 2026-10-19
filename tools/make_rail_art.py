"""Спрайты «Узкоколейки» (24x24, палитра tools/palette.hex): вагонетка с рудой, стрелочный перевод, депо, завал.
Рисуются кодом попиксельно, затем обводятся тёмным контуром в 1 пиксель. Запуск: python tools/make_rail_art.py"""
import os
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "assets", "pixel", "rail")
C = {
    "o": "0b1210", "k": "2c3238", "i": "4a5560", "l": "7b8896", "h": "aab8c4", "s": "d9e4ec",
    "w": "3a2418", "W": "5a3a22", "m": "7a4d2c", "M": "a86a3d", "n": "c78a55",
    "b": "7d6a3e", "B": "c9a45c", "g": "e0b64a", "G": "f3d98a", "y": "ffd84a",
    "c": "a86a3d", "r": "c0553f", "R": "e7794f", "e": "4fd44a", "E": "a6ec7a",
    "d": "3a7c8c", "D": "7fdbe6", "t": "26382f", "T": "3d5a4d", "q": "6a5a45", "Q": "8a7a5f",
}


def rgba(code):
    v = C[code]
    return (int(v[0:2], 16), int(v[2:4], 16), int(v[4:6], 16), 255)


def from_rows(rows):
    img = Image.new("RGBA", (24, 24), (0, 0, 0, 0))
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch != ".":
                img.putpixel((x, y), rgba(ch))
    return img


def outline(img):
    out = img.copy()
    dark = rgba("o")
    for y in range(24):
        for x in range(24):
            if img.getpixel((x, y))[3] > 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < 24 and 0 <= ny < 24 and img.getpixel((nx, ny))[3] > 0 and img.getpixel((nx, ny)) != dark:
                    out.putpixel((x, y), dark)
                    break
    return out


MINECART = [
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........GyG.............",
    "......GggggD.Gy.........",
    ".....gggbggDDggg........",
    "....ggbgggdDdgbgg.......",
    "..hhhhhhhhhhhhhhhhhhh...",
    "..lsslllllllllllllllk...",
    "...lhlllMlllllllMllk....",
    "...lhlliiiiiiiiiillk....",
    "....lhliiiiiiiiiilk.....",
    "....lhlllMlllllMllk.....",
    ".....liiiiiiiiiiik......",
    ".....kkkkkkkkkkkkk......",
    "......ii.......ii.......",
    ".....ilhi.....ilhi......",
    ".....ihki.....ihki......",
    "......ii.......ii.......",
    "...mmmmmmmmmmmmmmmmmm...",
    "........................",
    "........................",
]

ARROW = [
    "........................",
    "........................",
    "..........ee............",
    "..........eEe...........",
    "..........eEEe..........",
    "...eeeeeeeeEEEe.........",
    "...EEEEEEEEEEEEe........",
    "...EEEEEEEEEEEEEe.......",
    "...eeeeeeeeEEEEe........",
    "..........eEEe..........",
    "..........eEe...........",
    "..........ee............",
    "........................",
    "..l.....l.....l.....l...",
    "hhhhhhhhhhhhhhhhhhhhhhhh",
    "mlmmmmmmlmmmmmlmmmmmlmmm",
    "MmM...MmM...MmM...MmM...",
    "mlmmmmmmlmmmmmlmmmmmlmmm",
    "hhhhhhhhhhhhhhhhhhhhhhhh",
    "..l.....l.....l.....l...",
    "........................",
    "........................",
    "........................",
    "........................",
]

DEPOT = [
    "........................",
    "...........rr...........",
    ".........rrRRrr.........",
    ".......rrRRRRRRrr.......",
    ".....rrRRRRRRRRRRrr.....",
    "...rrRRRRRRRRRRRRRRrr...",
    "..rcccccccccccccccccr...",
    "....mMmMmMmMmMmMmMm.....",
    "....mMmkkkkkkkkkmMm.....",
    "....mMmkGGkkkkkkmMm.....",
    "....mMmkyGkkkkkkmMm.....",
    "....mMmkkkkkkkkkmMm.....",
    "....mMmkkkkkkkkkmMm.....",
    "....mMmkkkkkkkkkmMm.....",
    "....mMmkkkkkkkkkmMm.....",
    "....mMmkkkkkkkkkmMm.....",
    "....mMmkkkkkkkkkmMm.....",
    "....WWWWWWWWWWWWWWW.....",
    "..l.....l.....l.....l...",
    "hhhhhhhhhhhhhhhhhhhhhhhh",
    "mmmmmmmmmmmmmmmmmmmmmmmm",
    "hhhhhhhhhhhhhhhhhhhhhhhh",
    "........................",
    "........................",
]

RUBBLE = [
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "..........QQq...........",
    ".........QQqqq..........",
    "....QQq..Qqqqq..........",
    "...QQqqq.qqqqwq.QQq.....",
    "...Qqqqq.qqqwqqQQqqq....",
    "..QQqqwqQQqqqqQqqqqqq...",
    "..QqqqqQQqqqqqqqqwqqq...",
    ".QQqqqqQqqqwqqqqqqqqqq..",
    ".QqqqwqqqqqqqqqQQqqqwq..",
    "QQqqqqqqqQQqqqqQqqqqqqq.",
    "Qqqqqqqqqqqqqqqqqqqqqqq.",
    "........................",
    "..l.....l.....l.....l...",
    "hhhhhhhhhhhhhhhhhhhhhhhh",
    "mmmmmmmmmmmmmmmmmmmmmmmm",
    "hhhhhhhhhhhhhhhhhhhhhhhh",
    "........................",
    "........................",
]


TOKEN = [
    "........................",
    "........................",
    "........................",
    "........bbbbbbb.........",
    "......bbGGGGGGgbb.......",
    ".....bGGGgggggggBb......",
    "....bGGgggggggggBBb.....",
    "....bGgggBBBBBgggBb.....",
    "...bGggBBbbbbbBBgBBb....",
    "...bGggBbbkkkbbBgBBb....",
    "...bGggBbkkkkkbBgBBb....",
    "...bGggBbkkkkkbBgBBb....",
    "...bGggBbkkkkkbBgBBb....",
    "...bGggBbbkkkbbBgBBb....",
    "...bGggBBbbbbbBBgBBb....",
    "....bGgggBBBBBgggBb.....",
    "....bGggggggggggBBb.....",
    ".....bBggggggggBBb......",
    "......bbBBBBBBBbb.......",
    "........bbbbbbb.........",
    "........................",
    "........................",
    "........................",
    "........................",
]


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, rows in (("minecart", MINECART), ("switch", ARROW), ("depot", DEPOT), ("rubble", RUBBLE), ("token", TOKEN)):
        assert len(rows) == 24 and all(len(r) == 24 for r in rows), name
        outline(from_rows(rows)).save(os.path.join(OUT, name + ".png"))
        print("saved", name)


if __name__ == "__main__":
    main()
