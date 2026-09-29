#!/usr/bin/env python3
"""Готовит иконки для сторов и заставку запуска из главной картинки assets/app_icon.png.

Запуск из корня проекта:  python3 tools/make_icons.py     (нужен Pillow)
Исходник assets/app_icon.png не меняется. Создаются:
  assets/icon_background.png  — фон адаптивной иконки Android (432x432, картинка на весь слой)
  assets/icon_foreground.png  — передний слой адаптивной иконки (432x432, прозрачный)
  assets/splash.png           — заставка запуска 1920x1080 (вместо логотипа движка)
  store/assets/icon_512.png, icon_216.png — иконки для RuStore и AppGallery
"""
import os

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def vgradient(size, stops):
    w, h = size
    img = Image.new("RGB", size)
    px = img.load()
    for y in range(h):
        t = y / (h - 1)
        for i in range(len(stops) - 1):
            if stops[i][0] <= t <= stops[i + 1][0]:
                k = (t - stops[i][0]) / max(1e-6, stops[i + 1][0] - stops[i][0])
                c = tuple(int(stops[i][1][j] + (stops[i + 1][1][j] - stops[i][1][j]) * k) for j in range(3))
                break
        for x in range(w):
            px[x, y] = c
    return img


def glow(size, center, radius, color, alpha):
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    steps = 40
    for i in range(steps, 0, -1):
        r = radius * i / steps
        a = int(alpha * (1 - i / steps) ** 2)
        d.ellipse([center[0] - r, center[1] - r, center[0] + r, center[1] + r], fill=color + (a,))
    return layer


def main():
    src = Image.open(os.path.join(ROOT, "assets", "app_icon.png")).convert("RGB")
    side = min(src.size)
    src = src.crop(((src.width - side) // 2, (src.height - side) // 2, (src.width + side) // 2, (src.height + side) // 2))

    os.makedirs(os.path.join(ROOT, "store", "assets"), exist_ok=True)
    src.resize((512, 512), Image.LANCZOS).save(os.path.join(ROOT, "store", "assets", "icon_512.png"), optimize=True)
    src.resize((216, 216), Image.LANCZOS).save(os.path.join(ROOT, "store", "assets", "icon_216.png"), optimize=True)

    # адаптивная иконка: картинка на весь слой, лаунчер сам обрежет её по маске (круг, «сквиркл»)
    canvas = 432
    src.resize((canvas, canvas), Image.LANCZOS).save(os.path.join(ROOT, "assets", "icon_background.png"), optimize=True)
    Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0)).save(os.path.join(ROOT, "assets", "icon_foreground.png"))

    # заставка запуска
    W, H = 1920, 1080
    splash = vgradient((W, H), [(0, (10, 28, 36)), (0.55, (14, 46, 58)), (1, (8, 24, 32))]).convert("RGBA")
    splash.alpha_composite(glow((W, H), (W // 2, int(H * 0.42)), 620, (232, 170, 110), 90))
    logo = src.resize((420, 420), Image.LANCZOS).convert("RGBA")
    logo_mask = Image.new("L", (420, 420), 0)
    ImageDraw.Draw(logo_mask).ellipse([0, 0, 419, 419], fill=255)
    ring = Image.new("RGBA", (444, 444), (0, 0, 0, 0))
    ImageDraw.Draw(ring).ellipse([0, 0, 443, 443], outline=(244, 220, 176, 210), width=5)
    lx, ly = W // 2 - 210, int(H * 0.42) - 210
    splash.paste(logo, (lx, ly), logo_mask)
    splash.alpha_composite(ring, (lx - 12, ly - 12))
    d = ImageDraw.Draw(splash)
    try:
        title_font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 92)
        sub_font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 34)
    except OSError:
        title_font = sub_font = ImageFont.load_default()
    for text, font, y, color in [("QUIET WATERS", title_font, int(H * 0.42) + 250, (255, 240, 214, 255)), ("ТИХИЕ ВОДЫ  •  РЫБАЛКА", sub_font, int(H * 0.42) + 370, (228, 180, 117, 255))]:
        w = d.textlength(text, font=font)
        d.text(((W - w) / 2, y), text, font=font, fill=color)
    splash.convert("RGB").save(os.path.join(ROOT, "assets", "splash.png"), optimize=True)
    print("готово")


if __name__ == "__main__":
    main()
