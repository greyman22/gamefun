extends "res://scripts/hen.gd"
var drowning: float=0
var woolly: bool=true

func configure(data: RefCounted, value: Dictionary) -> void:
	super.configure(data,value)
	wander_radius=30
	swims=false
	navigation.max_drop=1
	drowning=float(record.get("state",{}).get("drowning",0))
	health=float(record.get("state",{}).get("health",Combat.stats("lamb" if chick else "sheep").health))
	record.defense=Combat.stats("lamb" if chick else "sheep").defense

func _ready() -> void:
	super._ready()
	var area: Area3D=get_child(0)
	var collider: CollisionShape3D=area.get_child(0)
	collider.shape.size=Vector3(0.82,1.15,1.0)
	collider.position.y=0.575

func build() -> void:
	if is_instance_valid(visual):
		remove_child(visual)
		visual.queue_free()
	if chick and Hens.adult(record,model.game_time) and health>0:
		health=Combat.grown_health(record,"sheep")
	chick=not Hens.adult(record,model.game_time)
	woolly=model.game_time>=float(record.get("wool_at",0))
	resting=Hens.resting(record,model.game_time)
	legs.clear()
	wings.clear()
	visual=Node3D.new()
	add_child(visual)
	visual.scale=Vector3.ONE*(0.52 if chick else 1.0)
	var fleece:=Color("e9e6dc") if not resting else Color("c7bdde")
	var skin:=Color("b5a091")
	part(Vector3(0,0.68,0),Vector3(0.66,0.56,0.88) if woolly else Vector3(0.5,0.4,0.75),fleece if woolly else skin)
	if woolly:
		for x in [-1,1]:
			for z in [-1,0,1]:
				part(Vector3(x*0.32,0.72,z*0.26),Vector3(0.13,0.3,0.25),fleece.darkened(0.04))
	part(Vector3(0,0.91,-0.48),Vector3(0.34,0.37,0.37),skin)
	part(Vector3(0,1.08,-0.43),Vector3(0.37,0.13,0.31),fleece if woolly else skin)
	part(Vector3(0,0.81,-0.68),Vector3(0.26,0.16,0.08),Color("796d65"))
	for side in [-1,1]:
		part(Vector3(side*0.23,0.97,-0.43),Vector3(0.16,0.09,0.17),skin)
		part(Vector3(side*0.174,0.98,-0.57),Vector3(0.025,0.055,0.06),Color("24242a"))
		for z in [-0.28,0.28]:
			var leg:=Node3D.new()
			leg.position=Vector3(side*0.21,0.4,z)
			visual.add_child(leg)
			legs.append(leg)
			var mat:=StandardMaterial3D.new()
			mat.albedo_color=skin
			Visuals.tool_part(leg,Vector3(0,-0.16,0),Vector3(0.12,0.33,0.12),mat)
			mat=StandardMaterial3D.new()
			mat.albedo_color=Color("49433e")
			Visuals.tool_part(leg,Vector3(0,-0.35,0),Vector3(0.14,0.1,0.17),mat)

func simulate(delta: float, lure: Variant=null) -> void:
	if woolly!=(model.game_time>=float(record.get("wool_at",0))):
		build()
	# Follow wheat only across dry terrain. A sheep already in water seeks shore.
	var dry_lure: Variant=lure
	if lure is Vector3 and not Hens.dry_land(model,Vector3i(lure.floor())):
		dry_lure=null
	move_bird(delta,dry_lure)
	var level: float=cached_water
	var wet: bool=is_finite(level) and position.y<=level+0.12
	if wet:
		drowning+=delta
		visual.position.y=-0.45
	else:
		drowning=0
		visual.position.y=0
		# Terrain can be removed below a sheep, including into water.
		if step_time>=1 and not Registry.cube(model.sample_block(Vector3i((position-Vector3(0,0.08,0)).floor()))):
			position.y-=delta*3
			step_from=position
			step_to=position

func serialize_state() -> Dictionary:
	var state: Dictionary=super.serialize_state()
	state.drowning=drowning
	return state

func body_width() -> float:
	return 0.23 if chick else 0.4

func body_height() -> float:
	return 0.6 if chick else 1.15
