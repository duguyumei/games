#!/usr/bin/env python3
"""Generate a monochrome wind-spade icon and compose it onto a card template.

The script intentionally keeps the card background and program-rendered number in
the template. It is dependency-free so the same geometry can be reused for a
complete suit/card set.
"""
import argparse, struct, zlib, binascii, math, os

parser = argparse.ArgumentParser()
parser.add_argument('--icon-source', default='/Users/cc/.codex/worktrees/8df1/taiwu/godot/assets/card_concepts/wind-suit-icon-final-v1.png')
parser.add_argument('--card-source', default='/Users/cc/.codex/worktrees/8df1/taiwu/godot/assets/card_concepts/wind-7-prototype-v4.png')
parser.add_argument('--out-dir', default='/Users/cc/Documents/taiwu/godot/assets/card_concepts')
parser.add_argument('--card-name', default='wind-7-final-composite-v1')
parser.add_argument('--corner-size', type=int, default=70)
args = parser.parse_args()
ROOT = args.out_dir
ICON_SRC = args.icon_source
CARD_SRC = args.card_source
os.makedirs(ROOT, exist_ok=True)

def png_read(path):
    data = open(path, 'rb').read()
    assert data[:8] == b'\x89PNG\r\n\x1a\n'
    pos, idat, width, height, ctype = 8, b'', 0, 0, None
    while pos < len(data):
        n = struct.unpack('>I', data[pos:pos+4])[0]; typ = data[pos+4:pos+8]; chunk = data[pos+8:pos+8+n]; pos += 12+n
        if typ == b'IHDR': width, height, depth, ctype, _, _, interlace = struct.unpack('>IIBBBBB', chunk); assert depth == 8 and interlace == 0
        elif typ == b'IDAT': idat += chunk
        elif typ == b'IEND': break
    channels = {2:3, 6:4}[ctype]; raw = zlib.decompress(idat); stride = width*channels; rows=[]; p=0; prev=bytearray(stride)
    for _ in range(height):
        f=raw[p]; p+=1; cur=bytearray(raw[p:p+stride]); p+=stride
        for i in range(stride):
            a=cur[i-channels] if i>=channels else 0; b=prev[i]; c=prev[i-channels] if i>=channels else 0
            if f==1: cur[i]=(cur[i]+a)&255
            elif f==2: cur[i]=(cur[i]+b)&255
            elif f==3: cur[i]=(cur[i]+((a+b)//2))&255
            elif f==4:
                q=a+b-c; pa=abs(q-a); pb=abs(q-b); pc=abs(q-c); pr=a if pa<=pb and pa<=pc else (b if pb<=pc else c); cur[i]=(cur[i]+pr)&255
        row=[]
        for x in range(width):
            i=x*channels; row.extend(cur[i:i+3]); row.append(cur[i+3] if channels==4 else 255)
        rows.append(row); prev=cur
    return width,height,rows

def png_write(path,w,h,rows):
    raw=b''.join(b'\0'+bytes(row) for row in rows)
    def chunk(t,d): return struct.pack('>I',len(d))+t+d+struct.pack('>I',binascii.crc32(t+d)&0xffffffff)
    out=b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',w,h,8,6,0,0,0))+chunk(b'IDAT',zlib.compress(raw,9))+chunk(b'IEND',b'')
    open(path,'wb').write(out)

def blank(w,h): return [[0,0,0,0]*(w) for _ in range(h)]
def blend(dst, x, y, color):
    if not (0<=x<len(dst[0])//4 and 0<=y<len(dst)): return
    i=x*4; sa=color[3]/255.0; da=dst[y][i+3]/255.0; oa=sa+da*(1-sa)
    if oa<=0: return
    for k in range(3): dst[y][i+k]=int((color[k]*sa+dst[y][i+k]*da*(1-sa))/oa+0.5)
    dst[y][i+3]=int(oa*255+0.5)

def resize_rgba(src, sw, sh, dw, dh):
    out=blank(dw,dh)
    for y in range(dh):
        sy=(y+0.5)*sh/dh-0.5; y0=max(0,min(sh-1,int(math.floor(sy)))); y1=min(sh-1,y0+1); fy=sy-y0
        for x in range(dw):
            sx=(x+0.5)*sw/dw-0.5; x0=max(0,min(sw-1,int(math.floor(sx)))); x1=min(sw-1,x0+1); fx=sx-x0
            vals=[]
            for c in range(4):
                a=src[y0][x0*4+c]*(1-fx)+src[y0][x1*4+c]*fx; b=src[y1][x0*4+c]*(1-fx)+src[y1][x1*4+c]*fx; vals.append(int(a*(1-fy)+b*fy+0.5))
            out[y][x*4:x*4+4]=vals
    return out

def cubic(a,b,c,d,t):
    u=1-t; return (u*u*u*a[0]+3*u*u*t*b[0]+3*u*t*t*c[0]+t*t*t*d[0], u*u*u*a[1]+3*u*u*t*b[1]+3*u*t*t*c[1]+t*t*t*d[1])

def stroke(canvas, points, width, alpha):
    prev=None
    steps=180
    for j in range(steps+1):
        t=j/steps; p=cubic(*points,t)
        if prev:
            dx=p[0]-prev[0]; dy=p[1]-prev[1]; dist=max(1,int(math.hypot(dx,dy))); r=width/2
            for q in range(dist+1):
                x=prev[0]+dx*q/dist; y=prev[1]+dy*q/dist
                xmin=max(0,int(x-r-1)); xmax=min(len(canvas[0])//4-1,int(x+r+1)); ymin=max(0,int(y-r-1)); ymax=min(len(canvas)-1,int(y+r+1))
                for yy in range(ymin,ymax+1):
                    for xx in range(xmin,xmax+1):
                        dd=math.hypot(xx-x,yy-y); aa=max(0,min(255,int(alpha*(1-dd/r)))) if r else 0
                        if aa: blend(canvas,xx,yy,(24,27,25,aa))
        prev=p

iw,ih,ir=png_read(ICON_SRC)
mask=blank(iw,ih); minx,miny, maxx,maxy=iw,ih,0,0
for y in range(ih):
    for x in range(iw):
        i=x*4; lum=(ir[y][i]*299+ir[y][i+1]*587+ir[y][i+2]*114)//1000; a=max(0,min(255,(178-lum)*5))
        if a>5:
            mask[y][i:i+4]=[24,27,25,a]; minx=min(minx,x); miny=min(miny,y); maxx=max(maxx,x); maxy=max(maxy,y)
trim=[row[minx*4:(maxx+1)*4] for row in mask[miny:maxy+1]]; tw,th=maxx-minx+1,maxy-miny+1
icon=blank(1024,1024); resized=resize_rgba(trim,tw,th,640,790)
for y,row in enumerate(resized):
    for x in range(640):
        if row[x*4+3]: blend(icon,94+x,95+y,row[x*4:x*4+4])
stroke(icon,[(635,503),(735,462),(892,383),(974,354)],29,235)
stroke(icon,[(735,462),(850,424),(944,360),(1000,334)],7,190)
stroke(icon,[(760,480),(850,452),(942,400),(986,375)],4,160)
icon_path = ROOT+'/wind-suit-icon-final-v2.png'
png_write(icon_path,1024,1024,icon)

cw,ch,cr=png_read(CARD_SRC); card=cr
def copy_patch(src, sx, sy, w, h, dx, dy):
    for yy in range(h):
        for xx in range(w):
            if 0 <= sy+yy < len(src) and 0 <= sx+xx < len(src[0])//4 and 0 <= dy+yy < len(card) and 0 <= dx+xx < len(card[0])//4:
                si=(sy+yy)*(len(src[0]))+(sx+xx)*4; di=(dy+yy)*len(card[0])+ (dx+xx)*4
                card[dy+yy][(dx+xx)*4:(dx+xx)*4+4]=src[sy+yy][(sx+xx)*4:(sx+xx)*4+4]

def overlay(src,sw,sh,x,y,w,h,rotate=False):
    scaled=resize_rgba(src,sw,sh,w,h)
    for yy in range(h):
        for xx in range(w):
            sx=w-1-xx if rotate else xx; sy=h-1-yy if rotate else yy; px=scaled[sy][sx*4:sx*4+4]
            if px[3]: blend(card,x+xx,y+yy,px)
# Clear the prototype's old wind glyphs with nearby parchment texture before placing the final mark.
corner = args.corner_size
copy_patch(cr, 185, 212, 122, 124, 44, 211)
copy_patch(cr, 600, 1184, 128, 136, 852, 1184)
overlay(icon,1024,1024,53,231,corner,corner,False)
overlay(icon,1024,1024,901,1225,corner,corner,True)
card_path = ROOT+'/'+args.card_name+'.png'
png_write(card_path,cw,ch,card)
print(icon_path)
print(card_path)
