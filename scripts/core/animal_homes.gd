extends RefCounted
const Hens=preload("res://scripts/core/hens.gd")
const Space=preload("res://scripts/core/actor_space.gd")
var queue: Array[String]=[]
var work_budget_usec: int=1500
var max_candidates: int=12

static func spacing(species: String) -> float:
	return 10.0 if species=="sheep" else Hens.HOME_SPACING

static func surface(model: RefCounted, x: int, z: int, near_y: float) -> Variant:
	if abs(x)>model.generator.world_limit()-2 or abs(z)>model.generator.world_limit()-2:
		return null
	var water_top: float=Hens.water_level(model,Vector3(x+0.5,near_y,z+0.5))
	var natural: int=model.generator.height(x,z)
	var levels: Array[int]=[]
	for offset in [0,1,-1,2,-2,3,-3,4,-4]:
		var y: int=floori(near_y)+offset
		if not levels.has(y):
			levels.append(y)
	if not levels.has(natural):
		levels.append(natural)
	for y in levels:
		if is_finite(water_top) and y<water_top:
			continue
		var point:=Vector3(x+0.5,y,z+0.5)
		if Hens.valid_home(model,point):
			return point
	return null

static func inland(model: RefCounted, point: Vector3) -> bool:
	# A dry patch around the home keeps a released flock off the shoreline.
	for offset in [Vector2i(3,0),Vector2i(-3,0),Vector2i(0,3),Vector2i(0,-3),Vector2i(2,2),Vector2i(-2,2),Vector2i(2,-2),Vector2i(-2,-2)]:
		if surface(model,floori(point.x)+offset.x,floori(point.z)+offset.y,point.y)==null:
			return false
	return true

func tick(system: Node) -> void:
	var released: Array[String]=[]
	var following_hens: int=0
	for id: String in system.active:
		if not system.model.entities.has(id):
			continue
		var record: Dictionary=system.model.entities[id]
		if record.type not in ["hen","sheep"]:
			continue
		var actor: Node3D=system.active[id]
		var lure: Variant=system.grain_lure if record.type=="sheep" else system.seed_lure
		var lured: bool=actor.pursuit_allowed and lure is Vector3 and actor.position.distance_squared_to(lure)<=100
		if record.type=="hen" and actor.following_seeds:
			following_hens+=1
		if lured and record.has("home_request"):
			record.erase("home_request")
			actor.home_pending=false
		if actor.following_seeds and not lured and not record.has("home_request"):
			released.append(id)
		if record.has("home_request") and not queue.has(id):
			queue.append(id)
	if following_hens>1:
		for id: String in system.active:
			if system.model.entities.has(id) and system.model.entities[id].type=="hen" and system.active[id].following_seeds:
				system.model.entities[id].flock_lured=true
	for id: String in released:
		var record: Dictionary=system.model.entities[id]
		var actor: Node3D=system.active[id]
		record.home_request={"origin":actor.position,"index":0,"inland":record.type=="hen" and (following_hens>1 or record.get("flock_lured",false)),"retry_at":0.0}
		actor.home_pending=true
		if not queue.has(id):
			queue.append(id)
	var stamp: int=Time.get_ticks_usec()
	var checked: int=0
	var initial: int=queue.size()
	var sleeping: int=0
	while not queue.is_empty() and checked<max_candidates and Time.get_ticks_usec()-stamp<work_budget_usec:
		var id: String=queue.pop_front()
		if not system.model.entities.has(id) or not system.active.has(id):
			continue
		var record: Dictionary=system.model.entities[id]
		if not record.has("home_request"):
			continue
		var job: Dictionary=record.home_request
		if float(job.retry_at)>system.model.game_time:
			queue.append(id)
			sleeping+=1
			if sleeping>=initial:
				break
			continue
		checked+=1
		var index: int=int(job.index)
		var strict: bool=bool(job.inland) and index<257
		var sample_index: int=index%257
		var origin: Vector3=job.origin
		var radius: float=0 if sample_index==0 else (2 if index<257 else 4)*(1+(sample_index-1)/16)
		var angle: float=TAU*((sample_index-1)%16)/16 if sample_index>0 else 0
		var desired: Vector3=origin+Vector3(cos(angle),0,sin(angle))*radius
		var point: Variant=surface(system.model,floori(desired.x),floori(desired.z),origin.y)
		if point is Vector3 and valid(system.model,id,point,strict):
			record.home=point
			record.settling_home=true
			record.erase("home_request")
			record.erase("flock_lured")
			var actor: Node3D=system.active[id]
			actor.home_pending=false
			actor.route.clear()
			actor.decision_elapsed=0
		else:
			job.index=index+1
			if job.index>=514:
				job.index=0
				job.retry_at=system.model.game_time+2
			queue.append(id)

static func valid(model: RefCounted, id: String, point: Vector3, prefer_inland: bool) -> bool:
	var record: Dictionary=model.entities[id]
	if not Space.clear(model,point,0.43 if record.type=="sheep" else 0.25,1.15 if record.type=="sheep" else 0.92):
		return false
	var gap: float=spacing(record.type)
	for other_id: String in model.entities:
		var other: Dictionary=model.entities[other_id]
		if other_id==id or other.type!=record.type or other.get("state",{}).get("dead",false) or other.has("home_request"):
			continue
		var home: Vector3=other.get("home",other.position)
		if Vector2(home.x-point.x,home.z-point.z).length()<gap:
			return false
	return not prefer_inland or inland(model,point)
