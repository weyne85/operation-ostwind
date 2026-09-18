"""
Operation Ostwind - Karten der Trigger-Zonen erzeugen

Zeichnet alle Trigger-Zonen aus Schritt 3 und 4 der README auf eine
OpenStreetMap-Karte. Die Bilder landen in docs/ und helfen beim Platzieren
der Zonen im Missionseditor.

Aufruf:
    python tools/zone_map.py

Benötigt Python 3 und Pillow (pip install pillow). Die Kartenkacheln kommen
von tile.openstreetmap.org und werden im Temp-Ordner zwischengespeichert.

Die Koordinaten stehen unten in ZONES. Wer eine Zone verschiebt, ändert sie
hier und in der README und lässt das Skript neu laufen.
"""

import math
import os
import tempfile
import time
import urllib.request

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "docs")
CACHE = os.path.join(tempfile.gettempdir(), "ostwind_tiles")
TILE_URL = "https://tile.openstreetmap.org/{z}/{x}/{y}.png"
USER_AGENT = "OperationOstwind-ZoneMap/1.0 (private DCS mission)"
FT = 0.3048

# Art der Zone: front, sam, ewr, ewr_blue, cap_red, cap_blue, airbase
# Label: Richtung des Textes vom Punkt aus (n, s, e, w, ne, nw, se, sw)
ZONES = [
    # Name,              Art,        Breite,  Länge,   Radius ft, Label
    ("Zone Batumi",      "front",    41.6093, 41.6003, 5000, "e"),
    ("Zone Kobuleti",    "front",    41.8403, 41.7994, 5000, "w"),
    ("Zone Senaki",      "front",    42.2455, 42.0501, 5000, "n"),
    ("Zone Kutaisi",     "front",    42.1783, 42.4910, 6500, "n"),
    ("Zone Zestafoni",   "front",    42.1074, 43.0393, 5000, "s"),
    ("Zone Rikoti",      "front",    42.0506, 43.4926, 4000, "nw"),
    ("Zone Khashuri",    "front",    41.9973, 43.5989, 5000, "s"),
    ("Zone Gori",        "front",    41.9818, 44.1118, 6500, "w"),
    ("Zone Tbilisi",     "front",    41.6685, 44.9559, 6500, "n"),
    ("Zone Soganlug",    "front",    41.6494, 44.9371, 4000, "sw"),
    ("Zone Vaziani",     "front",    41.6292, 45.0364, 5000, "se"),
    ("SAM Kutaisi",      "sam",      42.1800, 42.5800, 500,  "s"),
    ("SAM Zestafoni",    "sam",      42.1238, 43.0663, 500,  "ne"),
    ("SAM Rikoti",       "sam",      42.0412, 43.5250, 500,  "ne"),
    ("SAM Khashuri",     "sam",      41.9950, 43.6600, 500,  "e"),
    ("SAM Gori",         "sam",      41.9700, 44.1900, 500,  "s"),
    ("SAM Tbilisi",      "sam",      41.7225, 45.0300, 500,  "ne"),
    ("SAM Vaziani",      "sam",      41.6400, 45.0200, 500,  "e"),
    ("EWR West",         "ewr",      42.4200, 42.6050, 500,  "e"),
    ("EWR Ost",          "ewr",      42.1350, 44.1850, 500,  "e"),
    ("RED CAP West",     "cap_red",  42.8500, 43.0600, 5000, "e"),
    ("RED CAP Ost",      "cap_red",  42.5900, 44.3600, 5000, "e"),
    ("BLUE EWR",         "ewr_blue", 41.8250, 41.9450, 500,  "e"),
    ("BLUE CAP Front",   "cap_blue", 42.2100, 42.2700, 5000, "s"),
    # Nur zur Orientierung auf der Übersicht, keine Trigger-Zonen
    ("Nalchik",          "airbase",  43.5130, 43.6382, 0,    "e"),
    ("Beslan",           "airbase",  43.2046, 44.6098, 0,    "e"),
    ("Mozdok",           "airbase",  43.7833, 44.6027, 0,    "e"),
]

# Name, Zoom, Süd, Nord, West, Ost, Gitterabstand in Grad, Titel, Ecke der Legende
# Die Übersicht beschriftet nur Radar, CAP und Flugplätze in Russland und
# zeigt die Ausschnitte der Detailkarten.
MAPS = [
    ("karte_uebersicht", 8, 41.35, 44.00, 41.20, 45.60, 0.5,
     "Operation Ostwind - Übersicht", "nw"),
    ("karte_west", 10, 41.52, 42.50, 41.45, 43.25, 0.25,
     "Operation Ostwind - West: Batumi bis Zestafoni", "ne"),
    ("karte_ost", 10, 41.55, 42.20, 42.95, 45.25, 0.25,
     "Operation Ostwind - Ost: Zestafoni bis Vaziani", "sw"),
]
DETAIL = {"karte_west": "Karte West", "karte_ost": "Karte Ost"}
OVERVIEW_LABELS = ("ewr", "ewr_blue", "cap_red", "airbase")

STYLE = {
    "front":    {"fill": (30, 90, 200, 70),  "line": (30, 90, 200, 255)},
    "sam":      {"fill": (210, 30, 30, 255), "line": (120, 0, 0, 255)},
    "ewr":      {"fill": (240, 140, 0, 255), "line": (130, 70, 0, 255)},
    "ewr_blue": {"fill": (30, 90, 200, 255), "line": (0, 40, 120, 255)},
    "cap_red":  {"fill": (210, 30, 30, 50),  "line": (210, 30, 30, 255)},
    "cap_blue": {"fill": (30, 90, 200, 50),  "line": (30, 90, 200, 255)},
    "airbase":  {"fill": (90, 90, 90, 255),  "line": (0, 0, 0, 255)},
}

LEGEND = [
    ("front", "Frontzone (Radius maßstäblich)"),
    ("sam", "SAM-Stellung (Rot)"),
    ("ewr", "Frühwarnradar (Rot)"),
    ("ewr_blue", "Frühwarnradar (Blau)"),
    ("cap_red", "CAP-Zone Rot"),
    ("cap_blue", "CAP-Zone Blau"),
]


def font(size, bold=False):
    names = ["arialbd.ttf", "DejaVuSans-Bold.ttf"] if bold else ["arial.ttf", "DejaVuSans.ttf"]
    for name in names:
        for folder in ["", "C:/Windows/Fonts", "/usr/share/fonts/truetype/dejavu"]:
            try:
                return ImageFont.truetype(os.path.join(folder, name), size)
            except OSError:
                pass
    return ImageFont.load_default()


def world_px(lat, lon, zoom):
    """Web-Mercator: Pixel in der Weltkarte der Zoomstufe."""
    n = 256 * 2 ** zoom
    x = (lon + 180) / 360 * n
    s = math.sin(math.radians(lat))
    y = (0.5 - math.log((1 + s) / (1 - s)) / (4 * math.pi)) * n
    return x, y


def meters_per_px(lat, zoom):
    return 156543.03392 * math.cos(math.radians(lat)) / 2 ** zoom


def get_tile(z, x, y):
    path = os.path.join(CACHE, str(z), str(x), f"{y}.png")
    if not os.path.exists(path):
        os.makedirs(os.path.dirname(path), exist_ok=True)
        req = urllib.request.Request(TILE_URL.format(z=z, x=x, y=y),
                                     headers={"User-Agent": USER_AGENT})
        with urllib.request.urlopen(req, timeout=30) as r:
            data = r.read()
        with open(path, "wb") as f:
            f.write(data)
        time.sleep(0.2)
    return Image.open(path).convert("RGB")


def ddm(value, pos, neg):
    """Grad und Dezimalminuten, zum Beispiel N 42°03.0'."""
    hemi = pos if value >= 0 else neg
    value = abs(value)
    deg = int(value)
    minutes = (value - deg) * 60
    return f"{hemi} {deg}°{minutes:04.1f}'"


def text_halo(draw, xy, text, fnt, fill=(0, 0, 0), anchor="la"):
    draw.text(xy, text, font=fnt, fill=fill, anchor=anchor,
              stroke_width=3, stroke_fill=(255, 255, 255))


def draw_marker(draw, kind, x, y, r_px, size):
    st = STYLE[kind]
    if kind == "front":
        r = max(r_px, 5)
        draw.ellipse([x - r, y - r, x + r, y + r], fill=st["fill"], outline=st["line"], width=2)
        draw.ellipse([x - 2, y - 2, x + 2, y + 2], fill=st["line"])
    elif kind in ("cap_red", "cap_blue"):
        # Fadenkreuz, damit CAP-Zonen nicht wie Frontzonen aussehen
        r = max(r_px, 6)
        draw.ellipse([x - r, y - r, x + r, y + r], fill=st["fill"], outline=st["line"], width=2)
        draw.line([(x - r - 4, y), (x + r + 4, y)], fill=st["line"], width=2)
        draw.line([(x, y - r - 4), (x, y + r + 4)], fill=st["line"], width=2)
    elif kind == "sam":
        s = size
        draw.polygon([(x, y - s), (x - s, y + s * 0.8), (x + s, y + s * 0.8)],
                     fill=st["fill"], outline=st["line"])
    elif kind in ("ewr", "ewr_blue"):
        s = size * 0.8
        draw.rectangle([x - s, y - s, x + s, y + s], fill=st["fill"], outline=st["line"], width=2)
    else:
        s = size * 0.6
        draw.polygon([(x, y - s), (x + s, y), (x, y + s), (x - s, y)],
                     fill=st["fill"], outline=st["line"])


def label_pos(x, y, direction, gap):
    dx = {"e": 1, "w": -1, "n": 0, "s": 0, "ne": 1, "nw": -1, "se": 1, "sw": -1}[direction]
    dy = {"e": 0, "w": 0, "n": -1, "s": 1, "ne": -1, "nw": -1, "se": 1, "sw": 1}[direction]
    h = {1: "l", -1: "r", 0: "m"}[dx]
    v = {1: "t", -1: "b", 0: "m"}[dy]
    return (x + dx * gap, y + dy * gap), h + v


def render(name, zoom, south, north, west, east, grid, title, legend_corner):
    x0, y0 = world_px(north, west, zoom)
    x1, y1 = world_px(south, east, zoom)
    tx0, ty0 = int(x0 // 256), int(y0 // 256)
    tx1, ty1 = int(x1 // 256), int(y1 // 256)

    base = Image.new("RGB", ((tx1 - tx0 + 1) * 256, (ty1 - ty0 + 1) * 256))
    for tx in range(tx0, tx1 + 1):
        for ty in range(ty0, ty1 + 1):
            base.paste(get_tile(zoom, tx, ty), ((tx - tx0) * 256, (ty - ty0) * 256))
    ox, oy = x0 - tx0 * 256, y0 - ty0 * 256
    img = base.crop((int(ox), int(oy), int(ox + x1 - x0), int(oy + y1 - y0)))

    # Karte etwas aufhellen, damit die Markierungen hervortreten
    img = Image.blend(img, Image.new("RGB", img.size, (255, 255, 255)), 0.25).convert("RGBA")

    def px(lat, lon):
        wx, wy = world_px(lat, lon, zoom)
        return wx - x0, wy - y0

    overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    small = font(13)
    label_font = font(15 if zoom >= 10 else 13, bold=True)

    # Koordinatengitter
    lat = math.ceil(south / grid) * grid
    while lat < north:
        _, y = px(lat, west)
        draw.line([(0, y), (img.width, y)], fill=(80, 80, 80, 110), width=1)
        text_halo(draw, (4, y - 2), ddm(lat, "N", "S"), small, fill=(60, 60, 60), anchor="lb")
        lat += grid
    lon = math.ceil(west / grid) * grid
    while lon < east:
        x, _ = px(south, lon)
        draw.line([(x, 0), (x, img.height)], fill=(80, 80, 80, 110), width=1)
        text_halo(draw, (x + 3, img.height - 4), ddm(lon, "E", "W"), small, fill=(60, 60, 60), anchor="lb")
        lon += grid

    overview = name not in DETAIL
    if overview:
        for m in MAPS:
            if m[0] in DETAIL:
                ax, ay = px(m[3], m[4])
                bx, by = px(m[2], m[5])
                draw.rectangle([ax, ay, bx, by], outline=(60, 60, 60, 200), width=2)
                text_halo(draw, (ax + 4, ay + 3), DETAIL[m[0]], small, fill=(60, 60, 60))

    size = 9 if zoom >= 10 else 7
    for zname, kind, zlat, zlon, radius_ft, ldir in ZONES:
        if not (south <= zlat <= north and west <= zlon <= east):
            continue
        if kind == "airbase" and zoom >= 10:
            continue
        x, y = px(zlat, zlon)
        r_px = radius_ft * FT / meters_per_px(zlat, zoom)
        draw_marker(draw, kind, x, y, r_px, size)
        if overview and kind not in OVERVIEW_LABELS:
            continue
        gap = max(r_px, size) + 5
        pos, anchor = label_pos(x, y, ldir, gap)
        color = STYLE[kind]["line"][:3] if kind != "airbase" else (40, 40, 40)
        text_halo(draw, pos, zname, label_font, fill=color, anchor=anchor)

    img = Image.alpha_composite(img, overlay)
    draw = ImageDraw.Draw(img)

    # Titel
    title_font = font(20, bold=True)
    text_halo(draw, (12, 10), title, title_font, fill=(0, 0, 0))

    # Legende
    lw, lh = 250, len(LEGEND) * 22 + 10
    lx = img.width - lw - 10 if "e" in legend_corner else 18
    # Oben links steht der Titel, dort die Legende darunter setzen
    top = 44 if "w" in legend_corner else 12
    ly = top if "n" in legend_corner else img.height - lh - 30
    draw.rectangle([lx - 8, ly - 6, lx + lw - 8, ly + lh - 6],
                   fill=(255, 255, 255, 230), outline=(120, 120, 120))
    for i, (kind, text) in enumerate(LEGEND):
        cy = ly + 10 + i * 22
        draw_marker(draw, kind, lx + 10, cy, 7, 7)
        draw.text((lx + 26, cy), text, font=small, fill=(0, 0, 0), anchor="lm")

    # Quellenangabe
    text_halo(draw, (img.width - 6, img.height - 4), "Kartendaten © OpenStreetMap-Mitwirkende",
              small, fill=(60, 60, 60), anchor="rb")

    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name + ".png")
    img.convert("RGB").save(path, optimize=True)
    print(f"{path}  ({img.width} x {img.height})")


def main():
    for m in MAPS:
        render(*m)


if __name__ == "__main__":
    main()
