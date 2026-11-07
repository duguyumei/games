from PIL import Image, ImageFilter

BASE = "/Users/cc/Documents/qi-forge-2/sandbox"
SRC = BASE + "/shell_src2.png"         # 绿幕版源图（只读保全）
OUT = BASE + "/card_shell_v3.png"

img = Image.open(SRC).convert("RGBA")
W, H = img.size
px = img.load()

# 1) 水印：左底镜像到右底（用户裁定）——检测框 (951,2083)-(1691,2386)
x0, y0, x1, y1 = 945, 2080, 1695, 2390
patch = img.crop((W - x1, y0, W - x0, y1)).transpose(Image.FLIP_LEFT_RIGHT)
mask = Image.new("L", patch.size, 255).filter(ImageFilter.GaussianBlur(6))
img.paste(patch, (x0, y0), mask)
print("watermark mirrored")

# 2) 外框定位（非白像素）→ 裁掉白边
bx0, by0, bx1, by1 = W, H, 0, 0
for y in range(0, H, 2):
    for x in range(0, W, 2):
        r, g, b, a = px[x, y]
        mx = max(r, g, b); mn = min(r, g, b)
        br = (int(r) + int(g) + int(b)) / 3.0
        if br < 238 or mx - mn > 18:
            bx0 = min(bx0, x); bx1 = max(bx1, x)
            by0 = min(by0, y); by1 = max(by1, y)
PAD = 2
img = img.crop((max(0, bx0 - PAD), max(0, by0 - PAD), min(W, bx1 + PAD + 1), min(H, by1 + PAD + 1)))
W, H = img.size
px = img.load()
print("cropped:", img.size)

# 3) 绿键抠透（硬切：缓冲压窄到≈1px，边缘锐利）
for y in range(H):
    for x in range(W):
        r, g, b, a0 = px[x, y]
        dom = min(int(g) - int(r), int(g) - int(b))
        if dom > 26:
            a = 0
        elif dom > 19:
            a = int(255 * (26 - dom) / 7.0)
        else:
            a = 255
        # 去绿边：保留的像素若带绿溢出，压回金属色
        if a == 255 and dom > 0:
            g2 = min(int(g), (int(r) + int(b)) // 2 + 14)
            px[x, y] = (r, g2, b, a0)
        else:
            px[x, y] = (r, g, b, min(a0, a))

# 4) 透明边裁齐（绿幕漫到框外）
bx0, by0, bx1, by1 = W, H, 0, 0
for y in range(0, H, 2):
    for x in range(0, W, 2):
        if px[x, y][3] > 128:
            bx0 = min(bx0, x); bx1 = max(bx1, x)
            by0 = min(by0, y); by1 = max(by1, y)
TRIM_X = max(0, bx0 - 2)
TRIM_Y = max(0, by0 - 2)
img = img.crop((TRIM_X, TRIM_Y, min(W, bx1 + 3), min(H, by1 + 3)))
W, H = img.size
px = img.load()

# 5) 细金线修复：从源图原位置整块拷回（源里线完整饱和，直接覆盖）
src_img = Image.open(SRC).convert("RGBA")
OFF_X = TRIM_X   # 源图 → 裁后坐标偏移（用实际裁剪值）
OFF_Y = TRIM_Y
REGION = (640, 2130, 1250, 2275)   # 细线一带（v 坐标）
sx0 = REGION[0] + OFF_X
sy0 = REGION[1] + OFF_Y
patch = src_img.crop((sx0, sy0, REGION[2] + OFF_X, REGION[3] + OFF_Y))
pp = patch.load()
copied = 0
for y in range(REGION[1], REGION[3]):
    for x in range(REGION[0], REGION[2]):
        r, g, b, sa = pp[x - REGION[0], y - REGION[1]]
        dom = min(int(g) - int(r), int(g) - int(b))
        if dom > 26:
            continue   # 纯绿背景不带回来
        g2 = min(int(g), (int(r) + int(b)) // 2 + 8)   # 搬运时顺手洗绿晕
        px[x, y] = (r, g2, b, 255)
        copied += 1
print("line restored from source px:", copied)

# 6) 底部条带全面去绿晕（薄金线的 blend 绿洗成正经金色）
deg = 0
for y in range(2100, H):
    for x in range(0, W):
        r, g, b, a = px[x, y]
        if a > 0 and int(g) > (int(r) + int(b)) // 2 + 6:
            px[x, y] = (r, (int(r) + int(b)) // 2 + 6, b, a)
            deg += 1
print("de-greened px:", deg)

OUT = BASE + "/card_shell_v6.png"
img.save(OUT)
print("green keyed + trimmed ->", OUT, img.size)

# 预览
bg = Image.new("RGBA", (W + 160, H + 160), (23, 19, 13, 255))
bg.alpha_composite(img, (80, 80))
bg.convert("RGB").save("/Users/cc/shell_v6_dark.png")
small = img.resize((300, 422), Image.LANCZOS)
bg2 = Image.new("RGBA", (460, 562), (23, 19, 13, 255))
bg2.alpha_composite(small, (80, 70))
bg2.convert("RGB").save("/Users/cc/shell_v6_game.png")

p2 = img.load()
print("== 行剖面（卡y） ==")
for pct in range(0, 100, 2):
    vals = [sum(p2[x, y][:3]) / 3.0 for y in range(int(H * pct / 100), int(H * (pct + 2) / 100), 5)
            for x in range(int(W * 0.10), int(W * 0.90), 10) if p2[x, y][3] > 128]
    m = int(sum(vals) / max(1, len(vals))) if vals else 0
    print(f"y{pct:3d}%: {m:3d}  card_y={pct * 4.22:.0f}")
print("== 列剖面（窗行带） ==")
for pct in range(0, 100, 2):
    vals = [sum(p2[x, y][:3]) / 3.0 for x in range(int(W * pct / 100), int(W * (pct + 2) / 100), 4)
            for y in range(int(H * 0.30), int(H * 0.50), 6) if p2[x, y][3] > 128]
    m = int(sum(vals) / max(1, len(vals))) if vals else 0
    print(f"x{pct:3d}%: {m:3d}  card_x={pct * 3.0:.0f}")
