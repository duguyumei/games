# -*- coding: utf-8 -*-
"""我方信息×架子 位置交换对比图（2026-09-27 用户问「要不要交换下位置」）

现状 A：敌牌左上·我牌右下（对角）·架子左缘两杆(420/545)·丹田伴牌左。
交换 B：我牌左下（敌我身份同缘一竖线）·架子右缘两杆（510/620 底右角贴身排，
   上杆 510 与我罡变列(477-505)仅 5px 净空——右缘拥挤代价直画出来）。
底图＝v5.common 零件级重建（跳过旧三杆架/旧账本/旧敌簇），牌件复用 gen_foe_info_rethink。
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_layout_mockups_v5 as v5
import gen_foe_info_rethink as rt
from PIL import Image, ImageDraw

W, H = v5.W, v5.H
F, rrect, text = v5.F, v5.rrect, v5.text
BONE, GOLD, INK = v5.BONE, v5.GOLD, v5.INK
CHIP_BG, CHIP_BD = v5.CHIP_BG, v5.CHIP_BD
XINFA = rt.XINFA

GONG = [("破甲拳", v5.ZHU, "lit", None), ("点穴", v5.ZHU, "lit", None),
        ("连环掌", v5.ZHU, "dim", "式3"), (None, None, "empty", None), (None, None, "empty", None)]
HU = [("铁布衫", v5.ZHEJIN, "lit", None), ("金钟罩", v5.ZHEJIN, "dim", "罡4"),
      (None, None, "empty", None), (None, None, "empty", None), (None, None, "empty", None)]


def base_clean():
    """v5.common 零件级重建：桌/牌河物件/血带/气海/打出位/在途书签/按钮/顶栏＋带翼罡变列；
    跳过旧三杆架、顶左丹田 chip、旧敌簇、旧我方账本。"""
    v5.ctx.img = Image.new("RGB", (W, H + v5.CAP), v5.ROOM)
    v5.draw_table()
    bw, n = 23, 13
    x = 640 - (n * (bw + 4) - 4) / 2
    for _ in range(n):
        v5.ctx.layers.append((v5.tile_back(bw), int(x), 153))
        x += bw + 4
    v5.meld_group(360, 252, ["5s", "5s", "5s"], 30)
    v5.meld_group(800, 578, ["3m", "3m", "3m"], 26)
    v5.meld_group(945, 578, ["2p", "3p", "4p"], 26)
    v5.hp_track("foe", 640, 278, 400, 98)
    v5.qisea(640, 376)
    v5.hp_track("me", 640, 478, 400, 137)
    v5.discard_slot(640, 318, 170, 50, ["5p", "6p", "7p"], "普攻 · 3 张", v5.ZHU)
    v5.discard_slot(640, 436, 170, 54, ["1s"], "虚招", (110, 104, 95))
    v5.standing_sign(775, 352, "破甲拳", v5.ZHU, 2, 4)
    v5.button((534, 578, 638, 624), "变招", v5.XUANQING)
    v5.button((646, 578, 750, 624), "攻击", v5.ZHU)
    dr = v5.DR()
    dr.rectangle((0, 0, W, 30), fill=(23, 22, 20))
    dr.line([(0, 30), (W, 30)], fill=CHIP_BD)
    text(dr, (12, 15), "‹ 演武场", F("wk", 13), BONE, anchor="lm")
    text(dr, (640, 15), "回合 12 · 组 1-3", F("wk", 13), GOLD, anchor="mm")
    v5.chip(dr, (848, 277, 946, 305), "罡 9")
    v5.chip(dr, (952, 277, 1050, 305), "变 9")
    v5.chip(dr, (848, 477, 946, 505), "罡 10")
    v5.chip(dr, (952, 477, 1050, 505), "变 9")
    v5.hand(v5.HAND, hover=3)
    v5.flush()
    return v5.ctx.img.copy()


def draw_plate(dr, x0, strip_y, name, av, atk, dfn, state_at_right, state_label, state_above):
    """名牌（N2 定案形制）。state_at_right=状态签贴右缘（右角牌）；False=贴左缘（左角牌）。
    state_above=状态行挂条上（临战侧·下角牌）；False=挂条下（上角牌）。"""
    rrect(dr, (x0, strip_y, x0 + 274, strip_y + 92), 8, fill=CHIP_BG, outline=CHIP_BD, width=2)
    rt.avatar(dr, (x0 + 12, strip_y + 10, x0 + 56, strip_y + 54), av)
    text(dr, (x0 + 68, strip_y + 22), name, F("ms", 18), GOLD, anchor="lm")
    rt.stat_block(dr, (x0 + 154, strip_y + 10, x0 + 200, strip_y + 54), "攻", atk)
    rt.stat_block(dr, (x0 + 208, strip_y + 10, x0 + 254, strip_y + 54), "防", dfn)
    dr.line([(x0 + 12, strip_y + 62), (x0 + 264, strip_y + 62)], fill=(70, 64, 52), width=1)
    v5.mini_seals(dr, x0 + 12, strip_y + 66, XINFA)
    v5.chip(dr, (x0 + 160, strip_y + 64, x0 + 264, strip_y + 88), "劲10 骨3 气12")
    rt.fit(dr, "劲10 骨3 气12", F("wk", 13), 96, "三力chip")
    sx = x0 + 226 if state_at_right else x0
    sy = strip_y - 30 if state_above else strip_y + 98
    rt.state_seal(dr, (sx, sy, sx + 48, sy + 24), state_label)


def rack(dr, x0, y0, label, items, color):
    v5.rail(dr, x0, y0, label)
    for i, (t, _, st, bd) in enumerate(items):
        v5.bm_hang(x0 + 15 + i * 40, y0 + 5, t, color, st, bd)


def dantian(dr, box):
    rrect(dr, box, 4, fill=CHIP_BG, outline=CHIP_BD)
    text(dr, ((box[0] + box[2]) / 2, (box[1] + box[3]) / 2), "丹田 · 14", F("wk", 13), GOLD, anchor="mm")


def main():
    os.makedirs(v5.OUT, exist_ok=True)
    # A 现状
    img = base_clean()
    dr = ImageDraw.Draw(img)
    draw_plate(dr, 2, 36, "玄冥子", "玄", "12", "8", False, "破绽", False)   # 敌牌左上·状态贴左缘挂条下
    draw_plate(dr, 1004, 600, "无名", "无", "12", "1", True, "护体", True)  # 我牌右下·状态贴右缘挂条上
    dantian(dr, (898, 632, 996, 660))
    rack(dr, 40, 420, "功法", GONG, v5.ZHU)
    rack(dr, 40, 545, "护身", HU, v5.ZHEJIN)
    v5.ctx.img = img
    v5.caption("A 现状 ┃ 敌牌左上·我牌右下（对角）｜架子左缘两杆(420/545)｜丹田伴牌左")
    v5.save("swap_A_现状.png")

    # B 交换：我牌左下·架子右缘
    img = base_clean()
    dr = ImageDraw.Draw(img)
    draw_plate(dr, 2, 36, "玄冥子", "玄", "12", "8", False, "破绽", False)
    draw_plate(dr, 2, 618, "无名", "无", "12", "1", False, "护体", True)    # 我牌左下·状态贴左缘挂条上
    dantian(dr, (284, 652, 382, 680))
    rack(dr, 976, 510, "功法", GONG, v5.ZHU)                                # 右缘底角贴身排：上杆 510 距我罡变列底(505)仅 5px
    rack(dr, 976, 620, "护身", HU, v5.ZHEJIN)                               # 下杆墨迹底 620+99=719 贴屏底
    v5.ctx.img = img
    v5.caption("B 交换 ┃ 我牌左下（敌我身份同缘）｜架子右缘两杆贴底角(510/620·与罡变列 5px 净空)｜丹田随牌")
    v5.save("swap_B_交换.png")

    # 对比条
    sw, sh = 640, 390
    sheet = Image.new("RGB", (2 * sw + 3 * 12, sh + 40), (18, 20, 24))
    d2 = ImageDraw.Draw(sheet)
    for i, (lab, nm) in enumerate([("A 现状", "swap_A_现状.png"), ("B 交换", "swap_B_交换.png")]):
        x = 12 + i * (sw + 12)
        d2.text((x + sw / 2, 16), lab, font=F("wk", 16), fill=GOLD, anchor="mm")
        sheet.paste(Image.open(os.path.join(v5.OUT, nm)).resize((sw, sh), Image.LANCZOS), (x, 34))
    sheet.save(os.path.join(v5.OUT, "swap_对比.png"))
    print("saved swap_A/B/对比")


if __name__ == "__main__":
    main()
