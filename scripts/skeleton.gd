extends "res://scripts/zombie.gd"
signal arrow_released(origin: Vector3, velocity: Vector3, attack_value: float)
const Visuals=preload("res://scripts/item_visuals.gd")
const Arrows=preload("res://scripts/core/arrows.gd")
const Homes=preload("res://scripts/core/animal_homes.gd")
var bow_visual: Node3D
var drawn_arrow: Node3D
var cover_point: Variant=null
var peek_point: Variant=null
var cover_trunk:=Vector3i.ZERO
var cover_player:=Vector3(INF,INF,INF)
var cover_elapsed: float=0

func configure(data: RefCounted, value: Dictionary) -> void:
	# Upgrade saved skeletons once, preserving their remaining health percentage.
	if int(value.get("health_revision",0))<1:
		if value.get("state",{}).has("health"):
			value.state.health=float(value.state.health)*2
		value.health_revision=1
	super.configure(data,value)
	var stats: Dictionary=Combat.stats("skeleton")
	if not record.has("defense"):
		record.defense=randi_range(int(stats.defense_min),int(stats.defense_max))
	cover_elapsed=rest_offset/10
	var state: Dictionary=record.get("state",{})
	cover_point=state.get("cover_point")
	peek_point=state.get("peek_point")
	cover_trunk=state.get("cover_trunk",Vector3i.ZERO)

func build_body() -> void:
	visual=Node3D.new()
	add_child(visual)
	var bone:=material(Color("ddd8c5"))
	var joint:=material(Color("ada894"))
	var dark:=material(Color("25282b"))
	# Hollow rib cage, separate thin limbs, spine and a recognisable skull.
	part(visual,Vector3(0,1.24,0.1),Vector3(0.075,0.62,0.08),bone)
	for y in [1.1,1.22,1.34,1.46]:
		for side in [-1,1]:
			part(visual,Vector3(side*0.16,y,0),Vector3(0.22,0.045,0.22),bone)
	part(visual,Vector3(0,0.93,0),Vector3(0.41,0.13,0.2),bone)
	part(visual,Vector3(0,1.75,-0.02),Vector3(0.43,0.4,0.36),bone)
	for x in [-0.105,0.105]:
		part(visual,Vector3(x,1.79,-0.205),Vector3(0.105,0.115,0.012),dark)
	part(visual,Vector3(0,1.69,-0.207),Vector3(0.055,0.055,0.014),dark)
	part(visual,Vector3(0,1.6,-0.19),Vector3(0.29,0.06,0.08),joint)
	for x in [-0.1,-0.05,0,0.05,0.1]:
		part(visual,Vector3(x,1.62,-0.235),Vector3(0.032,0.065,0.025),bone)
	left_leg=limb(Vector3(-0.145,0.9,0),Vector3(0.085,0.86,0.085),bone)
	right_leg=limb(Vector3(0.145,0.9,0),Vector3(0.085,0.86,0.085),bone)
	left_arm=limb(Vector3(-0.33,1.46,0),Vector3(0.085,0.68,0.085),bone)
	right_arm=limb(Vector3(0.33,1.46,0),Vector3(0.085,0.68,0.085),bone)
	for leg in [left_leg,right_leg]:
		part(leg,Vector3(0,-0.81,-0.055),Vector3(0.14,0.1,0.24),joint)
	for arm in [left_arm,right_arm]:
		part(arm,Vector3(0,-0.65,0),Vector3(0.13,0.1,0.12),bone)
	bow_visual=Visuals.bow_model(left_arm,1.5)
	bow_visual.position=Vector3(0,-0.66,0)
	bow_visual.rotation.y=PI/2
	drawn_arrow=Visuals.arrow_model(bow_visual,0.8)
	drawn_arrow.rotation.y=-PI/2
	drawn_arrow.hide()

func update_behavior(delta: float, player: CharacterBody3D) -> void:
	cover_elapsed-=delta
	if player!=null and pursuit_allowed and (behavior=="chase" or position.distance_to(player.position)<float(Combat.stats("skeleton").aggro_start)) and cover_elapsed<=0:
		cover_elapsed=1.5
		if cover_point==null or model.sample_kind(cover_trunk)!="wood" or cover_player.distance_squared_to(player.position)>4:
			choose_cover(player.position)
	super.update_behavior(delta,player)

func hold_range(player: CharacterBody3D, distance: float) -> bool:
	return cover_point==null and distance<=float(Combat.stats("skeleton").stand_off) and sight_to(player.position)

func behavior_destination(player: CharacterBody3D) -> Vector3:
	if behavior!="chase":
		return origin
	if cover_point is Vector3 and peek_point is Vector3:
		return peek_point if attack_cooldown<2.4 or strike_time>=0 else cover_point
	return player.position

func choose_cover(player: Vector3) -> void:
	cover_player=player
	cover_point=null
	peek_point=null
	var candidates: Dictionary={}
	var key: Vector3i=model.key(Vector3i(position.floor()))
	for x in range(key.x-1,key.x+2):
		for z in range(key.z-1,key.z+2):
			for tree: Dictionary in model.generator.trees_in_chunk(Vector3i(x,key.y,z)):
				candidates[tree.base]=true
			for y in range(key.y-1,key.y+2):
				var chunk:=Vector3i(x,y,z)
				for index: int in model.edits.get(chunk,{}):
					if int(model.edits[chunk][index])==Registry.id("wood"):
						candidates[chunk*16+Vector3i(index%16,(index/16)%16,index/256)]=true
	var ordered: Array=candidates.keys()
	ordered.sort_custom(func(a: Vector3i,b: Vector3i) -> bool: return Vector3(a).distance_squared_to(position)<Vector3(b).distance_squared_to(position))
	var best: float=INF
	for i in range(mini(ordered.size(),12)):
		var trunk: Vector3i=ordered[i]
		var center:=Vector3(trunk)+Vector3(0.5,0,0.5)
		if center.distance_to(position)>10 or model.sample_kind(trunk)!="wood":
			continue
		var away: Vector3=center-player
		away.y=0
		if away.length_squared()<0.1:
			continue
		away=away.normalized()
		var desired: Vector3=center+away*1.0
		var hidden: Variant=Homes.surface(model,floori(desired.x),floori(desired.z),position.y)
		if not hidden is Vector3 or not clear_at(hidden):
			continue
		# Require the trunk to actually occlude the hiding position.
		if Arrows.first_wall(model,hidden+Vector3.UP*1.3,player+Vector3.UP*1.0)==null:
			continue
		var side: Vector3=Vector3(-away.z,0,away.x)
		for sign_value in [-1,1]:
			var desired_peek: Vector3=hidden+side*sign_value*1.4
			var peek: Variant=Homes.surface(model,floori(desired_peek.x),floori(desired_peek.z),hidden.y)
			if not peek is Vector3 or not clear_at(peek) or peek.distance_to(player)>float(Combat.stats("skeleton").reach) or absf(peek.y-hidden.y)>1:
				continue
			if Arrows.first_wall(model,peek+Vector3.UP*1.45,player+Vector3.UP*1.0)!=null:
				continue
			var cost: float=position.distance_to(hidden)+absf(peek.distance_to(player)-9)*0.25
			if cost<best:
				best=cost
				cover_point=hidden
				peek_point=peek
				cover_trunk=trunk

func can_hit(player: CharacterBody3D) -> bool:
	if player==null or behavior!="chase" or not pursuit_allowed or position.distance_to(player.position)>float(Combat.stats("skeleton").reach):
		return false
	return Arrows.first_wall(model,muzzle(),player.position+Vector3.UP*1.0)==null

func muzzle() -> Vector3:
	return position+Vector3.UP*1.44-global_basis.z*0.65-global_basis.x*0.25

func attack(player: CharacterBody3D) -> void:
	if health<=0 or attack_cooldown>0 or strike_time>=0 or hopping or knockback.active() or not can_hit(player):
		return
	attack_cooldown=float(Combat.stats("skeleton").interval)
	strike_time=0
	strike_hit=false
	rotation.y=atan2(position.x-player.position.x,position.z-player.position.z)
	animate(false,0)

func advance_strike(delta: float, player: CharacterBody3D) -> void:
	if strike_time<0:
		return
	strike_time+=delta
	if player!=null:
		rotation.y=atan2(position.x-player.position.x,position.z-player.position.z)
	var stats: Dictionary=Combat.stats("skeleton")
	if strike_time>=float(stats.aim_seconds) and not strike_hit:
		strike_hit=true
		if can_hit(player):
			var from: Vector3=muzzle()
			var target: Vector3=player.position+Vector3.UP*1.0
			var distance: float=from.distance_to(target)
			var spread: float=tan(deg_to_rad(float(stats.spread_degrees)+distance*float(stats.spread_per_meter)))*distance
			var right: Vector3=(target-from).normalized().cross(Vector3.UP).normalized()
			var angle: float=randf()*TAU
			var radius: float=sqrt(randf())*spread
			target+=right*cos(angle)*radius+Vector3.UP*sin(angle)*radius*0.6
			var travel: float=maxf(0.05,distance/float(stats.projectile_speed))
			var velocity: Vector3=(target-from)/travel+Vector3.UP*float(stats.projectile_gravity)*travel*0.5
			arrow_released.emit(from,velocity,randf_range(float(stats.attack_min),float(stats.attack_max)))
	if strike_time>=float(stats.aim_seconds)+0.25:
		strike_time=-1

func animate(walking: bool, delta: float) -> void:
	if not is_instance_valid(left_leg):
		return
	walk_time+=delta*(6 if walking else 1)
	var stride: float=sin(walk_time)*0.4 if walking else 0
	left_leg.rotation.x=stride
	right_leg.rotation.x=-stride
	var drawing: bool=strike_time>=0 and not strike_hit
	var amount: float=clampf(strike_time/float(Combat.stats("skeleton").aim_seconds),0,1) if drawing else 0
	left_arm.rotation=Vector3(lerpf(1.1,1.58,amount),0,-0.08)
	right_arm.rotation=Vector3(lerpf(0.35,1.45,amount),lerpf(0,0.85,amount),0)
	bow_visual.basis=(left_arm.basis.inverse()*Basis(Vector3.UP,PI/2)).scaled(Vector3.ONE*1.5)
	Visuals.bow_draw(bow_visual,amount)
	drawn_arrow.visible=drawing
	drawn_arrow.position=Vector3(-0.06-amount*0.15,0,0)
	for surface: Dictionary in surfaces:
		surface.material.albedo_color=(surface.base as Color).lerp(Color(1,0.35,0.25),hurt_time/0.22*0.7)
	health_caption.global_position=global_position+Vector3.UP*2.2
	health_caption.visible=health<max_health or behavior=="chase"
	health_caption.text="Skelett · %d %%"%ceili(health/max_health*100)

func serialize_state() -> Dictionary:
	var state: Dictionary=super.serialize_state()
	state.cover_point=cover_point
	state.peek_point=peek_point
	state.cover_trunk=cover_trunk
	return state
