#!/usr/bin/env python3
"""Generate a deterministic, low-resolution four-suit Taiwu preview deck."""

from __future__ import annotations

import argparse
import io
import math
import random
import re
import shutil
import subprocess
import tempfile
import xml.etree.ElementTree as ET
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFont


SUITS = (
    ("wind", "风", (43, 58, 62)),
    ("forest", "林", (43, 77, 50)),
    ("fire", "火", (139, 48, 33)),
    ("mountain", "山", (91, 70, 53)),
)
RANKS = ("A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K")
PIPS = {
    2: ((.5, .25), (.5, .75)), 3: ((.5, .22), (.5, .5), (.5, .78)),
    4: ((.32, .25), (.68, .25), (.32, .75), (.68, .75)),
    5: ((.32, .23), (.68, .23), (.5, .5), (.32, .77), (.68, .77)),
    6: ((.32, .22), (.68, .22), (.32, .5), (.68, .5), (.32, .78), (.68, .78)),
    7: ((.32, .2), (.68, .2), (.5, .35), (.32, .5), (.68, .5), (.32, .8), (.68, .8)),
    8: ((.32, .18), (.68, .18), (.5, .34), (.32, .44), (.68, .44), (.5, .6), (.32, .8), (.68, .8)),
    9: ((.32, .17), (.68, .17), (.32, .38), (.68, .38), (.5, .5), (.32, .62), (.68, .62), (.32, .83), (.68, .83)),
    10: ((.32, .14), (.68, .14), (.5, .27), (.32, .36), (.68, .36), (.32, .64), (.68, .64), (.5, .73), (.32, .86), (.68, .86)),
}


def font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    candidates = (
        "/System/Library/Fonts/Helvetica.ttc",
        "/System/Library/Fonts/Supplemental/Arial.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    )
    for path in candidates:
        if Path(path).exists():
            return ImageFont.truetype(path, size=size)
    return ImageFont.load_default()


def _svg_native_mask(path: Path, size: int) -> Image.Image:
    """Small dependency-free renderer for flat, path-based monochrome SVG icons."""
    root = ET.parse(path).getroot()
    view = [float(v) for v in root.attrib.get("viewBox", "0 0 1024 1024").replace(",", " ").split()]
    vx, vy, vw, vh = view
    scale = size / max(vw, vh)
    ox, oy = (size-vw*scale)/2-vx*scale, (size-vh*scale)/2-vy*scale
    token_re = re.compile(r"[AaCcHhLlMmQqSsTtVvZz]|[-+]?(?:\d*\.\d+|\d+\.?)(?:[eE][-+]?\d+)?")

    def render_path(data: str) -> list[list[tuple[float, float]]]:
        tokens = token_re.findall(data)
        out: list[list[tuple[float, float]]] = []
        current: list[tuple[float, float]] = []
        i, command, x, y, sx, sy = 0, "", 0., 0., 0., 0.
        last_control: tuple[float, float] | None = None

        def number() -> float:
            nonlocal i
            value = float(tokens[i]); i += 1
            return value

        def point(relative: bool) -> tuple[float, float]:
            px, py = number(), number()
            return (px+x, py+y) if relative else (px, py)

        def curve(p0, p1, p2, p3):
            for step in range(1, 13):
                t = step/12; u = 1-t
                current.append((u**3*p0[0]+3*u*u*t*p1[0]+3*u*t*t*p2[0]+t**3*p3[0],
                                u**3*p0[1]+3*u*u*t*p1[1]+3*u*t*t*p2[1]+t**3*p3[1]))

        def arc(p0, rx, ry, angle, large, sweep, p1):
            if rx == 0 or ry == 0 or p0 == p1:
                current.append(p1); return
            rx, ry = abs(rx), abs(ry)
            phi = math.radians(angle % 360); cp, sp = math.cos(phi), math.sin(phi)
            dx, dy = (p0[0]-p1[0])/2, (p0[1]-p1[1])/2
            xp, yp = cp*dx+sp*dy, -sp*dx+cp*dy
            lam = xp*xp/(rx*rx)+yp*yp/(ry*ry)
            if lam > 1:
                factor = math.sqrt(lam); rx *= factor; ry *= factor
            num = max(0., rx*rx*ry*ry-rx*rx*yp*yp-ry*ry*xp*xp)
            den = max(1e-12, rx*rx*yp*yp+ry*ry*xp*xp)
            coef = (-1 if large == sweep else 1)*math.sqrt(num/den)
            cxp, cyp = coef*(rx*yp/ry), coef*(-ry*xp/rx)
            cx = cp*cxp-sp*cyp+(p0[0]+p1[0])/2
            cy = sp*cxp+cp*cyp+(p0[1]+p1[1])/2
            def theta(ux, uy, vx, vy):
                return math.atan2(ux*vy-uy*vx, ux*vx+uy*vy)
            start = theta(1, 0, (xp-cxp)/rx, (yp-cyp)/ry)
            delta = theta((xp-cxp)/rx, (yp-cyp)/ry, (-xp-cxp)/rx, (-yp-cyp)/ry)
            if not sweep and delta > 0: delta -= 2*math.pi
            if sweep and delta < 0: delta += 2*math.pi
            steps = max(4, math.ceil(abs(delta)*8))
            for step in range(1, steps+1):
                t = start+delta*step/steps
                current.append((cx+cp*rx*math.cos(t)-sp*ry*math.sin(t),
                                cy+sp*rx*math.cos(t)+cp*ry*math.sin(t)))

        while i < len(tokens):
            if tokens[i].isalpha():
                command = tokens[i]; i += 1
            relative = command.islower(); op = command.upper()
            if op == "M":
                nx, ny = point(relative)
                if current: out.append(current)
                current = [(nx, ny)]; x, y, sx, sy = nx, ny, nx, ny
                command = "l" if relative else "L"
            elif op == "Z":
                current.append((sx, sy)); out.append(current); current = []
                x, y = sx, sy; command = ""; last_control = None
            elif op == "L":
                x, y = point(relative); current.append((x, y)); last_control = None
            elif op == "H":
                x = number() + (x if relative else 0); current.append((x, y)); last_control = None
            elif op == "V":
                y = number() + (y if relative else 0); current.append((x, y)); last_control = None
            elif op in ("C", "S"):
                p0 = (x, y)
                if op == "C": c1 = point(relative)
                else: c1 = (2*x-last_control[0], 2*y-last_control[1]) if last_control else p0
                c2, p3 = point(relative), point(relative)
                curve(p0, c1, c2, p3); x, y = p3; last_control = c2
            elif op in ("Q", "T"):
                p0 = (x, y)
                if op == "Q": q = point(relative)
                else: q = (2*x-last_control[0], 2*y-last_control[1]) if last_control else p0
                p3 = point(relative)
                c1 = (p0[0]+2*(q[0]-p0[0])/3, p0[1]+2*(q[1]-p0[1])/3)
                c2 = (p3[0]+2*(q[0]-p3[0])/3, p3[1]+2*(q[1]-p3[1])/3)
                curve(p0, c1, c2, p3); x, y = p3; last_control = q
            elif op == "A":
                rx, ry, angle, large, sweep = number(), number(), number(), bool(number()), bool(number())
                p1 = point(relative); arc((x, y), rx, ry, angle, large, sweep, p1)
                x, y = p1; last_control = None
            else:
                raise ValueError(f"unsupported SVG path command: {command}")
        if current: out.append(current)
        return out

    mask = Image.new("1", (size, size))
    for element in root.iter():
        if element.tag.rsplit("}", 1)[-1] != "path" or not element.attrib.get("d"):
            continue
        compound = Image.new("1", (size, size))
        for points in render_path(element.attrib["d"]):
            polygon = [((px*scale)+ox, (py*scale)+oy) for px, py in points]
            sub = Image.new("1", (size, size)); ImageDraw.Draw(sub).polygon(polygon, fill=1)
            compound = ImageChops.logical_xor(compound, sub)
        mask = ImageChops.logical_or(mask, compound)
    if mask.getbbox() is None:
        raise ValueError(f"SVG contains no renderable paths: {path}")
    return mask.convert("L")


def svg_mask(path: Path, size: int) -> Image.Image:
    """Rasterize an SVG to a mask with CairoSVG or a system converter."""
    png: bytes | None = None
    try:
        import cairosvg  # type: ignore
        png = cairosvg.svg2png(url=str(path), output_width=size, output_height=size)
    except ImportError:
        pass
    if png is None:
        with tempfile.TemporaryDirectory(prefix="taiwu-svg-") as tmp:
            out = Path(tmp) / "icon.png"
            if shutil.which("rsvg-convert"):
                subprocess.run(["rsvg-convert", "-w", str(size), "-h", str(size), "-o", str(out), str(path)], check=True)
            else:
                return _svg_native_mask(path, size)
            png = out.read_bytes()
    image = Image.open(io.BytesIO(png)).convert("RGBA")
    image.thumbnail((size, size), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (size, size))
    canvas.alpha_composite(image, ((size - image.width) // 2, (size - image.height) // 2))
    alpha = canvas.getchannel("A")
    darkness = ImageChops.invert(canvas.convert("L"))
    return ImageChops.multiply(alpha, darkness) if alpha.getextrema() == (255, 255) else alpha


def paper(size: tuple[int, int], rng: random.Random) -> Image.Image:
    w, h = size
    image = Image.new("RGB", size, (226, 211, 174))
    px = image.load()
    for y in range(h):
        edge = min(x := y, h - 1 - y) / max(1, h * .12)
        for xx in range(w):
            rim = min(edge, xx / max(1, w * .12), (w - 1 - xx) / max(1, w * .12), 1)
            grain = rng.randrange(-8, 9) - int((1 - rim) * 11)
            px[xx, y] = (max(0, 226 + grain), max(0, 211 + grain), max(0, 174 + grain))
    return image


def cover_background(path: Path, size: tuple[int, int]) -> Image.Image:
    image = Image.open(path).convert("RGBA")
    scale = max(size[0] / image.width, size[1] / image.height)
    image = image.resize((round(image.width * scale), round(image.height * scale)), Image.Resampling.LANCZOS)
    left, top = (image.width - size[0]) // 2, (image.height - size[1]) // 2
    return image.crop((left, top, left + size[0], top + size[1]))


def ink_pattern(layer: Image.Image, suit: str, color: tuple[int, int, int], rng: random.Random) -> None:
    d = ImageDraw.Draw(layer, "RGBA")
    w, h = layer.size
    faint = (*color, 30)
    if suit == "wind":
        for i in range(8):
            y = h * (.18 + i * .09) + rng.uniform(-10, 10)
            pts = [(w * .08, y), (w * .36, y - 20), (w * .64, y + 16), (w * .92, y - 8)]
            d.line(pts, fill=faint, width=rng.choice((2, 3, 4)), joint="curve")
    elif suit == "forest":
        for x in (.22, .38, .58, .76):
            base = (w * x, h * .88)
            top = (w * (x + rng.uniform(-.05, .05)), h * rng.uniform(.12, .28))
            d.line((base, top), fill=faint, width=rng.choice((3, 4, 5)))
            for t in (.3, .48, .66):
                bx, by = base[0] + (top[0] - base[0]) * t, base[1] + (top[1] - base[1]) * t
                d.line((bx, by, bx + rng.choice((-1, 1)) * w * .12, by - h * .09), fill=faint, width=2)
    elif suit == "fire":
        for i in range(6):
            cx = w * (.16 + i * .14)
            pts = [(cx, h * .85), (cx - 18, h * .62), (cx + 15, h * .47), (cx + rng.uniform(-20, 20), h * .18)]
            d.line(pts, fill=faint, width=rng.choice((3, 4, 5)), joint="curve")
    else:
        for i in range(5):
            y = h * (.38 + i * .09)
            pts = [(w * .04, y), (w * .25, y - 45), (w * .42, y - 12), (w * .62, y - 65), (w * .94, y)]
            d.line(pts, fill=faint, width=rng.choice((2, 3, 4)), joint="curve")
    for _ in range(34):
        x, y = rng.randrange(w), rng.randrange(h)
        r = rng.choice((1, 1, 2, 3))
        d.ellipse((x-r, y-r, x+r, y+r), fill=(*color, rng.randrange(8, 22)))


def tint_icon(mask: Image.Image, color: tuple[int, int, int], size: int) -> Image.Image:
    resized = mask.resize((size, size), Image.Resampling.LANCZOS)
    result = Image.new("RGBA", resized.size, (*color, 255))
    result.putalpha(resized)
    return result


def corner(rank: str, icon: Image.Image, color: tuple[int, int, int], scale: float) -> Image.Image:
    width, height = round(45 * scale), round(69 * scale)
    out = Image.new("RGBA", (width, height))
    d = ImageDraw.Draw(out)
    f = font(round((23 if rank != "10" else 20) * scale))
    box = d.textbbox((0, 0), rank, font=f)
    d.text(((width - box[2]) / 2, 0), rank, font=f, fill=(*color, 255), stroke_width=max(0, round(scale)-1))
    mark = tint_icon(icon, color, round(27 * scale))
    out.alpha_composite(mark, ((width-mark.width)//2, round(31*scale)))
    return out


def make_card(suit: str, rank: str, color: tuple[int, int, int], icon: Image.Image,
              size: tuple[int, int], seed: int, background: Path | None) -> Image.Image:
    w, h = size
    rng = random.Random(seed)
    image = paper(size, rng).convert("RGBA")
    if background:
        bg = cover_background(background, size)
        bg.putalpha(ImageEnhance.Brightness(bg.getchannel("A")).enhance(.35))
        image = Image.alpha_composite(image, bg)
    pattern = Image.new("RGBA", size)
    ink_pattern(pattern, suit, color, rng)
    image = Image.alpha_composite(image, pattern)
    d = ImageDraw.Draw(image, "RGBA")
    d.rounded_rectangle((5, 5, w-6, h-6), radius=10, outline=(*color, 205), width=2)
    d.rounded_rectangle((10, 10, w-11, h-11), radius=7, outline=(*color, 75), width=1)
    c = corner(rank, icon, color, w / 240)
    image.alpha_composite(c, (12, 12))
    image.alpha_composite(c.rotate(180), (w-12-c.width, h-12-c.height))
    if rank == "A":
        mark = tint_icon(icon, color, round(w * .42))
        image.alpha_composite(mark, ((w-mark.width)//2, (h-mark.height)//2))
    elif rank.isdigit():
        mark_size = round(w * .15)
        mark = tint_icon(icon, color, mark_size)
        for x, y in PIPS[int(rank)]:
            tile = mark.rotate(180) if y > .5 else mark
            image.alpha_composite(tile, (round(w*x-mark_size/2), round(h*(.15+.7*y)-mark_size/2)))
    else:
        panel = (round(w*.29), round(h*.25), round(w*.71), round(h*.75))
        d.rounded_rectangle(panel, radius=8, fill=(235, 222, 188, 155), outline=(*color, 105), width=1)
        f = font(round(w * .28))
        box = d.textbbox((0, 0), rank, font=f)
        d.text(((w-box[2])/2, (h-box[3])/2-4), rank, font=f, fill=(*color, 220))
        mark = tint_icon(icon, color, round(w*.16))
        image.alpha_composite(mark, ((w-mark.width)//2, round(h*.62)))
    return image.convert("RGB")


def main() -> int:
    here = Path(__file__).resolve().parent
    default_icons = here.parent.parent / "assets" / "card_system" / "icons"
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--output", type=Path, required=True)
    p.add_argument("--width", type=int, default=240)
    p.add_argument("--height", type=int, default=336)
    p.add_argument("--seed", type=int, default=838350)
    for suit, _, _ in SUITS:
        p.add_argument(f"--{suit}-icon", type=Path, default=default_icons / f"{suit}.svg")
        p.add_argument(f"--{suit}-background", type=Path, default=None,
                       help="Optional full-card pattern master; layout is drawn separately")
    args = p.parse_args()
    if args.width < 120 or args.height < 168:
        p.error("preview dimensions must be at least 120x168")
    args.output.mkdir(parents=True, exist_ok=True)
    icons = {}
    for suit, _, _ in SUITS:
        path = getattr(args, f"{suit}_icon")
        if not path.is_file():
            p.error(f"missing SVG icon: {path}")
        icons[suit] = svg_mask(path, 256)
    cards = []
    for suit_index, (suit, _, color) in enumerate(SUITS):
        suit_dir = args.output / suit
        suit_dir.mkdir(exist_ok=True)
        background = getattr(args, f"{suit}_background")
        if background and not background.is_file():
            p.error(f"missing background master: {background}")
        for rank_index, rank in enumerate(RANKS):
            card = make_card(suit, rank, color, icons[suit], (args.width, args.height),
                             args.seed + suit_index * 100 + rank_index, background)
            path = suit_dir / f"{rank.lower()}.png"
            card.save(path, optimize=True)
            cards.append(card)
    gap = 8
    sheet = Image.new("RGB", (13*(args.width+gap)+gap, 4*(args.height+gap)+gap), (44, 39, 31))
    for i, card in enumerate(cards):
        sheet.paste(card, (gap+(i % 13)*(args.width+gap), gap+(i // 13)*(args.height+gap)))
    sheet.save(args.output / "contact_sheet.png", optimize=True)
    print(f"generated {len(cards)} cards and contact_sheet.png in {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
