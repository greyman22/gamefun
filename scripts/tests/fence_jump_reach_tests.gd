extends SceneTree
const Player = preload("res://scripts/player.gd")
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func expect(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func solid(center: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.position = center
	body.add_child(collider)
	root.add_child(body)
func run() -> void:
	solid(Vector3(0,-0.5,0),Vector3(20,1,20))
	solid(Vector3(0,0.5,0),Vector3.ONE)
	solid(Vector3(1,0.5,0),Vector3.ONE)
	solid(Vector3(0,0.5,3),Vector3(1,1,1))
	for x in [0.0,1.0]:
		var marker := Node3D.new()
		marker.position = Vector3(x,0,0)
		root.add_child(marker)
		marker.add_to_group("wooden_fences")
	var player := Player.new()
	root.add_child(player)
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	await physics_frame
	for z in [0.0,3.0]:
		player.position = Vector3(-1.2,0.02,z)
		player.velocity = Vector3(3,Player.JUMP_SPEED,0)
		for frame in range(60):
			await physics_frame
			player.velocity.x = 3
			player.velocity.y -= 20.0/60.0
			player.move_with_fence_guard()
		if z == 0.0:
			expect(player.position.x < -0.8,"Ground jump must not get onto 1m fence")
		else:
			expect(player.position.x > 0.4,"Jump must still clear an ordinary 1m block")
	player.position = Vector3(0,1.01,0)
	player.fence_access_height = 1.0
	for frame in range(25):
		await physics_frame
		player.velocity = Vector3(2,-0.5,0)
		player.move_with_fence_guard()
	expect(player.position.x>0.7 and absf(player.position.y-1.0)<0.05,"Player already at fence height can walk along top")
	expect(load("res://scripts/world.gd").INTERACTION_REACH==5.0,"Interaction ray limited to five metres")
	var registry = load("res://scripts/core/registry.gd")
	registry.initialize()
	for kind in ["stone","dirt","wood","foliage","planks","fence"]:
		expect(registry.seconds("hand",kind)==3.0,"Manual work takes three seconds: "+kind)
		expect(registry.seconds(registry.catalog.blocks[kind].tool,kind)==0.7,"Correct tool takes 0.7 seconds: "+kind)
	player.queue_free()
	print("FENCE JUMP AND REACH TESTS: ","PASS" if failures==0 else failures)
	quit(0 if failures==0 else 1)
