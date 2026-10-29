# -*- coding: utf-8 -*-
"""对局 2.5D 布局效果图 V2（2026-09-24 反馈轮）
变更：
  1. 打出位＝敌我各一（各半场贴中线，各显本方最近一批＋攻击分类标）
  2. 血带重绘：朱砂笔意（玄墨底槽·渐变朱填·火头亮端·骨白数字签）
  3. 在途武学＝书本体立起于中线（m24 形制），无小黑盒；空态不画
  4. 三轨重构：功法＝书·我右手案头（亮=可发动）／护身＝书·我左手案头／心法＝竖签·侧腰
产出三帧：我方决策拍／截牌窗拍／我方发动拍。
"""
import os
from PIL import Image, ImageDraw, ImageFont

ROOT = "/Users/cc/Documents/jianghu-card-game"
MJ = os.path.join(ROOT, "forbidden-gamble/assets/mj25d")
FONT_DIR = os.path.join(ROOT, "forbidden-gamble/assets/fonts")
OUT = os.path.join(ROOT, "game-design-docs/layout_mockups")
W, H, CAP = 1280, 720, 60

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
DEEP_BLUE = (32, 48, 88)
PAGE_YELL = (216, 200, 164)

_fonts = {}
def F(n, s):
    k = (n, s)
    if k not in _fonts:
        _fonts[k] = ImageFont.truetype({
            "wk": os.path.join(FONT_DIR, "LXGWWenKai-Medium.ttf"),
            "ms": os.path.join(FONT_DIR, "MaShanZheng-Regular.ttf"),
        }[n], s)
    return _fonts[k]

_sprites = {}
def sprite(rel):
    if rel not in _sprites:
        _sprites[rel] = Image.open(os.path.join(MJ, rel)).convert("RGBA")
    return _sprites[rel]

def tile_v(face, w):
    s = sprite(f"竖/{face}.png")
    return s.resize((w, int(w * s.height / s.width)), Image.LANCZOS)

def tile_h(face, w):
    s = sprite(f"横/h{face}.png")
    return s.resize((w, int(w * s.height / s.width)), Image.LANCZOS)

def tile_back(w):
    s = sprite("背/b_01.png")
    return s.resize((w, int(w * s.height / s.width)), Image.LANCZOS)

class Ctx:
    img = None
    layers = []
    overlays = []

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
        y += font.size + 2

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

# ---------- V2 血带：朱砂笔意 ----------
def hp_track(owner, cx, y, total_w, hp, hp_max=150):
    h = 26
    slant = 9  # 斜切端头（笔锋）
    if owner == "foe":
        pts = [(cx - total_w / 2 + slant, y), (cx + total_w / 2, y),
               (cx + total_w / 2 - slant, y + h), (cx - total_w / 2, y + h)]
        live_end = y + h          # 消耗向下（向中线）
        anchor_end = y
    else:
        pts = [(cx - total_w / 2, y), (cx + total_w / 2 - slant, y),
               (cx + total_w / 2, y + h), (cx - total_w / 2 + slant, y + h)]
        live_end = y              # 消耗向上（向中线）
        anchor_end = y + h
    dr = DR()
    dr.polygon(pts, fill=(24, 21, 18), outline=(88, 78, 62))
    # 顶部内嵌高光线
    dr.line([pts[0], pts[1]], fill=(120, 108, 84), width=1)
    # 填充：沿长度渐变（外端深 → 活端亮），活端火头
    frac = max(0.0, min(1.0, hp / hp_max))
    x0, x1 = cx - total_w / 2 + 4, cx + total_w / 2 - 4
    n_seg_fill = int((x1 - x0) * frac)
    for i in range(n_seg_fill):
        t = i / max(1, (x1 - x0) * frac)
        if owner == "me":
            c = (int(150 + 62 * t), int(42 + 40 * t), int(36 + 24 * t))
        else:
            t = 1 - t
            c = (int(150 + 62 * t), int(42 + 40 * t), int(36 + 24 * t))
        xx0 = x0 + i
        inset = 3
        dr.line([(xx0, y + inset), (xx0, y + h - inset)], fill=c)
    # 火头（活端亮帽）
    if frac > 0.02:
        fx = x1 - n_seg_fill if owner == "foe" else x0 + n_seg_fill
        dr.line([(fx - 2, y + 3), (fx - 2, y + h - 3)], fill=(236, 128, 92), width=2)
    # 段刻（每 30）
    for i in range(1, hp_max // 30):
        xx = x0 + int((x1 - x0) * i / (hp_max // 30))
        dr.line([(xx, y + 2), (xx, y + h - 2)], fill=(16, 14, 12))
    # 骨白数字签（外端外侧）
    tagw = 74
    if owner == "me":
        rrect(dr, (cx - total_w / 2 - tagw - 8, y + h / 2 - 11, cx - total_w / 2 - 8, y + h / 2 + 11), 3,
              fill=BONE, outline=CHIP_BD)
        text(dr, (cx - total_w / 2 - 8 - tagw / 2, y + h / 2), f"气血 {hp}", F("wk", 12), INK, anchor="mm")
    else:
        rrect(dr, (cx - total_w / 2 - tagw - 8, y + h / 2 - 11, cx - total_w / 2 - 8, y + h / 2 + 11), 3,
              fill=BONE, outline=CHIP_BD)
        text(dr, (cx - total_w / 2 - 8 - tagw / 2, y + h / 2), f"气血 {hp}", F("wk", 12), INK, anchor="mm")

def qisea(cx, cy):
    dr = DR()
    w, h = 122, 66
    rrect(dr, (cx - w / 2, cy - h / 2 + 4, cx + w / 2, cy + h / 2 + 4), 8, fill=(50, 46, 40))
    rrect(dr, (cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2), 8, fill=(74, 69, 60), outline=CHIP_BD)
    text(dr, (cx, cy - 10), "气海", F("wk", 22), GOLD, anchor="mm")
    text(dr, (cx, cy + 15), "余 64 张", F("wk", 13), BONE, anchor="mm")

# ---------- V2 书（m24 形制） ----------
def _book_canvas(w, title, rail, dim=False, scale=2):
    """画一本平放的书（2× 超采样）。封面朝上：订口左、白签右置、签底印。"""
    cw, ch = int(w * scale), int(w * 0.764 * scale)
    im = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    cover = tuple(int(c * (0.55 if dim else 1.0)) for c in DEEP_BLUE)
    d.rounded_rectangle((1, 1, cw - 2, ch - 2), radius=3 * scale, fill=cover,
                        outline=tuple(int(c * 0.6) for c in DEEP_BLUE))
    # 订口（左缘书脊包边）
    d.rectangle((1, 1, int(cw * 0.11), ch - 2), fill=tuple(int(c * (0.45 if dim else 0.85)) for c in DEEP_BLUE))
    # 白贴签（30% 宽·75% 高·右侧）
    lx0 = int(cw * 0.58)
    d.rounded_rectangle((lx0, int(ch * 0.12), lx0 + int(cw * 0.30), int(ch * 0.88)), radius=2,
                        fill=(226, 220, 202) if not dim else (150, 145, 132))
    # 签底印
    d.rectangle((lx0 + int(cw * 0.30) // 2 - 4 * scale, int(ch * 0.70), lx0 + int(cw * 0.30) // 2 + 4 * scale,
                 int(ch * 0.70) + 8 * scale), fill=tuple(int(c * (0.6 if dim else 1.0)) for c in rail))
    # 竖排书名
    fs = max(8, int(w * 0.16))
    font = F("wk", fs)
    with Image.new("RGBA", (fs + 8, len(title) * (fs + 2) + 8), (0, 0, 0, 0)) as tf:
        td = ImageDraw.Draw(tf)
        yy = 2
        for chch in title:
            td.text(((fs + 8) / 2, yy), chch, font=font,
                    fill=INK if not dim else (110, 106, 96), anchor="ma")
            yy += fs + 2
        tf = tf.resize((max(1, int((fs + 8))), max(1, int(len(title) * (fs + 2) + 8))))
        im.paste(tf, (lx0 + int(cw * 0.30 // 2) - int((fs + 8) / 2 * 0.5), int(ch * 0.12)), tf)
    # 页册缘（右端纸黄细条）
    d.rectangle((cw - 4, int(ch * 0.18), cw - 2, int(ch * 0.82)), fill=PAGE_YELL if not dim else (140, 132, 112))
    return im.resize((int(cw / scale), int(ch / scale)), Image.LANCZOS)

def _standing_book_canvas(w, title, rail, scale=2):
    """立起的书（发动态）：封面朝镜头，微侧见脊。"""
    cw, ch = int(w * scale), int(w * 1.32 * scale)
    im = Image.new("RGBA", (cw + 10 * scale, ch), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((8 * scale, 1, 8 * scale + cw - 2, ch - 2), radius=3 * scale,
                        fill=DEEP_BLUE, outline=tuple(int(c * 0.6) for c in DEEP_BLUE))
    d.rectangle((8 * scale, 1, 8 * scale + int(cw * 0.10), ch - 2), fill=tuple(int(c * 0.85) for c in DEEP_BLUE))
    lx0 = 8 * scale + int(cw * 0.56)
    d.rounded_rectangle((lx0, int(ch * 0.08), lx0 + int(cw * 0.30), int(ch * 0.92)), radius=2, fill=(226, 220, 202))
    fs = max(9, int(w * 0.20))
    font = F("wk", fs)
    yy = int(ch * 0.14)
    for chch in title:
        d.text((lx0 + int(cw * 0.15), yy), chch, font=font, fill=INK, anchor="ma")
        yy += fs + 3
    d.rectangle((lx0 + int(cw * 0.15) - 5 * scale, int(ch * 0.78), lx0 + int(cw * 0.15) + 5 * scale,
                 int(ch * 0.78) + 10 * scale), fill=rail)
    return im.resize((int((cw + 10 * scale) / scale), int(ch / scale)), Image.LANCZOS)

def book_rack(cx, cy, specs, w=64, pivot_spread=None):
    """案头书架：同层平放小摊扇。specs: [(title, rail, lit)]"""
    n = len(specs)
    angles = [(i - (n - 1) / 2) * 13 for i in range(n)]
    for (title, rail, lit), ang in zip(specs, angles):
        bk = _book_canvas(w, title, rail, dim=not lit)
        bk = bk.rotate(ang, expand=True, resample=Image.BICUBIC)
        x = cx + (angles.index(ang) if ang in angles else 0)  # placeholder
        ctx.layers.append((bk, 0, 0))
        ctx.layers[-1] = (bk, int(cx + (ang / 13) * w * 0.62 - bk.width / 2),
                          int(cy - bk.height / 2 - abs(ang) * 0.15))
        if lit:
            dr = DR()
            rrect(dr, (cx + (ang / 13) * w * 0.62 - w / 2 - 6, cy - w * 0.764 / 2 - 6,
                       cx + (ang / 13) * w * 0.62 + w / 2 + 6, cy + w * 0.764 / 2 + 6), 6,
                  outline=tuple(GOLD) , width=2)

def standing_book(cx, cy, title, rail, remain, total):
    """中线立书（在途功法）＋拍数刻度＋光晕。"""
    w = 46
    bk = _standing_book_canvas(w, title, rail)
    # 光晕
    dr = DR()
    for i, a_ in [(0, 36), (1, 66), (2, 100)]:
        pad = 6 + i * 5
        ov = Image.new("RGBA", (W, H + CAP), (0, 0, 0, 0))
        ImageDraw.Draw(ov).rounded_rectangle(
            (cx - bk.width / 2 - pad, cy - bk.height / 2 - pad, cx + bk.width / 2 + pad, cy + bk.height / 2 + pad),
            radius=6, outline=tuple(GOLD) + (a_,), width=2)
        ctx.overlays.append(ov)
    ctx.layers.append((bk, int(cx - bk.width / 2), int(cy - bk.height / 2)))
    # 拍数刻度（更漏点）
    dr = DR()
    dot_y = cy + bk.height / 2 + 14
    x0 = cx - (total * 14 - 6) / 2
    for i in range(total):
        lit = i < remain
        dr.ellipse((x0 + i * 14, dot_y - 4, x0 + i * 14 + 8, dot_y + 4),
                   fill=GOLD if lit else (70, 66, 58),
                   outline=CHIP_BD)
    text(dr, (cx, dot_y + 12), f"余 {remain} 拍", F("wk", 12), GOLD, anchor="mm")

# ---------- V2 打出位（敌我各一） ----------
def discard_slot(cx, cy, w, h, faces, tag, tag_color, highlight=False):
    dr = DR()
    if highlight:
        rrect(dr, (cx - w / 2 - 10, cy - h / 2 - 10, cx + w / 2 + 10, cy + h / 2 + 10), 12, outline=GOLD, width=3)
    else:
        dr.rounded_rectangle((cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2), radius=10, outline=DASH)
    tw = 38 if len(faces) > 1 else 44
    total = len(faces) * (tw + 6) - 6
    x = cx - total / 2
    for f_ in faces:
        sp = tile_h(f_, tw)
        ctx.layers.append((sp, int(x), int(cy - sp.height / 2)))
        x += tw + 6
    rrect(dr, (cx - 46, cy - h / 2 - 26, cx + 46, cy - h / 2 - 6), 3, fill=CHIP_BG, outline=tag_color)
    text(dr, (cx, cy - h / 2 - 16), tag, F("wk", 12), BONE, anchor="mm")

def meld_group(cx, y_bottom, faces, tw):
    x = cx - (3 * tw + 8) / 2
    for i, f_ in enumerate(faces):
        sp = tile_h(f_, tw)
        if i == 1:
            sp = sp.rotate(90, expand=True)
        ctx.layers.append((sp, int(x), int(y_bottom - sp.height)))
        x += tw + 4

def button(box, label, rail, dim=False):
    dr = DR()
    x0, y0, x1, y1 = box
    k = 0.55 if dim else 0.45
    rrect(dr, (x0 + 1, y0 + 3, x1 + 1, y1 + 3), 10, fill=tuple(int(c * k) for c in rail))
    rrect(dr, (x0, y0, x1, y1), 8,
          fill=tuple(int(c * (0.55 if dim else 0.8)) for c in rail),
          outline=tuple(int(c * 0.55) for c in rail), width=2)
    ov = Image.new("RGBA", (int(x1 - x0), int((y1 - y0) * 0.42)), (255, 255, 255, 30 if dim else 70))
    ctx.img.paste(ov, (int(x0), int(y0)), ov)
    text(dr, ((x0 + x1) / 2, (y0 + y1) / 2 + 2), label, F("ms", 24),
         BONE if not dim else (140, 134, 122), anchor="mm")

def chip(dr, box, label, fg=BONE):
    rrect(dr, box, 4, fill=CHIP_BG, outline=CHIP_BD)
    text(dr, ((box[0] + box[2]) / 2, (box[1] + box[3]) / 2), label, F("wk", 13), fg, anchor="mm")

def sign(dr, x, y, chars, seal_color):
    rrect(dr, (x, y, x + 26, y + 80), 3, fill=BONE, outline=CHIP_BD)
    fs = 13 if len(chars) <= 2 else 12
    vtext(dr, x + 13, y + 18, chars, F("wk", fs), INK)
    dr.rectangle((x + 9, y + 5, x + 17, y + 13), fill=seal_color)

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

    # 敌手牌行
    bw, n = 23, 13
    x = 640 - (n * (bw + 4) - 4) / 2
    for i in range(n):
        ctx.layers.append((tile_back(bw), int(x), 153))
        x += bw + 4

    # 副露
    meld_group(360, 252, ["5s", "5s", "5s"], 44)
    meld_group(800, 578, ["3m", "3m", "3m"], 34)
    meld_group(945, 578, ["2p", "3p", "4p"], 34)

    # 中线战况带
    hp_track("foe", 640, 278, 400, 98)
    qisea(640, 376)
    hp_track("me", 640, 478, 400, 137)

    # 打出位（敌我各一）
    hl = (frame == "claim")
    discard_slot(640, 318, 170, 44, ["5p", "6p", "7p"], "普攻 · 3 张", BLOOD, highlight=hl)
    discard_slot(640, 436, 170, 50, ["1s"], "虚招", (110, 104, 95))

    # 在途书（中线立书）
    if frame == "cast":
        standing_book(775, 348, "点穴", ZHU, 3, 4)
    else:
        standing_book(505, 348, "破甲拳", ZHU, 2, 4)

    # 三轨：功法书（我右手案头／敌右手＝屏左，敌手牌行左侧）
    book_rack(1125, 572, [("破甲拳", ZHU, frame != "cast"), ("点穴", ZHU, False), ("连环掌", ZHU, True)], w=64)
    book_rack(378, 163, [("破甲拳", ZHU, False), ("点穴", ZHU, False), ("连环掌", ZHU, True)], w=52)
    # 护身书（我左手案头／敌左手＝屏右）
    book_rack(168, 588, [("铁布衫", ZHEJIN, True), ("金钟罩", ZHEJIN, False)], w=58)
    book_rack(948, 163, [("铁布衫", ZHEJIN, False), ("金钟罩", ZHEJIN, True)], w=48)

    button((534, 578, 638, 624), "变招", XUANQING, dim=(frame == "cast"))
    button((646, 578, 750, 624), "攻击", ZHU, dim=(frame == "cast"))

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

    # 心法签（侧腰）
    for i, nm in enumerate(["拆招诀", "运筹诀", "洗练诀"]):
        sign(dr, 9 + i * 32, 466, nm, XUANQING)
    for i, nm in enumerate(["拆招诀", "运筹诀", "洗练诀"]):
        sign(dr, 1244 - i * 32, 159, nm, XUANQING)

def claim_popup():
    dr = DR()
    px, py = 860, 232
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
    common("steady"); hand(HAND, hover=3); flush()
    caption("V2 主案 · 我方决策拍 ┃ 打出位敌我各一｜功法书=右手案头(亮=可发动) 护身书=左手案头 心法签=侧腰｜中线：敌在途破甲拳立书倒计时")
    save("layout_V2_主案_我方决策拍.png")

    common("claim"); claim_popup(); hand(HAND, dim=True); flush()
    caption("V2 主案 · 截牌窗拍 ┃ 敌打出位（上）接管焦点、截牌窗弹出、手牌压暗")
    save("layout_V2_主案_截牌窗拍.png")

    common("cast"); hand(HAND, hover=None); flush()
    caption("V2 主案 · 我方发动拍 ┃ 点穴书自我案头飞至中线立起（金晕＋拍数刻度）、按钮压暗＝本拍打出已锁定为功法")
    save("layout_V2_主案_我方发动拍.png")

if __name__ == "__main__":
    main()
