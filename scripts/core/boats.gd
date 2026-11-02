extends RefCounted
const Registry=preload("res://scripts/core/registry.gd")
const Water=preload("res://scripts/core/water.gd")
const SPEED: float=6.0
static func surface(model: RefCounted, point: Vector3) -> float:
	var cell:=Vector3i(point.floor())
	for dy in [0,-1,1]:
		var test: Vector3i=cell+Vector3i.UP*dy
		var kind: String=model.kind_at(test)
		if Water.wet(kind):
			return float(test.y)+Water.height(kind)
	return -INF
static func clear(model: RefCounted, point: Vector3, yaw: float) -> bool:
	var basis:=Basis(Vector3.UP,yaw)
	for x in [-0.42,0.42]:
		for z in [-0.88,0.0,0.88]:
			var sample: Vector3=point+basis*Vector3(x,0,z)
			var level: float=surface(model,sample-Vector3.UP*0.25)
			if not is_finite(level) or absf(level-point.y)>0.35:
				return false
			for y in [0.1,0.65,1.5]:
				if Registry.cube(model.block(Vector3i((sample+Vector3.UP*y).floor()))):
					return false
	return true
static func launch(system: Node, point: Vector3, yaw: float) -> String:
	var level: float=surface(system.model,point-Vector3.UP*0.1)
	if not is_finite(level):
		return ""
	point.y=level
	if not clear(system.model,point,yaw):
		return ""
	for record in system.model.entities.values():
		if record.type=="boat" and record.position.distance_to(point)<2.2:
			return ""
	var id: String="boat_%d_%d"%[Time.get_ticks_usec(),randi()]
	system.model.entities[id]={"type":"boat","kind":"boat","position":point,"state":{"yaw":yaw,"hits":0}}
	system.activate(id,system.model.entities[id])
	return id
static func pick(world: Node) -> String:
	var start: Vector3=world.player.camera.global_position
	var finish: Vector3=start-world.player.camera.global_basis.z*5.0
	var query:=PhysicsRayQueryParameters3D.create(start,finish,33,[world.player.get_rid()])
	query.collide_with_areas=true
	var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(query)
	return str(hit.collider.get_meta("boat_id","")) if not hit.is_empty() else ""
static func board(world: Node, id: String) -> bool:
	if not world.entity_system.active.has(id):
		return false
	var boat: Node3D=world.entity_system.active[id]
	world.mounted_boat=id
	world.player.riding_boat=boat
	world.player.position=boat.position+Vector3.UP*0.12
	world.player.velocity=Vector3.ZERO
	world.player.reset_fall_tracking()
	world.player.camera.position.y=1.0
	return true
static func leave(world: Node) -> void:
	if is_instance_valid(world.entity_system) and world.entity_system.active.has(world.mounted_boat):
		world.entity_system.active[world.mounted_boat].moving=false
	world.mounted_boat=""
	world.player.riding_boat=null
	world.player.camera.position.y=world.player.STANDING_EYE_HEIGHT
	world.player.reset_fall_tracking()
static func move(world: Node, delta: float, axis: Vector2) -> void:
	if not world.entity_system.active.has(world.mounted_boat):
		leave(world)
		return
	var boat: Node3D=world.entity_system.active[world.mounted_boat]
	var direction: Vector3=world.player.global_basis*Vector3(axis.x,0,axis.y)
	direction.y=0
	direction=direction.limit_length(1.0)
	var desired_yaw: float=boat.rotation.y if direction.is_zero_approx() else atan2(-direction.x,-direction.z)
	# Turning also checks the whole hull so the bow cannot rotate into a bank.
	var yaw: float=lerp_angle(boat.rotation.y,desired_yaw,minf(1,delta*7))
	if clear(world.model,boat.position,yaw):
		boat.rotation.y=yaw
	var movement: Vector3=direction*SPEED*delta
	var steps: int=maxi(1,ceili(movement.length()/0.1))
	var start: Vector3=boat.position
	for step in range(steps):
		for component in [0,2]:
			var candidate: Vector3=boat.position
			candidate[component]+=movement[component]/steps
			if clear(world.model,candidate,boat.rotation.y):
				boat.position=candidate
	boat.moving=start.distance_squared_to(boat.position)>0.000001
	world.model.entities[world.mounted_boat].position=boat.position
	world.model.entities[world.mounted_boat].state=boat.serialize_state()
	world.player.position=boat.position+Vector3.UP*0.12
	world.player.velocity=Vector3.ZERO
static func hit(world: Node, id: String) -> void:
	if not world.model.entities.has(id):
		return
	var record: Dictionary=world.model.entities[id]
	record.state.hits=int(record.state.get("hits",0))+1
	if int(record.state.hits)<3:
		return
	if world.mounted_boat==id:
		leave(world)
	var point: Vector3=record.position+Vector3.UP*0.15
	world.entity_system.deactivate(id)
	world.model.entities.erase(id)
	var drop: String=world.entity_system.spawn_drop("boat",point)
	world.model.entities[drop].state.floating=true
	world.model.entities[drop].state.velocity_x=0
	world.model.entities[drop].state.velocity_z=0
