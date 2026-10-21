"""Original, deterministic SVG kit for the three-node art study. No reference pixels.

Run from any directory with Python's standard library. Assets remain independent
of level numbers, UI text, reward logic and scroll positions.
"""
from pathlib import Path
import math
import random

OUT = Path(__file__).resolve().parents[1] / "assets/campaign/map_art"
DEFS = '''<defs>
<linearGradient id="sky" x2="0" y2="1"><stop stop-color="#06355d"/><stop offset=".4" stop-color="#087db0"/><stop offset="1" stop-color="#f16f26"/></linearGradient>
<radialGradient id="blue"><stop stop-color="#31b3e8" stop-opacity=".65"/><stop offset="1" stop-color="#0483bf" stop-opacity="0"/></radialGradient>
<radialGradient id="heat"><stop stop-color="#ffed77" stop-opacity=".85"/><stop offset=".35" stop-color="#ff9b23" stop-opacity=".65"/><stop offset="1" stop-color="#ff5a19" stop-opacity="0"/></radialGradient>
<linearGradient id="wall" x2=".2" y2="1"><stop stop-color="#385a78"/><stop offset=".5" stop-color="#273749"/><stop offset="1" stop-color="#582d31"/></linearGradient>
<linearGradient id="rock" x2=".7" y2="1"><stop stop-color="#37495b"/><stop offset=".4" stop-color="#1e2b3d"/><stop offset="1" stop-color="#622724"/></linearGradient>
<linearGradient id="stone" x2="0" y2="1"><stop stop-color="#eed6b2"/><stop offset=".35" stop-color="#bca78c"/><stop offset="1" stop-color="#695e57"/></linearGradient>
<linearGradient id="steel" x2=".8" y2="1"><stop stop-color="#faf8df"/><stop offset=".22" stop-color="#b3c3ce"/><stop offset=".5" stop-color="#586e80"/><stop offset=".75" stop-color="#293c50"/><stop offset="1" stop-color="#abc0c6"/></linearGradient>
<linearGradient id="iron" x2="1" y2="1"><stop stop-color="#5c798b"/><stop offset=".3" stop-color="#263747"/><stop offset="1" stop-color="#0c1423"/></linearGradient>
<linearGradient id="wood" x2="0" y2="1"><stop stop-color="#f7b34e"/><stop offset=".3" stop-color="#b87128"/><stop offset=".7" stop-color="#8b4218"/><stop offset="1" stop-color="#d58b36"/></linearGradient>
<linearGradient id="gold" x2=".25" y2="1"><stop stop-color="#fff6a3"/><stop offset=".3" stop-color="#ffe141"/><stop offset=".55" stop-color="#f8a814"/><stop offset="1" stop-color="#a9480b"/></linearGradient>
<linearGradient id="flame" x2="0" y2="1"><stop stop-color="#ff6b13"/><stop offset=".5" stop-color="#ffc536"/><stop offset="1" stop-color="#fff7a0"/></linearGradient>
<linearGradient id="lava" x2="0" y2="1"><stop stop-color="#ffec60"/><stop offset=".35" stop-color="#ffb31f"/><stop offset="1" stop-color="#ef4715"/></linearGradient>
<linearGradient id="cloth" x2="1" y2=".4"><stop stop-color="#3d0c20"/><stop offset=".4" stop-color="#ac2634"/><stop offset=".65" stop-color="#671427"/><stop offset="1" stop-color="#c93b3b"/></linearGradient>
<linearGradient id="green" x2=".15" y2="1"><stop stop-color="#c7f34b"/><stop offset=".5" stop-color="#7fba12"/><stop offset="1" stop-color="#3b710b"/></linearGradient>
<linearGradient id="orange" x2="0" y2="1"><stop stop-color="#fff891"/><stop offset=".2" stop-color="#ffd83b"/><stop offset=".55" stop-color="#ff9b0c"/><stop offset="1" stop-color="#c54a08"/></linearGradient>
<linearGradient id="red" x2="0" y2="1"><stop stop-color="#f58328"/><stop offset=".2" stop-color="#dc3c17"/><stop offset=".65" stop-color="#971c17"/><stop offset="1" stop-color="#4e1420"/></linearGradient>
<linearGradient id="inset" x2=".8" y2="1"><stop stop-color="#283b4d"/><stop offset="1" stop-color="#090f1a"/></linearGradient>
<linearGradient id="chest" x2=".1" y2="1"><stop stop-color="LIGHT"/><stop offset=".4" stop-color="BASE"/><stop offset="1" stop-color="DARK"/></linearGradient>
</defs>'''

def svg(name, w, h, body, colours=("#d68743", "#9a491f", "#502719")):
    defs = DEFS.replace("LIGHT", colours[0]).replace("BASE", colours[1]).replace("DARK", colours[2])
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / f"{name}.svg").write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">{defs}{body}</svg>\n', encoding="utf-8")

def path(d, fill, stroke=None, width=2, extra=""):
    return f'<path d="{d}" fill="{fill}"'+(f' stroke="{stroke}" stroke-width="{width}" stroke-linejoin="round"' if stroke else "")+f' {extra}/>'

def rect(x,y,w,h,fill,stroke=None,r=0):
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" fill="{fill}"'+(f' stroke="{stroke}" stroke-width="2"' if stroke else "")+'/>'

def ellipse(x,y,rx,ry,fill):
    return f'<ellipse cx="{x}" cy="{y}" rx="{rx}" ry="{ry}" fill="{fill}"/>'

def bolt(x,y,r=4):
    return ellipse(x+1,y+2,r+1,r+1,"#101725")+ellipse(x,y,r,r,"url(#steel)")+path(f'M{x-r/2} {y-r/2}l{r} {r}',"none","#6c7b85",1)

def banner(x,y,scale=1):
    return f'<g transform="translate({x} {y}) scale({scale})">'+path('M0 0L65 4L60 135L42 122L25 153L17 130L-3 145Z','url(#cloth)','#331927',3)+path('M10 4L9 115M53 8L49 113','none','#df5a46',1)+ellipse(30,53,21,24,'none').replace('fill="none"','fill="none" stroke="#c35e58" stroke-width="4"')+path('M17 47L27 53L24 60L18 57ZM43 47L33 53L36 60L42 57Z','#d17a64')+'</g>'

def torch(x,y,scale=1):
    return f'<g transform="translate({x} {y}) scale({scale})">'+ellipse(0,-12,65,65,'url(#heat)')+path('M-12 2L-9 42L9 42L12 2Z','url(#rock)','#101723',2)+rect(-17,-1,34,8,'url(#steel)','#1b2430')+path('M-14-4C-25-25-6-32-9-54C4-38 1-29 7-34C15-45 15-42 15-33C31-10 12-4-14-4Z','url(#flame)','#ff9d28',1)+path('M-6-6C-14-20 1-23 0-36C15-20 8-9 7-6Z','#fff1a0')+'</g>'

def scenery():
    rng=random.Random(77)
    b=rect(0,0,1280,600,'url(#sky)')+ellipse(640,105,600,320,'url(#blue)')
    # Cold skyline, three staggered distances, and clouds above the arena.
    for depth in range(3):
        for x in range(-40,1330,56):
            y=45+depth*23+rng.randrange(40)
            b+=path(f'M{x} 180V{y+20}l10-3V{y}l10 14h20v166Z',['#07517b','#0b4970','#123d61'][depth],extra=f'opacity="{.3+depth*.17}"')
    for x in [-80,120,400,730,1030,1320]: b+=ellipse(x,40,180,80,'url(#blue)')
    # Distant coliseum arcade, regular joints and masonry highlight.
    b+=path('M0 122Q640 198 1280 122V345H0Z','url(#wall)','#172b43',4)
    for y in [132,149,230,248,277,300]:
        b+=path(f'M0 {y}Q640 {y+72} 1280 {y}','none','#45718c' if y in [132,248] else '#172f47',2)
    for x in range(0,1281,80):
        curve=37*math.sin(math.pi*x/1280)
        y=155+curve
        b+=path(f'M{x+9} {y+65}V{y+20}Q{x+32} {y-9} {x+56} {y+20}V{y+65}Z','#092b44','#5b6b7b',5)
        b+=path(f'M{x+13} {y+64}V{y+22}Q{x+32} {y+1} {x+51} {y+22}','none','#1c5277',5)
        for seam in [0,12,25,39,53]: b+=path(f'M{x+3} {y+seam}h10M{x+57} {y+seam}h12','none','#1a3145',1)
    for x in range(0,1280,24):
        y=257+8*math.sin(x/180)
        b+=ellipse(x,y,3,4,'#172c3d')+path(f'M{x-5} {y+13}Q{x-4} {y+1} {x} {y+3}Q{x+5} {y+2} {x+6} {y+13}Z','#183348')
        if x%72==0: b+=ellipse(x,y+1,1.5,2,'#b28b6c')
    # Front tier arches, brick texture and battlements; wrap exactly at the edges.
    b+=path('M0 297Q640 365 1280 297V440H0Z','url(#wall)','#172538',5)
    for x in range(-80,1280,160):
        y=310+24*math.sin(math.pi*(x+80)/1280)
        b+=ellipse(x+80,y+98,95,100,'url(#heat)')
        b+=path(f'M{x+18} {y+123}V{y+60}Q{x+80} {y-15} {x+142} {y+60}V{y+123}Z','#71332b','#172133',7)
        b+=path(f'M{x+30} {y+123}V{y+63}Q{x+80} {y+5} {x+130} {y+63}V{y+123}Z','url(#inset)','#c57242',3)
        b+=path(f'M{x+47} {y+123}V{y+79}Q{x+80} {y+26} {x+113} {y+79}V{y+123}Z','url(#red)')
        b+=path(f'M{x+72} {y+123}l6-45 7-11 7 56Z','url(#lava)')
        for k in range(9):
            theta=math.pi+k*math.pi/8
            px=x+80+63*math.cos(theta); py=y+65+61*math.sin(theta)
            b+=path(f'M{px:.1f} {py:.1f}l{12*math.cos(theta):.1f} {12*math.sin(theta):.1f}','none','#172538',2)
        b+=rect(x+2,y-9,16,110,'url(#rock)','#1d3044')
    for y in range(320,440,20):
        for x in range((y%40)*2,1280,60): b+=path(f'M{x} {y}l51 3m-26 0v14','none','#0e2236',1,extra='opacity=".35"')
    for x in range(0,1280,32):
        y=289+27*math.sin(math.pi*x/1280)
        b+=path(f'M{x} {y}v-13l11-2v14l15 2v-16l6 1v18Z','url(#rock)','#172c40',1)
    for x,y,sz in [(88,112,.8),(389,165,.58),(892,141,.7),(1154,116,.9),(243,299,.6),(1020,315,.55)]: b+=banner(x,y,sz)
    # Chained lava idol assembled from separate faceted stone polygons.
    b+='<g transform="translate(610 115)">'
    for side in [-1,1]:
        for k in range(8):
            cx=side*(44+k*17); cy=18-k*4+math.sin(k/3)*12
            b+=f'<ellipse cx="{cx}" cy="{cy}" rx="7" ry="11" transform="rotate({side*35} {cx} {cy})" fill="none" stroke="#112438" stroke-width="6"/><ellipse cx="{cx}" cy="{cy-1}" rx="6" ry="10" fill="none" stroke="#46647c" stroke-width="2"/>'
    b+=ellipse(0,110,180,170,'url(#heat)')
    b+=path('M-65 5L-96-44L-66-35L-36-5L0-19L36-5L66-35L96-44L65 5L69 63L43 87L-43 87L-69 63Z','url(#rock)','#10283e',5)
    for d,c in [('M-65 5L-36-5L-8 28L-49 17Z','#405871'),('M65 5L36-5L8 28L49 17Z','#384d68'),('M-49 17L-8 28L0 56L-36 50Z','#1d3045'),('M49 17L8 28L0 56L36 50Z','#26384e'),('M-66-35L-36-5L-59-8Z','#576a7d')]: b+=path(d,c)
    b+=path('M-53 25L-15 42L-41 43ZM53 25L15 42L41 43Z','#ff8b22','#ffb935',2)
    b+=path('M-39 62Q0 51 39 62L29 79H-29Z','#fbc354','#922d19',2)
    b+=path('M-22 76C-30 140-13 205-23 276H26C16 201 30 145 22 76Z','url(#lava)')
    for x in [-14,-4,6,16]: b+=path(f'M{x} 80Q{x+10} 170 {x-3} 273','none','#fff3a0',2)
    b+='</g>'
    for x,y in [(20,291),(317,313),(975,313),(1255,291)]: b+=torch(x,y,.65)
    # Lava surface at bottom: multiple luminous flowing contours.
    b+=path('M0 418Q640 460 1280 418V600H0Z','url(#lava)')
    for i in range(32):
        x=rng.randrange(-100,1280); y=rng.randrange(445,600)
        b+=path(f'M{x} {y}q50-20 105-3t160 4q-42 19-95 11t-135-3','none',rng.choice(['#ffe77b','#ffce43','#ec6515']),rng.choice([1,2,3]))
    svg('coliseum',1280,600,b)
    # Foreground silhouettes are transparent; independent from far architecture.
    b=''
    for x in range(-80,1360,160):
        b+=path(f'M{x} 600V{536+(x%3)*8}l80-28 80 25v67Z','url(#rock)','#070f1d',4)
        for off in [15,103]:
            peak=487+rng.randrange(45)
            b+=path(f'M{x+off} 600V{peak+45}l-9-3 14-42 13 42-8 5V600Z','#091626','#152d43',3)
            b+=path(f'M{x+off+5} {peak+5}l5 31h-7Z','#35536b')
    for x in [192,850]: b+=banner(x,512,.85)
    for x in [18,1234]: b+=torch(x,544,.6)
    svg('foreground',1280,600,b)

def node_assets():
    rng=random.Random(9)
    b=ellipse(130,211,115,18,'#05101d')
    b+=path('M31 55L9 100L27 181L55 198L61 239L87 215L110 266L135 228L150 244L185 211L197 177L226 147L246 86L211 56Z','url(#rock)','#121d2c',4)
    for d,c in [('M31 55L9 100L62 116L78 71Z','#4a5664'),('M62 116L27 181L55 198L78 151Z','#243043'),('M62 116L110 266L109 146L132 94Z','#152538'),('M132 94L150 244L185 211L176 99Z','#394052'),('M176 99L197 177L226 147L246 86Z','#273548'),('M78 151L87 215L61 239Z','#5b3937')]: b+=path(d,c,'#172437',1)
    for i in range(34):
        x=rng.randrange(35,225); y=rng.randrange(85,182)
        b+=path(f'M{x} {y}l{rng.randrange(5,20)}-4 8 8','none',rng.choice(['#72808a','#111e31','#9b4d37']),1,extra='opacity=".4"')
    b+=banner(120,118,.55)
    svg('island',260,280,b)
    b=ellipse(120,51,110,30,'#0a1320')+path('M13 41Q120 3 227 41L222 71Q117 117 17 71Z','url(#stone)','#302a2a',4)+ellipse(120,40,108,30,'#c3b7a0')
    for i in range(10):
        theta=i*math.tau/10
        a=(120+107*math.cos(theta),40+29*math.sin(theta)); c=(120+62*math.cos(theta+.07),40+17*math.sin(theta+.07))
        b+=path(f'M{a[0]:.2f} {a[1]:.2f}L{c[0]:.2f} {c[1]:.2f}','none','#665e55',2)
        if 0<theta<math.pi: b+=path(f'M{a[0]:.2f} {a[1]:.2f}v30','none','#62574e',2)
    b+=path('M20 45Q120 79 221 45','none','#f1dcc0',2)+ellipse(120,42,66,17,'#817568')
    for d in ['M22 36l21 4 7 16','M75 22l13 7-5 12','M163 27l-11 8 8 12','M187 53l-13 12 5 10','M67 74l-3 16']:
        b+=path(d,'none','#5e554e',1.5)
    for i in range(42):
        x=rng.randrange(27,210); y=rng.randrange(28,70)
        b+=ellipse(x,y,rng.choice([.5,.8,1.2]),.5,'#dfc8a5' if i%2 else '#756f63')
    svg('platform',240,112,b)
    b=path('M17 8L153 5L159 60L9 65L6 15Z','url(#wood)','#201a1e',5)
    for y in [18,35,52]: b+=path(f'M12 {y}Q56 {y-4} 94 {y}T154 {y+1}','none','#693817',1)
    b+=path('M13 13L151 10M13 38L155 35','none','#ffd47a',2)
    for x,y in [(31,23),(121,47),(85,20)]:
        b+=path(f'M{x} {y}q10-5 16 1t13 0m-23 3q7 3 13-1','none','#562d18',.7)
    for x,y in [(14,15),(150,12),(17,57),(149,54)]: b+=bolt(x,y,4)
    svg('number_sign',168,72,b)
    b=path('M28 5L103 5L124 25L124 106L104 124L27 124L6 104L6 25Z','url(#steel)','#0c1420',6)+path('M29 16L101 16L113 30V100L99 112H31L17 99V29Z','url(#inset)','#bac5c8',2)
    b+=path('M24 33Q66 15 107 33V64Q57 38 24 71Z','#ffffff',extra='opacity=".035"')
    for x,y in [(19,45),(107,77),(44,118),(12,68),(91,11)]:
        b+=path(f'M{x} {y}l5-3m-1 4 4-2','none','#f2e9cc',.7)
    for x,y in [(27,13),(103,14),(116,30),(116,102),(101,116),(29,116),(14,101),(14,28)]: b+=bolt(x,y,4)
    svg('boss_frame',132,132,b)
    pts=[]
    for i in range(10):
        ang=-math.pi/2+i*math.pi/5; r=31 if i%2==0 else 14
        pts.append(f'{36+math.cos(ang)*r:.2f},{36+math.sin(ang)*r:.2f}')
    b=f'<polygon points="{" ".join(pts)}" fill="url(#gold)" stroke="#6e370c" stroke-width="4" stroke-linejoin="round"/>'
    b+=path('M36 7L36 35L8 27L27 23Z','#fff9af')+path('M36 35L54 60L48 40L64 27Z','#d17a0c')
    svg('star',72,72,b)
    for name,col in [('bronze',('#eab278','#ac4e22','#4f241b')),('gold',('#ffef79','#e49717','#784111')),('diamond',('#96f5ff','#229be5','#103f8a'))]:
        b=ellipse(60,100,55,10,'#07111e')+path('M9 47Q10 3 58 5Q105 2 112 39L111 88L87 104L10 91Z','url(#chest)','#1c1a24',5)
        b+=path('M11 47L89 51L111 39V88L88 102V52Q81 9 55 6','url(#chest)','#351f20',2)
        b+=path('M12 52L87 56L110 43','none','#edbf77' if name=='bronze' else col[0],3)
        for d in ['M24 9Q42 15 43 52L43 95L30 93L30 53Q28 20 17 17Z','M71 8Q91 14 94 49V98L83 102V53Q81 18 60 6Z']:
            b+=path(d,'url(#steel)','#252637',2)
        b+=rect(50,54,24,29,'url(#steel)','#292534',3)+ellipse(62,65,4,5,'#1e2532')+path('M60 68v7h4v-7','#1e2532')
        for x,y in [(15,57),(103,49),(16,84),(102,84)]: b+=bolt(x,y,2)
        b+=path('M18 33Q48 16 71 26','none',col[0],2)
        if name=='diamond': b+=path('M62 48L80 64L64 87L45 63Z','#2bc8ff','#152c64',3)+path('M62 48L64 71L45 63ZM62 48L80 64L64 71Z','#a7faff','#e2ffff',1)
        svg('chest_'+name,122,114,b,col)

def interface_assets():
    b=path('M9 13L105 8L101 107L7 111Z','url(#green)','#0d1b11',6)+path('M12 18L99 13','none','#e1ffa0',3)
    b+=path('M31 58L56 33L82 57H74V88H61V68H50V88H38V57Z','#f9ffe3','#416327',3)
    svg('home',114,120,b)
    b=path('M8 27L29 11H199L224 27L214 99L199 113H28L10 99Z','url(#red)','#26191d',6)+path('M14 31L32 18H197L217 31','none','#ffca5e',3)
    for x in [29,61,94,129,165,200]: b+=bolt(x,23,3)+bolt(x,103,3)
    for x in [60,115,170]: b+=path(f'M{x-10} 11l10-15 10 15Z','url(#steel)','#222c32',2)
    svg('shop',232,124,b)
    b=path('M8 15L18 7H246L258 18V65L246 77H18L7 65Z','url(#iron)','#07121e',5)+path('M18 15H246','none','#6f91a5',2)+rect(18,22,229,44,'#081725',r=4)
    svg('resource_bar',266,86,b)
    for name,d in [('arrow','M15 39L51 8V24H94V58H51V75Z'),('jump','M7 40L41 9V27L71 9V27H99V56H71V73L41 55V73Z')]:
        b=path(d,'url(#steel)','#0b1521',9)+path(d,'url(#orange)','#8d400e',3)+path('M19 38L47 15','none','#fff6b7',3)
        svg(name,108,84,b)
    b=path('M9 5H174L188 18L182 62H12L3 49Z','url(#iron)','#071422',4)+path('M13 11H170','none','#698b9c',2)
    svg('nav_plate',192,70,b)
    svg('energy',64,78,path('M28 4H55L40 28H60L19 73L26 42H7Z','url(#orange)','#702b11',4)+path('M29 8H49L31 31H16Z','#fff4a3'))
    svg('coin',72,78,ellipse(36,41,30,31,'#8c480f')+ellipse(34,37,30,31,'url(#gold)')+ellipse(34,37,23,24,'none').replace('fill="none"','fill="none" stroke="#fff296" stroke-width="2"')+path('M18 26L27 33L34 20L43 33L51 26L46 48H23Z','#e9840e','#9c4a0a',2))
    svg('diamond',72,78,path('M15 8H54L69 28L35 71L3 28Z','#31b7f2','#0c2c4c',4)+path('M15 8L24 27L3 28ZM54 8L46 27L69 28ZM24 27L35 71L46 27Z','#a0f4ff','#167bc9',1)+path('M15 8H54L46 27H24Z','#d3ffff','#237bbd',1))

if __name__ == '__main__':
    scenery(); node_assets(); interface_assets()
    print(f'Generated {len(list(OUT.glob("*.svg")))} independent SVG assets in {OUT}')
