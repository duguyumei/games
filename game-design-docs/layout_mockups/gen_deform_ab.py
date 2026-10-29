# -*- coding: utf-8 -*-
"""远近形变 A/B 锚定对比图（2026-09-24）。
A＝透视包：桌梯形（R≈0.61≈studio 手调机位烘焙观感）＋桌上内容随深度缩放＋
   远端重点信息（敌血带/敌打出位/敌在途立签）基准放大补偿（可调）；HUD 平面不变形。
B＝平面包：R=1 全桌等大（天凤/Balatro 路线），深度感只留光影/压暗；HUD 平面。
同一 V5 决策拍内容，唯一变量＝形变包。复用 gen_layout_mockups_v5 的绘制函数。
"""
import os
import sys
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_layout_mockups_v5 as v5

W, H, CAP = v5.W, v5.H, v5.CAP
CX, Y_FAR, Y_NEAR = 640.0, 122.0, 708.0
HAND = v5.HAND
ZHU, ZHEJIN, XUANQING = v5.ZHU, v5.ZHEJIN, v5.XUANQING
OUT = v5.OUT


def clamp(x, a, b):
    return max(a, min(b, x))


def dscale(y, R):
    """深度缩放：远缘 Y_FAR 处＝R，近缘 Y_NEAR 处＝1（与桌梯形同一插值）。"""
    return R + (1.0 - R) * clamp((y - Y_FAR) / (Y_NEAR - Y_FAR), 0.0, 1.0)


def render_group(build):
    """把一组 v5 绘制调用渲染到透明临时画布，返回 (画布, 绝对坐标 bbox)。"""
    saved = (v5.ctx.img, v5.ctx.layers, v5.ctx.overlays)
    v5.ctx.img = Image.new("RGBA", (W, H + CAP), (0, 0, 0, 0))
    v5.ctx.layers, v5.ctx.overlays = [], []
    build()
    tmp = v5.ctx.img
    for it in v5.ctx.layers:
        v5.pastea(tmp, it[0], it[1], it[2], it[3] if len(it) > 3 else 255)
    for ov in v5.ctx.overlays:
        tmp = Image.alpha_composite(tmp, ov)
    v5.ctx.img, v5.ctx.layers, v5.ctx.overlays = saved
    return tmp, tmp.getbbox()


def place(final, tmp, bb, ax, ay, s, comp=1.0):
    """锚点放缩：元素锚 (ax,ay) 落在深度线原位，横向按 s 向 CX 收敛，尺寸乘 s*comp。"""
    sp = tmp.crop(bb)
    sc = s * comp
    if abs(sc - 1.0) > 0.004:
        sp = sp.resize((max(1, int(sp.width * sc)), max(1, int(sp.height * sc))), Image.LANCZOS)
    ax_in, ay_in = (ax - bb[0]) * sc, (ay - bb[1]) * sc
    tx = CX + (ax - CX) * s
    final.paste(sp, (int(tx - ax_in), int(ay - ay_in)), sp)


def draw_table(final, R):
    dr = ImageDraw.Draw(final)

    def band(near_half, y0, y1, fill):
        h0, h1 = near_half * R, near_half
        dr.polygon([(CX - h0, y0), (CX + h0, y0), (CX + h1, y1), (CX - h1, y1)], fill=fill)

    band(690, 96, 722, v5.RIM_WALL)
    band(678, 101, 718, v5.RIM_TOP)
    band(632, 122, 708, v5.FELT)
    ov = Image.new("RGBA", (W, H + CAP), (0, 0, 0, 0))
    d2 = ImageDraw.Draw(ov)
    hf = 632 * R
    d2.polygon([(CX - hf, 122), (CX + hf, 122), (CX + hf, 192), (CX - hf, 192)], fill=(0, 0, 0, 46))
    d2.polygon([(CX - 632, 560), (CX + 632, 560), (CX + 632, 708), (CX - 632, 708)], fill=(255, 255, 255, 10))
    d2.line([(320, 374), (540, 374)], fill=(58, 108, 76, 110), width=2)
    d2.line([(740, 374), (960, 374)], fill=(58, 108, 76, 110), width=2)
    final.paste(Image.alpha_composite(final.convert("RGBA"), ov).convert("RGB"), (0, 0))


def rail_row(ry, label, hang_items, pin_items, chip=None):
    def build():
        dr = ImageDraw.Draw(v5.ctx.img)
        v5.rail(dr, 40, ry, label)
        for i, it in enumerate(hang_items):
            v5.bm_hang(55 + i * 40, ry + 5, *it)
        for i, it in enumerate(pin_items):
            v5.bm_pin(55 + i * 40, ry + 2, it[0], XUANQING, filled=it[1])
        if chip:
            box, lab = chip[:4], chip[4]
            v5.rrect(dr, box, 4, fill=v5.CHIP_BG, outline=v5.CHIP_BD)
            v5.text(dr, ((box[0] + box[2]) / 2, (box[1] + box[3]) / 2),
                    lab, v5.F("wk", 12), v5.GOLD, anchor="mm")
    return build


def build_frame(R, comp_on):
    final = Image.new("RGB", (W, H + CAP), v5.ROOM)
    v5.ctx.img = final
    draw_table(final, R)
    cb = 1.22 if comp_on else 1.0   # 远端重点补偿（血带/打出位）
    cs = 1.12 if comp_on else 1.0   # 远端立签补偿

    def backs():
        bw, n = 23, 13
        x = CX - (n * (bw + 4) - 4) / 2
        for _ in range(n):
            v5.ctx.layers.append((v5.tile_back(bw), int(x), 153))
            x += bw + 4
    tmp, bb = render_group(backs)
    place(final, tmp, bb, CX, 169, dscale(169, R))

    for cx, yb, faces, tw in [(360, 252, ["5s", "5s", "5s"], 30),
                              (800, 578, ["3m", "3m", "3m"], 26),
                              (945, 578, ["2p", "3p", "4p"], 26)]:
        tmp, bb = render_group(lambda f=faces, t=tw: v5.meld_group(cx, yb, f, t))
        place(final, tmp, bb, cx, yb, dscale(yb, R))

    tmp, bb = render_group(lambda: v5.hp_track("foe", 640, 278, 400, 98))
    place(final, tmp, bb, 640, 291, dscale(291, R), cb)
    tmp, bb = render_group(lambda: v5.discard_slot(640, 318, 170, 50, ["5p", "6p", "7p"], "普攻 · 3 张", ZHU))
    place(final, tmp, bb, 640, 318, dscale(318, R), cb)
    tmp, bb = render_group(lambda: v5.qisea(640, 376))
    place(final, tmp, bb, 640, 376, dscale(376, R))
    tmp, bb = render_group(lambda: v5.discard_slot(640, 436, 170, 54, ["1s"], "虚招", (110, 104, 95)))
    place(final, tmp, bb, 640, 436, dscale(436, R))
    tmp, bb = render_group(lambda: v5.hp_track("me", 640, 478, 400, 137))
    place(final, tmp, bb, 640, 491, dscale(491, R))

    # 决策拍＝敌方在途立签（气海右侧）
    tmp, bb = render_group(lambda: v5.standing_sign(775, 352, "破甲拳", ZHU, 2, 4))
    place(final, tmp, bb, 775, 352, dscale(352, R), cs)

    gong = [("破甲拳", ZHU, "lit", None), ("点穴", ZHU, "lit", None), ("连环掌", ZHU, "dim", "式3"),
            (None, None, "empty", None), (None, None, "empty", None)]
    hu = [("铁布衫", ZHEJIN, "lit", None), ("金钟罩", ZHEJIN, "dim", "罡4"),
          (None, None, "empty", None), (None, None, "empty", None), (None, None, "empty", None)]
    pins = [("拆招诀", True), ("运筹诀", True), ("洗练诀", True), (None, False), (None, False)]
    for ry, build in [(420, rail_row(420, "功法", gong, [], None)),
                      (519, rail_row(519, "护身", hu, [], (248, 519 + 58, 296, 519 + 82, "罡 10"))),
                      (618, rail_row(618, "心法", [], pins, None))]:
        tmp, bb = render_group(build)
        place(final, tmp, bb, 137, ry + 2, dscale(ry, R))

    tmp, bb = render_group(lambda: v5.hand(HAND, hover=3))
    place(final, tmp, bb, CX, 716, dscale(716, R))

    # ---- HUD（两包同款平面，不变形） ----
    dr = ImageDraw.Draw(final)
    v5.button((534, 578, 638, 624), "变招", XUANQING)
    v5.button((646, 578, 750, 624), "攻击", ZHU)
    dr.rectangle((0, 0, W, 30), fill=(23, 22, 20))
    dr.line([(0, 30), (W, 30)], fill=v5.CHIP_BD)
    v5.text(dr, (12, 15), "‹ 演武场", v5.F("wk", 13), v5.BONE, anchor="lm")
    v5.text(dr, (640, 15), "回合 12 · 组 1-3", v5.F("wk", 13), v5.GOLD, anchor="mm")
    v5.rrect(dr, (1216, 38, 1271, 93), 4, fill=(33, 28, 23), outline=v5.CHIP_BD)
    v5.text(dr, (1243, 65), "玄", v5.F("ms", 22), v5.GOLD, anchor="mm")
    v5.chip(dr, (1117, 36, 1215, 64), "罡 9　变 9")
    v5.chip(dr, (1117, 65, 1215, 93), "攻 12　防 8")
    v5.chip(dr, (1136, 94, 1270, 122), "劲 10　骨 3　气 12")
    v5.chip(dr, (146, 34, 236, 62), "丹田 · 13", fg=v5.GOLD)
    v5.mini_seals(dr, 1117, 130, ["拆招诀", "运筹诀", "洗练诀"])
    v5.chip(dr, (1116, 566, 1214, 594), "丹田 · 16", fg=v5.GOLD)
    v5.chip(dr, (1136, 600, 1270, 628), "劲 10　骨 3　气 12")
    v5.chip(dr, (1117, 632, 1215, 660), "攻 12　防 8")
    v5.chip(dr, (1117, 664, 1215, 692), "变 9")
    v5.rrect(dr, (1216, 632, 1271, 687), 4, fill=(33, 28, 23), outline=v5.CHIP_BD)
    v5.text(dr, (1243, 659), "无", v5.F("ms", 22), v5.GOLD, anchor="mm")
    return final


def main():
    os.makedirs(OUT, exist_ok=True)
    a = build_frame(0.61, True)
    v5.ctx.img = a
    v5.caption("A · 透视包（studio 机位档 R≈0.61）┃ 桌上内容随深度缩┃ 敌方重点信息放大补偿(可调)┃ HUD 平面")
    a.save(os.path.join(OUT, "deform_A_透视包.png"))
    print("saved deform_A_透视包.png")

    b = build_frame(1.0, False)
    v5.ctx.img = b
    v5.caption("B · 平面包（R=1）┃ 全桌等大┃ 深度感只留光影压暗┃ HUD 平面")
    b.save(os.path.join(OUT, "deform_B_平面包.png"))
    print("saved deform_B_平面包.png")

    ab = Image.new("RGB", (W, 2 * (H + CAP)), v5.ROOM)
    ab.paste(a, (0, 0))
    ab.paste(b, (0, H + CAP))
    ab.save(os.path.join(OUT, "deform_AB_对比.png"))
    print("saved deform_AB_对比.png")


if __name__ == "__main__":
    main()
