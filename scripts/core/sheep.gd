extends RefCounted
const Hens=preload("res://scripts/core/hens.gd")
const Registry=preload("res://scripts/core/registry.gd")
const DROWN_SECONDS: float=10

const SHEEP_SEPARATION: float=10
const PAIRED_GROUP_DISTANCE: int=50

static func grouping_gap(mode: String) -> int:
	return 100 if mode=="debug" else 160

static func group_centers(_model: RefCounted, gx: int, gz: int, mode: String) -> Array[Vector3]:
	# The pitch includes the pair's own 50m span, so neighboring pairings
	# actually have the requested gap instead of merging into one uniform grid.
	var pitch: int=grouping_gap(mode)+PAIRED_GROUP_DISTANCE
	var anchor:=Vector3(gx*pitch+33,0,gz*pitch+34)
	return [anchor+Vector3(-25,0,0),anchor+Vector3(25,0,0)]

static func legacy_group_near(model: RefCounted, point: Vector3, mode: String) -> bool:
	# Existing flocks/pets are preserved; do not double-populate visited old areas.
	var old: Dictionary=model.landmarks.get("sheep_groups",{})
	var spacing: int=50 if mode=="debug" else 80
	var gx: int=floori((point.x-33)/spacing)
	var gz: int=floori((point.z-34)/spacing)
	for x in range(gx-1,gx+2):
		for z in range(gz-1,gz+2):
			var key: String="%s:%d,%d"%[mode,x,z]
			if old.has(key) and Vector2(old[key].x-point.x,old[key].z-point.z).length()<spacing*0.9:
				return true
	return false

static func spawn_position(model: RefCounted, desired: Vector3) -> Variant:
	for candidate in range(82):
		var dx: int=0 if candidate==0 else (candidate-1)%9-4
		var dz: int=0 if candidate==0 else (candidate-1)/9-4
		var point:=Vector3(floorf(desired.x)+dx+0.5,0,floorf(desired.z)+dz+0.5)
		point.y=model.generator.height(floori(point.x),floori(point.z))
		if absf(point.x)>model.generator.world_limit()-2 or absf(point.z)>model.generator.world_limit()-2:
			continue
		var cell:=Vector3i(point.floor())
		if not Hens.dry_land(model,cell) or model.sample_kind(cell)!="air" or not Registry.cube(model.sample_block(cell+Vector3i.DOWN)) or not Hens.Space.clear(model,point,0.43,1.15):
			continue
		var free: bool=true
		for record: Dictionary in model.entities.values():
			if record.type not in ["sheep","hen","zombie","skeleton"] or record.get("state",{}).get("dead",false):
				continue
			var gap: float=Vector2(record.position.x-point.x,record.position.z-point.z).length()
			if (record.type=="sheep" and gap<SHEEP_SEPARATION) or (gap<0.9 and absf(record.position.y-point.y)<1.5):
				free=false
				break
		if free:
			return point
	return null

static func ensure_nearby(model: RefCounted, position: Vector3, mode: String) -> void:
	var pitch: int=grouping_gap(mode)+PAIRED_GROUP_DISTANCE
	var groups: Dictionary=model.landmarks.get_or_add("sheep_clusters",{})
	var gx: int=floori(position.x/pitch)
	var gz: int=floori(position.z/pitch)
	for x in range(gx-1,gx+2):
		for z in range(gz-1,gz+2):
			var centers: Array[Vector3]=group_centers(model,x,z,mode)
			for group in range(2):
				var point: Vector3=centers[group]
				var key: String="%s:%d,%d:%d"%[mode,x,z,group]
				if groups.has(key) or Vector2(point.x-position.x,point.z-position.z).length()>75 or absf(point.x)>model.generator.world_limit()-16 or absf(point.z)>model.generator.world_limit()-16:
					continue
				groups[key]=point
				if legacy_group_near(model,point,mode):
					continue
				var count: int=3+model.generator.hash_at(x*2+group,z,1007)%2
				for i in range(count):
					var desired: Vector3=point+Vector3(-5 if i%2==0 else 5,0,-5 if i<2 else 5)
					var spawn: Variant=spawn_position(model,desired)
					if spawn==null:
						continue
					var id: String="sheep_cluster_%s_%d"%[key,i]
					Hens.create(model,id,spawn,spawn,mode,model.generator.hash_at(x*11+group*4+i,z,1019)%100<20,"sheep")
					model.entities[id].group_center=point

static func shear(system: Node, id: String, collector: Variant = null) -> bool:
	if not system.model.entities.has(id):
		return false
	var record: Dictionary=system.model.entities[id]
	if record.type!="sheep" or not Hens.adult(record,system.model.game_time) or system.model.game_time<float(record.get("wool_at",0)):
		return false
	record.wool_at=system.model.game_time+randf_range(30,60 if system.game_mode=="debug" else 240)
	record.last_shear_yield=randi_range(1,3)
	for i in range(int(record.last_shear_yield)):
		var drop: String=system.spawn_drop("wool",record.position+Vector3(0,0.65,0))
		if collector is Vector3:
			system.model.entities[drop].needs_approach=true
			system.model.entities[drop].collection_origin=collector
	if system.active.has(id):
		system.active[id].build()
	return true

static func tick(system: Node, delta: float) -> void:
	Hens.tick(system,delta,"sheep")
	for id: String in system.active.keys():
		if not system.model.entities.has(id) or system.model.entities[id].type!="sheep":
			continue
		var actor: Node3D=system.active[id]
		if actor.drowning>=DROWN_SECONDS:
			var record: Dictionary=system.model.entities[id]
			var point: Vector3=actor.position+Vector3(0,0.4,0)
			Hens.cancel_pair(system.model,record)
			system.deactivate(id)
			system.model.entities.erase(id)
			system.spawn_drop("raw_mutton",point)
			for i in range(randi_range(1,3)):
				system.spawn_drop("wool",point)
