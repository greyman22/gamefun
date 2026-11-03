extends Node3D
const Combat = preload("res://scripts/core/combat.gd")
const Registry=preload("res://scripts/core/registry.gd")
const Space = preload("res://scripts/core/actor_space.gd")
const Knockback = preload("res://scripts/core/knockback.gd")
var knockback = Knockback.new()
var wander_radius: float = 20
var swims: bool = true
var flee_until: float = 0
var flee_from: Vector3 = Vector3.ZERO
var health: float = 24
var hurt_time: float = 0
const Hens = preload("res://scripts/core/hens.gd")
const Visuals = preload("res://scripts/item_visuals.gd")
const Navigation = preload("res://scripts/core/zombie_navigation.gd")
var model: RefCounted
var record: Dictionary
var navigation = Navigation.new()
var visual: Node3D
var hearts: Array[Label3D] = []
var legs: Array[Node3D] = []
var wings: Array[Node3D] = []
var gliding: bool = false
var glide_duration: float = 1
var chick: bool = false
var decision_interval: float=0.25
var decision_elapsed: float=0
var route_target:=Vector3(INF,INF,INF)
var route_revision: int=-1
var rest_offset: float=0
var idling: bool=false
var water_column:=Vector2i(2147483647,2147483647)
var water_check: float=0
var cached_water: float=-INF
var support_cell:=Vector3i(2147483647,2147483647,2147483647)
var support_check: float=0
var supported: bool=true
var wait: float = 0
var route: Array[Vector3] = []
var resting: bool = false
var pursuit_allowed: bool = true
var following_seeds: bool = false
var home_pending: bool=false
var family_following: bool=false
var family_check: float=0
var family_leader: String=""
var swimming: bool=false
var shore_retry: float=0
var phase: float = 0
var step_from := Vector3.ZERO
var step_to := Vector3.ZERO
var step_time: float = 1

func configure(data: RefCounted, value: Dictionary) -> void:
	model = data
	record = value
	home_pending=record.has("home_request")
	family_leader=str(record.get("adult_leader",""))
	navigation.model = data
	rest_offset=float(absi(str(record.position).hash())%1000)/100
	decision_elapsed=rest_offset/10
	navigation.max_drop = 8
	navigation.avoid_water=true
	var species: String="sheep" if record.get("type", "hen")=="sheep" else "hen"
	var young_kind: String="lamb" if species=="sheep" else "chick"
	Combat.starting_health(record,species if Hens.adult(record,model.game_time) else young_kind)
	var state: Dictionary = record.get("state", {})
	rest_offset=float(state.get("rest_offset",rest_offset))
	flee_until=float(state.get("flee_until",0))
	flee_from=state.get("flee_from",record.position)
	step_from = state.get("step_from", record.position)
	step_to = state.get("step_to", record.position)
	step_time = float(state.get("step_time", 1))
	gliding = bool(state.get("gliding",false))
	glide_duration = float(state.get("glide_duration",1))
	following_seeds=bool(state.get("following_seeds",false))
	phase = float(state.get("phase", 0))
	health = float(state.get("health", Combat.stats("hen" if Hens.adult(record, model.game_time) else "chick").health))
	chick = bool(state.get("was_chick", not Hens.adult(record, model.game_time)))
	knockback.restore(state.get("knockback", {}))
	if not record.has("defense"):
		var stats: Dictionary = Combat.stats("hen")
		record.defense = stats.rare_defense if absi(str(record.position).hash()) % 100 < int(stats.rare_defense_percent) else stats.defense

func _ready() -> void:
	var area := Area3D.new()
	area.collision_layer = 8
	area.collision_mask = 0
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.55, 0.8, 0.6)
	collision.shape = shape
	collision.position.y = 0.4
	area.add_child(collision)
	add_child(area)
	for index in range(4):
		var heart := Label3D.new()
		heart.text = "\u2665"
		heart.visible=false
		heart.modulate = Color(1, 0.22, 0.35)
		heart.font_size = 48
		heart.pixel_size = 0.007
		heart.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		add_child(heart)
		hearts.append(heart)
	build()

func part(point: Vector3, dimensions: Vector3, color: Color) -> MeshInstance3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	return Visuals.tool_part(visual, point, dimensions, material)

func build() -> void:
	if is_instance_valid(visual):
		remove_child(visual)
		visual.queue_free()
	if chick and Hens.adult(record, model.game_time) and health > 0:
		health = Combat.grown_health(record,"hen")
	chick = not Hens.adult(record, model.game_time)
	legs.clear()
	wings.clear()
	visual = Node3D.new()
	add_child(visual)
	visual.scale = Vector3.ONE * (0.52 if chick else 1.0)
	resting = Hens.resting(record, model.game_time)
	var feathers := Color("f5d255") if chick else (Color("a475d1") if resting else Color("f1eee1"))
	part(Vector3(0, 0.4, 0), Vector3(0.44, 0.42, 0.5), feathers)
	part(Vector3(0, 0.7, -0.19), Vector3(0.29, 0.31, 0.29), feathers)
	part(Vector3(0, 0.66, -0.39), Vector3(0.16, 0.1, 0.16), Color("e6a42f"))
	part(Vector3(0, 0.87, -0.17), Vector3(0.09, 0.1, 0.2), Color("d43834"))
	part(Vector3(0, 0.55, -0.3), Vector3(0.09, 0.14, 0.08), Color("d43834"))
	for side in [-1, 1]:
		part(Vector3(side * 0.15, 0.75, -0.28), Vector3(0.025, 0.045, 0.045), Color("171c21"))
		wings.append(part(Vector3(side * 0.25, 0.42, 0.02), Vector3(0.09, 0.27, 0.34), feathers.darkened(0.12)))
		var leg := Node3D.new()
		leg.position = Vector3(side * 0.12, 0.2, 0.01)
		visual.add_child(leg)
		legs.append(leg)
		var orange := StandardMaterial3D.new()
		orange.albedo_color = Color("d59232")
		Visuals.tool_part(leg, Vector3(0, -0.08, 0), Vector3(0.045, 0.24, 0.045), orange)
		Visuals.tool_part(leg, Vector3(0, -0.175, -0.07), Vector3(0.12, 0.05, 0.21), orange)

func simulate(delta: float, seed_lure: Variant = null) -> void:
	move_bird(delta,seed_lure)
	pose_swimming()

func move_bird(delta: float, seed_lure: Variant = null) -> void:
	update_family(delta)
	var family_target: Variant=family_position()
	if resting != Hens.resting(record, model.game_time):
		build()
	if chick == Hens.adult(record,model.game_time):
		build()
	decision_elapsed=maxf(0,decision_elapsed-delta)
	water_check-=delta
	support_check-=delta
	var feet_cell:=Vector3i((position-Vector3.UP*0.05).floor())
	if support_check<=0 or feet_cell!=support_cell:
		support_cell=feet_cell
		supported=Registry.cube(model.sample_block(feet_cell)) and not Hens.Water.wet(model.sample_kind(Vector3i(position.floor())))
		support_check=0.25
	var urgent: bool=knockback.active() or model.game_time<flee_until or seed_lure is Vector3 and pursuit_allowed and position.distance_squared_to(seed_lure)<=100 or not str(record.get("partner","")).is_empty() or model.game_time<float(record.get("love_until",0)) or following_seeds or family_target is Vector3 or home_pending or record.get("settling_home",false) or swimming or not supported
	idling=not urgent and step_time>=1 and fposmod(model.game_time+rest_offset,10.0)<4.5
	if idling:
		# Keep safety/lifecycle checks, but no navigation, water scans or pose rebuilds.
		if hurt_time>0:
			hurt_time=maxf(0,hurt_time-delta)
			visual.scale=Vector3.ONE*(0.52 if chick else 1.0)*(1+hurt_time*0.25)
		for leg in legs:
			leg.rotation.x=0
		visual.rotation.z=0
		for heart in hearts:
			heart.hide()
		return
	hurt_time = maxf(0, hurt_time - delta)
	visual.scale = Vector3.ONE * (0.52 if chick else 1.0) * (1.0 + hurt_time * 0.25)
	if knockback.active():
		var movement: Vector3 = knockback.step(delta)
		var steps: int = maxi(1, ceili(movement.length() / 0.04))
		for index in range(steps):
			for axis in [0, 2]:
				var next := position
				next[axis] += movement[axis] / steps
				if (following_seeds or family_following or record.get("settling_home",false) or Vector2(position.x-record.home.x,position.z-record.home.z).length()>wander_radius or Vector2(next.x - record.home.x, next.z - record.home.z).length() <= wander_radius) and Space.clear(model, next, body_width(),body_height()):
					var shift := next - position
					position = next
					step_from += shift
					step_to += shift
	var fleeing: bool=model.game_time<flee_until
	var attracted: bool = not fleeing and pursuit_allowed and seed_lure is Vector3 and position.distance_to(seed_lure) <= 10.0
	var column:=Vector2i(floori(position.x),floori(position.z))
	if water_check<=0 or column!=water_column:
		water_column=column
		cached_water=Hens.water_level(model,position)
		water_check=0.15 if swimming else 0.3
	var water_level: float=cached_water
	swimming=is_finite(water_level) and position.y<=water_level+0.12
	if swimming:
		position.y=water_level
		if step_time>=1:
			step_from=position
			step_to=position
	shore_retry=maxf(0,shore_retry-delta)
	if swimming and not attracted and not Hens.valid_home(model,record.home) and shore_retry<=0:
		var home: Variant=Hens.land_home(model,position,record.home)
		if home is Vector3:
			record.home=home
			route.clear()
		shore_retry=2
	navigation.allow_swim=swims and (attracted or swimming or family_target is Vector3)
	if attracted != following_seeds:
		decision_elapsed=0
		if following_seeds and not attracted:
			if not home_pending and not record.get("settling_home",false):
				var home: Variant=Hens.land_home(model,position,record.home)
				if home is Vector3:
					record.home=home
			# Discard the remaining follow step, not just its queued path.
			if not gliding or swimming:
				step_from=position
				step_to=position
				step_time=1
				gliding=false
		route.clear()
		wait = 0
		following_seeds = attracted
	if chick == Hens.adult(record, model.game_time):
		build()
	phase += delta
	for index in range(hearts.size()):
		var remaining: float = float(record.get("hearts_until", 0)) - model.game_time
		hearts[index].visible = remaining > 0
		hearts[index].position = Vector3(cos(index * TAU / 4) * 0.4, 0.9 + (1.5 - remaining) * 0.5, sin(index * TAU / 4) * 0.4)
	if home_pending and not attracted and not fleeing and not swimming:
		return
	if step_time < 1:
		step_time = minf(1,step_time+delta/glide_duration if gliding else step_time+delta*(0.85 if swimming else (6.0 if fleeing else (2.6 if attracted or family_target is Vector3 else 1.3))))
		position = step_from.lerp(step_to, step_time)
		var level_change: float = absf(step_to.y - step_from.y)
		if gliding:
			# First clear the roof edge at its original height, then flutter down.
			position = step_from.lerp(step_to,minf(1,step_time/0.25))
			position.y = lerpf(step_from.y,step_to.y,smoothstep(0.25,1.0,step_time))
			for i in range(wings.size()):
				wings[i].rotation.z = (-1 if i==0 else 1)*(0.85+sin(phase*20)*0.45)
		elif level_change > 0.1:
			position.y += sin(step_time * PI) * (0.2 + level_change * 0.5)
		var level: float=cached_water
		if is_finite(level) and position.y<level:
			position.y=level
		for index in range(legs.size()):
			legs[index].rotation.x = -0.45 if gliding else sin(phase * (20 if attracted else 12) + index * PI) * 0.45
		visual.rotation.z = 0.0 if gliding else sin(phase * 12) * 0.07
		return
	gliding=false
	for wing in wings:
		wing.rotation.z=0
	visual.rotation.z = 0
	for leg in legs:
		leg.rotation.x = 0
	wait -= delta
	if wait > 0 and not attracted and not swimming and not fleeing and not family_target is Vector3 and not record.get("settling_home",false):
		return
	var target: Vector3 = record.home
	var partner: String = record.get("partner", "")
	if fleeing:
		var away: Vector3=position-flee_from
		away.y=0
		if away.length_squared()<0.01:
			away=Vector3.RIGHT
		target=position+away.normalized()*6
	elif swimming and not attracted:
		target=record.home
	elif model.entities.has(partner):
		target = model.entities[partner].position
		if Hens.mating_close(position, target):
			return
		if Vector3i(position.floor()) == Vector3i(target.floor()):
			position = position.move_toward(target, delta * 1.3)
			return
	elif attracted:
		target = seed_lure
		if Vector2(position.x - target.x, position.z - target.z).length() <= 1.1 and absf(position.y-target.y)<=1.0:
			return
		if Vector3i(position.floor())==Vector3i(target.floor()):
			# Grid navigation has no path inside its starting cell. Complete the
			# last short approach continuously, while keeping feet on ground.
			var offset: Vector3=target-position
			offset.y=0
			var candidate: Vector3=position+offset.normalized()*minf(delta*(0.85 if swimming else 2.6),maxf(0,offset.length()-1.0))
			var floor_cell:=Vector3i((candidate-Vector3(0,0.05,0)).floor())
			if (Registry.cube(model.sample_block(floor_cell)) or swimming) and Space.clear(model,candidate,body_width(),body_height()):
				position=candidate
				step_from=position
				step_to=position
				for index in range(legs.size()):
					legs[index].rotation.x=sin(phase*20+index*PI)*0.45
			return
	elif family_target is Vector3:
		target=family_target
		if Vector2(position.x-target.x,position.z-target.z).length()<=1.8 and absf(position.y-target.y)<=1.1:
			route.clear()
			return
	elif record.get("settling_home",false):
		if position.distance_to(record.home)<0.65:
			record.settling_home=false
			route.clear()
			return
		target=record.home
	elif route.is_empty():
		if Vector2(position.x-record.home.x,position.z-record.home.z).length()<=wander_radius:
			var angle := randf() * TAU
			target += Vector3(cos(angle), 0, sin(angle)) * randf_range(1, wander_radius-2)
			target.y = model.generator.height(floori(target.x), floori(target.z))
	var revision: int=navigation.budget.revision if navigation.budget!=null else 0
	var changed: bool=route_target.distance_squared_to(target)>2.25 or route_revision!=revision
	if changed and decision_elapsed<=0:
		route.clear()
	if route.is_empty():
		if decision_elapsed>0:
			return
		var found: Array[Vector3]=navigation.path(position,target)
		if navigation.deferred:
			return
		route=found
		route_target=target
		route_revision=revision
		decision_elapsed=decision_interval if not route.is_empty() else maxf(0.5,decision_interval)
	if route.is_empty():
		return
	# Validate the next step after digging/building, rather than following stale paths.
	navigation.visited_checks.clear()
	if not navigation.clear_at(Vector3i(route[0].floor())):
		route.clear()
		decision_elapsed=0.1
		return
	var next: Vector3 = route.pop_front()
	if not attracted and not fleeing and not family_target is Vector3 and not record.get("settling_home",false) and Vector2(position.x-record.home.x,position.z-record.home.z).length()<=wander_radius and Vector2(next.x - record.home.x, next.z - record.home.z).length() > wander_radius:
		route.clear()
		return
	step_from = position
	step_to = next
	step_time = 0
	gliding = step_from.y-step_to.y>1.05
	glide_duration = 0.5+maxf(0,step_from.y-step_to.y)/1.8
	look_at(Vector3(next.x, position.y, next.z))
	if route.is_empty() and partner.is_empty() and not attracted and not swimming:
		wait = 0

func serialize_state() -> Dictionary:
	return {"rest_offset":rest_offset,"flee_until":flee_until,"flee_from":flee_from,"following_seeds":following_seeds,"step_from":step_from, "step_to":step_to, "step_time":step_time, "phase":phase, "gliding":gliding,"glide_duration":glide_duration, "health":health, "was_chick":chick, "knockback":knockback.snapshot()}

func receive_hit(amount: float) -> void:
	health = maxf(0, health - amount)
	hurt_time = 0.2
	wait = 0
	route.clear()

func apply_knockback(attacker: Vector3, damage: float) -> void:
	knockback.start(attacker, position, damage)
	flee_from=attacker
	flee_until=model.game_time+4
	step_time=1
	step_from=position
	step_to=position
	route.clear()
	decision_elapsed=0
	Hens.cancel_pair(model,record)

func pose_swimming() -> void:
	if not is_instance_valid(visual):
		return
	if not swimming:
		visual.position.y=0
		visual.rotation.x=0
		if not gliding:
			for wing in wings:
				wing.rotation.z=0
		return
	var size: float=0.52 if chick else 1.0
	# Immerse the body and feet, leaving the breast and head above the surface.
	visual.position.y=(-0.28+sin(phase*3)*0.012)*size
	visual.rotation.x=0.1+sin(phase*3)*0.018
	visual.rotation.z=sin(phase*3)*0.025
	for i in range(legs.size()):
		legs[i].rotation.x= -0.8+sin(phase*7+i*PI)*0.25
	for i in range(wings.size()):
		wings[i].rotation.z=(-1 if i==0 else 1)*(0.18+sin(phase*5+i*PI)*0.08)

func body_width() -> float:
	return 0.15 if chick else 0.25

func body_height() -> float:
	return 0.45 if chick else 0.9

func update_family(delta: float) -> void:
	if Hens.adult(record,model.game_time):
		family_following=false
		family_leader=""
		record.erase("adult_leader")
		return
	family_check-=delta
	if family_check>0:
		return
	family_check=0.5
	var previous: String=family_leader
	if not family_leader.is_empty():
		if not valid_adult(family_leader,20):
			family_leader=""
	if family_leader.is_empty():
		var nearest: float=144
		for id: String in model.entities:
			if valid_adult(id,12):
				var distance: float=position.distance_squared_to(model.entities[id].position)
				if distance<nearest:
					nearest=distance
					family_leader=id
	family_following=not family_leader.is_empty()
	if family_following:
		record.adult_leader=family_leader
	else:
		record.erase("adult_leader")
	if previous!=family_leader:
		route.clear()
		decision_elapsed=0

func valid_adult(id: String, distance: float) -> bool:
	if not model.entities.has(id):
		return false
	var other: Dictionary=model.entities[id]
	return other.type==record.type and Hens.adult(other,model.game_time) and not other.get("state",{}).get("dead",false) and position.distance_squared_to(other.position)<=distance*distance

func family_position() -> Variant:
	if not family_following or not model.entities.has(family_leader):
		return null
	var target: Vector3=model.entities[family_leader].position
	if not swims and not Hens.dry_land(model,Vector3i(target.floor())):
		return null
	return target
