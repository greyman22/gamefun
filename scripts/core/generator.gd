extends RefCounted

const VERSION: int = 3
const SEA_LEVEL: int = -2
const MAX_WATER_DEPTH: int = 12
var version: int=VERSION
const SIZE: int = 16
const MIN_Y: int = -64
const MAX_Y: int = 63
const HALF_WORLD: int = 1024
var seed_value: int
var noise := FastNoiseLite.new()
var column_cache: Dictionary = {}
var tree_cache: Dictionary = {}

func _init(world_seed: int = 20261030, generation_version: int=VERSION) -> void:
	version=generation_version
	seed_value = world_seed
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
	# A seed-specific hill keeps the familiar starting area recognisable.
	var center := Vector2(-10 + hash_at(1, 2) % 4, 11)
	var radius: float = 5.0 + hash_at(3, 4) % 3
	var hill: float = maxf(0, 1.0 - Vector2(x - center.x, z - center.y).length() / radius)
	value += floori(hill * (3 + hash_at(5, 6) % 3))
	if version>=3:
		var carve: float=water_bed(x,z)
		var shore_blend: float=smoothstep(26.0,46.0,distance)
		value=roundi(lerpf(value,minf(value,carve),shore_blend))
		value=maxi(SEA_LEVEL-MAX_WATER_DEPTH,value)
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
	if (version<3 or height(x,z)>=SEA_LEVEL) and h % 5 != 0 and Vector2(x, z).length() > 15 and absi(x) < HALF_WORLD - 3 and absi(z) < HALF_WORLD - 3:
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
	if cell.y < MIN_Y or absi(cell.x) >= HALF_WORLD or absi(cell.z) >= HALF_WORLD:
		return 7
	if cell.y > MAX_Y:
		return 0
	if cell.y >= height(cell.x, cell.z):
		return 21 if version>=3 and cell.y<SEA_LEVEL else 0
	var gx: int = floori(float(cell.x) / 2) * 2
	var gz: int = floori(float(cell.z) / 2) * 2
	var gy: int = floori(float(cell.y) / 2) * 2
	var surface: int = mini(mini(height(gx, gz), height(gx + 1, gz)), mini(height(gx, gz + 1), height(gx + 1, gz + 1)))
	if gy + 1 > surface - 4:
		return 30 if version>=3 and height(cell.x,cell.z)<SEA_LEVEL else 2
	return 1 if hash_at(gx + gy * 117, gz, 41) % 100 < (90 if gy < surface - 12 else 65) else 2

func generate(key: Vector3i) -> PackedByteArray:
	if column_cache.size() > 8192:
		column_cache.clear()
	if tree_cache.size() > 2048:
		tree_cache.clear()
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

func water_bed(x: int, z: int) -> float:
	var lake_x: int=roundi(float(x-100)/320)
	var lake_z: int=roundi(float(z-80)/320)
	var bottom: float=64
	for gx in range(lake_x-1,lake_x+2):
		for gz in range(lake_z-1,lake_z+2):
			var h: int=hash_at(gx,gz,1103)
			var center:=Vector2(gx*320+100+h%23-11,gz*320+80+(h/31)%23-11)
			var rx: float=85+h%31
			var rz: float=65+(h/101)%26
			var delta:=Vector2((x-center.x)/rx,(z-center.y)/rz)
			var r: float=delta.length()+noise.get_noise_2d(x*0.7,z*0.7)*0.08
			bottom=minf(bottom,SEA_LEVEL+2-(MAX_WATER_DEPTH+2)*(1-smoothstep(0.2,1.15,r)))
	var phase: float=float(hash_at(1,9,1117)%628)/100
	for row in range(lake_z-1,lake_z+2):
		var bend: float=sin(x*0.018+phase)*17+sin(x*0.047-phase)*6
		var width: float=3+17*(0.5+0.5*sin(x*0.009+row*1.7+phase))
		var d: float=absf(z-(row*320+80+bend))
		bottom=minf(bottom,river_bed(d,width))
	for column in range(lake_x-1,lake_x+2):
		var bend: float=sin(z*0.015-phase)*21+sin(z*0.041+phase)*5
		var width: float=3+17*(0.5+0.5*sin(z*0.011+column*1.3-phase))
		var d: float=absf(x-(column*320+100+bend))
		bottom=minf(bottom,river_bed(d,width))
	return bottom
func river_bed(distance: float, width: float) -> float:
	var half_width: float=width*0.5
	if distance>half_width+2:
		return 64
	# Full channel width is below water; banks rise over the next two metres.
	if distance<=half_width:
		return SEA_LEVEL-1-(2+width*0.12)*(1-pow(distance/maxf(half_width,0.1),2))
	return lerpf(SEA_LEVEL-1,SEA_LEVEL+3,(distance-half_width)/2)
