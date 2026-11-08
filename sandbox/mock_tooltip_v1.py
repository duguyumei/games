#!/usr/bin/env python3
from PIL import Image, ImageDraw, ImageFont

FONT = "assets/fonts/noto_sans_sc.ttf"
INK=(23,19,13); GOLD=(239,200,81); GOLD_DIM=(138,111,46); GOLD_DARK=(42,29,8)
CREAM=(255,246,226); MAIN=(240,230,200); SUB=(154,143,116)
WARM=(200,120,110); COOL=(140,190,140)
f22=ImageFont.truetype(FONT,22); f20=ImageFont.truetype(FONT,20)
f16=ImageFont.truetype(FONT,16); f14=ImageFont.truetype(FONT,14); f13=ImageFont.truetype(FONT,13)

def chamfer(x,y,w,h,c):
    return [(x+c,y),(x+w-c,y),(x+w,y+c),(x+w,y+h-c),(x+w-c,y+h),(x+c,y+h),(x,y+h-c),(x,y+c)]

def draw_new(d,x,y,w,h):
    d.polygon(chamfer(x+4,y+4,w,h,7), fill=(0,0,0,56))
    d.polygon(chamfer(x,y,w,h,7), fill=(15,12,8,248))
    d.line(chamfer(x,y,w,h,7), fill=GOLD, width=2)
    d.line(chamfer(x+2,y+2,w-4,h-4,6), fill=GOLD_DARK, width=1)
    d.line(chamfer(x+3,y+3,w-6,h-6,5), fill=GOLD_DIM, width=1)

def t(d,xy,s,f,c): d.text(xy,s,font=f,fill=c)
def wt(d,s,f): return d.textlength(s,font=f)

def wrap(d,s,f,tw):
    out,cur=[],""
    for ch in s:
        if wt(d,cur+ch,f)>tw and cur: out.append(cur); cur=ch
        else: cur+=ch
    out.append(cur); return out

SHORT=[("title","青蛊铃"),("line","每回合开始：蛊虫 +1（最多 3）。")]
MID=[("title","破绽"),("line","受到伤害 +2，回合结束 -1 层。")]
LONG=[("title","幽冥剑客"),("attr","耐久","24/30"),("attr","攻击","6"),("attr","防御","2"),
      ("attr","抗性","10%"),("attr","攻击次数","1"),
      ("line","意图：连斩 · 造成 6 点伤害并施加 1 层「破绽」。")]

W,H=1720,900
im=Image.new("RGB",(W,H),INK); d=ImageDraw.Draw(im,"RGBA")
for gy in range(0,H,6): d.line([(0,gy),(W,gy)],fill=(255,255,255,4))
t(d,(48,30),"浮窗改版示意 v1（草图，未动项目文件）",f22,MAIN)
t(d,(48,62),"左＝现状：窗宽被 min_w 焊死在 300/240、内外边距 67、软蓝灰圆角框 ｜ 右＝改后：宽撑内容、金线切角框、卡外 10px",f14,SUB)
d.line([(860,92),(860,H-20)],fill=(239,200,81,36),width=1)

def draw_now(x,y,rows):
    pad_l,pad_t,pad_r=22,16,45; minw=300
    w=max(minw,max(wt(d,(r[1] if r[0]!="attr" else r[1]+"   "+r[2]),f20) for r in rows))+pad_l+pad_r
    h=44+26*len(rows)
    d.rounded_rectangle([x+8,y+8,x+8+w,y+8+h],radius=20,fill=(0,0,0,40))
    d.rounded_rectangle([x,y,x+w,y+h],radius=20,fill=(36,50,60),outline=(74,95,109),width=3)
    cy=y+pad_t
    for r in rows:
        if r[0]=="title": t(d,(x+pad_l,cy),r[1],f20,(220,190,120))
        elif r[0]=="line": t(d,(x+pad_l,cy),r[1],f20,(215,210,200))
        else:
            t(d,(x+pad_l,cy),r[1],f20,(200,170,110)); t(d,(x+pad_l+110,cy),r[2],f20,(215,210,200))
        cy+=26
    return w,h

def draw_new_block(x,y,rows,maxw=352):
    pad_l,pad_t,pad_r,pad_b,sep=16,10,16,12,5
    nat=[]
    for r in rows:
        if r[0]=="title": nat.append(wt(d,r[1],f22)+4)
        elif r[0]=="line": nat.append(wt(d,r[1],f20))
        else: nat.append(110+wt(d,r[2],f20))
    tw=min(max(nat),maxw); bw=tw+pad_l+pad_r; bh=0; plan=[]
    for r in rows:
        if r[0]=="title": plan.append((r,30)); bh+=30
        elif r[0]=="attr": plan.append((r,26)); bh+=26
        else:
            ls=wrap(d,r[1],f20,tw); plan.append((r,27*len(ls))); bh+=27*len(ls)
    bh+=sep*(len(plan)-1)+pad_t+pad_b
    draw_new(d,x,y,bw,bh); cy=y+pad_t
    for r,lh in plan:
        if r[0]=="title": t(d,(x+pad_l,cy+2),r[1],f22,GOLD)
        elif r[0]=="attr":
            t(d,(x+pad_l,cy),r[1],f20,GOLD_DIM); t(d,(x+pad_l+110,cy),r[2],f20,CREAM)
        else:
            for i,ls in enumerate(wrap(d,r[1],f20,tw)): t(d,(x+pad_l,cy+i*27),ls,f20,CREAM)
        cy+=lh+sep
    return bw,bh

def card(x,y,w,h,name="幽冥剑客"):
    d.rounded_rectangle([x+5,y+5,x+w+5,y+h+5],radius=6,fill=(0,0,0,45))
    d.rounded_rectangle([x,y,x+w,y+h],radius=6,fill=(52,62,74),outline=(120,104,60),width=2)
    d.rectangle([x+10,y+10,x+w-10,y+h-90],fill=(30,36,44))
    t(d,(x+16,y+h-74),name,f20,(220,205,170))

t(d,(48,96),"现 状",f16,WARM)
w1,h1=draw_now(48,128,SHORT)
t(d,(48+w1+12,134),"%d×%d"%(w1,h1),f13,WARM)
t(d,(48+w1+12,158),"两行字，右边空 100px",f13,WARM)

card(48,280,234,329)
draw_now(48+120,280,LONG)
t(d,(48,630),"① 窗宽与内容无关：短提示也 307 宽（min_w 300 ＋ 内外边距 67）",f14,WARM)
t(d,(48,656),"② 位置只认 host 矩形右边 +10；窗一宽就翻到左边，压住卡本身",f14,WARM)
t(d,(48,682),"③ 边框＝软蓝灰圆角＋8px 投影，跟水墨金线卡面不是一个语言",f14,WARM)

t(d,(900,96),"改 后",f16,COOL)
card(900,176,234,329)
x0=900+234+10
w3,h3=draw_new_block(x0,176,LONG)
d.line([(x0-10,176+h3+14),(x0-2,176+h3+14)],fill=GOLD,width=2)
t(d,(x0-10,176+h3+20),"10px，永远在卡外",f13,COOL)
t(d,(x0,152),"宽 352 顶格换行",f13,COOL)

w4,h4=draw_new_block(900,552,SHORT)
t(d,(900,552+h4+8),"%d 宽（原 307）"%w4,f13,COOL)
w5,h5=draw_new_block(900+w4+24,552,MID)
t(d,(900+w4+24,552+h5+8),"%d 宽"%w5,f13,COOL)

t(d,(48,722),"边框细节 ×2：2px 亮金 → 1px 墨线 → 1px 暗金，切角 7px（非圆角），内边距 16/10，9 宫格 14px",f14,SUB)
zx=48
for lbl,bw,bh,nl in [("单行 176×54",176,54,1),("两行 240×86",240,86,2),("三行 300×118",300,118,3)]:
    sub=Image.new("RGB",(bw*2,bh*2),INK); sd=ImageDraw.Draw(sub,"RGBA")
    draw_new(sd,0,0,bw*2,bh*2)
    for i in range(nl):
        sd.line([(34,40+i*46),(bw*2-34,40+i*46)],fill=(255,246,226,70+i*60),width=8)
    im.paste(sub,(zx,752))
    t(d,(zx,752+bh*2+8),lbl,f13,SUB)
    zx+=bw*2+40

im.save("sandbox/tip_mock_v1.png"); print("ok",im.size)
