# -*- coding: utf-8 -*-
"""对局布局效果图 V4（2026-09-24 技能架形制轮）
变更：
  1. 发动位翻侧：我方在途立签＝气海左侧、敌方＝右侧（回归 我左/敌右 牌河锚定语义）；
  2. 技能架三版形制供选：
     A 挂签架——横杆挂书签（签孔+绳+流苏，流苏色=轨色，空槽=垂空绳）；
     B 托盘嵌槽——统一漆盘内嵌槽位、书签立于槽中（Balatro 托盘式）；
     C 角花框线——委角双框+四角金角花（Kenney/金钮描边语汇式）。
产出：A/B/C 三张决策拍 + A 版发动拍。
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
ZHU = (184, 64, 51)
ZHEJIN = (194, 156, 79)
XUANQING = (61, 84, 89)
INK = (33, 28, 23)
CHIP_BG = (26, 24, 21)
CHIP_BD = (112, 100, 77)
DASH = (150, 138, 112)
PAPER = (222, 212, 188)
WOOD = (96, 68, 42)
WOOD_D = (66, 46, 28)
TRAY = (34, 29, 24)

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
        y += font.size + 1

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

def tint(c, base, k):
    return tuple(int(a + (b - a) * k) for a, b in zip(c, base))

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

def hp_track(owner, cx, y, total_w, hp, hp_max=150):
    h = 26
    slant = 9
    if owner == "foe":
        pts = [(cx - total_w / 2 + slant, y), (cx + total_w / 2, y),
               (cx + total_w / 2 - slant, y + h), (cx - total_w / 2, y + h)]
    else:
        pts = [(cx - total_w / 2, y), (cx + total_w / 2 - slant, y),
               (cx + total_w / 2, y + h), (cx - total_w / 2 + slant, y + h)]
    dr = DR()
    dr.polygon(pts, fill=(24, 21, 18), outline=(88, 78, 62))
    dr.line([pts[0], pts[1]], fill=(120, 108, 84))
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
        dr.line([(x0 + i, y + 3), (x0 + i, y + h - 3)], fill=c)
    if frac > 0.02:
        fx = x1 - n_seg_fill if owner == "foe" else x0 + n_seg_fill
        dr.line([(fx - 2, y + 3), (fx - 2, y + h - 3)], fill=(236, 128, 92), width=2)
    for i in range(1, hp_max // 30):
        xx = x0 + int((x1 - x0) * i / (hp_max // 30))
        dr.line([(xx, y + 2), (xx, y + h - 2)], fill=(16, 14, 12))
    tagw = 74
    rrect(dr, (cx - total_w / 2 - tagw - 8, y + h / 2 - 11, cx - total_w / 2 - 8, y + h / 2 + 11), 3,
          fill=PAPER, outline=CHIP_BD)
    text(dr, (cx - total_w / 2 - 8 - tagw / 2, y + h / 2), f"气血 {hp}", F("wk", 12), INK, anchor="mm")

def qisea(cx, cy):
    dr = DR()
    w, h = 122, 66
    rrect(dr, (cx - w / 2, cy - h / 2 + 4, cx + w / 2, cy + h / 2 + 4), 8, fill=(50, 46, 40))
    rrect(dr, (cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2), 8, fill=(74, 69, 60), outline=CHIP_BD)
    text(dr, (cx, cy - 10), "气海", F("wk", 22), GOLD, anchor="mm")
    text(dr, (cx, cy + 15), "余 64 张", F("wk", 13), BONE, anchor="mm")

# ---------- V4 技能架三形制 ----------
def _paper_content(dr, x, y, w, h, title, rail, state, badge, ytop):
    """书签内容：轨色晕染图区＋大字压纹＋竖排名＋底印＋（暗态角标）。"""
    base = PAPER if state == "lit" else (172, 164, 148)
    dr.polygon([(x + 4, ytop), (x + w - 4, ytop), (x + w, ytop + 4), (x + w, y),
                (x, y), (x, ytop + 4)], fill=base, outline=CHIP_BD)
    ah = int(h * 0.56)
    dr.rectangle((x + 2, ytop + ah, x + w - 2, y), fill=base)
    dr.rectangle((x, y, x + w, y), fill=base)
    rrect(dr, (x + 3, ytop + 5, x + w - 3, ytop + ah), 2, fill=tint(rail, base, 0.55))
    cxm, cym = x + w / 2, ytop + 5 + (ah - 5) / 2
    text(dr, (cxm, cym), title[0], F("wk", int(w * 0.5)), tint(rail, PAPER, 0.72), anchor="mm")
    dr.ellipse((cxm - 2, cym - int(w * 0.3), cxm + 2, cym - int(w * 0.3) + 4), fill=tint(rail, base, 0.3))
    fs = 11 if len(title) <= 3 else 10
    vtext(dr, x + w / 2, ytop + ah + 4, title, F("wk", fs), INK if state == "lit" else (100, 96, 88))
    dr.rectangle((x + w - 8, y - 8, x + w - 3, y - 3), fill=rail)
    if state == "dim" and badge:
        bw = 12 + len(badge) * 7
        rrect(dr, (x + w - bw - 2, ytop + 2, x + w - 2, ytop + 14), 3, fill=(120, 38, 32))
        text(dr, (x + w - 2 - bw / 2, ytop + 8), badge, F("wk", 9), (240, 230, 210), anchor="mm")

def bm_hang(cx, rail_y, title, rail, state="lit", badge=None):
    """A 挂签：横杆→绳→签孔→纸签→流苏。空槽=垂空绳。"""
    dr = DR()
    w = 30
    ph = 62
    # 绳＋签孔
    dr.line([(cx, rail_y), (cx, rail_y + 9)], fill=(150, 132, 100), width=2)
    dr.ellipse((cx - 3, rail_y + 9, cx + 3, rail_y + 15), outline=(120, 104, 78), width=2)
    if state == "empty":
        return
    if state == "ghost":
        dr.rounded_rectangle((cx - w / 2, rail_y + 18, cx + w / 2, rail_y + 18 + ph), 3, outline=rail, width=2)
        vtext(dr, cx, rail_y + 26, title, F("wk", 11), tint(rail, PAPER, 0.5))
    else:
        ytop = rail_y + 18
        _paper_content(dr, cx - w / 2, ytop + ph, w, ph, title, rail, state, badge, ytop)
        if state == "lit":
            dr.line([(cx - w / 2, ytop), (cx + w / 2, ytop)], fill=GOLD, width=1)
    # 流苏（轨色；暗态灰）
    ty = rail_y + 18 + ph + 2
    tc = rail if state == "lit" else (130, 124, 112)
    dr.rectangle((cx - 2, ty, cx + 2, ty + 4), fill=tc)
    for dx in (-3, 0, 3):
        dr.line([(cx + dx, ty + 4), (cx + dx, ty + 11)], fill=tc, width=1)

def bm_tray(x, slot_y, title, rail, state="lit", badge=None):
    """B 托盘嵌槽：书签立于凹槽，下半没入。空槽=露凹槽。"""
    dr = DR()
    w = 30
    ph = 50
    rrect(dr, (x, slot_y, x + w, slot_y + 26), 3, fill=(22, 19, 16), outline=(70, 62, 50))
    if state == "empty":
        return
    if state == "ghost":
        dr.rounded_rectangle((x, slot_y - ph, x + w, slot_y + 10), 3, outline=rail, width=2)
        vtext(dr, x + w / 2, slot_y - ph + 8, title, F("wk", 11), tint(rail, PAPER, 0.5))
        return
    _paper_content(dr, x, slot_y + 10, w, ph, title, rail, state, badge, slot_y - ph)
    if state == "lit":
        dr.line([(x, slot_y - ph), (x + w, slot_y - ph)], fill=GOLD, width=1)

def bm_frame(x, y, title, rail, state="lit", badge=None):
    """C 角花框线：委角双框＋四角金角花。空槽=暗委角框。"""
    dr = DR()
    w, h = 32, 70
    c = 6
    pts = [(x + c, y), (x + w - c, y), (x + w, y + c), (x + w, y + h - c),
           (x + w - c, y + h), (x + c, y + h), (x, y + h - c), (x, y + c)]
    if state == "empty":
        dr.polygon(pts, fill=(36, 33, 28), outline=(88, 80, 64))
        return
    if state == "ghost":
        dr.polygon(pts, outline=rail, width=2)
        vtext(dr, x + w / 2, y + 10, title, F("wk", 11), tint(rail, PAPER, 0.5))
        return
    dr.polygon(pts, fill=PAPER if state == "lit" else (172, 164, 148), outline=tuple(int(v * 0.85) for v in GOLD), width=2)
    dr.line(pts + [pts[0]], fill=rail, width=1)
    # 内容（内缩）
    _paper_content(dr, x + 2, y + h - 4, w - 4, h - 10, title, rail, state, badge, y + 4)
    # 四角角花
    for (ax, ay, dx, dy) in [(x + 1, y + 1, 1, 1), (x + w - 1, y + 1, -1, 1),
                             (x + 1, y + h - 1, 1, -1), (x + w - 1, y + h - 1, -1, -1)]:
        dr.line([(ax, ay + dy * 7), (ax, ay), (ax + dx * 7, ay)], fill=GOLD, width=2)

def rack(variant, x0, y0, labels, rows, mirror=False):
    """技能架。rows: [[(title, rail, state, badge)...x5] 功法, [...] 护身]"""
    dr = DR()
    pitch = 40
    n = 5
    width = n * pitch
    # 行标签（轨名竖签小牌）
    for r, (row, label) in enumerate(zip(rows, labels)):
        ry = y0 + r * 94
        lx = (x0 + width + 8) if not mirror else (x0 - 30)
        rrect(dr, (lx, ry + 6, lx + 22, ry + 54), 3, fill=CHIP_BG, outline=CHIP_BD)
        vtext(dr, lx + 11, ry + 12, label, F("wk", 11), GOLD)
        if variant == "A":
            # 横杆
            rx0 = x0 - 8
            rx1 = x0 + width + 2
            rrect(dr, (rx0, ry, rx1, ry + 5), 2, fill=WOOD, outline=WOOD_D)
            for ex in (rx0, rx1 - 4):
                dr.rectangle((ex, ry - 3, ex + 4, ry + 8), fill=(202, 168, 96))
            for i, spec in enumerate(row):
                cx = x0 + 4 + i * pitch + 15
                bm_hang(cx, ry + 5, *spec)
        elif variant == "B":
            rrect(dr, (x0 - 8, ry + 8, x0 + width + 4, ry + 86), 6, fill=TRAY, outline=(96, 84, 64), width=2)
            dr.line([(x0 - 4, ry + 12), (x0 + width, ry + 12)], fill=(130, 114, 84))
            for i, spec in enumerate(row):
                bm_tray(x0 + 2 + i * pitch, ry + 52, *spec)
        else:
            for i, spec in enumerate(row):
                bm_frame(x0 + 2 + i * pitch, ry, *spec)

def standing_sign_v4(cx, cy, title, rail, remain, total, variant="A"):
    """在途立签（放大书签·带签孔流苏·光晕·拍数珠）。"""
    w, h = 44, 118
    for i, a_ in [(0, 36), (1, 66), (2, 100)]:
        pad = 6 + i * 5
        ov = Image.new("RGBA", (W, H + CAP), (0, 0, 0, 0))
        ImageDraw.Draw(ov).rounded_rectangle(
            (cx - w / 2 - pad, cy - h / 2 - pad, cx + w / 2 + pad, cy + h / 2 + pad),
            radius=6, outline=tuple(GOLD) + (a_,), width=2)
        ctx.overlays.append(ov)
    dr = DR()
    # 签孔＋绳
    dr.line([(cx, cy - h / 2 - 6), (cx, cy - h / 2)], fill=(150, 132, 100), width=2)
    dr.ellipse((cx - 4, cy - h / 2, cx + 4, cy - h / 2 + 8), outline=(120, 104, 78), width=2)
    _paper_content(dr, cx - w / 2, cy + h / 2 - 8, w, h - 8, title, rail, "lit", None, cy - h / 2 + 10)
    dr.rounded_rectangle((cx - w / 2 - 1, cy - h / 2 + 9, cx + w / 2 + 1, cy + h / 2 - 6), 4, outline=GOLD)
    # 流苏
    ty = cy + h / 2 - 4
    dr.rectangle((cx - 3, ty, cx + 3, ty + 5), fill=rail)
    for dx in (-4, 0, 4):
        dr.line([(cx + dx, ty + 5), (cx + dx, ty + 14)], fill=rail, width=2)
    dot_y = cy + h / 2 + 24
    x0 = cx - (total * 14 - 6) / 2
    for i in range(total):
        dr.ellipse((x0 + i * 14, dot_y - 4, x0 + i * 14 + 8, dot_y + 4),
                   fill=GOLD if i < remain else (70, 66, 58), outline=CHIP_BD)
    text(dr, (cx, dot_y + 13), f"余 {remain} 拍", F("wk", 12), GOLD, anchor="mm")

# ---------- 打出位／副露／杂项（V3 沿用） ----------
def discard_slot(cx, cy, w, h, faces, tag, tag_color, highlight=False):
    dr = DR()
    if highlight:
        rrect(dr, (cx - w / 2 - 10, cy - h / 2 - 12, cx + w / 2 + 10, cy + h / 2 + 12), 12, outline=GOLD, width=3)
    else:
        dr.rounded_rectangle((cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2), radius=10, outline=DASH)
    tw = 30 if len(faces) > 1 else 36
    total = len(faces) * (tw + 6) - 6
    x = cx - total / 2
    for f_ in faces:
        sp = tile_v(f_, tw)
        ctx.layers.append((sp, int(x), int(cy - sp.height / 2)))
        x += tw + 6
    rrect(dr, (cx - 46, cy - h / 2 - 28, cx + 46, cy - h / 2 - 8), 3, fill=CHIP_BG, outline=tag_color)
    text(dr, (cx, cy - h / 2 - 18), tag, F("wk", 12), BONE, anchor="mm")

def meld_group(cx, y_bottom, faces, tw):
    hw = int(tw * 389 / 272)
    widths = [tw if i != 1 else hw for i in range(len(faces))]
    total = sum(widths) + 4 * (len(faces) - 1)
    x = cx - total / 2
    for i, f_ in enumerate(faces):
        sp = tile_v(f_, tw)
        if i == 1:
            sp = sp.rotate(90, expand=True)
        ctx.layers.append((sp, int(x), int(y_bottom - sp.height)))
        x += widths[i] + 4

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

def joker_card(x, y, w, h, title, filled=True):
    dr = DR()
    if not filled:
        dr.rounded_rectangle((x, y, x + w, y + h), 5, outline=(118, 110, 90))
        return
    rrect(dr, (x, y, x + w, y + h), 5, fill=(42, 52, 56), outline=BONE)
    ah = int(h * 0.70)
    rrect(dr, (x + 3, y + 3, x + w - 3, y + ah), 3, fill=tint(XUANQING, (42, 52, 56), 0.45))
    cxm, cym = x + w / 2, y + ah / 2 + 1
    r0 = min(w, ah) // 2 - 6
    dr.ellipse((cxm - r0, cym - r0, cxm + r0, cym + r0), outline=(140, 170, 175), width=2)
    text(dr, (cxm, cym), title[0], F("wk", int(w * 0.34)), (150, 180, 185), anchor="mm")
    text(dr, (x + w / 2, y + h - (h - ah) / 2), title, F("wk", 11), GOLD, anchor="mm")

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

def common(variant, frame):
    ctx.img = Image.new("RGB", (W, H + CAP), ROOM)
    draw_table()

    bw, n = 23, 13
    x = 640 - (n * (bw + 4) - 4) / 2
    for i in range(n):
        ctx.layers.append((tile_back(bw), int(x), 153))
        x += bw + 4

    meld_group(360, 252, ["5s", "5s", "5s"], 30)
    meld_group(800, 578, ["3m", "3m", "3m"], 26)
    meld_group(945, 578, ["2p", "3p", "4p"], 26)

    hp_track("foe", 640, 278, 400, 98)
    qisea(640, 376)
    hp_track("me", 640, 478, 400, 137)

    discard_slot(640, 318, 170, 50, ["5p", "6p", "7p"], "普攻 · 3 张", ZHU)
    discard_slot(640, 436, 170, 54, ["1s"], "虚招", (110, 104, 95))

    # 发动位翻侧：我＝气海左、敌＝气海右
    if frame == "cast":
        standing_sign_v4(505, 358, "点穴", ZHU, 3, 4, variant)
    else:
        standing_sign_v4(775, 358, "破甲拳", ZHU, 2, 4, variant)

    # 技能架
    gong = [("破甲拳", ZHU, "lit", None),
            ("点穴", ZHU, "ghost" if frame == "cast" else "lit", None),
            ("连环掌", ZHU, "dim", "式3"),
            (None, None, "empty", None),
            (None, None, "empty", None)]
    hu = [("铁布衫", ZHEJIN, "lit", None),
          ("金钟罩", ZHEJIN, "dim", "罡4"),
          (None, None, "empty", None),
          (None, None, "empty", None),
          (None, None, "empty", None)]
    rack(variant, 1064, 480, ["功法", "护身"], [gong, hu])
    DR().rounded_rectangle((1006, 588, 1056, 616), 4, fill=CHIP_BG, outline=CHIP_BD)
    text(DR(), (1031, 602), "罡 10", F("wk", 13), GOLD, anchor="mm")

    egong = [("破甲拳", ZHU, "ghost", None),
             ("点穴", ZHU, "dim", "式2"),
             ("连环掌", ZHU, "lit", None),
             (None, None, "empty", None),
             (None, None, "empty", None)]
    ehu = [("铁布衫", ZHEJIN, "lit", None),
           ("金钟罩", ZHEJIN, "dim", "罡4"),
           (None, None, "empty", None),
           (None, None, "empty", None),
           (None, None, "empty", None)]
    rack(variant, 26, 62, ["护身", "功法"], [ehu, egong], mirror=True)
    DR().rounded_rectangle((226, 170, 276, 198), 4, fill=CHIP_BG, outline=CHIP_BD)
    text(DR(), (251, 184), "罡 9", F("wk", 13), GOLD, anchor="mm")

    for i in range(5):
        t = ["拆招诀", "运筹诀", "洗练诀"][i] if i < 3 else None
        joker_card(9 + i * 52, 505, 48, 72, t, filled=t is not None)
        joker_card(1022 + i * 52, 151, 48, 72, t, filled=t is not None)

    button((534, 578, 638, 624), "变招", XUANQING, dim=(frame == "cast"))
    button((646, 578, 750, 624), "攻击", ZHU, dim=(frame == "cast"))

    dr = DR()
    dr.rectangle((0, 0, W, 30), fill=(23, 22, 20))
    dr.line([(0, 30), (W, 30)], fill=CHIP_BD)
    text(dr, (12, 15), "‹ 演武场", F("wk", 13), BONE, anchor="lm")
    text(dr, (640, 15), "回合 12 · 组 1-3", F("wk", 13), GOLD, anchor="mm")

    rrect(dr, (1216, 38, 1271, 93), 4, fill=(33, 28, 23), outline=CHIP_BD)
    text(dr, (1243, 65), "玄", F("ms", 22), GOLD, anchor="mm")
    chip(dr, (1117, 36, 1215, 64), "变 9")
    chip(dr, (1117, 65, 1215, 93), "攻 12　防 8")
    chip(dr, (1136, 94, 1270, 122), "劲 10　骨 3　气 12")
    chip(dr, (146, 34, 236, 62), "丹田 · 13", fg=GOLD)

    rrect(dr, (9, 651, 64, 706), 4, fill=(33, 28, 23), outline=CHIP_BD)
    text(dr, (36, 678), "无", F("ms", 22), GOLD, anchor="mm")
    chip(dr, (10, 622, 144, 650), "劲 10　骨 3　气 12")
    chip(dr, (65, 651, 163, 679), "攻 12　防 8")
    chip(dr, (65, 680, 163, 708), "变 9")
    chip(dr, (1116, 685, 1214, 713), "丹田 · 16", fg=GOLD)

def caption(txt):
    dr = ImageDraw.Draw(ctx.img)
    dr.rectangle((0, H, W, H + CAP), fill=(18, 20, 24))
    text(dr, (W / 2, H + CAP / 2), txt, F("wk", 17), BONE, anchor="mm")

def save(name):
    ctx.img.save(os.path.join(OUT, name))
    print("saved", name)

def main():
    os.makedirs(OUT, exist_ok=True)
    common("A", "steady"); hand(HAND, hover=3); flush()
    caption("V4-A 挂签架 ┃ 横杆挂书签（签孔+绳+流苏·流苏=轨色·空槽=垂空绳）｜发动位已翻侧：敌在途=气海右")
    save("layout_V4A_挂签架_决策拍.png")

    common("B", "steady"); hand(HAND, hover=3); flush()
    caption("V4-B 托盘嵌槽 ┃ 统一漆盘＋凹槽位·书签立槽中露上半·行名牌在盘端")
    save("layout_V4B_托盘嵌槽_决策拍.png")

    common("C", "steady"); hand(HAND, hover=3); flush()
    caption("V4-C 角花框线 ┃ 委角双框＋四角金角花（金钮/Kenney 描边语汇）")
    save("layout_V4C_角花框线_决策拍.png")

    common("A", "cast"); hand(HAND, hover=None); flush()
    caption("V4-A 挂签架 · 我方发动拍 ┃ 点穴书签飞至气海【左】侧立起（我左敌右锚定）·架上原位虚影·按钮压暗")
    save("layout_V4A_挂签架_我方发动拍.png")

if __name__ == "__main__":
    main()
