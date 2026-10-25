"""Render the app icon (rounded gradient square with a check mark) to assets/icon.ico.

Usage: python tools/make_icon.py   (needs Pillow)
"""
from pathlib import Path

from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parents[1] / "src" / "habit_tracker" / "assets" / "icon.ico"
SIZE = 1024  # draw large, then downsample for smooth edges
TOP, BOTTOM = (124, 152, 255), (150, 104, 250)


def render() -> Image.Image:
    gradient = Image.new("RGBA", (SIZE, SIZE))
    draw = ImageDraw.Draw(gradient)
    for y in range(SIZE):
        t = y / (SIZE - 1)
        draw.line([(0, y), (SIZE, y)], fill=tuple(round(a + (b - a) * t) for a, b in zip(TOP, BOTTOM)) + (255,))

    mask = Image.new("L", (SIZE, SIZE), 0)
    ImageDraw.Draw(mask).rounded_rectangle([40, 40, SIZE - 40, SIZE - 40], radius=230, fill=255)
    icon = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    icon.paste(gradient, mask=mask)

    check = [(300, 530), (450, 680), (740, 370)]
    ImageDraw.Draw(icon).line(check, fill="white", width=96, joint="curve")
    for x, y in (check[0], check[-1]):  # round line caps
        ImageDraw.Draw(icon).ellipse([x - 48, y - 48, x + 48, y + 48], fill="white")
    return icon


if __name__ == "__main__":
    OUT.parent.mkdir(parents=True, exist_ok=True)
    render().resize((256, 256), Image.LANCZOS).save(
        OUT, sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
    print(f"Wrote {OUT}")
