extends RefCounted
const Farming=preload("res://scripts/core/farming.gd")
const Berries=preload("res://scripts/core/berries.gd")
static func duration(mode: String) -> float:
	return randf_range(60,180) if mode=="debug" else randf_range(120,300)
static func plant(model: RefCounted, cell: Vector3i, mode: String, mature: bool=false) -> String:
	if model.kind_at(cell)!= "air" or model.kind_at(cell+Vector3i.DOWN) not in ["dirt","farmland"] or not Berries.at_cell(model,cell).is_empty():
		return ""
	for record: Dictionary in model.entities.values():
		if record.get("cell",Vector3i(0,-1000,0))==cell and record.type in ["crop","sapling"]:
			return ""
	Farming.remove_wild(model,cell)
	var duration: float=duration(mode)
	var id: String="cotton_%s_%d"%[model.text_key(cell),Time.get_ticks_usec()]
	model.entities[id]={"type":"cotton_plant","cell":cell,"position":Vector3(cell)+Vector3(0.5,0,0.5),"planted_at":model.game_time-duration if mature else model.game_time,"ripe_at":model.game_time if mature else model.game_time+duration,"growth_seconds":duration,"mode":mode}
	return id
static func stage(record: Dictionary,time: float) -> int:
	return clampi(floori((time-float(record.planted_at))/float(record.growth_seconds)*4),0,3)
static func harvest(model: RefCounted,id: String,tool: String) -> Dictionary:
	if not model.entities.has(id):
		return {}
	var record: Dictionary=model.entities[id]
	if tool=="stone_shears":
		if model.game_time<float(record.ripe_at):
			return {}
		record.growth_seconds=duration(record.get("mode","play"))
		record.planted_at=model.game_time
		record.ripe_at=model.game_time+float(record.growth_seconds)
		return {"cotton":randi_range(1,3)}
	model.entities.erase(id)
	return {"cotton_shoot":randi_range(1,2),"cotton":randi_range(1,3)}
static func ensure_nearby(model: RefCounted,position: Vector3,mode: String) -> void:
	var groups: Dictionary=model.landmarks.get_or_add("cotton_groups",{})
	var gx: int=floori(position.x/96)
	var gz: int=floori(position.z/96)
	for x in range(gx-1,gx+2):
		for z in range(gz-1,gz+2):
			var key: String="%d,%d"%[x,z]
			if groups.has(key):
				continue
			var cx: int=x*96+24+model.generator.hash_at(x,z,713)%32
			var cz: int=z*96+24+model.generator.hash_at(x,z,719)%32
			if Vector2(cx-position.x,cz-position.z).length()>72:
				continue
			groups[key]=true
			for offset in [Vector2i.ZERO,Vector2i(2,1),Vector2i(-1,2)]:
				var px: int=cx+offset.x
				var pz: int=cz+offset.y
				plant(model,Vector3i(px,model.generator.height(px,pz),pz),mode,true)
