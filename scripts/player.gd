extends CharacterBody3D

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
	velocity.x = direction.x * SPEED
	velocity.z = direction.z * SPEED
	jump_buffer_remaining = JUMP_BUFFER if jump_requested else maxf(0.0, jump_buffer_remaining - delta)
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
	move_and_slide()
	# A second boundary protects against slipping through a fence corner.
	position.x = clampf(position.x, -bounds_radius, bounds_radius)
	position.z = clampf(position.z, -bounds_radius, bounds_radius)
	if position.y < bottom_y - 8:
		position = respawn_position
		velocity = Vector3.ZERO
