extends Node3D

const Knockback = preload("res://scripts/core/knockback.gd")
var knockback = Knockback.new()
const Vitals = preload("res://scripts/core/vitals.gd")
var airborne: bool = false
var fall_peak: float = 0
const Combat = preload("res://scripts/core/combat.gd")
var pursuit_allowed: bool = true
var health: float = 100
const Registry = preload("res://scripts/core/registry.gd")
const RADIUS: float = 15.0
const Player = preload("res://scripts/player.gd")
const Navigation = preload("res://scripts/core/zombie_navigation.gd")
const SPEED: float = Player.SPEED / 3.0
var model: RefCounted
var home := Vector3.ZERO
var goal := Vector3.ZERO
var wait: float = 0
var walk_time: float = 0
var velocity_y: float = 0
var hopping: bool = false
var hop_from := Vector3.ZERO
var hop_to := Vector3.ZERO
var hop_time: float = 0
var attack_cooldown: float = 0
var left_leg: Node3D
var right_leg: Node3D
var left_arm: Node3D
var right_arm: Node3D
var origin := Vector3.ZERO
var behavior: String = "wander"
var navigation = Navigation.new()
var route: Array[Vector3] = []
var route_elapsed: float = 0
var strike_time: float = -1
var strike_hit: bool = false
var hurt_time: float = 0
var visual: Node3D
var surfaces: Array[Dictionary] = []
var health_caption: Label3D
var progress_anchor := Vector3.ZERO
var progress_elapsed: float = 0

func configure(data: RefCounted, record: Dictionary) -> void:
	model = data
	home = record.home
	origin = record.get("spawn_position", record.position)
	navigation.model = model
	goal = record.position
	progress_anchor = record.position
	restore_state(record.get("state", {}))

func _ready() -> void:
	visual = Node3D.new()
	add_child(visual)
	var skin := material(Color(0.3, 0.48, 0.2))
	var shirt := material(Color(0.17, 0.35, 0.38))
	var trousers := material(Color(0.22, 0.2, 0.32))
	var dark := material(Color(0.07, 0.1, 0.045))
	part(visual, Vector3(0, 1.14, 0), Vector3(0.56, 0.65, 0.3), shirt)
	part(visual, Vector3(0, 1.68, 0), Vector3(0.49, 0.46, 0.44), skin)
	for x in [-0.12, 0.12]:
		part(visual, Vector3(x, 1.72, -0.226), Vector3(0.09, 0.075, 0.025), dark)
	part(visual, Vector3(0, 1.55, -0.226), Vector3(0.24, 0.06, 0.025), dark)
	left_leg = limb(Vector3(-0.145, 0.83, 0), Vector3(0.24, 0.8, 0.27), trousers)
	right_leg = limb(Vector3(0.145, 0.83, 0), Vector3(0.24, 0.8, 0.27), trousers)
	left_arm = limb(Vector3(-0.4, 1.4, 0), Vector3(0.22, 0.68, 0.24), skin)
	right_arm = limb(Vector3(0.4, 1.4, 0), Vector3(0.22, 0.68, 0.24), skin)
	var hit_area := Area3D.new()
	hit_area.collision_layer = 2
	hit_area.collision_mask = 0
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.8, 1.9, 0.55)
	collision.shape = shape
	collision.position.y = 0.95
	hit_area.add_child(collision)
	add_child(hit_area)
	health_caption = Label3D.new()
	health_caption.position.y = 2.2
	health_caption.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	health_caption.font_size = 32
	health_caption.pixel_size = 0.004
	add_child(health_caption)
	health_caption.top_level = true
	repair_embedding()
	if not airborne:
		fall_peak = position.y
	animate(false, 0)

func material(color: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 1
	surfaces.append({"material": result, "base": color})
	return result

func part(parent: Node3D, center: Vector3, size_value: Vector3, surface: Material) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size_value
	mesh.mesh = box
	mesh.material_override = surface
	mesh.position = center
	parent.add_child(mesh)

func limb(pivot: Vector3, size_value: Vector3, surface: Material) -> Node3D:
	var joint := Node3D.new()
	joint.position = pivot
	visual.add_child(joint)
	part(joint, Vector3(0, -size_value.y * 0.5, 0), size_value, surface)
	return joint

func clear_at(feet: Vector3) -> bool:
	for x in [-0.28, 0.28]:
		for z in [-0.28, 0.28]:
			for y in [0.06, 0.95, 1.9]:
				if Registry.cube(model.block(Vector3i((feet + Vector3(x, y, z)).floor()))):
					return false
	return true

func floor_below(feet: Vector3, depth: float = 1.2) -> float:
	# The whole footprint must land on the highest supporting surface.
	# A centre-only test lets the legs sink into a ledge before the body clears it.
	var highest: float = -INF
	for x in [-0.28, 0.28]:
		for z in [-0.28, 0.28]:
			for y in range(floori(feet.y - 0.001), floori(feet.y - depth) - 1, -1):
				var cell := Vector3i(floori(feet.x+x),y,floori(feet.z+z))
				var top: float = y+1.0
				if top <= feet.y+0.02 and Registry.cube(model.block(cell)):
					highest = maxf(highest,top)
					break
	return highest

func grounded() -> bool:
	var floor_y: float = floor_below(position, 0.08)
	return floor_y > -INF and absf(position.y - floor_y) <= 0.02

func repair_embedding() -> bool:
	if clear_at(position):
		return true
	# Repair legacy saved positions or a block built inside an actor. Prefer a
	# small sideways move on the same level, not teleporting onto the cliff top.
	var old_position: Vector3 = position
	for vertical in [0, 1, -1, 2, -2, 3, -3, 4, 5, 6]:
		for radius in [0.0, 0.25, 0.5, 0.75, 1.0, 1.5, 2.0]:
			for index in range(8):
				var angle: float = TAU * index / 8
				var candidate: Vector3 = old_position + Vector3(cos(angle) * radius, vertical + 0.02, sin(angle) * radius)
				var floor_y: float = floor_below(candidate, 0.12)
				if floor_y == -INF:
					continue
				candidate.y = floor_y
				if clear_at(candidate):
					position = candidate
					velocity_y = 0
					hopping = false
					airborne = false
					fall_peak = position.y
					knockback.stop()
					route.clear()
					route_elapsed = 0
					return true
	return false

func land(floor_y: float) -> void:
	position.y = floor_y
	velocity_y = 0
	if airborne:
		var damage: float = Vitals.fall_damage(fall_peak - floor_y)
		if damage > 0:
			receive_hit(damage)
	airborne = false
	fall_peak = floor_y

func simulate_gravity(delta: float) -> void:
	if grounded():
		land(floor_below(position, 0.08))
		return
	if not airborne:
		airborne = true
		fall_peak = position.y
	fall_peak = maxf(fall_peak, position.y)
	velocity_y = maxf(-25, velocity_y - 18 * delta)
	var distance: float = -velocity_y * delta
	var steps: int = maxi(1, ceili(distance / 0.05))
	for index in range(steps):
		var next: Vector3 = position - Vector3(0, distance / steps, 0)
		var floor_y: float = floor_below(position, distance / steps + 0.02)
		if floor_y > -INF and next.y <= floor_y:
			land(floor_y)
			return
		if not clear_at(next):
			velocity_y = 0
			return
		position = next
	if position.y < -72:
		receive_hit(1000)

func choose_goal() -> void:
	for attempt in range(20):
		var angle: float = randf() * TAU
		var radius: float = sqrt(randf()) * (RADIUS - 0.8)
		var candidate: Vector3 = home + Vector3(cos(angle) * radius, 0, sin(angle) * radius)
		# Wander around the house rather than repeatedly trying to cross its walls.
		if absf(candidate.x - home.x) < 6.5 and absf(candidate.z - home.z) < 5.5:
			continue
		goal = candidate
		return
	goal = position

func start_hop(direction: Vector3) -> bool:
	if not grounded():
		return false
	var distance: float = Vector2(goal.x - position.x, goal.z - position.z).length()
	var target: Vector3 = position + direction * minf(0.8, maxf(0.35, distance))
	if not allowed_position(target):
		return false
	var floor_y: float = floor_below(target + Vector3(0, 1.05, 0), 2.1)
	if floor_y == -INF or absf(floor_y - position.y) > 1.05:
		return false
	target.y = floor_y
	if absf(target.y - position.y) > 0.1:
		# Land on the cell centre, not with a toe hanging over the next edge.
		target.x = floorf(target.x) + 0.5
		target.z = floorf(target.z) + 0.5
		if not allowed_position(target) or Vector2(target.x - position.x, target.z - position.z).length() > 1.4:
			return false
		floor_y = floor_below(target + Vector3(0, 0.02, 0), 0.1)
		if floor_y == -INF:
			return false
		target.y = floor_y
	if target.y>position.y+0.1 and model.kind_at(Vector3i((target-Vector3(0,0.05,0)).floor())) in ["fence","gate"]:
		return false
	if not clear_at(target):
		return false
	var peak: float = maxf(position.y, target.y) + 0.4
	if not clear_at(Vector3(position.x, peak, position.z)) or not clear_at(Vector3(target.x, peak, target.z)):
		return false
	for index in range(1, 25):
		if not clear_at(hop_position(position, target, index / 24.0)):
			return false
	airborne = true
	fall_peak = position.y
	hop_from = position
	hop_to = target
	hop_time = 0
	hopping = true
	return true

func hop_position(from: Vector3, to: Vector3, time: float) -> Vector3:
	var peak: float = maxf(from.y, to.y) + 0.4
	var horizontal: float = clampf((time - 0.35) / 0.4, 0, 1)
	var point: Vector3 = from.lerp(to, horizontal)
	if time < 0.35:
		point.y = lerpf(from.y, peak, time / 0.35)
	elif time < 0.75:
		point.y = peak
	else:
		point.y = lerpf(peak, to.y, (time - 0.75) / 0.25)
	return point

func advance_hop(delta: float) -> void:
	hop_time = minf(1, hop_time + delta / 0.65)
	var next: Vector3 = hop_position(hop_from, hop_to, hop_time)
	if clear_at(next):
		position = next
		fall_peak = maxf(fall_peak, position.y)
	else:
		hopping = false
		choose_goal()
	if hop_time >= 1:
		hopping = false
		velocity_y = 0
		if grounded():
			land(floor_below(position, 0.08))

func allowed_position(point: Vector3) -> bool:
	return behavior != "wander" or Vector2(point.x - home.x, point.z - home.z).length() <= RADIUS - 0.3

func sight_to(feet: Vector3) -> bool:
	var from: Vector3 = position + Vector3(0, 1.2, 0)
	var to: Vector3 = feet + Vector3(0, 1.2, 0)
	var steps: int = maxi(2, ceili(from.distance_to(to) / 0.25))
	for index in range(1, steps):
		if model.kind_at(Vector3i(from.lerp(to,float(index)/steps).floor())) not in ["fence","gate"] and Registry.cube(model.block(Vector3i(from.lerp(to, float(index) / steps).floor()))):
			return false
	return true

func set_behavior(next: String) -> void:
	if behavior == next:
		return
	behavior = next
	route.clear()
	route_elapsed = 0
	wait = 0

func update_behavior(delta: float, player: CharacterBody3D) -> void:
	if player == null:
		return
	if not pursuit_allowed:
		if behavior == "chase":
			set_behavior("return")
		strike_time = -1
	var distance: float = position.distance_to(player.position)
	var settings: Dictionary = Combat.stats("zombie")
	if behavior == "chase" and distance >= float(settings.get("aggro_break", 20)):
		set_behavior("return")
	elif pursuit_allowed and behavior != "chase" and distance <= float(settings.get("aggro_start", 10)) and sight_to(player.position):
		set_behavior("chase")
	if behavior == "wander":
		return
	if behavior == "return" and position.distance_to(origin) < 0.65:
		set_behavior("wander")
		choose_goal()
		return
	if behavior == "chase" and distance < 1.3:
		goal = position
		rotation.y = lerp_angle(rotation.y, atan2(position.x - player.position.x, position.z - player.position.z), minf(1, delta * 12))
		return
	route_elapsed -= delta
	var destination: Vector3 = player.position if behavior == "chase" else origin
	if route_elapsed <= 0 and not hopping:
		route = navigation.path(position, destination)
		route_elapsed = 0.65
	while not route.is_empty() and Vector2(route[0].x - position.x, route[0].z - position.z).length() < 0.22 and absf(route[0].y - position.y) < 0.1:
		route.pop_front()
	goal = route[0] if not route.is_empty() else destination

func can_hit(player: CharacterBody3D) -> bool:
	return pursuit_allowed and player != null and absf(player.position.y - position.y) <= 1.3 and Vector2(player.position.x - position.x, player.position.z - position.z).length() <= float(Combat.stats("zombie").reach) and sight_to(player.position)

func advance_strike(delta: float, player: CharacterBody3D) -> void:
	if strike_time < 0:
		return
	strike_time += delta
	if player != null:
		rotation.y = lerp_angle(rotation.y, atan2(position.x - player.position.x, position.z - player.position.z), minf(1, delta * 18))
	if strike_time >= 0.34 and not strike_hit:
		strike_hit = true
		if can_hit(player):
			player.receive_attack(Combat.damage(float(Combat.stats("zombie").attack), float(Combat.stats("player").defense)), position)
	if strike_time >= 0.65:
		strike_time = -1

func receive_hit(amount: float) -> void:
	health = maxf(0, health - amount)
	hurt_time = 0.22
	wait = maxf(wait, 0.12)

func apply_knockback(attacker: Vector3, force: float) -> void:
	knockback.start(attacker, position, force)
	if not knockback.active():
		return
	hopping = false
	strike_time = -1
	route.clear()
	route_elapsed = 0
	if behavior == "wander":
		set_behavior("return")
		goal = origin
	wait = maxf(wait, 0.25)

func move_knockback(delta: float) -> void:
	var movement: Vector3 = knockback.step(delta)
	var steps: int = maxi(1, ceili(movement.length() / 0.04))
	for index in range(steps):
		var next: Vector3 = position + movement / steps
		if clear_at(next):
			position = next
			continue
		# Preserve the free horizontal component instead of cancelling the hit.
		for axis in [0, 2]:
			if absf(movement[axis]) < 0.000001:
				continue
			var component: Vector3 = position
			component[axis] += movement[axis] / steps
			if clear_at(component):
				position = component
			else:
				movement[axis] = 0
				knockback.remaining[axis] = 0

func monitor_progress(delta: float) -> void:
	var distance: float = Vector2(goal.x - position.x, goal.z - position.z).length()
	var trying: bool = (hopping or (behavior != "wander" and grounded() and distance > 0.4)) and strike_time < 0 and not knockback.active()
	if not trying or Vector2(position.x - progress_anchor.x, position.z - progress_anchor.z).length() > 0.2:
		progress_anchor = position
		progress_elapsed = 0
		return
	progress_elapsed += delta
	if progress_elapsed < 1.5:
		return
	progress_elapsed = 0
	hopping = false
	route.clear()
	route_elapsed = 0
	wait = 0.1
	# Re-centre a stalled edge stance onto nearby solid footing. Validate the
	# complete small move so recovery cannot pass through a wall.
	var best: Vector3 = position
	var best_distance: float = INF
	for x in range(-1, 2):
		for z in range(-1, 2):
			var candidate := Vector3(floorf(position.x) + x + 0.5, position.y + 0.02, floorf(position.z) + z + 0.5)
			var floor_y: float = floor_below(candidate, 1.2)
			if floor_y == -INF:
				continue
			candidate.y = floor_y
			var cost: float = candidate.distance_to(position)
			if cost < 0.05 or cost > 1.2 or cost >= best_distance or not allowed_position(candidate) or not clear_at(candidate):
				continue
			var free: bool = true
			for index in range(1, 25):
				if not clear_at(position.lerp(candidate, index / 24.0)):
					free = false
					break
			if free:
				best = candidate
				best_distance = cost
	if best_distance < INF:
		position = best
		velocity_y = 0
		airborne = false
		fall_peak = position.y
	progress_anchor = position

func simulate(delta: float, player: CharacterBody3D = null) -> void:
	if health <= 0:
		return
	if not clear_at(position):
		repair_embedding()
	update_behavior(delta, player)
	advance_strike(delta, player)
	hurt_time = maxf(0, hurt_time - delta)
	attack_cooldown = maxf(0, attack_cooldown - delta)
	var pushed: bool = knockback.active()
	if pushed:
		move_knockback(delta)
	if hopping:
		advance_hop(delta)
		monitor_progress(delta)
		animate(true, delta)
		return
	var walking: bool = false
	wait = maxf(0, wait - delta)
	var direction: Vector3 = goal - position
	direction.y = 0
	if direction.length() < (0.6 if behavior == "wander" else 0.12):
		if behavior == "wander":
			choose_goal()
			wait = randf_range(0.5, 2.0)
	elif wait == 0 and strike_time < 0 and not pushed and grounded():
		direction = direction.normalized()
		rotation.y = atan2(-direction.x, -direction.z)
		var next: Vector3 = position + direction * minf(SPEED * delta, Vector2(goal.x - position.x, goal.z - position.z).length())
		var inside: bool = allowed_position(next)
		var floor_y: float = floor_below(next)
		if inside and clear_at(next) and floor_y > -INF and absf(floor_y - position.y) < 0.1:
			next.y = floor_y
			position = next
			walking = true
		elif inside and start_hop(direction):
			walking = true
		if not walking:
			if behavior == "wander":
				choose_goal()
			else:
				route_elapsed = 0
			wait = randf_range(0.15, 0.35)
	if not hopping:
		simulate_gravity(delta)
	monitor_progress(delta)
	animate(walking, delta)

func attack(player: CharacterBody3D) -> void:
	if health <= 0 or attack_cooldown > 0 or strike_time >= 0 or hopping or knockback.active() or not can_hit(player):
		return
	attack_cooldown = float(Combat.stats("zombie").interval)
	strike_time = 0
	strike_hit = false
	rotation.y = atan2(position.x - player.position.x, position.z - player.position.z)
	animate(false, 0)

func animate(walking: bool, delta: float) -> void:
	if not is_instance_valid(left_leg):
		return
	walk_time += delta * (5 if walking else 1)
	var stride: float = sin(walk_time) * 0.45 if walking else 0.0
	left_leg.rotation.x = stride
	right_leg.rotation.x = -stride
	left_arm.rotation.x = 1.2 + sin(walk_time) * 0.1
	right_arm.rotation.x = 1.2 - sin(walk_time) * 0.1
	right_arm.rotation.z = 0
	visual.rotation = Vector3.ZERO
	if strike_time >= 0:
		if strike_time < 0.24:
			var windup: float = strike_time / 0.24
			right_arm.rotation.x = lerpf(1.2, -0.6, windup)
			right_arm.rotation.z = -0.3 * windup
			visual.rotation.y = -0.22 * windup
		elif strike_time < 0.38:
			var swing: float = (strike_time - 0.24) / 0.14
			right_arm.rotation.x = lerpf(-0.6, 2.0, swing)
			visual.rotation.y = lerpf(-0.22, 0.15, swing)
			visual.rotation.x = -0.1 * swing
		else:
			var recovery: float = clampf((strike_time - 0.38) / 0.27, 0, 1)
			right_arm.rotation.x = lerpf(2.0, 1.2, recovery)
			visual.rotation.y = 0.15 * (1 - recovery)
			visual.rotation.x = -0.1 * (1 - recovery)
	for surface: Dictionary in surfaces:
		surface.material.albedo_color = (surface.base as Color).lerp(Color(1, 0.4, 0.3), hurt_time / 0.22 * 0.8)
	health_caption.global_position = global_position + Vector3(0, 2.2, 0)
	health_caption.visible = health < 100 or behavior == "chase"
	health_caption.text = "Zombie · %d %%" % ceili(health)

func serialize_state() -> Dictionary:
	return {"airborne": airborne, "fall_peak": fall_peak, "knockback": knockback.snapshot(), "behavior": behavior, "strike_time": strike_time, "strike_hit": strike_hit, "health": health, "goal": goal, "wait": wait, "walk_time": walk_time, "rotation": rotation.y, "velocity_y": velocity_y, "hopping": hopping, "hop_from": hop_from, "hop_to": hop_to, "hop_time": hop_time, "attack_cooldown": attack_cooldown}

func restore_state(state: Dictionary) -> void:
	airborne = state.get("airborne", false)
	fall_peak = float(state.get("fall_peak", goal.y))
	knockback.restore(state.get("knockback", {}))
	behavior = state.get("behavior", "wander")
	strike_time = state.get("strike_time", -1)
	strike_hit = state.get("strike_hit", false)
	health = clampf(float(state.get("health", 100)), 0, 100)
	goal = state.get("goal", goal)
	wait = state.get("wait", 0)
	walk_time = state.get("walk_time", 0)
	rotation.y = state.get("rotation", 0)
	velocity_y = state.get("velocity_y", 0)

	hopping = state.get("hopping", false)
	hop_from = state.get("hop_from", Vector3.ZERO)
	hop_to = state.get("hop_to", Vector3.ZERO)
	hop_time = state.get("hop_time", 0)
	attack_cooldown = state.get("attack_cooldown", 0)
