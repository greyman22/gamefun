extends RefCounted
const Registry = preload("res://scripts/core/registry.gd")
const Berries = preload("res://scripts/core/berries.gd")
const MEADOW_SIZE: int = 80
const REGION_SIZE: int = 128
const WILD_HARVEST_SECONDS: float = 0.2
const HEIGHT_PATCH_SIZE: int = 6
static func meadow(model: RefCounted, x: int, z: int) -> bool:
	var gx: int = floori(float(x)/REGION_SIZE)
	var gz: int = floori(float(z)/REGION_SIZE)
	return posmod(x,REGION_SIZE)<MEADOW_SIZE and posmod(z,REGION_SIZE)<MEADOW_SIZE and ((gx==0 and gz==0) or model.generator.hash_at(gx,gz,601)%100<60)
static func wild_height(model: RefCounted, cell: Vector3i) -> float:
	# Shared height per small seeded patch makes tall grass form cover rather
	# than isolated random stalks. Occupancy remains the existing 25% mask.
	var gx: int = floori(float(cell.x+model.generator.hash_at(0,0,617)%6)/HEIGHT_PATCH_SIZE)
	var gz: int = floori(float(cell.z+model.generator.hash_at(0,0,619)%6)/HEIGHT_PATCH_SIZE)
	var group: int = model.generator.hash_at(floori(float(gx)/3),gz,613)
	var lane: int = posmod(gx,3) if group%2==0 else 2-posmod(gx,3)
	return [0.6,0.95,1.9][(lane+group%3)%3]
static func wild_width(model: RefCounted, cell: Vector3i) -> float:
	var height: float=wild_height(model,cell)
	return 1.4 if height>1.0 else (1.0 if height>0.6 else 0.6)
static func wild_at(model: RefCounted, cell: Vector3i) -> bool:
	if not meadow(model,cell.x,cell.z) or model.generator.hash_at(cell.x,cell.z,607)%100>=25:
		return false
	if cell.y!=model.generator.height(cell.x,cell.z):
		return false
	if model.landmarks.get("grass_removed",{}).has(model.text_key(cell)):
		return false
	return model.kind_at(cell)=="air" and model.kind_at(cell+Vector3i.DOWN)=="dirt" and Berries.at_cell(model,cell).is_empty()
static func crop_at(model: RefCounted, cell: Vector3i) -> String:
	for id: String in model.entities:
		if model.entities[id].type=="crop" and model.entities[id].cell==cell:
			return id
	return ""
static func stage(record: Dictionary, time: float) -> int:
	var duration: float = float(record.ripe_at)-float(record.planted_at)
	return clampi(floori((time-float(record.planted_at))/maxf(1,duration)*4),0,3)
static func ripe(record: Dictionary, time: float) -> bool:
	return time>=float(record.ripe_at)
static func remove_wild(model: RefCounted, cell: Vector3i) -> void:
	if not model.landmarks.has("grass_removed"):
		model.landmarks.grass_removed={}
	model.landmarks.grass_removed[model.text_key(cell)]=true
static func till(model: RefCounted, cell: Vector3i) -> bool:
	if model.kind_at(cell)!="dirt" or model.kind_at(cell+Vector3i.UP)!="air" or not Berries.at_cell(model,cell+Vector3i.UP).is_empty():
		return false
	remove_wild(model,cell+Vector3i.UP)
	return model.set_block(cell,"farmland")
static func plant(model: RefCounted, cell: Vector3i, mode: String) -> String:
	if model.kind_at(cell+Vector3i.DOWN)!="farmland" or model.kind_at(cell)!="air" or not crop_at(model,cell).is_empty() or not Berries.at_cell(model,cell).is_empty():
		return ""
	var duration: float = randi_range(60,120) if mode=="debug" else randi_range(240,480)
	var id: String = "crop_%s_%d"%[model.text_key(cell),Time.get_ticks_usec()]
	model.entities[id]={"type":"crop","kind":"grain","cell":cell,"position":Vector3(cell)+Vector3(0.5,0,0.5),"planted_at":model.game_time,"ripe_at":model.game_time+duration,"state":{}}
	return id
static func harvest_seconds(target: Dictionary, tool: String) -> float:
	return WILD_HARVEST_SECONDS if target.get("wild",false) else (0.7 if Registry.tool(tool) else 3.0)
static func harvest(model: RefCounted, target: Dictionary) -> Dictionary:
	if target.is_empty():
		return {}
	if target.get("wild",false):
		if not wild_at(model,target.cell):
			return {}
		remove_wild(model,target.cell)
		return {"grass_seed":1} if randf()<0.2 else {}
	var id: String = target.get("id","")
	if not model.entities.has(id) or not ripe(model.entities[id],model.game_time):
		return {}
	model.entities.erase(id)
	return {"grain":1,"grass_seed":randi_range(1,3)}
static func pick(model: RefCounted, start: Vector3, finish: Vector3) -> Dictionary:
	var best: Dictionary = {}
	var distance: float = start.distance_to(finish)+0.001
	for id: String in model.entities:
		var record: Dictionary = model.entities[id]
		if record.type!="crop" or start.distance_to(record.position)>7:
			continue
		var hit: Variant = AABB(record.position-Vector3(0.35,0,0.35),Vector3(0.7,1.0,0.7)).intersects_segment(start,finish)
		if hit!=null and start.distance_to(hit)<distance:
			distance=start.distance_to(hit)
			best={"wild":false,"id":id,"cell":record.cell,"point":hit}
	var seen: Dictionary = {}
	var steps: int = maxi(1,ceili(start.distance_to(finish)/0.08))
	for step in range(steps+1):
		var point: Vector3 = start.lerp(finish,float(step)/steps)
		for dx in [-1,0,1]:
			for dz in [-1,0,1]:
				var x: int=floori(point.x)+dx
				var z: int=floori(point.z)+dz
				var column:=Vector2i(x,z)
				if seen.has(column):
					continue
				seen[column]=true
				var cell:=Vector3i(x,model.generator.height(x,z),z)
				if wild_at(model,cell):
					var width: float=wild_width(model,cell)
					var hit: Variant=AABB(Vector3(cell)+Vector3(0.5-width/2,0,0.5-width/2),Vector3(width,wild_height(model,cell),width)).intersects_segment(start,finish)
					if hit!=null and start.distance_to(hit)<distance:
						distance=start.distance_to(hit)
						best={"wild":true,"cell":cell,"point":hit}
	return best
