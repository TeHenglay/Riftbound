# Cuts square skill paintings into diamond icons with a black border, for the
# HUD skill slots. Pixels outside the diamond are transparent, so the same
# image tinted dark doubles as the cooldown shade.
# Usage: python tools/art/diamond_icons.py "<folder of source PNGs>"
import os
import sys

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter

SIZE = 512
SS = 4  # supersampling for smooth diagonal edges
INSET = 6  # gap between the diamond tips and the image edge
BORDER = 30  # black border width, measured across the edge
ZOOM = 0.74  # painting scale inside the diamond; the rest is a blurred backdrop

# Source file name -> skill id (Skills.Defs keys, plus the fixed Block/Dash).
SOURCES = {
    "Rift Bolt.png": "RiftBolt",
    "Fireball.png": "Fireball",
    "Tidal Wave.png": "TidalWave",
    "Stone Spike.png": "StoneSpike",
    "Gust.png": "Gust",
    "Spark Bolt.png": "SparkBolt",
    "Steam Cloud.png": "SteamCloud",
    "Magma Meteor.png": "MagmaBurst",
    "Firestorm.png": "Firestorm",
    "Plasma Lance.png": "PlasmaLance",
    "Mudslide.png": "MudTrap",
    "Frost Gale.png": "FrostGale",
    "Quake Leap.png": "Sandstorm",
    "Magnet Quake.png": "MagnetQuake",
    "Thunderstorm.png": "Thunderstorm",
    "block.png": "Block",
    "dash.png": "Dash",
}

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
OUT = os.path.join(ROOT, "art", "skills")
# Skills with no new painting yet keep their old square art, cut the same way.
FALLBACKS = {
    "ChainShock": os.path.join(ROOT, "art", "ui", "icon_ChainShock.png"),
}


def diamond(size, inset):
    c = size / 2
    r = c - inset
    return [(c, c - r), (c + r, c), (c, c + r), (c - r, c)]


def mask(inset):
    big = Image.new("L", (SIZE * SS, SIZE * SS), 0)
    ImageDraw.Draw(big).polygon(diamond(SIZE * SS, inset * SS), fill=255)
    return big.resize((SIZE, SIZE), Image.LANCZOS)


def main(src_dir):
    os.makedirs(OUT, exist_ok=True)
    outer = mask(INSET)
    # The border is BORDER px thick across each edge; along the axis that is
    # BORDER * sqrt(2) of inset.
    inner = mask(INSET + BORDER * 1.4142)
    paths = {skill_id: os.path.join(src_dir, name) for name, skill_id in SOURCES.items()}
    paths.update(FALLBACKS)
    for skill_id, path in paths.items():
        art = Image.open(path).convert("RGBA").resize((SIZE, SIZE), Image.LANCZOS)
        icon = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
        icon.paste((7, 5, 10, 255), (0, 0), outer)
        # Shrink the painting so more of it shows inside the diamond, and fill
        # the tips with a dark, blurred copy so nothing is left empty.
        back = ImageEnhance.Brightness(art.filter(ImageFilter.GaussianBlur(18))).enhance(0.55)
        side = round(SIZE * ZOOM)
        back.paste(art.resize((side, side), Image.LANCZOS), ((SIZE - side) // 2, (SIZE - side) // 2))
        icon.paste(back, (0, 0), inner)
        icon.save(os.path.join(OUT, skill_id + ".png"), optimize=True)
        print(skill_id)
    # Empty slot: a solid black diamond.
    empty = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    empty.paste((7, 5, 10, 255), (0, 0), outer)
    empty.save(os.path.join(OUT, "Empty.png"), optimize=True)
    print("Empty")


if __name__ == "__main__":
    main(sys.argv[1])
