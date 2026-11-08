from PIL import Image

BASE = "/Users/cc/Documents/qi-forge-2/sandbox"
SRC = BASE + "/card_shell_v6.png"
OUT = BASE + "/card_fill.png"

img = Image.open(SRC).convert("RGBA")
W, H = img.size
px = img.load()

# 框外＝从画布四边漫水（穿越透明/半透明弱的像素），补集填乌木黑
VIS = [False] * (W * H)
stack = []
for x in range(W):
    for y in (0, H - 1):
        if px[x, y][3] < 60:
            VIS[y * W + x] = True
            stack.append((x, y))
for y in range(H):
    for x in (0, W - 1):
        if not VIS[y * W + x] and px[x, y][3] < 60:
            VIS[y * W + x] = True
            stack.append((x, y))
while stack:
    x, y = stack.pop()
    for nx, ny in ((x+1,y),(x-1,y),(x,y+1),(x,y-1)):
        if 0 <= nx < W and 0 <= ny < H and not VIS[ny * W + nx] and px[nx, ny][3] < 60:
            VIS[ny * W + nx] = True
            stack.append((nx, ny))

fill = Image.new("RGBA", (W, H), (0, 0, 0, 0))
fp = fill.load()
n = 0
for y in range(H):
    for x in range(W):
        if not VIS[y * W + x]:
            fp[x, y] = (26, 20, 13, 255)
            n += 1
fill.save(OUT)
print("fill px:", n, "->", OUT)

# 验证预览：填充层 + 壳叠加 压深底
shell = Image.open(SRC).convert("RGBA")
comp = Image.new("RGBA", (W, H))
comp.alpha_composite(fill)
comp.alpha_composite(shell)
bg = Image.new("RGBA", (W + 120, H + 120), (23, 19, 13, 255))
bg.alpha_composite(comp, (60, 60))
bg.convert("RGB").save("/Users/cc/fill_preview.png")
print("preview ok")
