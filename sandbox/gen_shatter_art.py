"""碎牌美术件（2026-11-06 表现层接手）：裂纹 2 档 + 碎块 + 碎闪。
输出到 qiforge/assets/hud/：crack_1.png / crack_2.png / fx_shard.png / fx_break_flash.png
"""
import math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

rng = np.random.default_rng(20261106)

INK = (20, 17, 14)
PAPER_EDGE = (246, 242, 232)

# ── 裂纹 ─────────────────────────────────────────────────────────
W, H = 300, 422


def draw_crack(d, x, y, ang, length, w0, depth, branch_p):
    """折线式断裂：每段几十像素走直线，段间锐折——太碎会像铁丝，不像裂。"""
    segs = max(3, int(length / 58))
    for i in range(segs):
        step = length / segs
        nx = x + math.cos(ang) * step
        ny = y + math.sin(ang) * step
        w = max(1.6, w0 * (1.0 - 0.7 * i / segs))
        d.line([(x, y), (nx, ny)], fill=INK + (238,), width=int(round(w)))
        if w >= 2.5:
            d.line([(x + 1.6, y + 1.6), (nx + 1.6, ny + 1.6)], fill=PAPER_EDGE + (185,), width=1)
        ang += rng.choice([-1.0, 1.0]) * rng.uniform(0.16, 0.52)
        x, y = nx, ny
        if depth < 3 and rng.random() < branch_p:
            bang = ang + rng.choice([-1.0, 1.0]) * rng.uniform(0.55, 1.15)
            draw_crack(d, x, y, bang, length * 0.45, max(1.4, w * 0.55), depth + 1, branch_p * 0.5)


def make_crack(tier: int) -> Image.Image:
    """tier 1/2/3 = 轻/中/重。裂纹条数、粗细、分叉概率、飞线密度逐档递增。"""
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    if tier == 1:
        starts = [(4, 120, 0.45), (294, 300, math.pi - 0.6)]
        w0, br, ln, hairs = 6.0, 0.45, 300, 4
    elif tier == 2:
        starts = [(4, 86, 0.4), (294, 246, math.pi - 0.7)]
        w0, br, ln, hairs = 8.0, 0.58, 330, 7
    else:
        starts = [(4, 70, 0.35), (294, 210, math.pi - 0.68), (150, 4, math.pi / 2 + 0.2),
                  (36, 414, -math.pi / 2 + 0.35)]
        w0, br, ln, hairs = 10.0, 0.72, 360, 11
    for sx, sy, ang in starts:
        draw_crack(d, sx, sy, ang, ln, w0, 0, br)
    for _ in range(hairs):
        x, y = rng.uniform(30, 270), rng.uniform(30, 390)
        a = rng.uniform(0, math.tau)
        l = rng.uniform(18, 46)
        d.line([(x, y), (x + math.cos(a) * l, y + math.sin(a) * l)],
               fill=INK + (70,), width=1)
    return img.filter(ImageFilter.GaussianBlur(0.4))


cracks = [make_crack(1), make_crack(2), make_crack(3)]
for i, c in enumerate(cracks):
    c.save("qiforge/assets/hud/crack_%d.png" % (i + 1))

# ── 碎块（纸/瓷片，可染米色）────────────────────────────────────
S = 96
pts = [(50, 10), (80, 26), (86, 58), (66, 84), (34, 80), (16, 50), (24, 24)]
mask = Image.new("L", (S, S), 0)
ImageDraw.Draw(mask).polygon(pts, fill=255)
mask = mask.filter(ImageFilter.GaussianBlur(0.6))

face = Image.new("RGBA", (S, S), (0, 0, 0, 0))
ImageDraw.Draw(face).polygon(pts, fill=(228, 219, 202, 255))
hi = Image.new("L", (S, S), 0)
ImageDraw.Draw(hi).polygon([(38, 26), (66, 34), (58, 56), (32, 44)], fill=110)
hi = hi.filter(ImageFilter.GaussianBlur(5))
face = Image.composite(Image.new("RGBA", (S, S), (255, 250, 238, 255)), face, hi)

edge = Image.new("RGBA", (S, S), (0, 0, 0, 0))
ed = ImageDraw.Draw(edge)
for i in range(len(pts)):
    ed.line([pts[i], pts[(i + 1) % len(pts)]], fill=(104, 92, 72, 245), width=4)
ealpha = Image.composite(edge.split()[3].convert("L"), Image.new("L", (S, S), 0), mask)
edge.putalpha(ealpha)
face.alpha_composite(edge)
face.putalpha(mask)
face.save("qiforge/assets/hud/fx_shard.png")

# ── 碎裂闪光 ─────────────────────────────────────────────────────
F = 192
yy, xx = np.mgrid[0:F, 0:F].astype(np.float32)
cx = cy = F / 2.0
r = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2) / (F * 0.5)
core = np.clip(1.0 - r / 0.55, 0, 1) ** 2.2
ring = np.exp(-((r - 0.42) ** 2) / (2 * 0.10 ** 2)) * 0.55
a = np.clip(core + ring, 0, 1)
rgb = np.zeros((F, F, 4), np.float32)
rgb[..., 0] = 255
rgb[..., 1] = 252 - 18 * np.clip(r, 0, 1)
rgb[..., 2] = 244 - 40 * np.clip(r, 0, 1)
rgb[..., 3] = a * 255
Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8), "RGBA").save(
    "qiforge/assets/hud/fx_break_flash.png")

# ── 预览：裂纹叠在真卡上 ─────────────────────────────────────────
card = Image.new("RGBA", (300, 422), (232, 225, 212, 255))
_d = ImageDraw.Draw(card)
_d.rectangle([0, 0, 299, 421], outline=(178, 150, 92, 255), width=6)
_d.rectangle([16, 52, 283, 300], fill=(30, 44, 68, 255))
_d.rectangle([16, 312, 283, 408], fill=(220, 212, 196, 255))
_d.rectangle([16, 312, 283, 340], fill=(24, 38, 60, 255))
paper = Image.new("RGBA", (300, 422), (233, 226, 210, 255))
sheet = Image.new("RGBA", (300 * 3 + 220, 470), (28, 28, 32, 255))
for i, cr in enumerate(cracks):
    b = card.copy()
    b.alpha_composite(cr)
    sheet.alpha_composite(b, (20 + i * 320, 24))
# 实机尺寸（手牌 216 宽）看小图可辨性
small = card.copy()
small.alpha_composite(cracks[2])
small = small.resize((216, 304), Image.LANCZOS)
sheet.alpha_composite(small, (960, 90))
sheet.convert("RGB").save("sandbox/crack_preview.png")

# 碎块 + 闪光小样
prev = Image.new("RGB", (460, 200), (233, 226, 210))
sh_r = Image.open("qiforge/assets/hud/fx_shard.png").resize((120, 120), Image.LANCZOS)
fl_r = Image.open("qiforge/assets/hud/fx_break_flash.png").resize((160, 160), Image.LANCZOS)
prev.paste(sh_r, (30, 40), sh_r)
prev.paste(fl_r, (200, 20), fl_r)
prev.save("sandbox/shard_preview.png")
print("ok")
