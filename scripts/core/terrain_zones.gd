extends RefCounted
const NAMES=["Gräsmark","Kuperad","Berg"]
const BLEND: float=110
var generation_version: int=5
var seed_value: int
var noise:=FastNoiseLite.new()
var cache: Dictionary={}
func _init(value: int,version: int=5) -> void:
	generation_version=version
	seed_value=value
	noise.seed=int(value%2147483647)
	noise.frequency=0.009
	noise.fractal_octaves=3
func hash_at(x: int,z: int,salt: int) -> int:
	return absi(x*73856093 ^ z*19349663 ^ seed_value*83492791 ^ salt*2654435761)%2147483647
func width(index: int,axis: int) -> int:
	return 1000+hash_at(index,axis,1301)%1001
func interval(index: int,axis: int) -> Vector2i:
	var start: int= -750
	if index>=0:
		for i in range(index):
			start+=width(i,axis)
	else:
		for i in range(-1,index-1,-1):
			start-=width(i,axis)
	return Vector2i(start,width(index,axis))
func axis_cell(value: int,axis: int) -> Vector3i:
	var index: int=0
	var start: int= -750
	if value<start:
		while value<start:
			index-=1
			start-=width(index,axis)
	else:
		while value>=start+width(index,axis):
			start+=width(index,axis)
			index+=1
	return Vector3i(index,start,width(index,axis))
func kind(gx: int,gz: int) -> int:
	return 0 if gx==0 and gz==0 else hash_at(gx,gz,1307)%3
func rect(gx: int,gz: int) -> Rect2i:
	var a: Vector2i=interval(gx,0)
	var b: Vector2i=interval(gz,1)
	return Rect2i(a.x,b.x,a.y,b.y)
func axis_weights(value: int,cell: Vector3i) -> Dictionary:
	var lo: float=value-cell.y
	var hi: float=cell.y+cell.z-value
	if lo<BLEND:
		var own: float=0.5+0.5*smoothstep(0,BLEND,lo)
		return {cell.x:own,cell.x-1:1-own}
	if hi<BLEND:
		var own: float=0.5+0.5*smoothstep(0,BLEND,hi)
		return {cell.x:own,cell.x+1:1-own}
	return {cell.x:1.0}
func info(x: int,z: int) -> Dictionary:
	var a: Vector3i=axis_cell(x,0)
	var b: Vector3i=axis_cell(z,1)
	var biome: int=kind(a.x,b.x)
	return {"kind":biome,"name":NAMES[biome],"rect":Rect2i(a.y,b.y,a.z,b.z),"grid":Vector2i(a.x,b.x)}
func profile(x: int,z: int) -> Dictionary:
	var key:=Vector2i(x,z)
	if cache.has(key):
		return cache[key]
	var ax: Dictionary=axis_weights(x,axis_cell(x,0))
	var az: Dictionary=axis_weights(z,axis_cell(z,1))
	var weights:=Vector3.ZERO
	for gx in ax:
		for gz in az:
			weights[kind(gx,gz)]+=float(ax[gx])*float(az[gz])
	var broad: float=noise.get_noise_2d(x*0.38,z*0.38)
	var detail: float=noise.get_noise_2d(x,z)
	var fine: float=noise.get_noise_2d(x*2.4,z*2.4)
	var patch: float=noise.get_noise_2d(x*1.1+1400,z*1.1-700)
	var plains: float=clampf(broad*16+detail*8,-10,10)
	var hills: float=9+broad*48+detail*32+fine*5+smoothstep(0.12,0.4,patch)*5
	var ridge: float=pow(clampf(1-absf(detail*2.1),0,1),3)
	var mountains: float=42+broad*108+detail*40+ridge*35+smoothstep(-0.1,0.08,patch)*25
	if generation_version>=5:
		plains=clampf(broad*7+detail*3,-4,4)
		hills=4+broad*25+detail*16+fine*3+smoothstep(0.18,0.4,patch)*3
		var peaks: float=noise.get_noise_2d(x*0.28+2400,z*0.28-1700)
		mountains=hills+8+broad*30+detail*12+ridge*10+smoothstep(0.05,0.4,peaks)*45
	var elevation: float=plains*weights.x+hills*weights.y+mountains*weights.z
	var result: Dictionary={"height":clampf(elevation,-28,164),"weights":weights,"patch":patch}
	cache[key]=result
	return result
func nearest_rect(point: Vector2,biome: int) -> Rect2i:
	var current: Dictionary=info(floori(point.x),floori(point.y))
	var best:=Rect2i()
	var distance: float=INF
	for x in range(current.grid.x-4,current.grid.x+5):
		for z in range(current.grid.y-4,current.grid.y+5):
			if kind(x,z)!=biome:
				continue
			var bounds: Rect2i=rect(x,z)
			var d: float=Vector2(bounds.get_center()).distance_squared_to(point)
			if d<distance:
				best=bounds
				distance=d
	return best
