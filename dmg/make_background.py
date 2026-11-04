"""Draws the DMG window background: an arrow from the app icon to Applications.

Writes background.png (1x) and background@2x.png; build.sh merges them into
a Retina-aware background.tiff. Icon positions must match settings.py.
"""
import os
from PIL import Image, ImageDraw, ImageFont

W, H = 600, 380
APP_X, APPS_X, ICON_Y = 160, 440, 175
HERE = os.path.dirname(os.path.abspath(__file__))


def font(size):
    for path in ("/System/Library/Fonts/SFNS.ttf",
                 "/System/Library/Fonts/Helvetica.ttc",
                 "/Library/Fonts/Arial.ttf"):
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def draw(scale):
    s = lambda v: int(v * scale)
    img = Image.new("RGB", (s(W), s(H)))
    d = ImageDraw.Draw(img)

    # Soft vertical gradient.
    top, bottom = (248, 249, 251), (232, 235, 240)
    for y in range(s(H)):
        t = y / (s(H) - 1)
        d.line([(0, y), (s(W), y)],
               fill=tuple(int(a + (b - a) * t) for a, b in zip(top, bottom)))

    # Arrow between the two icons.
    color = (120, 128, 140)
    x0, x1, y = s(APP_X + 78), s(APPS_X - 78), s(ICON_Y)
    head = s(16)
    d.line([(x0, y), (x1 - head, y)], fill=color, width=s(6))
    d.polygon([(x1, y), (x1 - head - s(4), y - head), (x1 - head - s(4), y + head)], fill=color)

    title = "Drag AirPod Clicker to Applications"
    f = font(s(17))
    tw = d.textlength(title, font=f)
    d.text(((s(W) - tw) / 2, s(300)), title, font=f, fill=(70, 76, 86))

    sub = "Then open it from your Applications folder"
    f2 = font(s(13))
    sw = d.textlength(sub, font=f2)
    d.text(((s(W) - sw) / 2, s(328)), sub, font=f2, fill=(120, 128, 140))
    return img


draw(1).save(os.path.join(HERE, "background.png"))
draw(2).save(os.path.join(HERE, "background@2x.png"))
