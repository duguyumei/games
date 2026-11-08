from PIL import Image, ImageDraw, ImageFont
SRC='/Users/cc/.dsh/attachments/v1/objects/5f/5f95486b48aa65c972e53eb8483b377c9b99fd61570b64096bcea15c3100c062'
FONT='assets/fonts/noto_sans_sc.ttf'
f20=ImageFont.truetype(FONT,20); f16=ImageFont.truetype(FONT,16); f14=ImageFont.truetype(FONT,14)
CY=(90,220,255); GRN=(130,230,160); GOLD=(239,200,81); MAIN=(240,230,200); SUB=(150,140,120)
src=Image.open(SRC).convert('RGB')
CX0,CY0,CX1,CY1=900,892,1810,1226
crop=src.crop((CX0,CY0,CX1,CY1))
OX,OY=150,52
W,H=1500,470
im=Image.new('RGB',(W,H),(23,19,13)); d=ImageDraw.Draw(im,'RGBA')
im.paste(crop,(OX,OY))
def tx(x,y): return (OX+(x-CX0), OY+(y-CY0))
boxes=[('①',(965,912,1689,981)),('②',(957,988,1668,1108)),('③',(929,1113,1634,1181))]
for lbl,(x0,y0,x1,y1) in boxes:
    a=tx(x0,y0); b=tx(x1,y1)
    d.rectangle([a[0],a[1],b[0],b[1]], outline=CY+(255,), width=2)
    d.text((a[0]-30,(a[1]+b[1])//2-11), lbl, font=f20, fill=CY)
pts=[tx(x0,(y0+y1)//2) for _, (x0,y0,x1,y1) in boxes]
for i in range(len(pts)-1): d.line([pts[i],pts[i+1]], fill=CY+(140,), width=1)
# 左缘漂移标尺
p0=tx(965,912); p2=tx(929,1113)
d.line([(p0[0]-56,p0[1]),(p0[0]-56,p2[1]+60)], fill=SUB+(200,), width=1)
for pp in (p0,p2): d.line([(pp[0]-62,pp[1]),(pp[0]-50,pp[1])], fill=SUB+(200,), width=1)
d.text((p0[0]-104,p0[1]+78), "左缘", font=f14, fill=GRN)
d.text((p0[0]-104,p0[1]+96), "左移", font=f14, fill=GRN)
d.text((p0[0]-104,p0[1]+114), "36px", font=f14, fill=GRN)

d.text((OX,20), "你的参考图：三个关键词窗、卡在右侧、整列朝左上递进", font=f16, fill=MAIN)

PX=1090
d.text((PX,58), "读到的三条规则", font=f16, fill=GOLD)
rules=[
 ("① 侧向动态", ["卡在屏幕右半边 → 整列放卡左边；", "卡在中间/左边 → 默认放右边。"]),
 ("② 从上往下", ["第一块顶边与卡顶齐，其余一块接", "一块往下摞；不居中、不自动跳位。"]),
 ("③ 斜卡带梯度", ["每块沿卡的倾角递进偏移，摞出来是", "一条斜列（图上左缘共左移 36px，", "≈ 每块 18px）。"]),
]
y=96
for head, lines in rules:
    d.text((PX,y), head, font=f16, fill=CY); y+=26
    for ln in lines:
        d.text((PX+16,y), ln, font=f14, fill=MAIN); y+=21
    y+=12
im.save('sandbox/tip_pos_rule.png'); print('ok',im.size)
