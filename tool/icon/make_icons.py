"""Renders Sefer's launcher icons: a black letter in Noto Serif Hebrew on
white, as Android adaptive icons with a monochrome layer for themed icons.

    python3 tool/icon/make_icons.py

Needs Pillow. Writes into android/app/src/main/res and assets/icons.
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
RES = ROOT / 'android/app/src/main/res'
FONT = Path(__file__).with_name('NotoSerifHebrew-Medium.ttf')

LETTERS = {'aleph': 'א', 'bet': 'ב'}
INK = (0, 0, 0, 255)
PAPER = (255, 255, 255, 255)

# Adaptive icons are 108 dp; launchers show the middle 72 dp and may mask
# it to a circle of 66 dp. The letter's box stays well inside that circle.
DENSITIES = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}
ADAPTIVE_DP = 108
LETTER_DP = 38  # the letter's larger side
LEGACY_DP = 48


def draw_letter(img, letter, box):
    """Draws [letter] so its ink fills [box] px on its larger side, centred."""
    size = 1000
    font = ImageFont.truetype(str(FONT), size)
    l, t, r, b = font.getbbox(letter)
    scale = box / max(r - l, b - t)
    font = ImageFont.truetype(str(FONT), max(8, round(size * scale)))
    l, t, r, b = font.getbbox(letter)
    w, h = img.size
    x = (w - (r - l)) / 2 - l
    y = (h - (b - t)) / 2 - t
    ImageDraw.Draw(img).text((x, y), letter, font=font, fill=INK)


def render(letter, px, box, background):
    # Draw large and scale down for clean edges.
    k = 4
    img = Image.new('RGBA', (px * k, px * k), background)
    draw_letter(img, letter, box * k)
    return img.resize((px, px), Image.LANCZOS)


def rounded(img, radius):
    mask = Image.new('L', img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, img.size[0] - 1, img.size[1] - 1), radius, fill=255)
    out = Image.new('RGBA', img.size, (0, 0, 0, 0))
    out.paste(img, (0, 0), mask)
    return out


def main():
    for name, letter in LETTERS.items():
        suffix = '' if name == 'aleph' else '_bet'
        for d, k in DENSITIES.items():
            folder = RES / f'mipmap-{d}'
            folder.mkdir(parents=True, exist_ok=True)
            # Foreground and monochrome: the letter on transparent.
            fg = render(letter, round(ADAPTIVE_DP * k), LETTER_DP * k, (0, 0, 0, 0))
            fg.save(folder / f'ic_launcher{suffix}_foreground.png')
            # Older Android: a white rounded square with the letter.
            px = round(LEGACY_DP * k)
            legacy = render(letter, px, LETTER_DP * 0.7 * k, PAPER)
            rounded(legacy, px * 0.22).save(folder / f'ic_launcher{suffix}.png')
        # For the picker in the app.
        (ROOT / 'assets/icons').mkdir(parents=True, exist_ok=True)
        render(letter, 192, 92, PAPER).save(ROOT / f'assets/icons/{name}.png')


if __name__ == '__main__':
    main()
