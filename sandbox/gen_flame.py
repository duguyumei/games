"""连击徽·火焰贴图：笔墨感的火舌——外沿墨、内芯金，像一笔画出来的火。
输出 3 变体到 qiforge/assets/hud/fx_flame_a/b/c.png（200×380，透明底）。
"""
import numpy as np, math
from PIL import Image, ImageFilter

W, H = 200, 380

def make(seed, lean, curl, width0, length):
    r = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    t = 1.0 - yy / float(H)                       # 0 底 1 顶
    tt = np.clip(t / length, 0, 1)                # 归一化到实际长度
    cx = (W - 1) * 0.5 + lean * (tt ** 1.3) * 34.0 + np.sin(tt * curl * np.pi) * 9.0
    hw = width0 * (1.0 - t) ** 0.92 + 1.2
    hw *= (0.80 + 0.35 * np.sin(tt * 5.2 + seed))
    d = np.abs(xx - cx) / np.maximum(hw, 0.8)
    a = np.clip(1.0 - d, 0.0, 1.0) ** 0.62
    a *= np.clip(t * 12.0, 0, 1)
    a *= np.clip((1.0 - tt) * 9.0, 0, 1)
    a *= (t <= length)
    # 毛糙（笔触边）
    n = r.normal(0, 1, (H // 6 + 2, W // 6 + 2)).astype(np.float32)
    n = np.array(Image.fromarray(((n - n.min()) / (np.ptp(n) + 1e-6) * 255).astype(np.uint8))
                 .resize((W, H), Image.BICUBIC), np.float32) / 255.0
    a *= (0.72 + 0.42 * n)
    a = np.clip(a, 0, 1)

    ink = np.array([26, 30, 42], np.float32)
    gold_lo = np.array([250, 168, 62], np.float32)
    gold_hi = np.array([255, 232, 168], np.float32)
    base = gold_lo * (1 - tt[..., None]) + gold_hi * tt[..., None] * 0.95
    edge = np.clip((d - 0.72) / 0.28, 0, 1) ** 1.2   # 只有最外 28% 是墨边
    col = base * (1 - edge[..., None]) + ink * edge[..., None]
    core = np.clip(1.0 - d / 0.70, 0, 1) ** 2.0
    col = col + (np.array([255, 246, 214], np.float32) - col) * (core[..., None] * 0.55)
    out = np.dstack([col, a * 255.0])
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGBA")

specs = [(1, -1.0, 1.5, 52.0, 0.95), (2, 0.15, 2.1, 64.0, 0.80), (3, 1.0, 1.1, 46.0, 1.0)]
for i, sp in enumerate(specs):
    make(*sp).save("qiforge/assets/hud/fx_flame_%s.png" % "abc"[i])

prev = Image.new("RGB", (700, 420), (232, 225, 212))
for i, nm in enumerate("abc"):
    im = Image.open("qiforge/assets/hud/fx_flame_%s.png" % nm)
    prev.paste(im, (10 + i * 210, 16), im)
    dk = Image.new("RGB", im.size, (14, 18, 28)); dk.paste(im, (0, 0), im)
    prev.paste(dk.resize((150, 285)), (10 + i * 210 + 20, 130))
prev.save("sandbox/flame_assets.png")
print("ok")
