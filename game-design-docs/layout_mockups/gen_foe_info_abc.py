# -*- coding: utf-8 -*-
"""敌方基本信息簇 A/B/C 效果图（2026-09-26 用户判现制丑 → 调研轮 → 出图选型）

调研原则（来源见复盘归档 2026-09-26 条）：P1 身份（像/名）→ P2 决策数（攻防罡变）
→ P3 派生数（三力+心法小印＝情报行）；数字大而扫读、标签小或图标化。

A 名牌式·数字上牌（agent 荐）：头像+名号条／攻防罡变四大数字牌
   （数字 22＝头像占位字实测档、轨标 13＝chip 现档）／情报行两条。
B 现制微调＋Kenney 蒙皮：三 chip 结构不动，仅文字层级（标签 12·数字 20＝探索值）
   ＋Kenney Fantasy 面板衬底（PNG/Double/Panel）＋名号条。
C 竖签式（对照·不荐）：一枚纸签全装——竖排数字扫读弱、与「chip=动态数值」形制拧。
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_layout_mockups_v5 as v5
from PIL import Image, ImageDraw

W, H = v5.W, v5.H
F, rrect, text, vtext = v5.F, v5.rrect, v5.text, v5.vtext
BONE, GOLD, DASH = v5.BONE, v5.GOLD, v5.DASH
CHIP_BG, CHIP_BD, INK = v5.CHIP_BG, v5.CHIP_BD, v5.INK
KENNEY_PANEL = os.path.join(v5.ROOT,
    "forbidden-gamble/assets/kenney/fantasy-ui-borders/PNG/Double/Panel/panel-016.png")

STATS = [("攻", "12"), ("防", "8"), ("罡", "9"), ("变", "9")]


def base_frame():
    v5.common("steady")
    v5.hand(v5.HAND, hover=3)
    v5.flush()
    dr = v5.DR()
    dr.rectangle((1105, 33, W, 172), fill=v5.ROOM)  # 盖掉旧敌簇（含旧心法小印行）
    return v5.ctx.img.copy()


def avatar_and_name(dr):
    rrect(dr, (1216, 36, 1271, 91), 4, fill=INK, outline=CHIP_BD)
    text(dr, (1243, 63), "玄", F("ms", 22), GOLD, anchor="mm")
    rrect(dr, (1216, 94, 1271, 114), 4, fill=CHIP_BG, outline=CHIP_BD)
    text(dr, (1243, 104), "玄冥子", F("ms", 13), GOLD, anchor="mm")


def info_rows(dr, x0, ytop):
    text(dr, (x0, ytop + 8), "劲 10　骨 3　气 12", F("wk", 12), DASH, anchor="lm")
    v5.mini_seals(dr, x0, ytop + 20, ["拆招诀", "运筹诀", "洗练诀"])


def variant_a(img):
    dr = ImageDraw.Draw(img)
    avatar_and_name(dr)
    x = 1131
    for lab, num in STATS:
        rrect(dr, (x, 118, x + 32, 158), 4, fill=CHIP_BG, outline=CHIP_BD)
        text(dr, (x + 16, 134), num, F("wk", 22), BONE, anchor="mm")
        text(dr, (x + 16, 150), lab, F("wk", 13), DASH, anchor="mm")
        x += 36
    info_rows(dr, 1131, 162)
    return img


def b_chip(dr, box, pairs):
    x1, y1, x2, y2 = box
    rrect(dr, box, 4, fill=CHIP_BG, outline=CHIP_BD)
    widths = []
    for lab, num in pairs:
        widths.append(dr.textlength(lab, font=F("wk", 12)) + 3
                      + dr.textlength(num, font=F("wk", 20)))
    total = sum(widths) + 10 * (len(pairs) - 1)
    x = (x1 + x2) / 2 - total / 2
    cy = (y1 + y2) / 2 + 1
    for lab, num in pairs:
        text(dr, (x, cy), lab, F("wk", 12), DASH, anchor="lm")
        x += dr.textlength(lab, font=F("wk", 12)) + 3
        text(dr, (x, cy), num, F("wk", 20), BONE, anchor="lm")
        x += dr.textlength(num, font=F("wk", 20)) + 10


def kenney_plate(dst_img, box, src=KENNEY_PANEL, b=16):
    """Kenney 96² 面板九宫格放大：角原生、边/心 LANCZOS 单向拉伸（直拉整图会有毛边）。"""
    sp = Image.open(src).convert("RGBA")
    x0, y0, x1, y1 = box
    w, h = x1 - x0, y1 - y0
    sw, sh = sp.size
    for sx, sy, dx, dy in [(0, 0, x0, y0), (sw - b, 0, x1 - b, y0),
                           (0, sh - b, x0, y1 - b), (sw - b, sh - b, x1 - b, y1 - b)]:
        r = sp.crop((sx, sy, sx + b, sy + b))
        dst_img.paste(r, (dx, dy), r)
    for r, pos in [
        (sp.crop((b, 0, sw - b, b)).resize((w - 2 * b, b), Image.LANCZOS), (x0 + b, y0)),
        (sp.crop((b, sh - b, sw - b, sh)).resize((w - 2 * b, b), Image.LANCZOS), (x0 + b, y1 - b)),
        (sp.crop((0, b, b, sh - b)).resize((b, h - 2 * b), Image.LANCZOS), (x0, y0 + b)),
        (sp.crop((sw - b, b, sw, sh - b)).resize((b, h - 2 * b), Image.LANCZOS), (x1 - b, y0 + b)),
        (sp.crop((b, b, sw - b, sh - b)).resize((w - 2 * b, h - 2 * b), Image.LANCZOS), (x0 + b, y0 + b)),
    ]:
        dst_img.paste(r, pos, r)


def variant_b(img):
    kenney_plate(img, (1103, 28, 1281, 184))
    dr = ImageDraw.Draw(img)
    b_chip(dr, (1111, 36, 1209, 64), [("罡", "9"), ("变", "9")])
    b_chip(dr, (1111, 65, 1209, 93), [("攻", "12"), ("防", "8")])
    avatar_and_name(dr)
    rrect(dr, (1130, 118, 1264, 146), 4, fill=CHIP_BG, outline=CHIP_BD)
    text(dr, (1197, 133), "劲 10　骨 3　气 12", F("wk", 12), DASH, anchor="mm")
    v5.mini_seals(dr, 1111, 154, ["拆招诀", "运筹诀", "洗练诀"])
    return img


def variant_c(img):
    dr = ImageDraw.Draw(img)
    sx0, sy0, sx1, sy1 = 1232, 36, 1276, 214
    rrect(dr, (sx0, sy0, sx1, sy1), 4, fill=v5.PAPER, outline=(150, 132, 100), width=2)
    dr.ellipse((1248, sy0 + 4, 1260, sy0 + 16), outline=(120, 104, 78), width=2)
    rrect(dr, (1242, sy0 + 22, 1266, sy0 + 46), 3, fill=INK, outline=CHIP_BD)
    text(dr, (1254, sy0 + 34), "玄", F("ms", 15), GOLD, anchor="mm")
    vtext(dr, 1254, sy0 + 50, "玄冥子", F("ms", 13), INK)
    dr.line([(sx0 + 8, 132), (sx1 - 8, 132)], fill=(150, 132, 100), width=1)
    y = 138
    for lab, num in STATS:
        text(dr, (1244, y), lab, F("wk", 12), (120, 110, 90), anchor="ma")
        text(dr, (1264, y), num, F("wk", 16), INK, anchor="ma")
        y += 18
    info_rows(dr, 1131, 166)
    return img


def main():
    os.makedirs(v5.OUT, exist_ok=True)
    variants = [
        ("A", variant_a, "敌信息 A · 名牌式·数字上牌（荐）┃ 顶=头像+名号条｜中=攻防罡变四大数字牌(数字22·轨标13)｜底=三力+心法小印情报行"),
        ("B", variant_b, "敌信息 B · 现制微调＋Kenney 蒙皮 ┃ 三 chip 结构不动·标签小字+数字大字·Kenney 面板衬底·加名号条"),
        ("C", variant_c, "敌信息 C · 竖签式（对照·不荐）┃ 一枚纸签全装——竖排数字扫读弱、与「chip=动态数值」三分形制拧"),
    ]
    crops = []
    for tag, fn, cap in variants:
        img = fn(base_frame())
        v5.ctx.img = img
        v5.caption(cap)
        v5.save(f"foe_info_{tag}.png")
        crops.append(img.crop((1090, 20, 1285, 215)))
    # 对比条：三案右上区裁条并排
    cw, ch = 195, 195
    sheet = Image.new("RGB", (3 * cw + 4 * 12, ch + 34), (18, 20, 24))
    d2 = ImageDraw.Draw(sheet)
    for i, (tag, _, _) in enumerate(variants):
        x = 12 + i * (cw + 12)
        d2.text((x + cw / 2, 14), tag, font=F("wk", 16), fill=v5.GOLD, anchor="mm")
        sheet.paste(crops[i], (x, 30))
    sheet.save(os.path.join(v5.OUT, "foe_info_ABC_对比.png"))
    print("saved foe_info_ABC_对比.png")


if __name__ == "__main__":
    main()
