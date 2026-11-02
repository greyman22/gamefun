"""Build original 256px surface textures, detail/normal maps and matching block icons.
Requires Pillow and NumPy; no external artwork is used.
"""
from pathlib import Path
import sys, json
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / '.texture-tools'))
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
OUT = Path(__file__).resolve().parents[1] / 'assets/materials'
OUT.mkdir(parents=True, exist_ok=True)
S=256
Y,X=np.mgrid[:S,:S].astype(float)
rng=np.random.default_rng(92417)

def noise(size):
    a=rng.random((size,size)).astype('float32')
    a=np.pad(a,((0,1),(0,1)),mode='wrap')
    return np.asarray(Image.fromarray(a).resize((S,S),Image.Resampling.BICUBIC),dtype=float)
N=[noise(n) for n in [4,12,32,96]]
fine=rng.random((S,S))

def rgb(color, tone=1):
    c=np.array([int(color[i:i+2],16) for i in (0,2,4)],float)/255
    return np.clip(c[None,None,:]*np.broadcast_to(tone,(S,S))[:,:,None],0,1)

def save(name,color,height,rough=.9,alpha=None):
    if isinstance(color,str):color=rgb(color)
    color=np.broadcast_to(color,(S,S,3)).copy()
    alpha=np.ones((S,S)) if alpha is None else alpha
    im=np.dstack([color,alpha])
    Image.fromarray(np.uint8(np.clip(im,0,1)*255)).save(OUT/f'{name}.png')
    h=np.clip(np.broadcast_to(height,(S,S)),0,1)
    detail=np.dstack([h,np.broadcast_to(rough,(S,S)),np.zeros((S,S))])
    Image.fromarray(np.uint8(np.clip(detail,0,1)*255)).save(OUT/f'{name}_detail.png')
    dx=(np.roll(h,-1,1)-np.roll(h,1,1))*S*.0125
    dy=(np.roll(h,-1,0)-np.roll(h,1,0))*S*.0125
    norm=np.dstack([-dx,dy,np.ones((S,S))])
    norm/=np.linalg.norm(norm,axis=2)[:,:,None]
    Image.fromarray(np.uint8((norm*.5+.5)*255)).save(OUT/f'{name}_normal.png')

# Rock: mineral variation, grains, sparse veins and hairline fractures.
tone=.68+N[0]*.22+N[1]*.2+N[2]*.18+fine*.08
crack=Image.new('L',(S,S));d=ImageDraw.Draw(crack)
for i in range(17):
    x,y=rng.integers(0,S,2);pts=[(int(x),int(y))]
    for j in range(int(rng.integers(2,6))):
        x+=int(rng.integers(-24,25));y+=int(rng.integers(9,30));pts.append((x,y))
    d.line(pts,fill=int(rng.integers(90,190)),width=int(rng.integers(1,3)))
c=np.asarray(crack,dtype=float)/255
stone=rgb('727974',tone)*(1-c[:,:,None]*.5)
stone+=(fine>.985)[:,:,None]*.075
# Stone uses an original 16x16 pixel motif, enlarged without smoothing.
# Independent RNG keeps all other material designs reproducible and unchanged.
pixel_rng=np.random.default_rng(53091)
pixels=np.full((16,16),126.0)
for _ in range(95):
    px,py=pixel_rng.integers(0,16,2)
    width=int(pixel_rng.integers(1,5));height=int(pixel_rng.integers(1,3))
    shade=float(pixel_rng.choice([105,112,119,126,133,140,146]))
    for dy in range(height):
        for dx in range(width):
            pixels[(py+dy)%16,(px+dx)%16]=shade
pixel_tone=np.repeat(np.repeat(pixels,16,axis=0),16,axis=1)/255.0
pixel_color=np.repeat(pixel_tone[:,:,None],3,axis=2)
save('stone',pixel_color,.5+(pixel_tone-.5)*.12,.96)
save('bedrock',rgb('45494e',tone)*(1-c[:,:,None]*.65),.3+N[1]*.35-c*.3,.98)
# Earth: clumps, tiny roots, embedded pebbles. Grass stays restrained and green.
earth=rgb('795237',.7+N[1]*.35+N[2]*.28+fine*.11)
earth+=(fine>.992)[:,:,None]*np.array([.16,.14,.1])
save('earth',earth,.25+N[1]*.25+N[2]*.24+fine*.15,.96)
grass=rgb('47732c',.64+N[0]*.12+N[1]*.38+N[3]*.25)
blade=Image.new('L',(S,S));d=ImageDraw.Draw(blade)
for i in range(1800):
    x,y=rng.integers(0,S,2)
    d.line((int(x),int(y),int(x+rng.integers(-3,4)),int(y-rng.integers(2,7))),fill=int(rng.integers(50,180)),width=1)
b=np.asarray(blade,dtype=float)/255
grass+=b[:,:,None]*np.array([.025,.065,.012])
# Blocky green grass motif inspired by classic voxel terrain.
green_rng=np.random.default_rng(81325)
green_palette=np.array([[76,139,38],[83,152,41],[93,164,45],[105,177,51],[119,188,58],[139,201,71],[161,218,88]],dtype=float)/255
pixels=green_palette[green_rng.choice(len(green_palette),(16,16),p=[.08,.16,.24,.24,.16,.09,.03])]
grass=np.repeat(np.repeat(pixels,16,axis=0),16,axis=1)*0.78
save('grass',grass,.5+(grass[:,:,1]-.6)*.08,.96)
mask=Y<(8+np.sin((X//16)*1.5)*2)
side=earth.copy();side[mask]=grass[mask]
save('earth_grass',side,np.where(mask,.65,.25+N[2]*.3),.96)
# Long wood grain, growth rings, bark fissures; no baked lighting/shadows.
grains=np.sin(Y*.31 + np.sin(X*.019)*2 + N[1]*4)
grain2=np.sin(Y*1.25+N[0]*7)
woodtone=.77+N[0]*.1+N[2]*.12+grains*.075+grain2*.025+fine*.025
planks=rgb('bb8b55',woodtone)
ph=.5+grains*.08+grain2*.035
for y in [63,127,191,255]:
    planks[max(0,y-1):y+1]*=.57;ph[max(0,y-1):y+1]=.2
for row,x in [(0,87),(1,176),(2,112),(3,212)]:
    planks[row*64:(row+1)*64,x:x+1]*=.65
save('planks',planks,ph,.84+N[2]*.1)
barkwave=np.sin(X*.23+N[1]*4)
bark=rgb('745035',.72+N[1]*.24+N[3]*.1+barkwave*.1)
barkh=.35+N[1]*.25+barkwave*.15
save('bark',bark,barkh,.97)
r=np.sqrt(((X-126)*1.03)**2+((Y-131)*.97)**2)
rings=np.sin(r*.38+N[1]*1.7)
end=rgb('b88e5c',.86+rings*.055+N[2]*.07)
edge=np.minimum.reduce([X,Y,255-X,255-Y])<10
end[edge]=bark[edge]
save('log_end',end,np.where(edge,barkh,.5+rings*.035),.9)
# Chest: inset wood panels, deep framing, brass latch and small nail heads.
chest=rgb('aa7840',woodtone);ch=.5+grains*.04
frame=(X<20)|(X>235)|(Y<17)|(Y>238)|((Y>87)&(Y<101))
chest[frame]=rgb('39281c',.9+N[2]*.15)[frame];ch[frame]=.7
latch=(X>=111)&(X<=144)&(Y>=79)&(Y<=149)
chest[latch]=np.array([.74,.58,.29]);ch[latch]=.88
rough=np.full((S,S),.91);rough[latch]=.58
for x in [12,243]:
    for y in [12,92,243]:
        nail=(X-x)**2+(Y-y)**2<10
        chest[nail]=[.22,.23,.23];ch[nail]=.83
save('chest_side',chest,ch,rough)
top=rgb('aa7840',woodtone);border=(X<18)|(X>237)|(Y<18)|(Y>237)
top[border]=rgb('39281c',.9+N[2]*.15)[border]
save('chest_top',top,np.where(border,.72,.5+grains*.04),.9)
# Workbench with a distinctive 4x4 wooden checkerboard and sturdy frame.
checks=((X//64+Y//64)%2)==0
bench=np.where(checks[:,:,None],rgb('cfa774',woodtone),rgb('65432d',woodtone))
save('bench_top',bench,.5+grains*.045,.9)
benchside=rgb('a47746',woodtone)
frame=(X<32)|(X>223)|(Y<28)|((Y>181)&(Y<205))
benchside[frame]=rgb('4d3324',woodtone)[frame]
save('bench_side',benchside,np.where(frame,.7,.43)+grains*.03,.9)
# Leaves: dense green clusters and cutout gaps; no brown branches.
lh=np.abs((X.astype(int)//32)*1619 ^ (Y.astype(int)//32)*31337 ^ 4*6971)
alpha=(lh%100<80).astype(float)
veins=(np.sin(X*.29+Y*.21)> .95).astype(float)
leaf=rgb('426b2d',.72+N[1]*.4+N[3]*.17)+veins[:,:,None]*np.array([.025,.04,.01])
save('leaves',leaf,.45+N[2]*.12+veins*.06,.95,alpha)
# Carved amethyst soul emblem.
r=np.sqrt(((X-127)/.82)**2+(Y-127)**2)
soul=rgb('35233f',.8+N[1]*.3);sh=.4+N[2]*.1
orb=r<94;inner=r<65
soul[orb]=rgb('73409b',.8+N[2]*.35)[orb]
soul[inner]=rgb('b96de5',.8+N[2]*.3)[inner];sh[orb]=.64;sh[inner]=.74
shine=((X-105)/17)**2+((Y-96)/27)**2<1
soul[shine]=[.89,.74,.96];sh[shine]=.82
save('soul',soul,sh,.78)
furrows=.5+.5*np.cos(Y*2*np.pi/32)
save('farmland',earth*(.62+.22*furrows[:,:,None]),.2+furrows*.4,.98)
# Stone oven: recessed mouth and top vent, with a separate burning face.
oven=stone.copy();oh=.35+N[2]*.12
mouth=(X>40)&(X<216)&(Y>116)&(Y<222)
vent=(X>54)&(X<202)&(Y>34)&(Y<66)
oven[mouth]=[.055,.048,.04];oh[mouth]=.1
oven[vent]=[.10,.11,.12];oh[vent]=.15
save('furnace',oven,oh,.96)
lit=oven.copy();flame=mouth&(Y>153+np.sin(X*.14)*14)
lit[flame]=rgb('ee8d27',.7+N[2]*.3)[flame]
coals=mouth&(Y>203);lit[coals]=[1,.52,.12]
save('furnace_lit',lit,oh,.96)
manifest={
 'lakebed':['earth']*3,
 'furnace':['furnace','stone','stone'],'furnace_lit':['furnace_lit','stone','stone'],'farmland':['earth','farmland','earth'],'gate':['planks']*3,'gate_open':['planks']*3,'fence':['planks']*3,'air':['earth']*3,'stone':['stone']*3,'dirt':['earth_grass','grass','earth'],
 'wood':['bark','log_end','log_end'],'foliage':['leaves']*3,'planks':['planks']*3,
 'workbench':['bench_side','bench_top','planks'],'chest':['chest_side','chest_top','planks'],
 'bedrock':['bedrock']*3,'soul_block':['soul']*3,'torch':['bark']*3,
 'door':['planks']*3,'door_top':['planks']*3,'door_open':['planks']*3,'door_top_open':['planks']*3}
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
# Isometric icons use the exact world textures, with simple face shading.
for kind in ['stone','dirt','wood','foliage','planks','workbench','chest','bedrock','soul_block','furnace']:
    icon=Image.new('RGBA',(128,128))
    specs=[(1,(64,12),(48,24),(-48,24),1),(0,(16,36),(48,24),(0,48),.8),(0,(64,60),(48,-24),(0,48),.65)]
    for face,origin,u,v,shade in specs:
        tex=Image.open(OUT/f'{manifest[kind][face]}.png').convert('RGBA')
        arr=np.array(tex);arr[:,:,:3]=np.uint8(arr[:,:,:3]*shade);tex=Image.fromarray(arr)
        inv=np.linalg.inv(np.array([u,v],float).T)*255
        off=-inv@np.array(origin,float)
        coeff=tuple(inv[0])+tuple([off[0]])+tuple(inv[1])+tuple([off[1]])
        mapped=tex.transform((128,128),Image.Transform.AFFINE,coeff,Image.Resampling.BICUBIC)
        mask=Image.new('L',(128,128));d=ImageDraw.Draw(mask)
        o=np.array(origin);uu=np.array(u);vv=np.array(v)
        d.polygon([tuple(o),tuple(o+uu),tuple(o+uu+vv),tuple(o+vv)],fill=255)
        mapped.putalpha(Image.fromarray(np.minimum(np.array(mapped.getchannel('A')),np.array(mask))))
        icon.alpha_composite(mapped)
    icon.save(OUT/f'icon_{kind}.png')
print('Generated',len(list(OUT.glob('*.png'))),'original texture/icon images at',S,'pixels per surface')
