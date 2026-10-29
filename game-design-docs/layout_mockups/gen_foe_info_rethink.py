# -*- coding: utf-8 -*-
"""敌方信息框重构 N1/N2/N3 效果图（2026-09-26 用户令：现制有问题·不参考旧布局·重新思考）

内容重审：
  删：三力列（劲/骨/气＝攻防的推导参数，非对敌决策读数；悬停可查推导式）＋朱印落款（零信息装饰）；
  留：攻/防面板（每战级决策数）＋名号/头像（身份）＋心法 5 印（构筑情报·悬停详情）；
  加：状态位＝破绽/护体（有则显·无则隐——V5 敌侧此前无家，实装 2D 里是临时 chip/日志）；
  确认在别处不进框：血（敌血带）／罡变（带右翼）／在途（中线书签）／武学（发动公示）／
  丹田手牌数（桌面牌可数）／副露（桌区）。

N1 散帐：敌方框解散——攻/防贴敌血带左翼（与右翼罡/变对称·中线＝完整战况账本），
   破绽/护体＝带上浮签（有则显）；右上只留身份锚（头像＋名号＋心法印行）。
N2 名牌横条：一块横排名牌——行1 头像｜名号｜攻防数字块；行2 心法印＋状态槽（右端·有则浮出）。
N3 无框锚点：头像即锚、无底板——破绽/护体＝裹头像色带（朱／钢青·状态长在人脸上），
   名号下攻防小 chip、心法印行收底。
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_layout_mockups_v5 as v5
from PIL import Image, ImageDraw

W, H = v5.W, v5.H
F, rrect, text = v5.F, v5.rrect, v5.text
BONE, GOLD, DASH, INK = v5.BONE, v5.GOLD, v5.DASH, v5.INK
CHIP_BG, CHIP_BD, ROOM = v5.CHIP_BG, v5.CHIP_BD, v5.ROOM
ZHU = v5.ZHU
ZHU_FILL = (146, 46, 38)     # 破绽（状态用朱的暗档）
STEEL = (96, 116, 132)       # 护体（钢青·说明用，不画）
AV_BD = (168, 144, 92)       # 头像金框
XINFA = ["拆招诀", "运筹诀", "洗练诀"]


def fit(dr, s, font, maxw, tag):
    w = dr.textlength(s, font=font)
    if w > maxw:
        print("OVERFLOW", tag, round(w, 1), ">", maxw)


def avatar(dr, box, ch="玄"):
    x0, y0, x1, y1 = box
    rrect(dr, box, 4, fill=INK, outline=AV_BD)
    text(dr, ((x0 + x1) / 2, (y0 + y1) / 2), ch, F("ms", int((y1 - y0) * 0.42)), GOLD, anchor="mm")


def state_seal(dr, box, label, fill=ZHU_FILL, outline=ZHU):
    x0, y0, x1, y1 = box
    rrect(dr, box, 4, fill=fill, outline=outline)
    text(dr, ((x0 + x1) / 2, (y0 + y1) / 2), label, F("wk", 12), v5.BONE, anchor="mm")
    fit(dr, label, F("wk", 12), (x1 - x0) - 8, "state:" + label)


def seals_small(dr, x0, y0, titles, slot=24, seal=18):
    """N3 用缩小版心法印行（5 槽·空槽点）。"""
    for i in range(5):
        x = x0 + i * slot
        if i < len(titles):
            rrect(dr, (x, y0, x + seal, y0 + seal), 3,
                  fill=v5.tint(v5.XUANQING, (20, 24, 26), 0.25), outline=(96, 116, 120))
            text(dr, (x + seal / 2, y0 + seal / 2), titles[i][0], F("wk", 10), (168, 192, 196), anchor="mm")
        else:
            dr.ellipse((x + seal / 2 - 3, y0 + seal / 2 - 3, x + seal / 2 + 3, y0 + seal / 2 + 3),
                       outline=(90, 84, 70))


def base_frame():
    """V5 决策拍底图＋盖旧敌簇；罡/变按现制落血带右翼（tscn 敌罡变列 848–1050,277–305）。"""
    v5.common("steady")
    v5.hand(v5.HAND, hover=3)
    v5.flush()
    img = v5.ctx.img.copy()
    dr = ImageDraw.Draw(img)
    dr.rectangle((1105, 20, W, 205), fill=ROOM)  # 旧敌簇（chip×3＋头像＋小印行）整片让位
    v5.chip(dr, (848, 277, 946, 305), "罡 9")
    v5.chip(dr, (952, 277, 1050, 305), "变 9")
    return img


# ---------- N1 散帐 ----------

def variant_n1(img):
    dr = ImageDraw.Draw(img)
    # 战况带左翼：攻/防贴带（与右翼罡/变同语言；血带纸签「气血 98」在 358 起，留 10px 隙）
    v5.chip(dr, (256, 277, 300, 305), "攻 12")
    v5.chip(dr, (304, 277, 348, 305), "防 8")
    # 带上浮签：状态位（有则显·无则空；护体＝钢青同位）
    state_seal(dr, (256, 245, 304, 271), "破绽")
    # 右上身份锚：头像＋名号＋心法 5 小印（构筑情报归身份）
    avatar(dr, (1216, 34, 1260, 78))
    text(dr, (1238, 90), "玄冥子", F("ms", 16), GOLD, anchor="mm")
    v5.mini_seals(dr, 1136, 104, XINFA)
    return img


# ---------- N2 名牌横条（09-27 定案＋两处修订：行2右端=三力·为后续影响三力的功法留位；状态=条下专职行） ----------

def stat_block(dr, box, lab, num):
    x0, y0, x1, y1 = box
    text(dr, ((x0 + x1) / 2, y0 + 3), lab, F("wk", 12), DASH, anchor="ma")
    text(dr, ((x0 + x1) / 2, (y0 + y1) / 2 + 9), num, F("wk", 22), BONE, anchor="mm")
    fit(dr, num, F("wk", 22), (x1 - x0) - 8, "stat:" + lab)


def variant_n2(img, left=False):
    dr = ImageDraw.Draw(img)
    dx = -1002 if left else 0  # 右版条 x0=1004；左版条 x0=2（同 2px 屏缘距）
    rrect(dr, (1004 + dx, 36, 1278 + dx, 128), 8, fill=CHIP_BG, outline=CHIP_BD, width=2)
    # 行1：头像｜名号｜攻块·防块
    avatar(dr, (1016 + dx, 46, 1060 + dx, 90))
    text(dr, (1070 + dx, 68), "玄冥子", F("ms", 18), GOLD, anchor="lm")
    stat_block(dr, (1156 + dx, 46, 1202 + dx, 90), "攻", "12")
    stat_block(dr, (1210 + dx, 46, 1256 + dx, 90), "防", "8")
    dr.line([(1016 + dx, 98), (1268 + dx, 98)], fill=(70, 64, 52), width=1)
    # 行2：心法 5 印｜三力（右端·用户令回归：后续可能有影响三力的功法）
    v5.mini_seals(dr, 1016 + dx, 102, XINFA)
    v5.chip(dr, (1164 + dx, 100, 1268 + dx, 124), "劲10 骨3 气12")
    fit(dr, "劲10 骨3 气12", F("wk", 13), 96, "三力chip")
    # 行3（专职状态行·条下新增·有则显无则隐）：右版自右缘左向生长／左版自左缘右向生长
    if left:
        state_seal(dr, (2, 134, 50, 158), "破绽")
    else:
        state_seal(dr, (1230, 134, 1278, 158), "破绽")
    return img


def cover_legacy(img):
    """盖 V5 图遗留的左上「丹田·13」chip（敌丹田＝桌面牌可数、定案不进名牌；两版同盖＝公平对比）。"""
    ImageDraw.Draw(img).rectangle((140, 30, 242, 66), fill=ROOM)
    return img


# ---------- N3 无框锚点 ----------

def variant_n3(img):
    dr = ImageDraw.Draw(img)
    av = (1206, 50, 1266, 110)
    avatar(dr, av, ch="玄")
    # 破绽＝朱带裹框（常态＝金细框无带；护体＝钢青带同位）＋上缘小签
    dr.rectangle((av[0] - 3, av[1] - 3, av[2] + 3, av[3] + 3), outline=ZHU_FILL, width=3)
    state_seal(dr, (av[0], av[1] - 18, av[0] + 46, av[1] + 2), "破绽")
    # 名号＋攻防小 chip
    text(dr, (1236, 122), "玄冥子", F("ms", 17), GOLD, anchor="mm")
    v5.chip(dr, (1186, 132, 1230, 156), "攻 12")
    v5.chip(dr, (1234, 132, 1278, 156), "防 8")
    # 心法印行收底
    seals_small(dr, 1158, 162, XINFA)
    return img


def main():
    os.makedirs(v5.OUT, exist_ok=True)
    variants = [
        ("N1", variant_n1, "N1 散帐 ┃ 敌框解散：攻/防贴敌血带左翼·与右翼罡/变对称｜破绽/护体＝带上浮签(有则显)｜右上只留身份锚(头像+名号+心法印)"),
        ("N2", variant_n2, "N2 名牌横条（定案·右上版）┃ 行1 头像|名号|攻防块｜行2 心法印＋三力(为后续影响三力的功法留位)｜条下专职状态行(破绽/护体·有则显)"),
        ("N3", variant_n3, "N3 无框锚点 ┃ 头像即锚·无底板：破绽/护体＝裹框色带(朱/钢青·状态长在人脸上)｜名号下攻防chip｜心法印行收底"),
    ]
    for tag, fn, cap in variants:
        img = fn(cover_legacy(base_frame()) if tag == "N2" else base_frame())
        v5.ctx.img = img
        v5.caption(cap)
        v5.save(f"foe_rethink_{tag}.png")
    # 三案对比条（右上区＋敌血带两翼同框并排；N2 列＝右上版）
    crops = []
    for tag in ("N1", "N2", "N3"):
        im = Image.open(os.path.join(v5.OUT, f"foe_rethink_{tag}.png"))
        crops.append((tag, im.crop((940, 18, 1280, 320))))
    cw, ch = 340, 302
    sheet = Image.new("RGB", (3 * cw + 4 * 12, ch + 40), (18, 20, 24))
    d2 = ImageDraw.Draw(sheet)
    for i, (tag, crop) in enumerate(crops):
        x = 12 + i * (cw + 12)
        d2.text((x + cw / 2, 16), tag, font=F("wk", 16), fill=GOLD, anchor="mm")
        sheet.paste(crop, (x, 34))
    sheet.save(os.path.join(v5.OUT, "foe_rethink_三案对比.png"))
    print("saved foe_rethink_三案对比.png")

    # 09-27 位置分叉：名牌移左上（用户令）——全帧 50% 左右对比
    img_l = variant_n2(cover_legacy(base_frame()), left=True)
    v5.ctx.img = img_l
    v5.caption("N2 名牌横条·左上版 ┃ 名牌移左上（右缘减负：原右上名牌＋带右翼罡变＋右下我方账本三簇堆叠→让位）｜内容同定案：行1 头像|名号|攻防｜行2 心法印+三力｜条下专职状态行(自左缘右向生长)")
    v5.save("foe_rethink_N2L.png")
    im_l = Image.open(os.path.join(v5.OUT, "foe_rethink_N2L.png"))
    im_r = Image.open(os.path.join(v5.OUT, "foe_rethink_N2.png"))
    sw, sh = 640, 390
    sheet2 = Image.new("RGB", (2 * sw + 3 * 12, sh + 40), (18, 20, 24))
    d3 = ImageDraw.Draw(sheet2)
    for i, (lab, im) in enumerate([("左上版", im_l), ("右上版", im_r)]):
        x = 12 + i * (sw + 12)
        d3.text((x + sw / 2, 16), lab, font=F("wk", 16), fill=GOLD, anchor="mm")
        sheet2.paste(im.resize((sw, sh), Image.LANCZOS), (x, 34))
    sheet2.save(os.path.join(v5.OUT, "foe_rethink_N2_左右对比.png"))
    print("saved foe_rethink_N2L.png / foe_rethink_N2_左右对比.png")


if __name__ == "__main__":
    main()
