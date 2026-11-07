"""经验金珠生成（2026-11-05 经验美术轮）：
同族笔法＝宣纸墨三色里的金；中心受光、右下背光、边缘深一档玉皮（这里是金皮）＋几粒溅点。
输出 qiforge/assets/hud/xp_orb.png（176×176，透明底）。
"""
import math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

S = 176
M = 4
rng = np.random.default_rng(7)

CX = CY = S / 2.0
R = S * 0.352

# ── 1) 有机边缘（极坐标谐波）＋溅点 ──────────────────────────────
harm = [(2, 0.022, 0.9), (3, 0.015, 2.1), (5, 0.010, 4.4), (7, 0.006, 1.2), (11, 0.004, 5.5)]


def edge_r(theta: float) -> float:
    r = R
    for k, a, ph in harm:
        r += R * a * math.sin(k * theta + ph)
    return r


big = Image.new("L", (S * M, S * M), 0)
d = ImageDraw.Draw(big)
pts = []
for i in range(1440):
    t = i / 1440.0 * 2.0 * math.pi
    r = edge_r(t)
    pts.append(((CX + r * math.cos(t)) * M, (CY + r * math.sin(t)) * M))
d.polygon(pts, fill=255)

# 溅点（小墨点，跟着珠走）
for ang, dist, rad in [(2.6, 1.14, 2.4), (5.2, 1.20, 1.7), (0.5, 1.16, 1.4), (3.9, 1.12, 1.9)]:
    x = CX + R * dist * math.cos(ang)
    y = CY + R * dist * math.sin(ang)
    d.ellipse([(x - rad) * M, (y - rad) * M, (x + rad) * M, (y + rad) * M], fill=255)

mask = big.resize((S, S), Image.LANCZOS)

# ── 2) 球面色（径向渐变 + 受光 + 背光）───────────────────────────
yy, xx = np.mgrid[0:S, 0:S].astype(np.float32)
dx = (xx - CX) / (S * 0.50)
dy = (yy - CY) / (S * 0.50)
dist = np.sqrt(dx * dx + dy * dy)          # 0 中心 → ≈0.7 边缘

stops_d = [0.00, 0.42, 0.72, 0.88, 1.00]
stops_c = [
    (238, 247, 255),
    (188, 214, 240),
    (126, 166, 210),
    (82, 126, 176),
    (46, 78, 120),
]
rgb = np.zeros((S, S, 3), np.float32)
for ch in range(3):
    rgb[..., ch] = np.interp(dist, stops_d, [c[ch] for c in stops_c])

# 高光（左上，椭圆高斯）
gx, gy = 0.375, 0.335
sx, sy = 0.092, 0.078
g = np.exp(-(((xx / S - gx) ** 2) / (2 * sx * sx) + ((yy / S - gy) ** 2) / (2 * sy * sy)))
rgb += (255.0 - rgb) * (g[..., None] * 0.85)

# 边缘反光（右下薄薄一圈）
gx2, gy2 = 0.70, 0.70
g2 = np.exp(-(((xx / S - gx2) ** 2) / (2 * 0.075 ** 2) + ((yy / S - gy2) ** 2) / (2 * 0.075 ** 2)))
rgb += np.array([220, 236, 255], np.float32) * (g2[..., None] * 0.30)

# 背光压暗（右下）
sx3, sy3 = 0.230, 0.230
sh = np.exp(-(((xx / S - 0.66) ** 2) / (2 * sx3 * sx3) + ((yy / S - 0.72) ** 2) / (2 * sy3 * sy3)))
rgb *= (1.0 - sh[..., None] * 0.34)

# 整体上亮下暗
rgb *= (1.05 - 0.14 * (yy / S))[..., None]

# 纸面颗粒
noise = rng.normal(0.0, 0.012, (S, S)).astype(np.float32)
rgb *= (1.0 + noise)[..., None]

rgbf = np.clip(rgb, 0, 255).astype(np.uint8)
img = Image.fromarray(rgbf, "RGB").convert("RGBA")

# ── 3) 边缘压深一档（金皮）＋轮廓线 ──────────────────────────────
inner = mask.filter(ImageFilter.MinFilter(7))          # 内缩 ≈3px
rim = np.asarray(mask, np.float32) - np.asarray(inner, np.float32)   # 0..255 边缘带
rim = np.clip(rim, 0, 255) / 255.0
arr = np.asarray(img, np.float32)
arr[..., :3] = arr[..., :3] * (1.0 - rim[..., None] * 0.40) + np.array([52, 82, 124], np.float32) * (rim[..., None] * 0.42)
img = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA")

# 轮廓：比 mask 小 1px 的带 → 深金线
er = mask.filter(ImageFilter.MinFilter(3))
line = np.clip(np.asarray(mask, np.float32) - np.asarray(er, np.float32), 0, 255) / 255.0
arr = np.asarray(img, np.float32)
arr[..., :3] = arr[..., :3] * (1.0 - line[..., None] * 0.55) + np.array([34, 56, 88], np.float32) * (line[..., None] * 0.55)
img = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA")

# ── 4) 上 alpha（软边 0.7px）────────────────────────────────────
a = np.asarray(mask.filter(ImageFilter.GaussianBlur(0.7)), np.float32)
arr = np.asarray(img, np.float32)
arr[..., 3] = a
img = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA")

img.save("qiforge/assets/hud/xp_orb.png")

# ── 5) 预览：纸底上 1:1 / 飞行尺寸 / 放大 ───────────────────────
paper = Image.new("RGBA", (620, 300), (231, 224, 211, 255))
d = ImageDraw.Draw(paper)
d.rectangle([0, 150, 619, 299], fill=(27, 41, 67, 255))   # 下半：条面的墨蓝
x = 16
for sz, label in [(176, "176"), (76, "2x38"), (51, "pop51"), (38, "38")]:
    im = img.resize((sz, sz), Image.LANCZOS)
    paper.alpha_composite(im, (x, 74 - sz // 2))
    paper.alpha_composite(im, (x, 224 - sz // 2))
    x += sz + 26
paper.convert("RGB").save("sandbox/xp_orb_preview.png")
print("ok", img.size)
