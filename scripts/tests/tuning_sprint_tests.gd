extends SceneTree
const Player = preload("res://scripts/player.gd")
const Registry = preload("res://scripts/core/registry.gd")
const Combat = preload("res://scripts/core/combat.gd")
const Berries = preload("res://scripts/core/berries.gd")
const Data = preload("res://scripts/core/world_data.gd")
const Daylight = preload("res://scripts/core/daylight.gd")
var failures := 0
var test_player: CharacterBody3D
func _initialize() -> void:
	call_deferred("run")
func expect(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	if is_instance_valid(test_player):
		test_player._unhandled_input(event)
func run() -> void:
	Registry.initialize()
	Combat.initialize()
	for pair in [["shovel","dirt"],["axe","wood"],["pickaxe","stone"]]:
		expect(is_equal_approx(Registry.seconds(pair[0],pair[1]),0.7),"Correct tool takes 0.7 seconds")
	expect(Registry.seconds("hand","dirt") == 3.0 and Berries.harvest_seconds("axe") == 0.8 and Berries.harvest_seconds("hand") == 3,"Hand speeds preserved and axe harvest accelerated")
	expect(Combat.stats("player").reach == 2.2 and Combat.stats("zombie").reach == 2.6,"Both unarmed reaches increased")
	var model := Data.new(123)
	for x in range(-2,9):
		for z in [-1,0,1]:
			model.set_block(Vector3i(x,35,z),"stone")
			model.set_block(Vector3i(x,32,z),"stone")
		for y in [33,34]:
			for z in [-1,1]:
				model.set_block(Vector3i(x,y,z),"stone")
	for y in [33,34]:
		model.set_block(Vector3i(-3,y,0),"stone")
	var light := Daylight.new()
	light.configure(model)
	var near := light.exposure(Vector3(7.5,34,0.5))
	var deep := light.exposure(Vector3(3.5,34,0.5))
	print("TUNNEL exposure: ",near," / ",deep)
	expect(near < 0.6 and deep < 0.03,"Tunnel already dark after two metres and nearly black after six")
	var floor_body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(20,0.5,20)
	collision.shape = shape
	collision.position.y = -0.25
	floor_body.add_child(collision)
	root.add_child(floor_body)
	var wall := StaticBody3D.new()
	var wall_collision := CollisionShape3D.new()
	var wall_shape := BoxShape3D.new()
	wall_shape.size = Vector3(3,1.2,0.5)
	wall_collision.shape = wall_shape
	wall_collision.position = Vector3(0,0.6,-2)
	wall.add_child(wall_collision)
	root.add_child(wall)
	var player := Player.new()
	root.add_child(player)
	test_player = player
	player.set_physics_process(false)
	await physics_frame
	player._physics_process(1.0/60)
	key(KEY_W,true)
	key(KEY_W,false)
	player.last_forward_press = Time.get_ticks_msec()-100
	key(KEY_W,true)
	expect(player.sprinting and Player.SPEED == 3.0 and Player.SPRINT_MULTIPLIER == 2,"Double W activates double walking speed")
	for frame in range(40):
		player._physics_process(1.0/60)
	expect(not player.sprinting,"Wall stops grounded sprint")
	key(KEY_W,false)
	player.position = Vector3.ZERO
	player.velocity = Vector3.ZERO
	await physics_frame
	player._physics_process(1.0/60)
	player.last_forward_press = Time.get_ticks_msec()-100
	key(KEY_W,true)
	key(KEY_SPACE,true)
	for frame in range(14):
		player._physics_process(1.0/60)
	expect(player.sprinting and player.position.y > 0.5,"Jumping at obstacle preserves sprint")
	key(KEY_SPACE,false)
	key(KEY_W,false)
	expect(not player.sprinting,"Releasing W ends sprint")
	player.queue_free()
	floor_body.queue_free()
	wall.queue_free()
	await process_frame
	print("TUNING AND SPRINT TESTS: ","PASS" if failures == 0 else failures)
	quit(0 if failures == 0 else 1)
