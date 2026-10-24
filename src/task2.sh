#!/usr/bin/env bash
# PRTS — 黑白平面开场；参考 1001548290-1-100028.mp4。
# Bash + Python 3 标准库。PRTS_SPEED=200 两倍速；PRTS_NO_ANIM=1 静态。
# Unicode Braille 每格 2×4 子像素；原生终端字体绘制小字。
# 动画约 10.4 秒（含柔和退场），Ctrl+C 跳过。退出恢复屏幕和光标，不改变 shell 配置。
(
    if [[ ! -t 1 || ${TERM:-dumb} == dumb || ${PRTS_NO_ANIM:-0} == 1 ]] || ! command -v python3 >/dev/null 2>&1; then
        printf 'PRTS / SYNTHESIZE INFORMATION / ANALYSIS OS\n'
        exit 0
    fi
    python3 - <<'PY'
import math
import os
import shutil
import signal
import sys
import time

E = '\033['
try:
    SPEED = max(25, min(1000, int(os.environ.get('PRTS_SPEED', '100')))) / 100
except ValueError:
    SPEED = 1
try:
    '⠿─'.encode(sys.stdout.encoding or 'utf-8')
except (UnicodeError, LookupError):
    print('PRTS / ANALYSIS OS')
    sys.exit(0)


def clamp(v):
    return max(0.0, min(1.0, v))


def ease(v):
    v = clamp(v)
    return v*v*(3-2*v)


def gray(v):
    return 232 + round(clamp(v)*23)


# 连续矢量字形，避免放大 5×7 位图造成的方块感。
# 每个字形 6×9，曲线通过多点连续描边。
GLYPHS = {
    'P': [[(0,9),(0,0),(3.7,0),(5,1),(5,3),(3.7,4.5),(0,4.5)]],
    'R': [[(0,9),(0,0),(3.7,0),(5,1),(5,3),(3.7,4.5),(0,4.5)],[(2.5,4.5),(5.5,9)]],
    'T': [[(0,0),(6,0)],[(3,0),(3,9)]],
    'S': [[(5.5,.8),(4.5,0),(1.5,0),(.3,1),(0,2),(.5,3.2),(1.5,4),(4.5,5),(5.5,6),(5.5,7.5),(4.5,9),(1,9),(0,8)]],
}


class Canvas:
    def __init__(self, columns, rows, bg):
        self.cols, self.rows = columns, rows
        self.w, self.h = columns*2, rows*4
        self.bg = bg
        self.pixels = {}
        self.labels = []

    def dot(self, x, y, ink):
        x, y = math.floor(x+.5), math.floor(y+.5)
        if 0 <= x < self.w and 0 <= y < self.h:
            old = self.pixels.get((x,y), self.bg)
            if abs(ink-self.bg) > abs(old-self.bg):
                self.pixels[x,y] = ink

    def line(self, x0, y0, x1, y1, ink, width=.65):
        length = max(1, math.ceil(math.hypot(x1-x0,y1-y0)*2))
        for i in range(length+1):
            t = i/length
            x,y=x0+(x1-x0)*t,y0+(y1-y0)*t
            self.dot(x,y,ink)
            if width > 1:
                for dx,dy in ((-.55,0),(.55,0),(0,-.55),(0,.55)):
                    self.dot(x+dx,y+dy,ink)

    def path(self, points, ink, width=.65):
        for a,b in zip(points,points[1:]):
            self.line(*a,*b,ink,width)

    def word(self, word, cx, y, scale, ink, width=.65):
        x=cx-(len(word)*8-2)*scale/2
        for ch in word:
            for path in GLYPHS[ch]:
                self.path([(x+a*scale,y+b*scale) for a,b in path],ink,width)
            x += 8*scale

    def text(self, cx, row, text, ink, style=0):
        x=round(cx/2-len(text)/2)
        row=int(row)
        if x < 0:
            text,x=text[-x:],0
        text=text[:max(0,self.cols-x)]
        if text and 0<=row<self.rows:
            self.labels.append((x,row,text,ink,style))

    def raster(self):
        # 每个格子的点阵掩码与亮度。空白保持真正的空格，避免背景噪点。
        bits=((1,8),(2,16),(4,32),(64,128))
        cells={}
        for (x,y),ink in self.pixels.items():
            key=(x//2,y//4)
            mask,old=cells.get(key,(0,self.bg))
            cells[key]=(mask|bits[y%4][x%2],ink if abs(ink-self.bg)>abs(old-self.bg) else old)
        grid=[[(' ',self.bg,0) for _ in range(self.cols)] for _ in range(self.rows)]
        for (x,y),(mask,ink) in cells.items():
            grid[y][x]=(chr(0x2800+mask),ink,0)
        for x,y,text,ink,style in self.labels:
            for i,ch in enumerate(text):
                grid[y][x+i]=(ch,ink,style)
        return grid


class Renderer:
    def __init__(self):
        self.previous=None
        self.shape=None
        self.bg=None

    def draw(self,c):
        grid=c.raster()
        out=[]
        shape=(c.cols,c.rows)
        if self.shape!=shape:
            out.append(f'{E}0;48;5;{c.bg}m{E}2J')
            self.previous=None
        elif self.bg!=c.bg:
            self.previous=None
        for y,row in enumerate(grid):
            if self.previous is not None and row==self.previous[y]:
                continue
            out.append(f'{E}{y+1};1H')
            last=None
            for ch,ink,style in row:
                if (ink,style)!=last:
                    out.append(f'{E}0;{style};38;5;{ink};48;5;{c.bg}m')
                    last=(ink,style)
                out.append(ch)
        sys.stdout.write(''.join(out))
        sys.stdout.flush()
        self.previous,self.shape,self.bg=grid,shape,c.bg


def mix(a,b,t):
    return a+(b-a)*t


def window(t,start,end,fade=.35):
    return ease((t-start)/fade)*(1-ease((t-end)/fade))


def arc(c,cx,cy,r,start,end,ink):
    count=max(2,int(abs(end-start)*r*1.4))
    c.path([(cx+r*math.cos(mix(start,end,i/count)),
             cy+r*math.sin(mix(start,end,i/count))) for i in range(count+1)],ink)


def corners(c,cx,cy,w,h,length,ink):
    for dx in (-1,1):
        for dy in (-1,1):
            x,y=cx+dx*w,cy+dy*h
            c.path([(x-dx*length,y),(x,y),(x,y-dy*length)],ink)


def scrambled(text,progress):
    # 字符只在锁定前短暂跳动；不读取输入，也不生成随机状态。
    n=int(clamp(progress)*len(text))
    noise='01:/_.'
    return ''.join(ch if i<n or ch==' ' else noise[(i+int(progress*40))%len(noise)]
                   for i,ch in enumerate(text))


def fast_out(v):
    v=clamp(v)
    return 1-(1-v)**4


def spring(v):
    # 阻尼回弹：位置可短暂超过终点；透明度仍用夹紧后的 ease。
    v=clamp(v)
    if v in (0,1):
        return v
    value=1-math.exp(-6*v)*(math.cos(10*v)+.6*math.sin(10*v))
    # 尾部平滑归一，避免归位瞬间跳动。
    return mix(value,1,ease((v-.72)/.28))


def bezier(a,b,c,d,v):
    u=1-v
    return (u*u*u*a[0]+3*u*u*v*b[0]+3*u*v*v*c[0]+v*v*v*d[0],
            u*u*u*a[1]+3*u*u*v*b[1]+3*u*v*v*c[1]+v*v*v*d[1])


def comet(c,cx,cy,r,a,length,ink):
    for i in range(6):
        start=a-length*(i+1)/6
        arc(c,cx,cy,r,start,start+length/6,gray(ink*(1-i/7)))


def relay(c,cx,cy,r,t,opacity):
    # 侧边路由线逐段生长，亮点沿折线传递；小窗口只保留核心标识。
    if c.cols<74 or opacity<=0:
        return
    for side in (-1,1):
        for lane in (-1,1):
            yy=cy+lane*r*.45
            points=[(cx+side*r*1.48,yy),
                    (cx+side*r*1.8,yy),
                    (cx+side*r*2.04,yy+lane*4),
                    (cx+side*min(r*2.55,c.w*.43),yy+lane*4)]
            grow=fast_out((t-1.5-(lane+1)*.10)/.55)
            for j in range(3):
                progress=clamp(grow*3-j)
                a,b=points[j],points[j+1]
                c.line(*a,mix(a[0],b[0],progress),mix(a[1],b[1],progress),gray(.22*opacity))
            phase=((t*1.3+lane*.23)%1)*3
            j=min(2,int(phase));a,b=points[j],points[j+1]
            if grow>.98:
                x,y=mix(a[0],b[0],phase-j),mix(a[1],b[1],phase-j)
                c.line(x-1,y,x+1,y,gray(.8*opacity))


def frame(t,cols,rows):
    # 更紧凑的时间线：0–4.85 黑场，4.85–5.4 转场，5.2–8.9 白场。
    light=ease((t-4.85)/.55)
    c=Canvas(cols,rows,gray(light))
    cx,cy=c.w/2,c.h*.44
    r=min(23,c.w*.17,c.h*.22)
    if t<4.85:
        fade=1-ease((t-4.45)/.4)
        calibration=window(t,0,.85,.2)*fade
        if calibration>0:
            position=spring(t/.85)
            spread=mix(1.65,1.04,position)
            corners(c,cx,cy,r*spread,r*.85*spread,4,gray(.6*calibration))
            yy=cy-r+2*r*fast_out((t-.05)/.7)
            c.line(cx-r*.9,yy,cx+r*.9,yy,gray(.55*calibration))
            c.line(cx-3,cy,cx+3,cy,gray(.5*calibration))
            c.line(cx,cy-3,cx,cy+3,gray(.5*calibration))

        # 短弧线粒子先奔向中心，继而消失，为标识入场引导视线。
        particles=window(t,.06,.85,.15)*fade
        if particles>0:
            for k in range(10):
                a=k*math.tau/10+.3
                v=fast_out((t-.04-k*.018)/.9)
                origin=(cx+math.cos(a)*r*1.7,cy+math.sin(a)*r*1.7)
                tangent=(cx+math.cos(a+.7)*r*1.5,cy+math.sin(a+.7)*r*1.5)
                near=(cx+math.cos(a-.3)*r*.6,cy+math.sin(a-.3)*r*.6)
                end=(cx+math.cos(a)*r*.4,cy+math.sin(a)*r*.4)
                p=bezier(origin,tangent,near,end,v)
                q=bezier(origin,tangent,near,end,max(0,v-.05))
                c.line(*q,*p,gray(.65*particles))

        # 碎片错峰抵达，沿法线轻微越过目标后回弹；不做整屏抖动。
        turn=spring((t-2.55)/.9)
        angle=(1-fast_out((t-.5)/1.1))*.45+math.pi/2*turn
        radius=r*(1+.035*math.sin((t-2.55)*10)*window(t,2.55,3.4,.15))
        if t>.3:
            vertices=[(cx+radius*math.cos(angle+i*math.pi/2),
                       cy+radius*math.sin(angle+i*math.pi/2)) for i in range(5)]
            for side in range(4):
                a,b=vertices[side],vertices[side+1]
                for part in range(4):
                    v=(t-.30-side*.045-part*.04)/.95
                    if v<=0:
                        continue
                    position=spring(v)
                    theta=(side+.5)*math.pi/2+angle
                    offset=(1-position)*r*(.55+part*.1)
                    tangent=math.sin(math.pi*clamp(v))*(1-clamp(v))*r*.14
                    dx=math.cos(theta)*offset-math.sin(theta)*tangent
                    dy=math.sin(theta)*offset+math.cos(theta)*tangent
                    gap=.12*(1-ease(v))
                    p,q=(part+gap)/4,(part+1-gap)/4
                    x0,y0=mix(a[0],b[0],p)+dx,mix(a[1],b[1],p)+dy
                    x1,y1=mix(a[0],b[0],q)+dx,mix(a[1],b[1],q)+dy
                    ink=gray(fade*(.45+.55*ease(v)))
                    if v<.75:
                        c.line(x0+dx*.18,y0+dy*.18,x1+dx*.18,y1+dy*.18,gray(.18*fade))
                    c.line(x0,y0,x1,y1,ink)

        sync=window(t,1.15,3.75,.3)*fade
        if sync>0:
            contraction=spring((t-3.3)/.8)
            breathing=1+.018*math.sin(t*5)
            for ring,direction in ((1.26,1),(1.43,-1)):
                rr=r*mix(ring,1.08,contraction)*breathing
                # 转动速度先快后慢，中段轻加速，避免匀速机械感。
                phase=direction*(.35*t+.8*fast_out((t-1.15)/1.4)+.4*ease((t-2.7)/.7))
                for k in range(4):
                    a=k*math.pi/2+phase
                    arc(c,cx,cy,rr,a,a+.45,gray(.36*sync))
            for k in range(32):
                a=k*math.tau/32
                outer=r*1.28
                length=2.1 if k%4==0 else .7
                c.line(cx+outer*math.cos(a),cy+outer*math.sin(a),
                       cx+(outer+length)*math.cos(a),cy+(outer+length)*math.sin(a),gray(.22*sync))
            comet(c,cx,cy,r*1.27,-t*1.9-.4*math.sin(t*1.5),.7,.88*sync)
            relay(c,cx,cy,r,t,sync)

        ghost=ease((t-1.65)/.45)*fade
        if ghost>0:
            shift=6*(1-spring((t-1.65)/.75))
            c.word('PR',cx,cy-r*.96-shift,r/15,gray(.32*ghost))
            c.word('TS',cx,cy+r*.14+shift,r/15,gray(.32*ghost))
        if t>1.15:
            ink=gray(fade*ease((t-1.15)/.3))
            row=int(cy/4)
            c.text(cx,row-1,scrambled('RHODES',(t-1.15)/.45),ink,3)
            c.text(cx,row,scrambled('ISLAND',(t-1.30)/.45),ink,3)

        # 环形收拢触发双重锁定波纹，完成动作后顺势进入转场。
        for delay in (0,.13):
            v=(t-3.6-delay)/.72
            if 0<v<1:
                expand=fast_out(v)
                rr=r*(1.03+.5*expand)
                c.path([(cx+rr*math.cos(i*math.pi/2),
                         cy+rr*math.sin(i*math.pi/2)) for i in range(5)],gray(.55*(1-ease(v))*fade))
        if t>3.75:
            dock=window(t,3.75,4.2,.15)*fade
            corners(c,cx,cy,r*1.15,r*1.15,3,gray(.65*dock))
        # 中央短线向两侧展开，承接下一个白色画面的字标横线。
        if t>4.2:
            half=r*fast_out((t-4.2)/.55)
            c.line(cx-half,cy,cx+half,cy,gray(.4*window(t,4.2,4.6,.15)))
        if t<1.25:
            status='01 / SIGNAL ACQUISITION'
        elif t<2.6:
            status='02 / NEURAL SYNCHRONIZATION'
        elif t<3.75:
            status='03 / IDENTITY RESOLUTION'
        else:
            status='04 / CONNECTION ESTABLISHED'
        c.text(cx,rows-4,status,gray(.43*fade))
        # 分段非线性进度：快速接入、短暂核验、快速完成。
        progress=.5*fast_out(t/1.5)+.3*ease((t-1.5)/1.6)+.2*fast_out((t-3.3)/.7)
        for k in range(25):
            x=cx-24+k*2
            c.line(x,c.h-8,x+.7,c.h-8,gray((.65 if k/24<=progress else .16)*fade))
        c.text(cx,rows-1,'P.R.T.S.  /  RHODES ISLAND',gray(.22*fade))
        return c

    top=int(cy/4-4)*4
    scale=min(1.7,max(1.4,cols/70))
    half=15*scale
    reveal=fast_out((t-5.05)/.9)
    ink=gray(mix(1,.06,ease((t-5.05)/.4)))
    # 字母沿弧线抵达，间距和高度轻微过冲再归位；亮度单独渐入。
    for i,ch in enumerate('PRTS'):
        v=(t-5.1-i*.09)/.85
        if v<=0:
            continue
        settle=spring(v)
        x=cx-half+i*8*scale+3*scale+(i-1.5)*4*(1-settle)
        y=top+(1-settle)*(7 if i%2==0 else -7)
        y+=math.sin(clamp(v)*math.pi)*(1-clamp(v))*2
        c.word(ch,x,y,scale,gray(mix(1,.06,ease(v))),1.5 if v>.8 else .65)
    c.line(cx-half,top-4,cx-half+2*half*reveal,top-4,ink)
    bottom=top+9*scale
    row=math.ceil((bottom+2)/4)
    if t>5.9:
        opacity=ease((t-5.9)/.4)
        c.text(cx,row,scrambled('SYNTHESIZE INFORMATION',(t-5.9)/.45),gray(mix(1,.12,opacity)))
    if t>6.15:
        c.text(cx,row+1,'ANALYSIS OS',gray(mix(1,.06,ease((t-6.15)/.35))),1)
    c.line(cx+half,(row+2)*4,cx+half-2*half*reveal,(row+2)*4,ink)
    # 扫描和角标联动，完成后向外松开；始终为字标保留阅读空间。
    scan=window(t,6.4,7.25,.2)
    if scan>0:
        x=mix(cx-half-3,cx+half+3,ease((t-6.4)/.9))
        c.line(x,top-7,x,(row+2)*4+3,gray(1-.3*scan))
        expand=3*(1-spring((t-6.4)/.7))
        corners(c,cx,(top+(row+2)*4)/2,half+6+expand,((row+2)*4-top)/2+7+expand,3,gray(1-.35*scan))
    message='P L E A S E  L O G I N'
    n=min(len(message),max(0,int((t-7.0)*24)))
    if n:
        display=message[:n]
        if n<len(message):
            display+='_' if int(t*8)%2 else ' '
        c.text(cx,row+4,display.ljust(len(message)),gray(.32))
    if t>8.05:
        opacity=ease((t-8.05)/.4)
        c.text(cx,rows-2,'TERMINAL SERVICE  /  STANDBY',gray(1-.46*opacity))
    return c


def outro(c,t):
    # 先消隐字标，再降低整个画面的亮度；留短暂黑场后恢复命令行。
    # 同时作用于窄窗口降级画面，窗口缩放不会打断退场。
    hide=ease((t-8.95)/.35)
    dim=ease((t-9.15)/1.05)
    if hide<=0:
        return c
    background=c.bg
    def tint(ink):
        ink=mix(ink,background,hide)
        return 232+round((ink-232)*(1-dim))
    c.bg=232+round((background-232)*(1-dim))
    if hide>=1:
        c.pixels.clear()
        c.labels.clear()
    else:
        c.pixels={point:tint(ink) for point,ink in c.pixels.items()}
        c.labels=[(x,y,text,tint(ink),style) for x,y,text,ink,style in c.labels]
    return c


def stop(_signum,_frame):
    raise KeyboardInterrupt


signal.signal(signal.SIGTERM,stop)
signal.signal(signal.SIGHUP,stop)
renderer=Renderer()
try:
    sys.stdout.write(f'{E}?1049h{E}?25l')
    sys.stdout.flush()
    start=time.monotonic()
    while True:
        tick=time.monotonic()
        t=(tick-start)*SPEED
        if t>=10.4:
            break
        size=shutil.get_terminal_size((80,24))
        cols,rows=max(1,size.columns-1),max(1,size.lines-1)
        if cols<46 or rows<18:
            # 缩小窗口时保持整洁；恢复窗口大小即可继续播放。
            c=Canvas(cols,rows,232)
            c.text(c.w/2,rows//2,'PRTS / ANALYSIS OS',250)
        else:
            c=frame(t,cols,rows)
        renderer.draw(outro(c,t))
        time.sleep(max(0,1/36-(time.monotonic()-tick)))
except KeyboardInterrupt:
    pass
finally:
    sys.stdout.write(f'{E}0m{E}?25h{E}?1049l')
    sys.stdout.flush()
PY
)
