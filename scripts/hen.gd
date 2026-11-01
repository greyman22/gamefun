extends Node3D
const Combat = preload("res://scripts/core/combat.gd")
const Space = preload("res://scripts/core/actor_space.gd")
const Knockback = preload("res://scripts/core/knockback.gd")
var knockback = Knockback.new()
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
var wait: float = 0
var route: Array[Vector3] = []
var resting: bool = false
var pursuit_allowed: bool = true
var following_soul: bool = false
var phase: float = 0
var step_from := Vector3.ZERO
var step_to := Vector3.ZERO
var step_time: float = 1

func configure(data: RefCounted, value: Dictionary) -> void:
	model = data
	record = value
	navigation.model = data
	navigation.max_drop = 8
	var state: Dictionary = record.get("state", {})
	step_from = state.get("step_from", record.position)
	step_to = state.get("step_to", record.position)
	step_time = float(state.get("step_time", 1))
	gliding = bool(state.get("gliding",false))
	glide_duration = float(state.get("glide_duration",1))
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
		health = float(Combat.stats("hen").health)
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

func simulate(delta: float, soul_lure: Variant = null) -> void:
	if resting != Hens.resting(record, model.game_time):
		build()
	hurt_time = maxf(0, hurt_time - delta)
	visual.scale = Vector3.ONE * (0.52 if chick else 1.0) * (1.0 + hurt_time * 0.25)
	if knockback.active():
		var movement: Vector3 = knockback.step(delta)
		var steps: int = maxi(1, ceili(movement.length() / 0.04))
		for index in range(steps):
			for axis in [0, 2]:
				var next := position
				next[axis] += movement[axis] / steps
				if Vector2(next.x - record.home.x, next.z - record.home.z).length() <= 15 and Space.clear(model, next, 0.15 if chick else 0.25, 0.45 if chick else 0.9):
					var shift := next - position
					position = next
					step_from += shift
					step_to += shift
	var attracted: bool = pursuit_allowed and soul_lure is Vector3 and position.distance_to(soul_lure) <= 10.0
	if attracted != following_soul:
		route.clear()
		wait = 0
		following_soul = attracted
	if chick == Hens.adult(record, model.game_time):
		build()
	phase += delta
	for index in range(hearts.size()):
		var remaining: float = float(record.get("hearts_until", 0)) - model.game_time
		hearts[index].visible = remaining > 0
		hearts[index].position = Vector3(cos(index * TAU / 4) * 0.4, 0.9 + (1.5 - remaining) * 0.5, sin(index * TAU / 4) * 0.4)
	if step_time < 1:
		step_time = minf(1,step_time+delta/glide_duration if gliding else step_time+delta*1.3)
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
		for index in range(legs.size()):
			legs[index].rotation.x = -0.45 if gliding else sin(phase * 12 + index * PI) * 0.45
		visual.rotation.z = 0.0 if gliding else sin(phase * 12) * 0.07
		return
	gliding=false
	for wing in wings:
		wing.rotation.z=0
	visual.rotation.z = 0
	for leg in legs:
		leg.rotation.x = 0
	wait -= delta
	if wait > 0 and not attracted:
		return
	var target: Vector3 = record.home
	var partner: String = record.get("partner", "")
	if model.entities.has(partner):
		target = model.entities[partner].position
		if Hens.mating_close(position, target):
			return
		route.clear()
		if Vector3i(position.floor()) == Vector3i(target.floor()):
			position = position.move_toward(target, delta * 1.3)
			return
	elif attracted:
		target = soul_lure
		route.clear()
		if Vector2(position.x - target.x, position.z - target.z).length() <= 1.1 and absf(position.y-target.y)<=1.0:
			return
	elif route.is_empty():
		var angle := randf() * TAU
		target += Vector3(cos(angle), 0, sin(angle)) * randf_range(1, 13)
		target.y = model.generator.height(floori(target.x), floori(target.z))
	if route.is_empty():
		route = navigation.path(position, target)
	if route.is_empty():
		wait = 1
		return
	var next: Vector3 = route.pop_front()
	if Vector2(next.x - record.home.x, next.z - record.home.z).length() > 15:
		route.clear()
		return
	step_from = position
	step_to = next
	step_time = 0
	gliding = step_from.y-step_to.y>1.05
	glide_duration = 0.5+maxf(0,step_from.y-step_to.y)/1.8
	look_at(Vector3(next.x, position.y, next.z))
	if route.is_empty() and partner.is_empty() and not attracted:
		wait = randf_range(1, 3)

func serialize_state() -> Dictionary:
	return {"step_from":step_from, "step_to":step_to, "step_time":step_time, "phase":phase, "gliding":gliding,"glide_duration":glide_duration, "health":health, "was_chick":chick, "knockback":knockback.snapshot()}

func receive_hit(amount: float) -> void:
	health = maxf(0, health - amount)
	hurt_time = 0.2
	wait = 0
	route.clear()

func apply_knockback(attacker: Vector3, damage: float) -> void:
	knockback.start(attacker, position, damage)
