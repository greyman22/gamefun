extends CharacterBody3D

const Knockback = preload("res://scripts/core/knockback.gd")
var knockback = Knockback.new()
const Vitals = preload("res://scripts/core/vitals.gd")
var vitals = Vitals.new()
var fall_peak: float = 0
var airborne: bool = false

const STANDING_EYE_HEIGHT: float = 1.65
const CROUCH_EYE_HEIGHT: float = 1.25
var crouching: bool = false
var crouch_edge_guard_active: bool = false
const SPEED: float = 3.0
const CROUCH_SPEED: float = 0.45
const SPRINT_MULTIPLIER: float = 2.0
const DOUBLE_TAP_MS: int = 300
var sprinting: bool = false
var last_forward_press: int = -1000
const SENSITIVITY: float = 0.0025
const JUMP_SPEED: float = 8.5
const JUMP_BUFFER: float = 0.15
const COYOTE_TIME: float = 0.1
var fence_access_height: float = 0
var jump_requested: bool = false
var jump_buffer_remaining: float = 0.0
var coyote_remaining: float = 0.0
var camera: Camera3D
var paused: bool = false
var inventory_open: bool = false
var movement_blocked: bool = false
var bounds_radius: float = 255.0
var bottom_y: float = -64.0
var respawn_position := Vector3(0, 0.05, 12)

func _ready() -> void:
	collision_layer = 1
	collision_mask = 1
	floor_snap_length = 0.15
	safe_margin = 0.01
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.9
	add_child(shape)
	camera = Camera3D.new()
	camera.position.y = STANDING_EYE_HEIGHT
	camera.current = true
	camera.far = 150.0
	add_child(camera)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and (event.physical_keycode == KEY_W or event.keycode == KEY_W) and not event.echo:
		if event.pressed and not paused and not inventory_open:
			var now: int = Time.get_ticks_msec()
			sprinting = now - last_forward_press <= DOUBLE_TAP_MS
			last_forward_press = now
		else:
			sprinting = false
	if event is InputEventKey and event.pressed and not event.echo:
		if (event.physical_keycode == KEY_SPACE or event.keycode == KEY_SPACE) and not paused and not inventory_open:
			jump_requested = true
		if event.keycode == KEY_ESCAPE:
			paused = not paused
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseButton and event.pressed and paused and not inventory_open:
		paused = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
	if event is InputEventMouseMotion and not paused and not inventory_open:
		rotate_y(-event.relative.x * SENSITIVITY)
		camera.rotation.x = clampf(camera.rotation.x - event.relative.y * SENSITIVITY, -1.4, 1.4)

func _physics_process(delta: float) -> void:
	update_crouch(delta,Input.is_physical_key_pressed(KEY_SHIFT) and not paused and not inventory_open)
	if paused or inventory_open:
		sprinting = false
		return
	if movement_blocked:
		sprinting = false
		velocity = Vector3.ZERO
		jump_requested = false
		return
	var direction := Vector3.ZERO
	if not paused and not inventory_open:
		var axis := Vector2(
			float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
			float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
		if axis.length() > 1.0:
			axis = axis.normalized()
		direction = transform.basis * Vector3(axis.x, 0.0, axis.y)
	if knockback.active():
		direction = Vector3.ZERO
	if not Input.is_physical_key_pressed(KEY_W):
		sprinting = false
	if crouching:
		sprinting=false
	var speed: float = CROUCH_SPEED if crouching else SPEED * (SPRINT_MULTIPLIER if sprinting else 1.0)
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	var repeat_jump: bool = Input.is_physical_key_pressed(KEY_SPACE)
	jump_buffer_remaining = JUMP_BUFFER if jump_requested or repeat_jump else maxf(0.0, jump_buffer_remaining - delta)
	if paused or inventory_open:
		jump_buffer_remaining = 0.0
	coyote_remaining = COYOTE_TIME if supported_floor() else maxf(0.0, coyote_remaining - delta)
	if not supported_floor():
		velocity.y -= 20.0 * delta
	else:
		velocity.y = 0.0
	if jump_buffer_remaining > 0.0 and coyote_remaining > 0.0 and not paused and not inventory_open:
		velocity.y = JUMP_SPEED
		jump_buffer_remaining = 0.0
		coyote_remaining = 0.0
	jump_requested = false
	guard_crouch_edges(delta)
	if not airborne:
		fall_peak = position.y
	fall_peak = maxf(fall_peak, position.y)
	if knockback.active():
		move_knockback(delta)
	move_with_fence_guard()
	if sprinting and not repeat_jump and supported_floor() and is_on_wall():
		sprinting = false
	if supported_floor():
		if airborne:
			vitals.damage(Vitals.fall_damage(fall_peak - position.y))
		airborne = false
		fall_peak = position.y
	else:
		airborne = true
	# A second boundary protects against slipping through a fence corner.
	position.x = clampf(position.x, -bounds_radius, bounds_radius)
	position.z = clampf(position.z, -bounds_radius, bounds_radius)
	if position.y < bottom_y - 8:
		vitals.damage(1000)

func update_crouch(delta: float, held: bool) -> void:
	crouching=held
	camera.position.y=lerpf(camera.position.y,CROUCH_EYE_HEIGHT if held else STANDING_EYE_HEIGHT,1.0-exp(-14.0*delta))

func crouch_supported(feet: Vector3) -> bool:
	# A small part of the foot may overhang, exposing the block side for
	# same-level bridge placement. Lower blocks do not count as safe support.
	for offset in [Vector3.ZERO,Vector3(-0.25,0,-0.25),Vector3(-0.25,0,0.25),Vector3(0.25,0,-0.25),Vector3(0.25,0,0.25)]:
		var query := PhysicsRayQueryParameters3D.create(feet+offset+Vector3(0,0.08,0),feet+offset-Vector3(0,0.18,0),1,[get_rid()])
		var hit: Dictionary=get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty() and hit.normal.y>0.5:
			return true
	return false

func supported_floor() -> bool:
	return is_on_floor() or (crouching and velocity.y<=0.1 and crouch_supported(position))

func guard_crouch_edges(delta: float) -> void:
	crouch_edge_guard_active=crouching and supported_floor() and velocity.y<=0.1 and delta>0
	if not crouch_edge_guard_active:
		return
	var movement := Vector3(velocity.x,0,velocity.z)*delta
	var allowed := Vector3.ZERO
	var steps: int=maxi(1,ceili(movement.length()/0.03))
	for step in range(steps):
		for axis in [0,2]:
			var proposed: Vector3=allowed
			proposed[axis]+=movement[axis]/steps
			if crouch_supported(position+proposed):
				allowed=proposed
	velocity.x=allowed.x/delta
	velocity.z=allowed.z/delta

func reset_fall_tracking() -> void:
	crouching=false
	if is_instance_valid(camera):
		camera.position.y=STANDING_EYE_HEIGHT
	sprinting = false
	last_forward_press = -1000
	knockback.stop()
	fall_peak = position.y
	airborne = false

func receive_attack(amount: float, attacker: Vector3) -> float:
	var before: float = vitals.health
	var taken: float = vitals.damage(amount, "zombie")
	# A lethal hit may synchronously respawn us; do not push the new incarnation.
	if taken > 0 and taken < before:
		knockback.start(attacker, position, taken)
	return taken

# Fences are one metre tall. Entry from below is a material rule, independent
# of jump height; walking onto the same top level remains possible.
func move_with_fence_guard() -> void:
	if is_on_floor():
		fence_access_height = position.y
	var previous: Vector3 = position
	move_and_slide()
	if crouch_edge_guard_active:
		# Capsule bottoms are rounded: retain a level stance while the foot
		# deliberately overhangs, instead of sliding down the block corner.
		var candidate := Vector3(position.x,previous.y,position.z)
		if not crouch_supported(candidate):
			position.x=previous.x
			position.z=previous.z
		position.y=previous.y
		velocity.y=0
	for fence in get_tree().get_nodes_in_group("wooden_fences"):
		var center: Vector3 = fence.global_position
		var top: float = center.y+1.0
		if fence_access_height>=top-0.05 or previous.y+1.8<center.y:
			continue
		var min_x: float = center.x-0.85
		var max_x: float = center.x+0.85
		var min_z: float = center.z-0.85
		var max_z: float = center.z+0.85
		if position.x>min_x and position.x<max_x and position.z>min_z and position.z<max_z:
			if previous.x<=min_x or previous.x>=max_x:
				position.x = minf(position.x,min_x) if previous.x<=min_x else maxf(position.x,max_x)
				velocity.x = 0
			if previous.z<=min_z or previous.z>=max_z:
				position.z = minf(position.z,min_z) if previous.z<=min_z else maxf(position.z,max_z)
				velocity.z = 0

func move_knockback(delta: float) -> void:
	var movement: Vector3 = knockback.step(delta)
	var steps: int = maxi(1, ceili(movement.length() / 0.04))
	for index in range(steps):
		for axis in [0, 2]:
			if absf(movement[axis]) < 0.000001:
				continue
			var component := Vector3.ZERO
			component[axis] = movement[axis] / steps
			var collision: KinematicCollision3D = move_and_collide(component)
			if collision != null:
				movement[axis] = 0
				knockback.remaining[axis] = 0

func receive_thorns(_source: Vector3) -> void:
	vitals.damage(5, "bush")
