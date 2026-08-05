#!/usr/bin/env python3
"""Build the deterministic, approved four-attribute playing-card deck."""

from __future__ import annotations

import argparse
import json
import math
import random
import shutil
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont


CARD_SIZE = (700, 980)
SUITS = (
    ("wind", "风", (38, 58, 69), (-21, -37)),
    ("forest", "林", (48, 75, 56), (13, -48)),
    ("fire", "火", (168, 60, 50), (-12, -34)),
    ("mountain", "山", (138, 81, 56), (7, -34)),
)
RANKS = ("A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K")
PIP_LAYOUTS = {
    "2": ((0, -155), (0, 155)),
    "3": ((0, -155), (0, 0), (0, 155)),
    "4": ((-105, -125), (105, -125), (-105, 125), (105, 125)),
    "5": ((-105, -135), (105, -135), (0, 0), (-105, 135), (105, 135)),
    "6": ((-105, -175), (105, -175), (-105, 0), (105, 0), (-105, 175), (105, 175)),
    "7": ((-105, -185), (105, -185), (0, -92), (-105, 0), (105, 0), (-105, 185), (105, 185)),
    "8": ((-105, -185), (105, -185), (0, -92), (-105, 0), (105, 0), (0, 92), (-105, 185), (105, 185)),
    "9": ((-105, -195), (105, -195), (-105, -65), (105, -65), (0, 0), (-105, 65), (105, 65), (-105, 195), (105, 195)),
    "10": ((-105, -205), (105, -205), (0, -137), (-105, -68), (105, -68), (-105, 68), (105, 68), (0, 137), (-105, 205), (105, 205)),
}


def smoothstep(value: float) -> float:
    value = max(0.0, min(1.0, value))
    return value * value * (3.0 - 2.0 * value)


def extract_mark(source: Image.Image, index: int) -> Image.Image:
    """Remove the warm paper using a border-derived color model."""
    half_w = source.width // 2
    half_h = source.height // 2
    left = (index % 2) * half_w
    top = (index // 2) * half_h
    quadrant = source.crop((left, top, left + half_w, top + half_h)).convert("RGBA")

    border = 28
    strips = (
        quadrant.crop((0, 0, quadrant.width, border)),
        quadrant.crop((0, quadrant.height - border, quadrant.width, quadrant.height)),
        quadrant.crop((0, 0, border, quadrant.height)),
        quadrant.crop((quadrant.width - border, 0, quadrant.width, quadrant.height)),
    )
    samples = []
    for strip in strips:
        rgb_strip = strip.convert("RGB")
        samples.extend(
            rgb_strip.getpixel((x, y))
            for y in range(rgb_strip.height)
            for x in range(rgb_strip.width)
        )
    samples.sort(key=lambda pixel: sum(pixel))
    middle = samples[len(samples) // 5 : -len(samples) // 5]
    background = tuple(sum(pixel[channel] for pixel in middle) / len(middle) for channel in range(3))

    pixels = quadrant.load()
    alpha = Image.new("L", quadrant.size, 0)
    alpha_pixels = alpha.load()
    bg_luma = 0.299 * background[0] + 0.587 * background[1] + 0.114 * background[2]
    for y in range(quadrant.height):
        for x in range(quadrant.width):
            red, green, blue, _ = pixels[x, y]
            distance = math.sqrt(
                (red - background[0]) ** 2
                + (green - background[1]) ** 2
                + (blue - background[2]) ** 2
            )
            luma = 0.299 * red + 0.587 * green + 0.114 * blue
            darkness = max(0.0, bg_luma - luma)
            score = max(distance, darkness * 1.2)
            alpha_pixels[x, y] = round(255 * smoothstep((score - 18.0) / 62.0))

    alpha = alpha.filter(ImageFilter.GaussianBlur(0.45))
    threshold = alpha.point(lambda value: 255 if value > 12 else 0)
    box = threshold.getbbox()
    if box is None:
        raise RuntimeError(f"No foreground found in quadrant {index}")
    padding = 20
    box = (
        max(0, box[0] - padding),
        max(0, box[1] - padding),
        min(quadrant.width, box[2] + padding),
        min(quadrant.height, box[3] + padding),
    )
    quadrant.putalpha(alpha)
    return quadrant.crop(box)


def paper_texture(size: tuple[int, int], seed: int = 804) -> Image.Image:
    rng = random.Random(seed)
    width, height = size
    noise_size = (max(1, width // 4), max(1, height // 4))
    noise = Image.frombytes(
        "L",
        noise_size,
        bytes(rng.randrange(72, 184) for _ in range(noise_size[0] * noise_size[1])),
    ).resize(size, Image.Resampling.BICUBIC).filter(ImageFilter.GaussianBlur(0.55))
    dark = Image.new("RGB", size, (224, 211, 187))
    light = Image.new("RGB", size, (249, 244, 232))
    paper = Image.composite(light, dark, noise).convert("RGBA")
    paper = Image.blend(Image.new("RGBA", size, (241, 232, 213, 255)), paper, 0.32)
    fibers = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(fibers)
    for _ in range(260):
        x = rng.randrange(width)
        y = rng.randrange(height)
        length = rng.randrange(8, 44)
        color = (110, 91, 61, rng.randrange(3, 10))
        draw.line((x, y, x + length, y + rng.choice((-1, 0, 1))), fill=color, width=1)
    return Image.alpha_composite(paper, fibers)


def fit(image: Image.Image, bounds: tuple[int, int]) -> Image.Image:
    copy = image.copy()
    copy.thumbnail(bounds, Image.Resampling.LANCZOS)
    return copy


def paste_center(canvas: Image.Image, image: Image.Image, center: tuple[int, int]) -> None:
    x = round(center[0] - image.width / 2)
    y = round(center[1] - image.height / 2)
    canvas.alpha_composite(image, (x, y))


def visual_centroid(image: Image.Image) -> tuple[float, float]:
    """Return an opacity-weighted centroid, emphasizing the solid ink."""
    alpha = image.getchannel("A")
    pixels = alpha.load()
    weighted_x = 0.0
    weighted_y = 0.0
    total = 0.0
    for y in range(image.height):
        for x in range(image.width):
            weight = (pixels[x, y] / 255.0) ** 2
            weighted_x += x * weight
            weighted_y += y * weight
            total += weight
    if total == 0.0:
        return ((image.width - 1) / 2.0, (image.height - 1) / 2.0)
    return (weighted_x / total, weighted_y / total)


def font(size: int) -> ImageFont.FreeTypeFont:
    path = "/System/Library/AssetsV2/com_apple_MobileAsset_Font8/88d6cc32a907955efa1d014207889413890573be.asset/AssetData/Kaiti.ttc"
    return ImageFont.truetype(path, size=size, index=0)


def corner_group(mark: Image.Image, color: tuple[int, int, int], rank_text: str = "A") -> Image.Image:
    group = Image.new("RGBA", (125, 178), (0, 0, 0, 0))
    rank = Image.new("RGBA", group.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(rank)
    rank_font = font(84 if rank_text == "10" else 92)
    rank_box = draw.textbbox((0, 0), rank_text, font=rank_font)
    rank_width = rank_box[2] - rank_box[0]
    draw.text(((96 - rank_width) / 2, -8), rank_text, font=rank_font, fill=color + (255,), stroke_width=0)
    group.alpha_composite(rank)

    small = fit(mark, (72, 66))
    rank_center_x, _ = visual_centroid(rank)
    mark_center_x, _ = visual_centroid(small)
    small_x = round(rank_center_x - mark_center_x)
    small_y = round(133 - small.height / 2)
    group.alpha_composite(small, (small_x, small_y))
    return group


def draw_corner_flourish(draw: ImageDraw.ImageDraw, x: int, y: int, sx: int, sy: int, color) -> None:
    points = [
        (x, y + sy * 38),
        (x, y),
        (x + sx * 38, y),
        (x + sx * 38, y + sy * 11),
        (x + sx * 18, y + sy * 11),
        (x + sx * 18, y + sy * 27),
    ]
    draw.line(points, fill=color, width=3, joint="curve")


def card_base(color: tuple[int, int, int]) -> Image.Image:
    width, height = CARD_SIZE
    card = paper_texture(CARD_SIZE)
    rounded = Image.new("L", CARD_SIZE, 0)
    ImageDraw.Draw(rounded).rounded_rectangle((2, 2, width - 3, height - 3), radius=34, fill=255)
    card.putalpha(rounded)

    draw = ImageDraw.Draw(card)
    border = color + (218,)
    soft_border = color + (96,)
    draw.rounded_rectangle((18, 18, width - 19, height - 19), radius=26, outline=border, width=4)
    draw.rounded_rectangle((30, 30, width - 31, height - 31), radius=20, outline=soft_border, width=1)
    draw_corner_flourish(draw, 34, 34, 1, 1, border)
    draw_corner_flourish(draw, width - 35, 34, -1, 1, border)
    draw_corner_flourish(draw, 34, height - 35, 1, -1, border)
    draw_corner_flourish(draw, width - 35, height - 35, -1, -1, border)

    return card


def add_corners(card: Image.Image, mark: Image.Image, color: tuple[int, int, int], rank_text: str) -> None:
    width, height = CARD_SIZE
    group = corner_group(mark, color, rank_text)
    card.alpha_composite(group, (38, 34))
    rotated = group.rotate(180, resample=Image.Resampling.BICUBIC, expand=False)
    card.alpha_composite(rotated, (width - group.width - 38, height - group.height - 34))


def build_card(mark: Image.Image, color: tuple[int, int, int], offset: tuple[int, int]) -> Image.Image:
    """Retained for rebuilding the historical A samples only."""
    width, height = CARD_SIZE
    card = card_base(color)
    central = fit(mark, (430, 520))
    shadow_alpha = central.getchannel("A").filter(ImageFilter.GaussianBlur(14)).point(lambda value: value // 8)
    shadow = Image.new("RGBA", central.size, color + (0,))
    shadow.putalpha(shadow_alpha)
    center = (width // 2 + offset[0], height // 2 + 42 + offset[1])
    paste_center(card, shadow, center)
    paste_center(card, central, center)

    add_corners(card, mark, color, "A")
    return card


def build_number_card(mark: Image.Image, color: tuple[int, int, int], rank: str) -> Image.Image:
    card = card_base(color)
    add_corners(card, mark, color, rank)
    max_height = 72 if rank in ("9", "10") else 88
    pip = fit(mark, (112, max_height))
    center_x, center_y = CARD_SIZE[0] // 2, CARD_SIZE[1] // 2 + 18
    for dx, dy in PIP_LAYOUTS[rank]:
        placed = pip.rotate(180, resample=Image.Resampling.BICUBIC, expand=False) if dy > 0 else pip
        paste_center(card, placed, (center_x + dx, center_y + dy))
    return card


def build_court_card(mark: Image.Image, color: tuple[int, int, int], rank: str) -> Image.Image:
    card = card_base(color)
    add_corners(card, mark, color, rank)
    draw = ImageDraw.Draw(card, "RGBA")
    center_x = CARD_SIZE[0] // 2
    draw.ellipse((164, 245, 536, 735), outline=color + (92,), width=3)
    draw.ellipse((178, 259, 522, 721), outline=color + (45,), width=1)
    title_font = font(190)
    title_box = draw.textbbox((0, 0), rank, font=title_font)
    title_width = title_box[2] - title_box[0]
    draw.text((center_x - title_width / 2, 238), rank, font=title_font, fill=color + (230,))
    ornament = fit(mark, (270, 270))
    paste_center(card, ornament, (center_x, 575))
    draw.line((225, 690, 475, 690), fill=color + (105,), width=2)
    draw.line((262, 702, 438, 702), fill=color + (55,), width=1)
    return card


def output_name(suit: str, rank: str) -> str:
    rank_part = rank.lower() if rank in ("A", "J", "Q", "K") else f"{int(rank):02d}"
    return f"{suit}-{rank_part}.png"


def deck_preview(cards: list[tuple[str, str, Image.Image]]) -> Image.Image:
    thumb_size = (140, 196)
    gap = 12
    margin = 24
    label_height = 40
    width = margin * 2 + len(RANKS) * thumb_size[0] + (len(RANKS) - 1) * gap
    height = margin * 2 + 4 * (thumb_size[1] + label_height) + 3 * gap
    sheet = paper_texture((width, height), seed=806)
    label_font = font(28)
    grouped: dict[str, list[tuple[str, Image.Image]]] = {suit: [] for suit, _, _, _ in SUITS}
    for suit, rank, card in cards:
        grouped[suit].append((rank, card))
    for row, (suit, suit_zh, color, _) in enumerate(SUITS):
        y = margin + row * (thumb_size[1] + label_height + gap)
        ImageDraw.Draw(sheet).text((margin, y + 3), suit_zh, font=label_font, fill=color + (255,))
        for column, (_, card) in enumerate(grouped[suit]):
            x = margin + column * (thumb_size[0] + gap)
            thumb = card.resize(thumb_size, Image.Resampling.LANCZOS)
            sheet.alpha_composite(thumb, (x, y + label_height))
    return sheet


def build_deck(approved_dir: Path, out_dir: Path) -> None:
    out_dir.mkdir(parents=True, exist_ok=True)
    preview_dir = out_dir / "preview"
    preview_dir.mkdir(exist_ok=True)
    cards: list[tuple[str, str, Image.Image]] = []
    manifest_cards = []
    for suit, suit_zh, color, _ in SUITS:
        mark = Image.open(approved_dir / "icons" / f"{suit}.png").convert("RGBA")
        for rank in RANKS:
            filename = output_name(suit, rank)
            destination = out_dir / filename
            if rank == "A":
                shutil.copyfile(approved_dir / filename, destination)
                card = Image.open(destination).convert("RGBA")
            elif rank in PIP_LAYOUTS:
                card = build_number_card(mark, color, rank)
                card.save(destination, format="PNG", optimize=False, compress_level=9)
            else:
                card = build_court_card(mark, color, rank)
                card.save(destination, format="PNG", optimize=False, compress_level=9)
            cards.append((suit, rank, card.copy()))
            manifest_cards.append(
                {
                    "filename": filename,
                    "attribute": suit,
                    "attribute_zh": suit_zh,
                    "rank": rank,
                    "display_name_zh": f"{suit_zh}{rank}",
                    "width": card.width,
                    "height": card.height,
                }
            )
            card.close()
    manifest = {"deck": "four-attribute-deck-v1", "card_count": len(manifest_cards), "cards": manifest_cards}
    (out_dir / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    deck_preview(cards).save(
        preview_dir / "four-attribute-deck-v1-preview.png", format="PNG", optimize=False, compress_level=9
    )


def contact_sheet(cards: list[Image.Image]) -> Image.Image:
    gap = 30
    margin = 34
    width = CARD_SIZE[0] * 2 + gap + margin * 2
    height = CARD_SIZE[1] * 2 + gap + margin * 2
    sheet = paper_texture((width, height), seed=805)
    positions = (
        (margin, margin),
        (margin + CARD_SIZE[0] + gap, margin),
        (margin, margin + CARD_SIZE[1] + gap),
        (margin + CARD_SIZE[0] + gap, margin + CARD_SIZE[1] + gap),
    )
    for card, position in zip(cards, positions):
        shadow = Image.new("RGBA", card.size, (0, 0, 0, 0))
        shadow.putalpha(card.getchannel("A").filter(ImageFilter.GaussianBlur(10)).point(lambda value: value // 5))
        sheet.alpha_composite(shadow, (position[0] + 5, position[1] + 8))
        sheet.alpha_composite(card, position)
    return sheet


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path)
    parser.add_argument("--out-dir", type=Path)
    parser.add_argument("--approved-dir", type=Path)
    parser.add_argument("--deck-out-dir", type=Path)
    args = parser.parse_args()
    if args.approved_dir or args.deck_out_dir:
        if not args.approved_dir or not args.deck_out_dir:
            parser.error("--approved-dir and --deck-out-dir must be used together")
        build_deck(args.approved_dir, args.deck_out_dir)
        print(f"Wrote 52 cards, manifest, and preview to {args.deck_out_dir}")
        return
    if not args.source or not args.out_dir:
        parser.error("--source and --out-dir are required when rebuilding A samples")
    args.out_dir.mkdir(parents=True, exist_ok=True)
    icons_dir = args.out_dir / "icons"
    icons_dir.mkdir(exist_ok=True)

    source = Image.open(args.source).convert("RGBA")
    marks = [extract_mark(source, index) for index in range(4)]
    cards = []
    for mark, (name, _, color, offset) in zip(marks, SUITS):
        mark.save(icons_dir / f"{name}.png")
        card = build_card(mark, color, offset)
        card.save(args.out_dir / f"{name}-a.png")
        cards.append(card)
    contact_sheet(cards).save(args.out_dir / "four-attribute-a-samples-v1.png")

    print(f"Wrote {len(marks)} transparent marks, {len(cards)} cards, and one contact sheet to {args.out_dir}")


if __name__ == "__main__":
    main()
