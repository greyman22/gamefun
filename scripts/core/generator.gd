extends RefCounted

const VERSION: int = 5
const TerrainZones=preload("res://scripts/core/terrain_zones.gd")
var zones: RefCounted
var rock_cache: Dictionary={}
var cave_cache: Dictionary={}
var cave_columns: Dictionary={}
const SEA_LEVEL: int = -2
const MAX_WATER_DEPTH: int = 12
var version: int=VERSION
const SIZE: int = 16
const MIN_Y: int = -64
const MAX_Y: int = 255
const HALF_WORLD: int = 16384
var seed_value: int
var noise := FastNoiseLite.new()
var column_cache: Dictionary = {}
var tree_cache: Dictionary = {}

func _init(world_seed: int = 20261030, generation_version: int=VERSION) -> void:
	version=generation_version
	seed_value = world_seed
	zones=TerrainZones.new(world_seed,version)
	noise.seed = int(world_seed % 2147483647)
	noise.frequency = 0.012
	noise.fractal_octaves = 3

func hash_at(x: int, z: int, salt: int = 0) -> int:
	return absi((x * 73856093) ^ (z * 19349663) ^ (seed_value * 83492791) ^ (salt * 2654435761)) % 2147483647

func height(x: int, z: int) -> int:
	var key := Vector2i(x, z)
	if column_cache.has(key):
		return column_cache[key]
	var distance := Vector2(x, z).length()
	var blend: float = smoothstep(14.0, 36.0, distance)
	var value: int = roundi((noise.get_noise_2d(x, z) * 19.0 + noise.get_noise_2d(x * 0.3, z * 0.3) * 16.0) * blend)
	if version>=4:
		value=roundi(float(zones.profile(x,z).height)*blend)
	# A seed-specific hill keeps the familiar starting area recognisable.
	var center := Vector2(-10 + hash_at(1, 2) % 4, 11)
	var radius: float = 5.0 + hash_at(3, 4) % 3
	var hill: float = maxf(0, 1.0 - Vector2(x - center.x, z - center.y).length() / radius)
	value += floori(hill * (3 + hash_at(5, 6) % 3))
	if version>=3:
		var carve: float=water_bed(x,z,value)
		var shore_blend: float=smoothstep(26.0,46.0,distance)
		value=roundi(lerpf(value,minf(value,carve),shore_blend))
		value=maxi(SEA_LEVEL-MAX_WATER_DEPTH,value)
	if version>=4 and zones.profile(x,z).weights.x>0.999:
		value=clampi(value,-10,10)
	column_cache[key] = value
	return value

func tree_info(gx: int, gz: int) -> Dictionary:
	var key := Vector2i(gx, gz)
	if tree_cache.has(key):
		return tree_cache[key]
	var h: int = hash_at(gx, gz, 21)
	var x: int = gx * 10 + 2 + h % 6
	var z: int = gz * 10 + 2 + (h / 7) % 6
	var result: Dictionary = {}
	if version>=5 and zones.profile(x,z).weights.x>0.6:
		var forest: float=noise.get_noise_2d(x*0.18+800,z*0.18-900)
		if forest<0.05 or h%100>=35:
			tree_cache[key]=result
			return result
	if (version<3 or height(x,z)>=SEA_LEVEL) and h % 5 != 0 and Vector2(x, z).length() > 15 and absi(x) < world_limit() - 3 and absi(z) < world_limit() - 3 and (version<4 or not rock_surface(x,z)):
		result = {"base": Vector3i(x, height(x, z), z), "height": 3 + h % 4}
		if version>=2:
			result=make_tree(result.base,result.height)
	tree_cache[key] = result
	return result

func trees_in_chunk(key: Vector3i) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var low := key * SIZE
	for gx in range(floori(float(low.x - 4) / 10), floori(float(low.x + SIZE + 4) / 10) + 1):
		for gz in range(floori(float(low.z - 4) / 10), floori(float(low.z + SIZE + 4) / 10) + 1):
			var tree := tree_info(gx, gz)
			if not tree.is_empty():
				result.append(tree)
	return result

func tree_kind(cell: Vector3i, tree: Dictionary) -> int:
	var base: Vector3i = tree.base
	var delta := cell - base
	if tree.has("voxels"):
		return int(tree.voxels.get(delta,0))
	if delta.x == 0 and delta.z == 0 and delta.y >= 0 and delta.y < tree.height:
		return 3
	if delta.y == tree.height and absi(delta.x) <= 1 and absi(delta.z) <= 1:
		return 4
	if delta.y == tree.height + 1 and absi(delta.x) + absi(delta.z) <= 1:
		return 4
	return 0

func owner(cell: Vector3i) -> Dictionary:
	for tree: Dictionary in trees_in_chunk(Vector3i(floori(float(cell.x) / SIZE), 0, floori(float(cell.z) / SIZE))):
		if tree_kind(cell, tree) != 0 or cell == tree.base + Vector3i.DOWN:
			return tree
	return {}

func ground(cell: Vector3i) -> int:
	if cell.y < MIN_Y or absi(cell.x) >= world_limit() or absi(cell.z) >= world_limit():
		return 7
	if cell.y > max_y():
		return 0
	if cell.y >= height(cell.x, cell.z):
		return 21 if version>=3 and cell.y<SEA_LEVEL else 0
	if version>=4 and cell.y>SEA_LEVEL+1 and cell.y>=height(cell.x,cell.z)-24 and cave_air(cell):
		return 0
	if version>=5 and cell.y>SEA_LEVEL and cell.y>=height(cell.x,cell.z)-25 and cave_lining(cell):
		return 1
	if version>=4 and rock_surface(cell.x,cell.z):
		return 1
	var gx: int = floori(float(cell.x) / 2) * 2
	var gz: int = floori(float(cell.z) / 2) * 2
	var gy: int = floori(float(cell.y) / 2) * 2
	var surface: int = mini(mini(height(gx, gz), height(gx + 1, gz)), mini(height(gx, gz + 1), height(gx + 1, gz + 1)))
	if gy + 1 > surface - 4:
		return 30 if version>=3 and height(cell.x,cell.z)<SEA_LEVEL else 2
	return 1 if hash_at(gx + gy * 117, gz, 41) % 100 < (90 if gy < surface - 12 else 65) else 2

func trim_caches() -> void:
	if column_cache.size() > 8192:
		column_cache.clear()
		rock_cache.clear()
		cave_columns.clear()
		zones.cache.clear()
	if tree_cache.size() > 2048:
		tree_cache.clear()
	if cave_cache.size()>2048:
		cave_cache.clear()
		cave_columns.clear()

func generate(key: Vector3i) -> PackedByteArray:
	trim_caches()
	var data := PackedByteArray()
	data.resize(SIZE * SIZE * SIZE * 2)
	var trees := trees_in_chunk(key)
	var origin := key * SIZE
	for z in range(SIZE):
		for x in range(SIZE):
			for y in range(SIZE):
				var cell := origin + Vector3i(x, y, z)
				var block: int = ground(cell)
				if block == 0 and cell.y <= height(cell.x, cell.z) + 8:
					for tree: Dictionary in trees:
						block = tree_kind(cell, tree)
						if block != 0:
							break
				data.encode_u16((x + SIZE * (y + SIZE * z)) * 2, block)
	return data

func make_tree(base: Vector3i, trunk_height: int) -> Dictionary:
	var h: int=hash_at(base.x,base.z,733)
	var voxels: Dictionary={}
	var branches: Array[Vector3i]=[]
	var radius: int=1 if trunk_height<=3 else 2
	# Three crown silhouettes, seeded independently of trunk height.
	for layer in range(-1,2):
		var r: int=radius if layer<=0 else 1
		for x in range(-r,r+1):
			for z in range(-r,r+1):
				if absi(x)==r and absi(z)==r and (h%3!=0 or layer>0):
					continue
				if h%3==2 and layer== -1 and absi(x)+absi(z)>r:
					continue
				voxels[Vector3i(x,trunk_height+layer,z)]=4
	if trunk_height>=5 and h%100<70:
		var count: int=2 if trunk_height>=6 and h%3!=0 else 1
		for i in range(count):
			var side: Vector3i=[Vector3i.RIGHT,Vector3i.BACK,Vector3i.LEFT,Vector3i.FORWARD][(h/101+i*2)%4]
			var length: int=1+(h/307+i)%2
			var branch_y: int=trunk_height-2+i
			var end: Vector3i=side*length+Vector3i.UP*(branch_y+1)
			for y in range(0,2):
				for x in range(-1,2):
					for z in range(-1,2):
						if y==1 and absi(x)+absi(z)>1:
							continue
						voxels[end+Vector3i(x,y,z)]=4
			for step in range(1,length+1):
				branches.append(side*step+Vector3i.UP*branch_y)
	for cell in branches:
		voxels[cell]=3
	for y in range(trunk_height):
		voxels[Vector3i(0,y,0)]=3
	return {"base":base,"height":trunk_height,"voxels":voxels,"branches":branches}

func water_bed(x: int, z: int, terrain: float=0) -> float:
	var lake_x: int=roundi(float(x-100)/320)
	var lake_z: int=roundi(float(z-80)/320)
	var bottom: float=512 if version>=4 else 64
	for gx in range(lake_x-1,lake_x+2):
		for gz in range(lake_z-1,lake_z+2):
			var h: int=hash_at(gx,gz,1103)
			var center:=Vector2(gx*320+100+h%23-11,gz*320+80+(h/31)%23-11)
			var rx: float=85+h%31
			var rz: float=65+(h/101)%26
			var delta:=Vector2((x-center.x)/rx,(z-center.y)/rz)
			var r: float=delta.length()+noise.get_noise_2d(x*0.7,z*0.7)*0.08
			var bed: float=SEA_LEVEL+2-(MAX_WATER_DEPTH+2)*(1-smoothstep(0.2,1.15,r))
			if version>=4:
				if r<1.5:
					bottom=minf(bottom,lerpf(terrain,bed,1-smoothstep(1.0,1.5,r)))
			else:
				bottom=minf(bottom,bed)
	var phase: float=float(hash_at(1,9,1117)%628)/100
	for row in range(lake_z-1,lake_z+2):
		var bend: float=sin(x*0.018+phase)*17+sin(x*0.047-phase)*6
		var width: float=3+17*(0.5+0.5*sin(x*0.009+row*1.7+phase))
		var d: float=absf(z-(row*320+80+bend))
		bottom=minf(bottom,river_bed(d,width,terrain))
	for column in range(lake_x-1,lake_x+2):
		var bend: float=sin(z*0.015-phase)*21+sin(z*0.041+phase)*5
		var width: float=3+17*(0.5+0.5*sin(z*0.011+column*1.3-phase))
		var d: float=absf(x-(column*320+100+bend))
		bottom=minf(bottom,river_bed(d,width,terrain))
	return bottom
func river_bed(distance: float, width: float, terrain: float=0) -> float:
	var half_width: float=width*0.5
	if version>=4:
		if distance>half_width+10:
			return 512
		if distance>half_width:
			return lerpf(SEA_LEVEL-1,terrain,smoothstep(0,10,distance-half_width))
	if distance>half_width+2:
		return 64
	# Full channel width is below water; banks rise over the next two metres.
	if distance<=half_width:
		return SEA_LEVEL-1-(2+width*0.12)*(1-pow(distance/maxf(half_width,0.1),2))
	return lerpf(SEA_LEVEL-1,SEA_LEVEL+3,(distance-half_width)/2)

func max_y() -> int:
	return 255 if version>=4 else 63
func world_limit() -> int:
	return HALF_WORLD if version>=4 else 1024
func rock_surface(x: int,z: int) -> bool:
	var key:=Vector2i(x,z)
	if rock_cache.has(key):
		return rock_cache[key]
	var p: Dictionary=zones.profile(x,z)
	var h: int=height(x,z)
	var slope: int=maxi(absi(height(x+1,z)-height(x-1,z)),absi(height(x,z+1)-height(x,z-1)))
	var rocky: bool=(p.weights.z>0.45 and (h>38 or slope>=4 or p.patch>0.16)) or (p.weights.y>0.45 and ((h>20 and p.patch>0.18) or p.patch>0.38 or slope>=5))
	if version>=5 and p.weights.z>0.45:
		rocky=h>24 or slope>=3 or p.patch> -0.05
	rock_cache[key]=rocky and h>=SEA_LEVEL
	return rock_cache[key]
func legacy_cave_for_tile(gx: int,gz: int) -> Dictionary:
	var key:=Vector2i(gx,gz)
	if cave_cache.has(key):
		return cave_cache[key]
	var h: int=hash_at(gx,gz,1409)
	var center:=Vector2i(gx*64+16+h%32,gz*64+16+(h/41)%32)
	var result: Dictionary={}
	if zones.profile(center.x,center.y).weights.z>0.6 and h%4!=0:
		var axis:=Vector2i.RIGHT if h%2==0 else Vector2i.DOWN
		var side:=Vector2i(-axis.y,axis.x)
		var length: int=14+(h/7)%6
		var width: int=2+(h/29)%5
		var tall: int=2+(h/73)%3
		var floor_y: int=maxi(SEA_LEVEL+3,height(center.x,center.y)-20)
		for end in [-1,1]:
			for across in [-3,0,3]:
				var point: Vector2i=center+axis*length*end+side*across
				floor_y=maxi(floor_y,height(point.x,point.y))
		for along in range(-length,length+1,2):
			for across in [-3,0,3]:
				var point: Vector2i=center+axis*along+side*across
				floor_y=maxi(floor_y,height(point.x,point.y)-20)
		var covered: bool=height(center.x,center.y)>=floor_y+tall+1
		for offset in [-5,5]:
			var point: Vector2i=center+axis*offset
			covered=covered and height(point.x,point.y)>=floor_y+tall+1
		if covered:
			result={"center":center,"axis":axis,"side":side,"half_length":length,"width":width,"height":tall,"floor":floor_y}
	cave_cache[key]=result
	return result
func legacy_caves_at_column(x: int,z: int) -> Array:
	var key:=Vector2i(x,z)
	if cave_columns.has(key):
		return cave_columns[key]
	var result: Array=[]
	if zones.profile(x,z).weights.z>0.4:
		var gx: int=floori(float(x)/64)
		var gz: int=floori(float(z)/64)
		for a in range(gx-1,gx+2):
			for b in range(gz-1,gz+2):
				var cave: Dictionary=cave_for_tile(a,b)
				if cave.is_empty():
					continue
				var delta: Vector2i=key-cave.center
				var along: int=(delta.x*cave.axis.x+delta.y*cave.axis.y)
				if absi(along)>int(cave.half_length):
					continue
				var across: int=(delta.x*cave.side.x+delta.y*cave.side.y)-roundi(sin(float(along)/cave.half_length*PI))
				var width: int=clampi(int(cave.width)+roundi(sin(along*0.23)*0.8),2,6)
				if across>= -width/2 and across< -width/2+width:
					result.append(cave)
	cave_columns[key]=result
	return result
func cave_air(cell: Vector3i) -> bool:
	for cave in caves_at_column(cell.x,cell.z):
		if cell.y>=int(cave.floor) and cell.y<int(cave.floor)+int(cave.height):
			return true
	return false

func cave_for_tile(gx: int,gz: int) -> Dictionary:
	if version<5:
		return legacy_cave_for_tile(gx,gz)
	var key:=Vector2i(gx,gz)
	if cave_cache.has(key):
		return cave_cache[key]
	var h: int=hash_at(gx,gz,1409)
	var center:=Vector2i(gx*64+20+h%24,gz*64+20+(h/41)%24)
	var result: Dictionary={}
	if zones.profile(center.x,center.y).weights.z>0.5 and height(center.x,center.y)>8:
		for attempt in range(4):
			var axis: Vector2i=[Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT,Vector2i.UP][(h+attempt)%4]
			var candidate: Dictionary=curved_cave(center,axis,h)
			if not candidate.is_empty():
				result=candidate
				break
	cave_cache[key]=result
	return result
func smooth_path(controls: Array[Vector2]) -> Array[Vector2i]:
	var result: Array[Vector2i]=[]
	for i in range(controls.size()-1):
		var a: Vector2=controls[maxi(0,i-1)]
		var b: Vector2=controls[i]
		var c: Vector2=controls[i+1]
		var d: Vector2=controls[mini(controls.size()-1,i+2)]
		var samples: int=maxi(8,ceili(b.distance_to(c)*2))
		for sample in range(samples+1):
			var t: float=float(sample)/samples
			var point: Vector2=(b*2+(c-a)*t+(a*2-b*5+c*4-d)*t*t+(-a+b*3-c*3+d)*t*t*t)*0.5
			var cell:=Vector2i(roundi(point.x),roundi(point.y))
			if result.is_empty() or result[-1]!=cell:
				result.append(cell)
	return result
func tunnel_footprint(path: Array[Vector2i],width: int) -> Dictionary:
	var result: Dictionary={}
	for i in range(path.size()):
		var wide: int=clampi(width+roundi(sin(i*0.25)),2,6)
		var start: int= -wide/2
		for x in range(start,start+wide):
			for z in range(start,start+wide):
				var offset:=Vector2(x+0.5,z+0.5)
				if offset.length()<=wide*0.5+0.1:
					result[path[i]+Vector2i(x,z)]=true
	return result
func curved_cave(center: Vector2i,axis: Vector2i,h: int) -> Dictionary:
	var side:=Vector2i(-axis.y,axis.x)
	var is_u: bool=h%2==0
	var depth: float=10+(h/7)%5
	var spread: float=5+(h/31)%3
	var local: Array[Vector2]=[]
	if is_u:
		local=[Vector2(-depth,-spread),Vector2(-depth*0.4,-spread),Vector2(3,-spread*0.7),Vector2(depth*0.3,0),Vector2(3,spread*0.7),Vector2(-depth*0.4,spread),Vector2(-depth,spread)]
	else:
		local=[Vector2(-depth-3,-spread*0.5),Vector2(-depth*0.5,spread*0.7),Vector2(0,-spread*0.5),Vector2(depth*0.55,spread*0.7),Vector2(depth+3,-spread*0.5)]
	var controls: Array[Vector2]=[]
	for p in local:
		controls.append(Vector2(center)+Vector2(axis)*p.x+Vector2(side)*p.y)
	var path: Array[Vector2i]=smooth_path(controls)
	var width: int=2+(h/29)%4
	var tall: int=2+(h/73)%3
	var footprint: Dictionary=tunnel_footprint(path,width)
	var floor_y: int=SEA_LEVEL+3
	for p in footprint:
		floor_y=maxi(floor_y,height(p.x,p.y)-20)
	for end in [0,path.size()-1]:
		for x in range(-2,3):
			for z in range(-2,3):
				floor_y=maxi(floor_y,height(path[end].x+x,path[end].y+z))
	var spawn: Vector2i=path[path.size()/2]
	if height(spawn.x,spawn.y)<floor_y+tall+1:
		return {}
	var roofed: int=0
	for p in path:
		if height(p.x,p.y)>=floor_y+tall:
			roofed+=1
	if roofed<path.size()/3:
		return {}
	var first_roof: int= -1
	var last_roof: int= -1
	for i in range(path.size()):
		if height(path[i].x,path[i].y)>=floor_y+tall:
			if first_roof<0:
				first_roof=i
			last_roof=i
	for i in range(first_roof,last_roof+1):
		if height(path[i].x,path[i].y)<floor_y+tall:
			return {}
	var spawn_index: int=(first_roof+last_roof)/2
	spawn=path[spawn_index]
	var direction:=Vector2(path[mini(last_roof,spawn_index+3)]-path[maxi(first_roof,spawn_index-3)]).normalized()

	var branches: Array=[]
	# Optional blind side passages stop beneath a solid roof; they never
	# extend the main route into a straight bore through the whole mountain.
	for branch_index in range(1+(h/101)%2):
		var index: int=path.size()*(2+branch_index)/5
		var origin: Vector2i=path[index]
		var tangent:=Vector2(path[mini(index+2,path.size()-1)]-path[maxi(0,index-2)]).normalized()
		var normal:=Vector2(-tangent.y,tangent.x)*(1 if (h/13+branch_index)%2==0 else -1)
		var branch_controls: Array[Vector2]=[Vector2(origin),Vector2(origin)+normal*3,Vector2(origin)+normal*(5+(h/307)%4)+tangent*2]
		var branch: Array[Vector2i]=smooth_path(branch_controls)
		var cells: Dictionary=tunnel_footprint(branch,2+branch_index)
		var safe: bool=true
		for p in cells:
			var cover: int=height(p.x,p.y)-floor_y
			if cover<tall+1 or cover>20:
				safe=false
				break
		for end in branch.slice(maxi(0,branch.size()-3)):
			if footprint.has(end):
				safe=false
		if safe:
			footprint.merge(cells)
			branches.append(branch)
	return {"center":spawn,"spawn":spawn,"look_direction":direction,"axis":axis,"side":side,"half_length":19,"width":width,"height":tall,"floor":floor_y,"path":path,"branches":branches,"footprint":footprint,"shape":"u" if is_u else "winding"}
func caves_at_column(x: int,z: int) -> Array:
	if version<5:
		return legacy_caves_at_column(x,z)
	var key:=Vector2i(x,z)
	if cave_columns.has(key):
		return cave_columns[key]
	var result: Array=[]
	if zones.profile(x,z).weights.z>0.35:
		var gx: int=floori(float(x)/64)
		var gz: int=floori(float(z)/64)
		for a in range(gx-1,gx+2):
			for b in range(gz-1,gz+2):
				var cave: Dictionary=cave_for_tile(a,b)
				if not cave.is_empty() and cave.footprint.has(key):
					result.append(cave)
	cave_columns[key]=result
	return result

func cave_lining(cell: Vector3i) -> bool:
	for offset in [Vector2i.ZERO,Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
		for c in caves_at_column(cell.x+offset.x,cell.z+offset.y):
			if offset==Vector2i.ZERO:
				if cell.y>=int(c.floor)-1 and cell.y<=int(c.floor)+int(c.height):
					return true
			elif cell.y>=int(c.floor) and cell.y<int(c.floor)+int(c.height):
				return true
	return false
