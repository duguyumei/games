# -*- coding: utf-8 -*-
"""对局 2.5D 布局效果图生成器（2026-09-24 总体设计轮）
产出三张 1280×720(+60 说明条) 全帧布局图，供用户挑选：
  A1 主案 · 垂直交换轴（我方决策拍 / 截牌窗拍）
  A2 备选 · 对角打出位
素材：mahjong_graphic 牌面精灵 + 霞鹜文楷/马善政（项目字体）。
"""
import os
from PIL import Image, ImageDraw, ImageFont

ROOT = "/Users/cc/Documents/jianghu-card-game"
MJ = os.path.join(ROOT, "forbidden-gamble/assets/mj25d")
FONT_DIR = os.path.join(ROOT, "forbidden-gamble/assets/fonts")
OUT = os.path.join(ROOT, "game-design-docs/layout_mockups")
W, H, CAP = 1280, 720, 60

# ---------- 色板（对局呈现_v1 用色档） ----------
ROOM = (48, 56, 66)
FELT = (33, 84, 57)
RIM_TOP = (88, 63, 40)
RIM_WALL = (60, 43, 28)
BONE = (217, 204, 174)
GOLD = (235, 219, 179)
BLOOD = (184, 64, 51)
ZHU = (184, 64, 51)
ZHEJIN = (194, 156, 79)
XUANQING = (61, 84, 89)
INK = (33, 28, 23)
CHIP_BG = (26, 24, 21)
CHIP_BD = (112, 100, 77)
DASH = (150, 138, 112)
FAINT = (172, 160, 132)
DEEP_BLUE = (30, 46, 82)

_fonts = {}
def F(name, size):
    key = (name, size)
    if key not in _fonts:
        path = {
            "wk": os.path.join(FONT_DIR, "LXGWWenKai-Medium.ttf"),
            "ms": os.path.join(FONT_DIR, "MaShanZheng-Regular.ttf"),
        }[name]
        _fonts[key] = ImageFont.truetype(path, size)
    return _fonts[key]

_sprites = {}
def sprite(rel):
    if rel not in _sprites:
        _sprites[rel] = Image.open(os.path.join(MJ, rel)).convert("RGBA")
    return _sprites[rel]

def tile_v(face, w):
    s = sprite(f"竖/{face}.png")
    return s.resize((w, int(w * s.height / s.width)), Image.LANCZOS)

def tile_h(face, w, rot=False):
    s = sprite(f"横/h{face}.png")
    s = s.resize((w, int(w * s.height / s.width)), Image.LANCZOS)
    if rot:
        s = s.rotate(90, expand=True)
    return s

def tile_back(w):
    s = sprite("背/b_01.png")
    return s.resize((w, int(w * s.height / s.width)), Image.LANCZOS)

# ---------- 画布状态 ----------
class Ctx:
    img = None
    layers = []     # (sprite, x_left, y_top[, alpha])
    overlays = []   # RGBA 全幅覆盖层

ctx = Ctx()
def DR():
    return ImageDraw.Draw(ctx.img)

def rrect(dr, box, r, fill=None, outline=None, width=1):
    dr.rounded_rectangle(box, radius=r, fill=fill, outline=outline, width=width)

def text(dr, xy, s, font, fill, anchor="la"):
    dr.text(xy, s, font=font, fill=fill, anchor=anchor)

def vtext(dr, cx, top, chars, font, fill):
    y = top
    for ch in chars:
        dr.text((cx, y), ch, font=font, fill=fill, anchor="ma")
        y += font.size + 3

def chip(dr, box, label, fg=BONE):
    rrect(dr, box, 4, fill=CHIP_BG, outline=CHIP_BD)
    text(dr, ((box[0] + box[2]) / 2, (box[1] + box[3]) / 2), label, F("wk", 13), fg, anchor="mm")

def sign(dr, x, y, chars, seal_color):
    rrect(dr, (x, y, x + 26, y + 80), 3, fill=BONE, outline=CHIP_BD)
    fs = 13 if len(chars) <= 2 else 12
    vtext(dr, x + 13, y + 18, chars, F("wk", fs), INK)
    dr.rectangle((x + 9, y + 5, x + 17, y + 13), fill=seal_color)

def pastea(img, sp, x_left, y_top, alpha=255):
    if alpha < 255:
        a = sp.getchannel("A").point(lambda v: v * alpha // 255)
        sp = sp.copy()
        sp.putalpha(a)
    img.paste(sp, (int(x_left), int(y_top)), sp)

def flush():
    for it in ctx.layers:
        pastea(ctx.img, it[0], it[1], it[2], it[3] if len(it) > 3 else 255)
    ctx.layers = []
    for ov in ctx.overlays:
        ctx.img = Image.alpha_composite(ctx.img.convert("RGBA"), ov).convert("RGB")
    ctx.overlays = []

# ---------- 桌面 ----------
def draw_table():
    dr = DR()
    dr.polygon([(225, 96), (1055, 96), (1330, 722), (-50, 722)], fill=RIM_WALL)
    dr.polygon([(228, 101), (1052, 101), (1318, 718), (-38, 718)], fill=RIM_TOP)
    dr.polygon([(255, 122), (1025, 122), (1272, 708), (8, 708)], fill=FELT)
    ov = Image.new("RGBA", (W, H + CAP), (0, 0, 0, 0))
    d2 = ImageDraw.Draw(ov)
    d2.polygon([(255, 122), (1025, 122), (1025, 192), (255, 192)], fill=(0, 0, 0, 46))
    d2.polygon([(8, 560), (1272, 560), (1272, 708), (8, 708)], fill=(255, 255, 255, 10))
    d2.line([(320, 374), (540, 374)], fill=(58, 108, 76, 110), width=2)
    d2.line([(740, 374), (960, 374)], fill=(58, 108, 76, 110), width=2)
    ctx.img = Image.alpha_composite(ctx.img.convert("RGBA"), ov).convert("RGB")

# ---------- 组件 ----------
def hp_track(owner, cx, y, total_w, hp, hp_max=150):
    """透视躺盘血带：外端锚定、失血向中线；刻线每 30；数字正立归读者。"""
    dr = DR()
    h = 26
    sk = 14
    if owner == "foe":
        pts = [(cx - total_w / 2 + sk, y), (cx + total_w / 2 - sk, y),
               (cx + total_w / 2, y + h), (cx - total_w / 2, y + h)]
    else:
        pts = [(cx - total_w / 2, y), (cx + total_w / 2, y),
               (cx + total_w / 2 - sk, y + h), (cx - total_w / 2 + sk, y + h)]
    dr.polygon(pts, fill=(20, 24, 22), outline=CHIP_BD)
    frac = max(0.0, min(1.0, hp / hp_max))
    x0, x1 = cx - total_w / 2 + 3, cx + total_w / 2 - 3
    if owner == "me":
        yf = (y + h - 3) - frac * (h - 6)
    else:
        yf = (y + 3) + frac * (h - 6)
    ov = Image.new("RGBA", (W, H + CAP), (0, 0, 0, 0))
    d2 = ImageDraw.Draw(ov)
    d2.polygon([(x0, min(yf, y + h - 3) if owner == "me" else y + 3),
                (x1, min(yf, y + h - 3) if owner == "me" else y + 3),
                (x1, y + h - 3 if owner == "me" else yf),
                (x0, y + h - 3 if owner == "me" else yf)], fill=tuple(BLOOD) + (235,))
    ctx.img = Image.alpha_composite(ctx.img.convert("RGBA"), ov).convert("RGB")
    dr = DR()
    for i in range(1, hp_max // 30):
        t = i / (hp_max // 30)
        yy = (y + h - 3) - t * (h - 6) if owner == "me" else (y + 3) + t * (h - 6)
        dr.line([(x0 + 1, yy), (x1 - 1, yy)], fill=(14, 14, 12))
    label = f"气血 {hp}"
    if owner == "me":
        text(dr, (cx - total_w / 2, y + h + 8), label, F("wk", 13), GOLD, anchor="lm")
    else:
        text(dr, (cx - total_w / 2, y - 9), label, F("wk", 13), GOLD, anchor="lm")

def qisea(cx, cy):
    dr = DR()
    w, h = 122, 66
    rrect(dr, (cx - w / 2, cy - h / 2 + 4, cx + w / 2, cy + h / 2 + 4), 8, fill=(50, 46, 40))
    rrect(dr, (cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2), 8, fill=(74, 69, 60), outline=CHIP_BD)
    text(dr, (cx, cy - 10), "气海", F("wk", 22), GOLD, anchor="mm")
    text(dr, (cx, cy + 15), "余 64 张", F("wk", 13), BONE, anchor="mm")

def inflight(cx, cy, active, name=None, remain=None):
    dr = DR()
    w, h = 96, 72
    if active:
        rrect(dr, (cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2), 8, fill=(24, 27, 27), outline=ZHEJIN, width=2)
        bx, by = cx - w / 2 + 9, cy - h / 2 + 11
        dr.rectangle((bx, by, bx + 26, by + 34), fill=DEEP_BLUE, outline=(18, 28, 52))
        dr.rectangle((bx + 6, by + 4, bx + 20, by + 30), fill=(228, 222, 205))
        dr.rectangle((bx + 10, by + 2, bx + 16, by + 8), fill=ZHU)
        text(dr, (cx + 14, cy - 8), name, F("wk", 16), BONE, anchor="mm")
        text(dr, (cx, cy + h / 2 - 14), f"余 {remain} 拍", F("wk", 15), GOLD, anchor="mm")
    else:
        dr.rounded_rectangle((cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2), radius=8, outline=DASH)
        ov = Image.new("RGBA", (W, H + CAP), (0, 0, 0, 0))
        ImageDraw.Draw(ov).text((cx, cy), "发动位", font=F("wk", 13), fill=tuple(BONE) + (110,), anchor="mm")
        ctx.overlays.append(ov)

def discard_slot(cx, cy, w, h, ghost=None, active=None, tag=None):
    dr = DR()
    if active:
        rrect(dr, (cx - w / 2 - 10, cy - h / 2 - 10, cx + w / 2 + 10, cy + h / 2 + 10), 12, outline=GOLD, width=3)
        tw = 54
        total = len(active) * (tw + 6) - 6
        x = cx - total / 2
        for f_ in active:
            sp = tile_h(f_, tw)
            ctx.layers.append((sp, int(x), int(cy - sp.height / 2)))
            x += tw + 6
        if tag:
            rrect(dr, (cx - 54, cy - h / 2 - 40, cx + 54, cy - h / 2 - 16), 4, fill=CHIP_BG, outline=BLOOD)
            text(dr, (cx, cy - h / 2 - 28), tag, F("wk", 14), BONE, anchor="mm")
    else:
        dr.rounded_rectangle((cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2), radius=10, outline=DASH)
        if ghost:
            tw = 34
            total = len(ghost) * (tw + 5) - 5
            x = cx - total / 2
            for f_ in ghost:
                sp = tile_h(f_, tw)
                ctx.layers.append((sp, int(x), int(cy - sp.height / 2), 70))
                x += tw + 5
            text(dr, (cx + w / 2 - 6, cy - h / 2 + 5), "上一批", F("wk", 11), FAINT, anchor="rd")
        else:
            text(dr, (cx + w / 2 - 5, cy + h / 2 - 5), "打出位", F("wk", 11), FAINT, anchor="rd")

def meld_group(cx, y_bottom, faces, tw):
    x = cx - (3 * tw + 8) / 2
    for i, f_ in enumerate(faces):
        sp = tile_h(f_, tw, rot=(i == 1))
        ctx.layers.append((sp, int(x), int(y_bottom - sp.height)))
        x += tw + 4

def button(box, label, rail):
    dr = DR()
    x0, y0, x1, y1 = box
    rrect(dr, (x0 + 1, y0 + 3, x1 + 1, y1 + 3), 10, fill=tuple(int(c * 0.45) for c in rail))
    rrect(dr, (x0, y0, x1, y1), 8, fill=tuple(int(c * 0.8) for c in rail),
          outline=tuple(int(c * 0.55) for c in rail), width=2)
    ov = Image.new("RGBA", (int(x1 - x0), int((y1 - y0) * 0.42)), (255, 255, 255, 70))
    ctx.img.paste(ov, (int(x0), int(y0)), ov)
    text(dr, ((x0 + x1) / 2, (y0 + y1) / 2 + 2), label, F("ms", 24), BONE, anchor="mm")

# ---------- 布局 ----------
HAND = ["1m", "2m", "3m", "5m", "7m", "8m", "9m", "2p", "3p", "4p", "6p", "2s", "3s", "5s"]

def hand(faces, hover=None, dim=False):
    tw, sp = 47, 50
    x = 640 - (len(faces) * sp - (sp - tw)) / 2
    for i, f_ in enumerate(faces):
        lift = 12 if i == hover else 0
        yb = 716 + lift
        ctx.layers.append((tile_v(f_, tw), int(x), int(yb - tw * 389 / 272)))
        if i == hover:
            DR().rounded_rectangle((x - 4, yb - 80, x + tw + 4, yb + 4), 6, outline=GOLD, width=2)
        x += sp
    if dim:
        ov = Image.new("RGBA", (W, H + CAP), (0, 0, 0, 0))
        ImageDraw.Draw(ov).rectangle((0, 630, W, 712), fill=(0, 0, 0, 100))
        ctx.overlays.append(ov)

def common(frame):
    ctx.img = Image.new("RGB", (W, H + CAP), ROOM)
    draw_table()
    dr = DR()

    # 敌手牌行（13 背）
    bw, n = 23, 13
    x = 640 - (n * (bw + 4) - 4) / 2
    for i in range(n):
        ctx.layers.append((tile_back(bw), int(x), 153))
        x += bw + 4

    # 副露：敌左翼 1.3× 作弊；我右翼严格
    meld_group(360, 252, ["5s", "5s", "5s"], 44)
    meld_group(800, 578, ["3m", "3m", "3m"], 34)
    meld_group(945, 578, ["2p", "3p", "4p"], 34)

    # 中线战况带
    hp_track("foe", 640, 278, 400, 98)
    qisea(640, 376)
    inflight(502, 350, True, "破甲拳", 2)
    inflight(735 if frame == "A2" else 778, 386, False)
    hp_track("me", 640, 478, 400, 137)

    # 打出位
    if frame == "A2":
        discard_slot(350, 320, 160, 52)                       # 我打出 → 敌半场左（河锚·我左上）
        discard_slot(880, 428, 190, 56, ghost=["8m"])          # 敌打出 → 我半场右（河锚·敌右下）
    else:
        discard_slot(640, 324, 150, 36)                        # 我打出 → 中线上段
        if frame == "A1b":
            discard_slot(640, 440, 178, 54, active=["5p", "6p", "7p"], tag="普攻 · 3 张")
        else:
            discard_slot(640, 440, 178, 54, ghost=["8m"])      # 敌打出 → 中线下段

    button((534, 578, 638, 624), "变招", XUANQING)
    button((646, 578, 750, 624), "攻击", ZHU)

    # ---- HUD ----
    dr = DR()
    dr.rectangle((0, 0, W, 30), fill=(23, 22, 20))
    dr.line([(0, 30), (W, 30)], fill=CHIP_BD)
    text(dr, (12, 15), "‹ 演武场", F("wk", 13), BONE, anchor="lm")
    text(dr, (640, 15), "回合 12 · 组 1-3", F("wk", 13), GOLD, anchor="mm")

    rrect(dr, (1216, 38, 1271, 93), 4, fill=(33, 28, 23), outline=CHIP_BD)
    text(dr, (1243, 65), "玄", F("ms", 22), GOLD, anchor="mm")
    chip(dr, (1117, 36, 1215, 64), "罡 10　变 9")
    chip(dr, (1117, 65, 1215, 93), "攻 12　防 8")
    chip(dr, (1136, 94, 1270, 122), "劲 10　骨 3　气 12")
    chip(dr, (146, 34, 236, 62), "丹田 · 13", fg=GOLD)

    rrect(dr, (9, 651, 64, 706), 4, fill=(33, 28, 23), outline=CHIP_BD)
    text(dr, (36, 678), "无", F("ms", 22), GOLD, anchor="mm")
    chip(dr, (10, 622, 144, 650), "劲 10　骨 3　气 12")
    chip(dr, (65, 651, 163, 679), "攻 12　防 8")
    chip(dr, (65, 680, 163, 708), "罡 10　变 9")
    chip(dr, (1116, 685, 1214, 713), "丹田 · 16", fg=GOLD)

    for i, nm in enumerate(["点穴", "连环掌", "破甲拳"]):
        sign(dr, 163 - i * 32, 74, nm, ZHU)
    for i, nm in enumerate(["铁布衫", "金钟罩"]):
        sign(dr, 163 - i * 32, 174, nm, ZHEJIN)
    for i, nm in enumerate(["拆招诀", "运筹诀", "洗练诀"]):
        sign(dr, 1244 - i * 32, 159, nm, XUANQING)
    for i, nm in enumerate(["点穴", "连环掌", "破甲拳"]):
        sign(dr, 1118 + i * 32, 596, nm, ZHU)
    for i, nm in enumerate(["铁布衫", "金钟罩"]):
        sign(dr, 1118 + i * 32, 498, nm, ZHEJIN)
    for i, nm in enumerate(["拆招诀", "运筹诀", "洗练诀"]):
        sign(dr, 9 + i * 32, 506, nm, XUANQING)

def claim_popup():
    dr = DR()
    px, py = 850, 380
    rrect(dr, (px, py, px + 188, py + 128), 8, fill=(23, 22, 20), outline=CHIP_BD, width=2)
    text(dr, (px + 94, py + 20), "截牌窗", F("wk", 15), GOLD, anchor="mm")
    for i, (nm, en) in enumerate([("吃", False), ("碰", True), ("杠", False), ("放行", None)]):
        bx = px + 12 + (i % 2) * 88
        by = py + 38 + (i // 2) * 44
        if en is True:
            rrect(dr, (bx, by, bx + 76, by + 32), 6, fill=tuple(int(c * 0.85) for c in ZHU), outline=ZHU)
            fg = BONE
        elif en is False:
            rrect(dr, (bx, by, bx + 76, by + 32), 6, fill=(45, 43, 40), outline=(70, 66, 60))
            fg = (110, 104, 95)
        else:
            rrect(dr, (bx, by, bx + 76, by + 32), 6, fill=CHIP_BG, outline=CHIP_BD)
            fg = BONE
        text(dr, (bx + 38, by + 16), nm, F("ms", 18), fg, anchor="mm")

def caption(txt):
    dr = ImageDraw.Draw(ctx.img)
    dr.rectangle((0, H, W, H + CAP), fill=(18, 20, 24))
    text(dr, (W / 2, H + CAP / 2), txt, F("wk", 17), BONE, anchor="mm")

def save(name):
    ctx.img.save(os.path.join(OUT, name))
    print("saved", name)

def main():
    os.makedirs(OUT, exist_ok=True)
    common("A1a"); hand(HAND, hover=3); flush(); caption("主案 A1 · 垂直交换轴 ┃ 我方决策拍：手牌为唯一焦点、中线静默（敌在途功法低频走钟）"); save("layout_A1_主案_我方决策拍.png")
    common("A1b"); claim_popup(); hand(HAND, dim=True); flush(); caption("主案 A1 · 截牌窗拍：敌打出沿中线推至我面前并接管焦点，手牌压暗、弹窗随窗计时"); save("layout_A1_主案_截牌窗拍.png")
    common("A2"); hand(HAND, hover=3); flush(); caption("备选 A2 · 对角打出位（承袭牌河锚定 我左上／敌右下）┃ 除打出位落点外与主案一致"); save("layout_A2_备选_对角打出位.png")

if __name__ == "__main__":
    main()
