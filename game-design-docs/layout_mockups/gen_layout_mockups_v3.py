# -*- coding: utf-8 -*-
"""对局 2.5D 布局效果图 V3（2026-09-24 技能架轮）
核心变更：
  1. 三轨载体＝书签（36 宽·带图区·轨色印）：功法/护身＝技能架双行固定 5 槽
     （亮=可用/暗=不可用+成本角标/虚影=在途），罡气读数随架；
  2. 心法＝小丑牌架（宽卡·图区 70%·固定 5 槽·侧腰）；
  3. 在途武学＝书签放大立签于中线（光晕＋拍数珠），空态不画；
  4. 打出位/副露全部竖牌正读（mahjong_graphic 竖版），被截那张旋转 90°。
三帧：我方决策拍／截牌窗拍／我方发动拍。
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
FAINT = (172, 160, 132)
PAPER = (222, 212, 188)

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
    """rail 色混纸色 k（0=rail, 1=纸）。"""
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

# ---------- V2 血带（朱砂笔意，沿用） ----------
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

# ---------- V3 书签 ----------
def bookmark(x, y, w, h, title, rail, state="lit", badge=None):
    """技能书签：上 58% 图区（纹章占位）＋竖排名＋底角轨色印。
    state: lit / dim(＋成本角标) / ghost(在途虚影) / empty(空槽)"""
    dr = DR()
    if state == "empty":
        dr.rounded_rectangle((x, y, x + w, y + h), 4, outline=(118, 110, 90))
        return
    if state == "ghost":
        dr.rounded_rectangle((x, y, x + w, y + h), 4, outline=rail, width=2)
        vtext(dr, x + w / 2, y + h / 2 - len(title) * 7, title, F("wk", 11), tint(rail, PAPER, 0.45))
        return
    base = PAPER if state == "lit" else (168, 160, 144)
    rrect(dr, (x, y, x + w, y + h), 4, fill=base, outline=CHIP_BD)
    if state == "lit":
        dr.rounded_rectangle((x - 1, y - 1, x + w + 1, y + h + 1), 5, outline=GOLD)
    ah = int(h * 0.58)
    rrect(dr, (x + 3, y + 3, x + w - 3, y + ah), 2, fill=tint(rail, base, 0.62))
    cxm, cym = x + w / 2, y + ah / 2 + 1
    r0 = min(w, ah) // 2 - 5
    dr.ellipse((cxm - r0, cym - r0, cxm + r0, cym + r0), outline=rail, width=2)
    text(dr, (cxm, cym), title[0], F("wk", int(w * 0.42)), tint(rail, INK, 0.25), anchor="mm")
    fs = 11 if len(title) <= 3 else 10
    vtext(dr, x + w / 2, y + ah + 4, title, F("wk", fs), INK if state == "lit" else (98, 94, 86))
    dr.rectangle((x + w - 9, y + h - 9, x + w - 3, y + h - 3), fill=rail)
    if state == "dim" and badge:
        bw = 10 + len(badge) * 7
        rrect(dr, (x + w - bw - 2, y + 2, x + w - 2, y + 14), 3, fill=(120, 38, 32))
        text(dr, (x + w - 2 - bw / 2, y + 8), badge, F("wk", 9), (240, 230, 210), anchor="mm")

def joker_card(x, y, w, h, title, filled=True):
    """心法小丑牌：暗底宽卡·图区 70%·底部小名。玄青轨。"""
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

def standing_sign(cx, cy, title, rail, remain, total):
    """在途＝书签放大立签：光晕＋拍数珠。"""
    w, h = 42, 112
    for i, a_ in [(0, 36), (1, 66), (2, 100)]:
        pad = 6 + i * 5
        ov = Image.new("RGBA", (W, H + CAP), (0, 0, 0, 0))
        ImageDraw.Draw(ov).rounded_rectangle(
            (cx - w / 2 - pad, cy - h / 2 - pad, cx + w / 2 + pad, cy + h / 2 + pad),
            radius=6, outline=tuple(GOLD) + (a_,), width=2)
        ctx.overlays.append(ov)
    dr = DR()
    rrect(dr, (cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2), 5, fill=PAPER, outline=CHIP_BD)
    dr.rounded_rectangle((cx - w / 2 - 1, cy - h / 2 - 1, cx + w / 2 + 1, cy + h / 2 + 1), 6, outline=GOLD)
    ah = int(h * 0.52)
    rrect(dr, (cx - w / 2 + 3, cy - h / 2 + 3, cx + w / 2 - 3, cy - h / 2 + ah), 3,
          fill=tint(rail, PAPER, 0.55))
    cxm, cym = cx, cy - h / 2 + ah / 2 + 1
    r0 = min(w, ah) // 2 - 4
    dr.ellipse((cxm - r0, cym - r0, cxm + r0, cym + r0), outline=rail, width=2)
    text(dr, (cxm, cym), title[0], F("wk", 17), tint(rail, INK, 0.25), anchor="mm")
    vtext(dr, cx, cy - h / 2 + ah + 8, title, F("wk", 13), INK)
    dr.rectangle((cx + w / 2 - 10, cy + h / 2 - 10, cx + w / 2 - 4, cy + h / 2 - 4), fill=rail)
    dot_y = cy + h / 2 + 16
    x0 = cx - (total * 14 - 6) / 2
    for i in range(total):
        dr.ellipse((x0 + i * 14, dot_y - 4, x0 + i * 14 + 8, dot_y + 4),
                   fill=GOLD if i < remain else (70, 66, 58), outline=CHIP_BD)
    text(dr, (cx, dot_y + 13), f"余 {remain} 拍", F("wk", 12), GOLD, anchor="mm")

# ---------- V3 打出位（竖牌正读） ----------
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
    """副露：竖牌正读，被截那张旋转 90°。"""
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

# ---------- 布局 ----------
HAND = ["1m", "2m", "3m", "5m", "7m", "8m", "9m", "2p", "3p", "4p", "6p", "2s", "3s", "5s"]
BM_W, BM_H, BM_GAP = 34, 76, 5
JK_W, JK_H, JK_GAP = 48, 72, 4

def skill_row(x0, y0, specs):
    for i, (title, rail, state, badge) in enumerate(specs):
        bookmark(x0 + i * (BM_W + BM_GAP), y0, BM_W, BM_H, title, rail, state, badge)

def joker_row(x0, y0, titles):
    for i in range(5):
        t = titles[i] if i < len(titles) else None
        joker_card(x0 + i * (JK_W + JK_GAP), y0, JK_W, JK_H, t, filled=t is not None)

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

    # 敌手牌行（13 背）
    bw, n = 23, 13
    x = 640 - (n * (bw + 4) - 4) / 2
    for i in range(n):
        ctx.layers.append((tile_back(bw), int(x), 153))
        x += bw + 4

    # 副露（竖牌，中张旋转标记）
    meld_group(360, 252, ["5s", "5s", "5s"], 30)
    meld_group(800, 578, ["3m", "3m", "3m"], 26)
    meld_group(945, 578, ["2p", "3p", "4p"], 26)

    # 中线战况带
    hp_track("foe", 640, 278, 400, 98)
    qisea(640, 376)
    hp_track("me", 640, 478, 400, 137)

    # 打出位（敌我各一·竖牌正读）
    discard_slot(640, 318, 170, 50, ["5p", "6p", "7p"], "普攻 · 3 张", ZHU, highlight=(frame == "claim"))
    discard_slot(640, 436, 170, 54, ["1s"], "虚招", (110, 104, 95))

    # 在途立签（中线放大书签）
    if frame == "cast":
        standing_sign(775, 360, "点穴", ZHU, 3, 4)
    else:
        standing_sign(505, 360, "破甲拳", ZHU, 2, 4)

    # ---- 技能架（书签双行·固定 5 槽） ----
    # 我：右下（功法上·护身下）
    skill_row(1064, 484, [("破甲拳", ZHU, "lit", None),
                          ("点穴", ZHU, "ghost" if frame == "cast" else "lit", None),
                          ("连环掌", ZHU, "dim", "式3"),
                          (None, None, "empty", None),
                          (None, None, "empty", None)])
    skill_row(1064, 570, [("铁布衫", ZHEJIN, "lit", None),
                          ("金钟罩", ZHEJIN, "dim", "罡4"),
                          (None, None, "empty", None),
                          (None, None, "empty", None),
                          (None, None, "empty", None)])
    # 我罡气随架
    DR().rounded_rectangle((1006, 588, 1056, 616), 4, fill=CHIP_BG, outline=CHIP_BD)
    text(DR(), (1031, 602), "罡 10", F("wk", 13), GOLD, anchor="mm")

    # 敌：左上（180° 镜像→护身上·功法下）；破甲拳在途＝虚影
    skill_row(26, 66, [("铁布衫", ZHEJIN, "lit", None),
                       ("金钟罩", ZHEJIN, "dim", "罡4"),
                       (None, None, "empty", None),
                       (None, None, "empty", None),
                       (None, None, "empty", None)])
    skill_row(26, 152, [("破甲拳", ZHU, "ghost", None),
                        ("点穴", ZHU, "dim", "式2"),
                        ("连环掌", ZHU, "lit", None),
                        (None, None, "empty", None),
                        (None, None, "empty", None)])
    DR().rounded_rectangle((226, 170, 276, 198), 4, fill=CHIP_BG, outline=CHIP_BD)
    text(DR(), (251, 184), "罡 9", F("wk", 13), GOLD, anchor="mm")

    # ---- 心法小丑架（侧腰） ----
    joker_row(9, 505, ["拆招诀", "运筹诀", "洗练诀"])
    joker_row(1022, 151, ["拆招诀", "运筹诀", "洗练诀"])

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
    caption("V3 主案 · 我方决策拍 ┃ 技能架=书签双行(功法/护身·固定5槽·亮/暗+成本角标/空槽) 罡气随架｜心法=小丑牌架(侧腰)｜打出位/副露竖牌正读｜中线=敌在途立签")
    save("layout_V3_主案_我方决策拍.png")

    common("claim"); claim_popup(); hand(HAND, dim=True); flush()
    caption("V3 主案 · 截牌窗拍 ┃ 敌打出位(竖牌)接管焦点、截牌窗弹出、手牌压暗")
    save("layout_V3_主案_截牌窗拍.png")

    common("cast"); hand(HAND, hover=None); flush()
    caption("V3 主案 · 我方发动拍 ┃ 点穴书签飞至中线放大立签(光晕+拍数珠)、架上原位虚影、按钮压暗")
    save("layout_V3_主案_我方发动拍.png")

if __name__ == "__main__":
    main()
