"""Рисует фоны зон (assets/bg/background_N.jpg) из tools/backgrounds.html в Chromium через Playwright.
Нужны playwright и Chromium: python3 tools/make_backgrounds.py [--planet N] [номер_зоны ...]
С --planet N рисует набор планеты N в файлы planetN_<зона>.jpg (сейчас есть набор для планеты 1, Марса)."""
import base64
import os
import sys
from playwright.sync_api import sync_playwright

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "assets", "bg")
CHROME = os.environ.get("CHROMIUM", "/opt/pw-browsers/chromium-1194/chrome-linux/chrome")


def main():
    args = sys.argv[1:]
    planet = 0
    if "--planet" in args:
        k = args.index("--planet")
        planet = int(args[k + 1])
        del args[k:k + 2]
    zones = [int(a) for a in args]
    os.makedirs(OUT, exist_ok=True)
    with sync_playwright() as p:
        browser = p.chromium.launch(executable_path=CHROME, args=["--no-sandbox"])
        page = browser.new_page(viewport={"width": 1080, "height": 1920})
        page.goto("file://" + os.path.join(HERE, "backgrounds.html"))
        count = page.evaluate("window.zoneCount")
        for i in zones or range(count):
            data = page.evaluate(f"(drawZone({i}, {planet}), document.getElementById('c').toDataURL('image/jpeg', 0.86))")
            path = os.path.join(OUT, f"planet{planet}_{i}.jpg" if planet else f"background_{i}.jpg")
            with open(path, "wb") as f:
                f.write(base64.b64decode(data.split(",", 1)[1]))
            print("готово:", path, os.path.getsize(path) // 1024, "КБ")
        browser.close()


if __name__ == "__main__":
    main()
