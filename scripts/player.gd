extends CharacterBody3D

const Knockback = preload("res://scripts/core/knockback.gd")
var knockback = Knockback.new()
const Vitals = preload("res://scripts/core/vitals.gd")
var vitals = Vitals.new()
var fall_peak: float = 0
var airborne: bool = false

const SPEED: float = 5.0
const SENSITIVITY: float = 0.0025
const JUMP_SPEED: float = 8.5
const JUMP_BUFFER: float = 0.15
const COYOTE_TIME: float = 0.1
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
	camera.position.y = 1.65
	camera.current = true
	camera.far = 150.0
	add_child(camera)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
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
	if paused or inventory_open:
		return
	if movement_blocked:
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
	velocity.x = direction.x * SPEED
	velocity.z = direction.z * SPEED
	var repeat_jump: bool = Input.is_physical_key_pressed(KEY_SPACE)
	jump_buffer_remaining = JUMP_BUFFER if jump_requested or repeat_jump else maxf(0.0, jump_buffer_remaining - delta)
	if paused or inventory_open:
		jump_buffer_remaining = 0.0
	coyote_remaining = COYOTE_TIME if is_on_floor() else maxf(0.0, coyote_remaining - delta)
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	else:
		velocity.y = 0.0
	if jump_buffer_remaining > 0.0 and coyote_remaining > 0.0 and not paused and not inventory_open:
		velocity.y = JUMP_SPEED
		jump_buffer_remaining = 0.0
		coyote_remaining = 0.0
	jump_requested = false
	if not airborne:
		fall_peak = position.y
	fall_peak = maxf(fall_peak, position.y)
	if knockback.active():
		move_knockback(delta)
	move_and_slide()
	if is_on_floor():
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

func reset_fall_tracking() -> void:
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

func receive_thorns(source: Vector3) -> void:
	var before: float = vitals.health
	var taken: float = vitals.damage(5, "bush")
	if taken > 0 and taken < before:
		if Vector2(source.x - position.x, source.z - position.z).length() < 0.01:
			source = position - camera.global_basis.z
		knockback.start_distance(source, position, 0.5)
