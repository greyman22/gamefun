extends RefCounted
const Registry=preload("res://scripts/core/registry.gd")
const Combat=preload("res://scripts/core/combat.gd")
const Visuals=preload("res://scripts/item_visuals.gd")
const MAX_PROJECTILES: int=64

static func spawn(system: Node, owner: String, origin: Vector3, velocity: Vector3, attack: float, team: String, gravity: float=6.0) -> String:
	var flights: Array=system.projectile_ids.keys()
	if flights.size()>=MAX_PROJECTILES:
		remove(system,flights[0])
	var id: String="arrow_%d_%d"%[Time.get_ticks_usec(),randi()]
	system.model.entities[id]={"type":"arrow_flight","position":origin,"velocity":velocity,"direction":velocity.normalized(),"attack":attack,"owner":owner,"origin":origin,"team":team,"gravity":gravity,"remaining":6.0,"stuck":false}
	system.activate(id,system.model.entities[id])
	return id

static func remove(system: Node, id: String) -> void:
	system.projectile_ids.erase(id)
	system.deactivate(id)
	system.model.entities.erase(id)

static func first_wall(model: RefCounted, from: Vector3, to: Vector3) -> Variant:
	var steps: int=maxi(1,ceili(from.distance_to(to)/0.1))
	for i in range(steps+1):
		var point: Vector3=from.lerp(to,float(i)/steps)
		if Registry.cube(model.sample_block(Vector3i(point.floor()))):
			return point
	return null

static func tick(system: Node, delta: float, player: CharacterBody3D=null) -> void:
	for id: String in system.projectile_ids.keys():
		if not system.model.entities.has(id):
			system.projectile_ids.erase(id)
			continue
		var record: Dictionary=system.model.entities[id]
		if record.type!="arrow_flight":
			continue
		record.remaining=float(record.remaining)-delta
		if record.remaining<=0:
			remove(system,id)
			continue
		if record.stuck:
			continue
		var from: Vector3=record.position
		var velocity: Vector3=record.velocity
		var to: Vector3=from+velocity*delta+Vector3.DOWN*float(record.gravity)*delta*delta*0.5
		velocity.y-=float(record.gravity)*delta
		var wall: Variant=first_wall(system.model,from,to)
		var end: Vector3=wall if wall is Vector3 else to
		var hit_point: Variant=null
		var target: String=""
		if record.team=="enemy" and player!=null:
			hit_point=AABB(player.position-Vector3(0.3,0,0.3),Vector3(0.6,1.8,0.6)).intersects_segment(from,end)
			if hit_point is Vector3:
				target="player"
		elif record.team=="player":
			var closest: float=INF
			for actor_id: String in system.active:
				if not system.model.entities.has(actor_id):
					continue
				var actor_record: Dictionary=system.model.entities[actor_id]
				if actor_record.type not in ["zombie","skeleton","hen","sheep"] or actor_record.get("state",{}).get("dead",false):
					continue
				var actor: Node3D=system.active[actor_id]
				var tall: float=1.9 if actor_record.type in ["zombie","skeleton"] else (0.5 if actor.chick else 1.15)
				var point: Variant=AABB(actor.position-Vector3(0.34,0,0.34),Vector3(0.68,tall,0.68)).intersects_segment(from,end)
				if point is Vector3 and from.distance_squared_to(point)<closest:
					closest=from.distance_squared_to(point)
					hit_point=point
					target=actor_id
		if not target.is_empty():
			remove(system,id)
			if target=="player":
				player.receive_attack(Combat.damage(float(record.attack),float(Combat.stats("player").defense)),record.origin,"arrow")
			else:
				var actor_record: Dictionary=system.model.entities[target]
				var defense: float=float(actor_record.get("defense",Combat.stats(actor_record.type).defense))
				system.damage_actor(target,Combat.damage(float(record.attack),defense),system.death_respawn_delay,record.origin)
			continue
		record.position=end
		record.velocity=velocity
		record.direction=velocity.normalized()
		if wall is Vector3:
			record.stuck=true
			record.remaining=300.0
			# Leave the shaft outside the surface, with the tip embedded.
			record.position=end-record.direction*0.32*Visuals.PROJECTILE_ARROW_SCALE
		if system.active.has(id):
			system.active[id].update_flight(record)
