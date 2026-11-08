# 垫底剪影 v2：行/列跨度法（修 v1 灌水法底部角部口袋误判）
# 规则：壳(v9)每行 alpha>100 的最左/最右 = 行界；每列最上/最下 = 列界；
#       垫底只允许在 行界之间 且 列界之间 —— 框外任何口袋一律出局
from PIL import Image

SH = 'card_shell_v9.png'
OUT = 'card_fill_v2.png'
sh = Image.open(SH).convert('RGBA')
W, H = sh.size
px = sh.load()

span_x = {}  # y -> (fx0, fx1)
for y in range(H):
    xs = [x for x in range(W) if px[x, y][3] > 100]
    if xs:
        span_x[y] = (min(xs), max(xs))
span_y = {}  # x -> (fy0, fy1)
for x in range(W):
    ys = [y for y in range(H) if px[x, y][3] > 100]
    if ys:
        span_y[x] = (min(ys), max(ys))

fill = Image.new('RGBA', (W, H), (0, 0, 0, 0))
fp = fill.load()
n = 0
for y in range(H):
    if y not in span_x:
        continue
    fx0, fx1 = span_x[y]
    for x in range(fx0 + 1, fx1):
        if x in span_y:
            fy0, fy1 = span_y[x]
            if fy0 < y < fy1:
                fp[x, y] = (26, 20, 13, 255)
                n += 1
fill.save(OUT)
print(f'{OUT}: 不透明px={n}')

# 复核：v1 相比 v2 多出的像素（应集中在底部两角）
old = Image.open('card_fill.png').convert('RGBA').load()
extra = sum(1 for y in range(H) for x in range(0, W, 2)
            if old[x, y][3] > 60 and fp[x, y][3] == 0)
print(f'v1 多出(已修掉的漏出)px≈{extra*2}')
