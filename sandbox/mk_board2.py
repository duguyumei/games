## 招式特效 形态×语言 对照板 v2（草稿：只定形态与语言）
## 关键修正：PIL 在 RGBA 图上直接画半透明会「替换 alpha」→ 白闪变白块。
## 所以卡面画在底图，一切半透明特效（笔触/剑/环/白闪）画在独立叠加层再一次合成。
import math, random
from PIL import Image, ImageDraw, ImageFont

SHEET = Image.open("qiforge/assets/hud/blade_sheet.png").convert("RGBA")
BOX = [(92,169,202,6),(405,165,231,39),(820,82,61,202),(81,466,213,80),(410,424,191,125),
       (777,447,187,117),(88,760,194,126),(440,761,129,124),(738,792,190,39)]

PAPER=(238,232,218); CARD=(224,214,190); EDGE=(74,64,48)
INK=(40,34,26)

F  = ImageFont.truetype("assets/fonts/noto_sans_sc.ttf", 30)
FS = ImageFont.truetype("assets/fonts/noto_sans_sc.ttf", 21)
FH = ImageFont.truetype("assets/fonts/noto_sans_sc.ttf", 26)

W,H = 1780, 2090
base = Image.new("RGB",(W,H),PAPER)
ov   = Image.new("RGBA",(W,H),(0,0,0,0))
d    = ImageDraw.Draw(base)

def stroke_im(idx, span, angle, alpha=1.0):
    x0,y0,cw,ch = BOX[idx-1]
    im = SHEET.crop((x0,y0,x0+cw,y0+ch))
    k = span/max(im.width, im.height)
    im = im.resize((max(2,int(im.width*k)), max(2,int(im.height*k))), Image.LANCZOS)
    if alpha < 1.0:
        im.putalpha(im.getchannel("A").point(lambda v: int(v*alpha)))
    return im.rotate(angle, expand=True, resample=Image.BICUBIC)

def put_ov(part, cx, cy):
    ov.alpha_composite(part, (int(cx-part.width/2), int(cy-part.height/2)))

def card(cx, cy, w=96, h=128):
    dd = ImageDraw.Draw(base)
    dd.rounded_rectangle([cx-w/2, cy-h/2, cx+w/2, cy+h/2], radius=7, fill=CARD,
                         outline=EDGE, width=3)
    dd.ellipse([cx-w*0.20, cy-h*0.34, cx+w*0.14, cy-h*0.10], fill=(74,66,54))
    dd.polygon([(cx-w*0.26,cy+h*0.42),(cx-w*0.13,cy-h*0.04),(cx+w*0.02,cy+h*0.10),
                (cx+w*0.20,cy-h*0.05),(cx+w*0.27,cy+h*0.42)], fill=(64,57,46))

def flash(cx, cy, a=0.42, w=96, h=128):
    layer = Image.new("RGBA",(W,H),(0,0,0,0))
    ImageDraw.Draw(layer).rounded_rectangle([cx-w/2, cy-h/2, cx+w/2, cy+h/2], radius=7,
                                            fill=(255,255,255,int(255*a)))
    ov.alpha_composite(layer)

def sword_into(target, bx, by, ang, L=300, w=16, style="ink"):
    dd = ImageDraw.Draw(target)
    ca, sa = math.cos(ang), math.sin(ang)
    def P(dx,dy): return (bx+dx*ca-dy*sa, by+dx*sa+dy*ca)
    body = [P(0,-w/2),P(L*0.70,-w*0.34),P(L,0),P(L*0.70,w*0.34),P(0,w/2)]
    if style=="clean":
        dd.polygon(body, fill=(214,220,230,255))
        dd.polygon([P(0,-w/2),P(L*0.70,-w*0.34),P(L,0),P(0,0)], fill=(247,249,252,255))
        dd.line([P(0,-w/2),P(L*0.70,-w*0.34),P(L,0)], fill=(60,64,74,255), width=2)
        dd.line([P(0,w/2),P(L*0.70,w*0.34),P(L,0)], fill=(60,64,74,255), width=2)
        dd.line([P(0,0),P(-36,0)], fill=(70,58,44,255), width=9)
        dd.line([P(0,-20),P(0,20)], fill=(120,96,52,255), width=7)
    else:
        dd.polygon(body, fill=(INK[0],INK[1],INK[2],255))
        dd.line([P(0,-w/2),P(L*0.70,-w*0.34),P(L,0)], fill=(255,255,255,170), width=2)
        dd.line([P(0,0),P(-36,0)], fill=(INK[0],INK[1],INK[2],255), width=9)
        dd.line([P(0,-20),P(0,20)], fill=(INK[0],INK[1],INK[2],255), width=7)
        rnd = random.Random(11)
        for _ in range(14):
            t = rnd.uniform(0.08,0.95)
            px, py = P(L*t, rnd.uniform(-w*0.45, 0))
            dd.ellipse([px-4,py-2,px+4,py+2], fill=(255,255,255,120))

def sword(bx, by, ang, L=300, w=16, style="ink"):
    layer = Image.new("RGBA",(W,H),(0,0,0,0))
    sword_into(layer, bx, by, ang, L, w, style)
    ov.alpha_composite(layer)

def trail(bx, by, ang, L, w, n=3, style="ink", a0=0.10):
    for k in range(n,0,-1):
        layer = Image.new("RGBA",(W,H),(0,0,0,0))
        sword_into(layer, bx-math.cos(ang)*44*k, by-math.sin(ang)*44*k, ang, L, w, style)
        layer.putalpha(layer.getchannel("A").point(lambda v: int(v*(a0+0.06*k))))
        ov.alpha_composite(layer)

def ring(cx, cy, r, style="ink", a=0.85):
    if style=="ink":
        for k in range(30):
            ang = 2*math.pi*k/30
            put_ov(stroke_im(6, 40, math.degrees(ang)+90, a),
                   cx+math.cos(ang)*r, cy+math.sin(ang)*r*0.60)
    else:
        layer = Image.new("RGBA",(W,H),(0,0,0,0))
        col = (255,255,255,170) if style=="clean" else (INK[0],INK[1],INK[2],200)
        ImageDraw.Draw(layer).ellipse([cx-r, cy-r*0.60, cx+r, cy+r*0.60], outline=col, width=6)
        ov.alpha_composite(layer)

# ── 标题与表头 ────────────────────────────────────────────────────────
d.text((40,32),"招式特效 · 形态 × 语言 对照板", font=F, fill=INK)
d.text((40,78),"六种攻击形态（行）× 三种表现语言（列）——草稿，只定“长什么样”，不做质感定稿",
       font=FS, fill=(110,100,84))
COLS=[400,880,1360]
for i,name in enumerate(["① 一笔剑意（只有笔触，不画剑）","② 墨影剑（剑是墨的剪影）","③ 实剑（写实金属）"]):
    d.text((COLS[i],118), name, font=FH, fill=INK)
ROWS=["① 单体 · 直刺","② 前排 · 下斩","③ 多段 · 连珠刺","④ 弹射 · 逍遥剑","⑤ 范围 · 回身剑","⑥ 万剑归宗"]
SUBS=["一击一目标","一字横扫整排","同一点连打三下","目标之间折跳","环状扩散·无方向","多主体齐射"]
TOP=168; RH=300; CY=lambda r: TOP+r*RH+RH//2

for r in range(6):
    y=TOP+r*RH
    d.line([(30,y),(W-30,y)], fill=(200,190,170), width=2)
    d.text((40,y+64), ROWS[r], font=FH, fill=INK)
    d.text((40,y+102), SUBS[r], font=FS, fill=(120,108,90))

# ── 卡面（底图先摆） ──────────────────────────────────────────────────
for r in range(6):
    offs = [-1,0,1] if r in (1,3,4,5) else [0]
    for cx0 in COLS:
        for k in offs:
            card(cx0+210+k*120, CY(r))

# ── 特效（叠加层） ────────────────────────────────────────────────────
for r in range(6):
    cy=CY(r)

    cx=COLS[0]+210                      # ① 一笔剑意
    if r==0:
        put_ov(stroke_im(1,430,-24,0.95), cx-70, cy+30)
        put_ov(stroke_im(9,160,64,0.5), cx+90, cy-95)
    elif r==1:
        for k in (-1,0,1): flash(cx+k*120, cy, 0.30)
        put_ov(stroke_im(2,540,-5,0.95), cx, cy-28)
    elif r==2:
        for k in range(3): put_ov(stroke_im(9,160,-34+k*9,0.95), cx-44+k*28, cy+34-k*34)
    elif r==3:
        for k in (-1,0,1): flash(cx+k*120, cy, 0.24)
        for k,ax in ((-1,-120),(0,0),(1,120)):
            put_ov(stroke_im(8,140, 34 if k%2==0 else -34, 0.95), cx+ax, cy-40)
    elif r==4:
        for k in (-1,0,1): flash(cx+k*120, cy, 0.26)
        ring(cx, cy+6, 205, "ink", 0.85)
    else:
        for k in (-1,0,1): flash(cx+k*120, cy, 0.18)
        for k in range(12):
            a=-58+k*11
            put_ov(stroke_im(1,210,a-10,0.9), cx-120+abs(k-6)*14, cy+40+math.sin(math.radians(a*2))*70)

    cx=COLS[1]+210                      # ② 墨影剑
    if r==0:
        trail(cx-118, cy+60, math.radians(-26), 300, 16, 3, "ink")
        sword(cx-118, cy+60, math.radians(-26), 300, 16, "ink")
    elif r==1:
        for k in (-1,0,1): flash(cx+k*120, cy, 0.26)
        sword(cx-300, cy+34, 0, 520, 15, "ink")
    elif r==2:
        for k in range(3): sword(cx-190+k*18, cy+64-k*40, math.radians(-32), 230, 13, "ink")
    elif r==3:
        for k in (-1,0,1): flash(cx+k*120, cy, 0.24)
        for k,ax in ((-1,-120),(0,0),(1,120)):
            sword(cx+ax-90, cy+26 if k==-1 else cy-64, math.radians(30 if k%2 else -30), 190, 12, "ink")
    elif r==4:
        for k in (-1,0,1): flash(cx+k*120, cy, 0.24)
        ring(cx, cy+6, 205, "dark")
        for k in range(8):
            a=2*math.pi*k/8
            sword(cx+math.cos(a)*150, cy+math.sin(a)*88, a+math.pi/2, 110, 10, "ink")
    else:
        for k in (-1,0,1): flash(cx+k*120, cy, 0.18)
        for k in range(11):
            a=math.radians(-62+k*12)
            sword(cx-140+abs(k-5)*12, cy+70, a, 210, 11, "ink")

    cx=COLS[2]+210                      # ③ 实剑
    if r==0:
        sword(cx-118, cy+60, math.radians(-26), 300, 16, "clean")
    elif r==1:
        for k in (-1,0,1): flash(cx+k*120, cy, 0.26)
        sword(cx-300, cy+34, 0, 520, 15, "clean")
    elif r==2:
        for k in range(3): sword(cx-190+k*18, cy+64-k*40, math.radians(-32), 230, 13, "clean")
    elif r==3:
        for k in (-1,0,1): flash(cx+k*120, cy, 0.24)
        for k,ax in ((-1,-120),(0,0),(1,120)):
            sword(cx+ax-90, cy+26 if k==-1 else cy-64, math.radians(30 if k%2 else -30), 190, 12, "clean")
    elif r==4:
        for k in (-1,0,1): flash(cx+k*120, cy, 0.24)
        ring(cx, cy+6, 205, "clean")
    else:
        for k in (-1,0,1): flash(cx+k*120, cy, 0.18)
        for k in range(11):
            a=math.radians(-62+k*12)
            sword(cx-140+abs(k-5)*12, cy+70, a, 210, 11, "clean")

out = Image.alpha_composite(base.convert("RGBA"), ov)
d2 = ImageDraw.Draw(out)
d2.line([(30,H-92),(W-30,H-92)], fill=(200,190,170), width=2)
d2.text((40,H-76),"笔触＝现役 blade_sheet 九格真墨迹；敌卡按游戏比例（190px）。草稿只定形态/语言，不定质感。",
        font=FS, fill=(120,108,90))
out.convert("RGB").save("sandbox/fx_forms_board.png")
print("saved")
