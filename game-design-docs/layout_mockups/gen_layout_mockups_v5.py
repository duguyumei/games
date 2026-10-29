# -*- coding: utf-8 -*-
"""对局布局效果图 V5（2026-09-24 敌我信息分层轮）
裁决落地：
  1. 敌方武学纯撤（发动时才公示：中线立签＋配方入河）；敌方罡气回信息簇；
  2. 敌方心法＝信息簇下小印行（玄青小章，悬停出说明）；
  3. 我方＝左侧三杆挂签架：功法（朱·活绳）／护身（赭金·活绳）／心法（玄青·钉驻签，
     常亮永不飞出）；罡气随护身杆；
  4. 我方账本归右下（丹田为头＋三力/攻防/变＋头像）；
  5. 发动位：我＝气海左、敌＝气海右（我左敌右贯通）。
三帧：决策拍／截牌窗拍／我方发动拍。
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
BRONZE = (176, 148, 92)

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

# ---------- V5 挂签（活绳）／钉驻签（心法） ----------
BM_W, PH, AH = 34, 66, 28

def _paper(dr, cx, ytop, title, rail, state, badge):
    w = BM_W
    base = PAPER if state == "lit" else (172, 164, 148)
    x = cx - w / 2
    dr.polygon([(x + 4, ytop), (x + w - 4, ytop), (x + w, ytop + 4), (x + w, ytop + PH),
                (x, ytop + PH), (x, ytop + 4)], fill=base, outline=CHIP_BD)
    rrect(dr, (x + 3, ytop + 5, x + w - 3, ytop + AH + 5), 2, fill=tint(rail, base, 0.55))
    text(dr, (cx, ytop + 5 + AH / 2), title[0], F("wk", 15), tint(rail, PAPER, 0.72), anchor="mm")
    vtext(dr, cx, ytop + AH + 9, title, F("wk", 10), INK if state == "lit" else (100, 96, 88))
    dr.rectangle((x + w - 8, ytop + PH - 8, x + w - 3, ytop + PH - 3), fill=rail)
    if state == "dim" and badge:
        bw = 12 + len(badge) * 7
        rrect(dr, (x + w - bw - 2, ytop + 2, x + w - 2, ytop + 14), 3, fill=(120, 38, 32))
        text(dr, (x + w - 2 - bw / 2, ytop + 8), badge, F("wk", 9), (240, 230, 210), anchor="mm")

def _tassel(dr, cx, ty, rail, lit):
    tc = rail if lit else (130, 124, 112)
    dr.rectangle((cx - 2, ty, cx + 2, ty + 4), fill=tc)
    for dx in (-3, 0, 3):
        dr.line([(cx + dx, ty + 4), (cx + dx, ty + 10)], fill=tc, width=1)

def bm_hang(cx, rail_y, title, rail, state="lit", badge=None):
    """功法/护身：活绳挂签（绳＋签孔），可取用——亮/暗/虚影/空(垂绳)。"""
    dr = DR()
    dr.line([(cx, rail_y), (cx, rail_y + 7)], fill=(150, 132, 100), width=2)
    dr.ellipse((cx - 3, rail_y + 7, cx + 3, rail_y + 13), outline=(120, 104, 78), width=2)
    if state == "empty":
        return
    ytop = rail_y + 16
    if state == "ghost":
        dr.rounded_rectangle((cx - BM_W / 2, ytop, cx + BM_W / 2, ytop + PH), 3, outline=rail, width=2)
        vtext(dr, cx, ytop + 8, title, F("wk", 10), tint(rail, PAPER, 0.5))
    else:
        _paper(dr, cx, ytop, title, rail, state, badge)
        if state == "lit":
            dr.line([(cx - BM_W / 2, ytop), (cx + BM_W / 2, ytop)], fill=GOLD, width=1)
        _tassel(dr, cx, ytop + PH + 2, rail, state == "lit")

def bm_pin(cx, rail_y, title, rail, filled=True):
    """心法：钉驻签——铜钉直接钉在杆上，无绳，常亮，永不飞出。空位＝钉孔。"""
    dr = DR()
    if not filled:
        dr.ellipse((cx - 2, rail_y - 1, cx + 2, rail_y + 3), outline=(120, 104, 78), width=1)
        return
    ytop = rail_y + 3
    _paper(dr, cx, ytop, title, rail, "lit", None)
    dr.ellipse((cx - 3, rail_y - 2, cx + 3, rail_y + 4), fill=BRONZE, outline=(120, 96, 52))
    _tassel(dr, cx, ytop + PH + 2, rail, True)

def rail(dr, x0, ry, label):
    rx0, rx1 = x0 - 8, x0 + 202
    rrect(dr, (rx0, ry, rx1, ry + 5), 2, fill=WOOD, outline=WOOD_D)
    for ex in (rx0, rx1 - 4):
        dr.rectangle((ex, ry - 3, ex + 4, ry + 8), fill=(202, 168, 96))
    rrect(dr, (rx1 + 8, ry + 4, rx1 + 30, ry + 54), 3, fill=CHIP_BG, outline=CHIP_BD)
    vtext(dr, rx1 + 19, ry + 10, label, F("wk", 11), GOLD)

def mini_seals(dr, x0, y0, titles):
    """敌方心法小印行：玄青小章，悬停出说明（画中仅示形）。"""
    for i in range(5):
        x = x0 + i * 30
        if i < len(titles):
            rrect(dr, (x, y0, x + 22, y0 + 22), 4, fill=tint(XUANQING, (20, 24, 26), 0.25), outline=(96, 116, 120))
            text(dr, (x + 11, y0 + 11), titles[i][0], F("wk", 12), (168, 192, 196), anchor="mm")
        else:
            dr.ellipse((x + 7, y0 + 7, x + 15, y0 + 15), outline=(90, 84, 70))

def standing_sign(cx, cy, title, rail, remain, total):
    w, h = 46, 122
    for i, a_ in [(0, 36), (1, 66), (2, 100)]:
        pad = 6 + i * 5
        ov = Image.new("RGBA", (W, H + CAP), (0, 0, 0, 0))
        ImageDraw.Draw(ov).rounded_rectangle(
            (cx - w / 2 - pad, cy - h / 2 - pad, cx + w / 2 + pad, cy + h / 2 + pad),
            radius=6, outline=tuple(GOLD) + (a_,), width=2)
        ctx.overlays.append(ov)
    dr = DR()
    dr.line([(cx, cy - h / 2 - 6), (cx, cy - h / 2)], fill=(150, 132, 100), width=2)
    dr.ellipse((cx - 4, cy - h / 2, cx + 4, cy - h / 2 + 8), outline=(120, 104, 78), width=2)
    ytop = cy - h / 2 + 12
    _paper(dr, cx, ytop, title, rail, "lit", None)
    dr.rounded_rectangle((cx - w / 2 - 1, ytop - 1, cx + w / 2 + 1, ytop + PH + 1), 4, outline=GOLD)
    _tassel(dr, cx, ytop + PH + 2, rail, True)
    dr.rectangle((cx - 3, ytop + PH + 4, cx + 3, ytop + PH + 9), fill=rail)
    for dx in (-4, 0, 4):
        dr.line([(cx + dx, ytop + PH + 9), (cx + dx, ytop + PH + 18)], fill=rail, width=2)
    dot_y = cy + h / 2 + 26
    x0 = cx - (total * 14 - 6) / 2
    for i in range(total):
        dr.ellipse((x0 + i * 14, dot_y - 4, x0 + i * 14 + 8, dot_y + 4),
                   fill=GOLD if i < remain else (70, 66, 58), outline=CHIP_BD)
    text(dr, (cx, dot_y + 13), f"余 {remain} 拍", F("wk", 12), GOLD, anchor="mm")

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

    discard_slot(640, 318, 170, 50, ["5p", "6p", "7p"], "普攻 · 3 张", ZHU, highlight=(frame == "claim"))
    discard_slot(640, 436, 170, 54, ["1s"], "虚招", (110, 104, 95))

    if frame == "cast":
        standing_sign(505, 352, "点穴", ZHU, 3, 4)
    else:
        standing_sign(775, 352, "破甲拳", ZHU, 2, 4)

    # ---- 我方三杆挂签架（左侧） ----
    dr = DR()
    RAILS_Y = [420, 519, 618]
    rail(dr, 40, RAILS_Y[0], "功法")
    rail(dr, 40, RAILS_Y[1], "护身")
    rail(dr, 40, RAILS_Y[2], "心法")
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
    xin = ["拆招诀", "运筹诀", "洗练诀"]
    for i, (title, r_, st, bd) in enumerate(gong):
        bm_hang(55 + i * 40, RAILS_Y[0] + 5, title, r_, st, bd)
    for i, (title, r_, st, bd) in enumerate(hu):
        bm_hang(55 + i * 40, RAILS_Y[1] + 5, title, r_, st, bd)
    for i in range(5):
        bm_pin(55 + i * 40, RAILS_Y[2] + 2, xin[i] if i < 3 else None, XUANQING, filled=i < 3)
    rrect(dr, (248, RAILS_Y[1] + 58, 296, RAILS_Y[1] + 82), 4, fill=CHIP_BG, outline=CHIP_BD)
    text(dr, (272, RAILS_Y[1] + 70), "罡 10", F("wk", 12), GOLD, anchor="mm")

    button((534, 578, 638, 624), "变招", XUANQING, dim=(frame == "cast"))
    button((646, 578, 750, 624), "攻击", ZHU, dim=(frame == "cast"))

    # ---- HUD ----
    dr = DR()
    dr.rectangle((0, 0, W, 30), fill=(23, 22, 20))
    dr.line([(0, 30), (W, 30)], fill=CHIP_BD)
    text(dr, (12, 15), "‹ 演武场", F("wk", 13), BONE, anchor="lm")
    text(dr, (640, 15), "回合 12 · 组 1-3", F("wk", 13), GOLD, anchor="mm")

    # 敌方信息簇（右上）＋罡气回簇＋心法小印行
    rrect(dr, (1216, 38, 1271, 93), 4, fill=(33, 28, 23), outline=CHIP_BD)
    text(dr, (1243, 65), "玄", F("ms", 22), GOLD, anchor="mm")
    chip(dr, (1117, 36, 1215, 64), "罡 9　变 9")
    chip(dr, (1117, 65, 1215, 93), "攻 12　防 8")
    chip(dr, (1136, 94, 1270, 122), "劲 10　骨 3　气 12")
    chip(dr, (146, 34, 236, 62), "丹田 · 13", fg=GOLD)
    mini_seals(dr, 1117, 130, ["拆招诀", "运筹诀", "洗练诀"])

    # 我方账本（右下：丹田为头）
    chip(dr, (1116, 566, 1214, 594), "丹田 · 16", fg=GOLD)
    chip(dr, (1136, 600, 1270, 628), "劲 10　骨 3　气 12")
    chip(dr, (1117, 632, 1215, 660), "攻 12　防 8")
    chip(dr, (1117, 664, 1215, 692), "变 9")
    rrect(dr, (1216, 632, 1271, 687), 4, fill=(33, 28, 23), outline=CHIP_BD)
    text(dr, (1243, 659), "无", F("ms", 22), GOLD, anchor="mm")

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
    caption("V5 · 我方决策拍 ┃ 左=三杆挂签架(功法/护身·活绳 心法·铜钉驻签·常亮) 罡随护身杆｜右下=账本(丹田为头)｜敌武学纯撤·心法缩小印行·罡回簇｜发动位我左敌右")
    save("layout_V5_我方决策拍.png")

    common("claim"); claim_popup(); hand(HAND, dim=True); flush()
    caption("V5 · 截牌窗拍 ┃ 敌打出位接管焦点、截牌窗弹出、手牌压暗")
    save("layout_V5_截牌窗拍.png")

    common("cast"); hand(HAND, hover=None); flush()
    caption("V5 · 我方发动拍 ┃ 点穴签飞至气海左立起(我左敌右)、功法杆原位虚影、按钮压暗；心法杆钉驻不动")
    save("layout_V5_我方发动拍.png")

if __name__ == "__main__":
    main()
