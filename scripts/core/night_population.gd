extends RefCounted
const Cycle=preload("res://scripts/core/day_cycle.gd")
const Homes=preload("res://scripts/core/animal_homes.gd")
const Space=preload("res://scripts/core/actor_space.gd")
const Hens=preload("res://scripts/core/hens.gd")
const MIN_COUNT: int=15
const MAX_COUNT: int=20
const MIN_RADIUS: float=40
const MAX_RADIUS: float=100
const TORCH_RADIUS: float=10
const MIN_LIFE: float=120
const MAX_LIFE: float=300
const CLEANUP_PHASE: String="Gryning"
var elapsed: float=0
var nearby_count: int=0
var target_count: int=0
var attempts: int=0
var work_budget_usec: int=1500
var max_candidates: int=12
var max_spawns: int=2

static func state(model: RefCounted) -> Dictionary:
	return model.landmarks.get_or_add("night_population",{"clock":0.0,"target":0,"night_key":"","serial":0})

static func night(model: RefCounted) -> bool:
	return Cycle.phase(model)=="Natt"

static func cleanup(model: RefCounted) -> bool:
	return Cycle.phase(model)==CLEANUP_PHASE

static func torch_safe(point: Vector3, torches: Array[Vector3]) -> bool:
	for torch in torches:
		if point.distance_squared_to(torch)<=TORCH_RADIUS*TORCH_RADIUS:
			return false
	return true

static func torches(model: RefCounted) -> Array[Vector3]:
	var points: Array[Vector3]=[]
	for record: Dictionary in model.entities.values():
		if record.type=="torch":
			points.append(record.position)
	return points

static func suitable(model: RefCounted, point: Vector3, player: Vector3, lights: Array[Vector3]) -> bool:
	var distance: float=point.distance_to(player)
	return distance>=MIN_RADIUS and distance<=MAX_RADIUS and torch_safe(point,lights) and Hens.valid_home(model,point) and Space.clear(model,point,0.34,1.95)

func candidate(model: RefCounted, player: Vector3, lights: Array[Vector3]) -> Variant:
	attempts+=1
	var angle: float=randf()*TAU
	var radius: float=sqrt(randf_range(MIN_RADIUS*MIN_RADIUS,MAX_RADIUS*MAX_RADIUS))
	var desired: Vector3=player+Vector3(cos(angle),0,sin(angle))*radius
	var point: Variant=Homes.surface(model,floori(desired.x),floori(desired.z),player.y)
	if not point is Vector3 or not suitable(model,point,player,lights):
		return null
	# Avoid creating bodies on top of existing animals or monsters.
	for record: Dictionary in model.entities.values():
		if record.type in ["zombie","skeleton","hen","sheep"] and not record.get("state",{}).get("dead",false) and point.distance_squared_to(record.position)<4:
			return null
	return point

func spawn(system: Node, point: Vector3, values: Dictionary) -> String:
	var species: String="skeleton" if randi()%4==0 else "zombie"
	values.serial=int(values.serial)+1
	var id: String="night_zombie_%d"%int(values.serial)
	while system.model.entities.has(id):
		values.serial=int(values.serial)+1
		id="night_zombie_%d"%int(values.serial)
	system.model.entities[id]={"type":species,"night_spawn":true,"night_engaged":false,"position":point,"home":point,"spawn_position":point,"expires_real":float(values.clock)+randf_range(MIN_LIFE,MAX_LIFE),"state":{"wait":randf_range(0,1.5)}}
	system.elapsed=1
	return id

func tick(system: Node, player: Vector3, delta: float) -> void:
	var model: RefCounted=system.model
	var values: Dictionary=state(model)
	values.clock=float(values.clock)+maxf(0,delta)
	elapsed+=maxf(0,delta)
	if elapsed<0.25:
		return
	elapsed=0
	var is_night: bool=night(model)
	var is_cleanup: bool=cleanup(model)
	if is_night:
		var clock: Dictionary=Cycle.state(model)
		var night_day: int=int(clock.day)-(1 if Cycle.hour(model)<4 else 0)
		var night_key: String=str(night_day)
		if str(values.night_key)!=night_key or int(values.target)<MIN_COUNT:
			values.night_key=night_key
			values.target=randi_range(MIN_COUNT,MAX_COUNT)
	target_count=int(values.target) if is_night else 0
	nearby_count=0
	var live: Array[String]=[]
	var rehome: Array[String]=[]
	var cleanup_key: String="%d:%s"%[int(Cycle.state(model).day),CLEANUP_PHASE]
	for id: String in model.entities.keys():
		var record: Dictionary=model.entities[id]
		if record.type not in ["zombie","skeleton"] or record.get("state",{}).get("dead",false):
			continue
		if system.active.has(id):
			record.position=system.active[id].position
		if is_cleanup and str(record.get("cleanup_key",""))!=cleanup_key:
			var end_minute: float=1320 if CLEANUP_PHASE=="Skymning" else 300
			var seconds: float=maxf(0.2,(end_minute-float(Cycle.state(model).minute))/1440*(Cycle.DEBUG_DAY_SECONDS if system.game_mode=="debug" else Cycle.REAL_DAY_SECONDS))
			record.cleanup_key=cleanup_key
			record.cleanup_at_real=float(values.clock)+randf_range(0.1,maxf(0.1,seconds-0.1))
		var timed_out: bool=record.get("night_spawn",false) and float(values.clock)>=float(record.get("expires_real",INF))
		var fading: bool=record.has("cleanup_at_real") and (float(values.clock)>=float(record.cleanup_at_real) or not is_cleanup)
		var distance: float=record.position.distance_to(player)
		var away: bool=record.get("night_spawn",false) and not record.get("night_engaged",false) and distance>MAX_RADIUS
		if timed_out or fading or away:
			system.mark_dead(id,system.death_respawn_delay)
			continue
		if distance<=MAX_RADIUS:
			nearby_count+=1
		if not record.get("night_spawn",false):
			continue
		live.append(id)
		if is_night and not record.get("night_engaged",false):
			var home_distance: float=record.home.distance_to(player)
			if home_distance<MIN_RADIUS or home_distance>MAX_RADIUS:
				rehome.append(id)
	# If old pursuers re-enter the ring, retire surplus ordinary roamers first.
	# Engaged enemies keep their promised home/lifetime instead of vanishing mid-chase.
	if nearby_count>MAX_COUNT:
		live.sort_custom(func(a: String,b: String) -> bool: return model.entities[a].position.distance_squared_to(player)>model.entities[b].position.distance_squared_to(player))
		for id: String in live:
			var record: Dictionary=model.entities[id]
			if nearby_count<=MAX_COUNT:
				break
			if not record.get("night_engaged",false) and record.position.distance_to(player)<=MAX_RADIUS:
				system.mark_dead(id,system.death_respawn_delay)
				nearby_count-=1
	if not is_night:
		return
	var lights: Array[Vector3]=torches(model)
	var stamp: int=Time.get_ticks_usec()
	var spawned: int=0
	for trial in range(max_candidates):
		if Time.get_ticks_usec()-stamp>=work_budget_usec or (nearby_count>=target_count and rehome.is_empty()):
			break
		var point: Variant=candidate(model,player,lights)
		if not point is Vector3:
			continue
		if not rehome.is_empty():
			var id: String=rehome.pop_front()
			var record: Dictionary=model.entities[id]
			record.home=point
			record.spawn_position=point
			record.state["behavior"]="return"
			record.state["goal"]=point
			if system.active.has(id):
				var actor: Node3D=system.active[id]
				actor.home=point
				actor.origin=point
				actor.set_behavior("return")
				actor.goal=point
				actor.behavior_elapsed=0
			continue
		if spawned>=max_spawns:
			break
		spawn(system,point,values)
		nearby_count+=1
		spawned+=1
