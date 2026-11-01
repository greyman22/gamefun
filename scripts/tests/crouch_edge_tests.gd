extends SceneTree
const Player=preload("res://scripts/player.gd")
const Registry=preload("res://scripts/core/registry.gd")
var failures:=0
func _initialize() -> void:
	call_deferred("run")
func expect(ok: bool, message: String) -> void:
	if not ok:
		failures+=1
		push_error(message)
func run() -> void:
	var body:=StaticBody3D.new()
	var collider:=CollisionShape3D.new()
	var shape:=BoxShape3D.new()
	shape.size=Vector3(1,1,1)
	collider.shape=shape
	body.position=Vector3(0.5,-0.5,0.5)
	body.add_child(collider)
	root.add_child(body)
	var player:=Player.new()
	root.add_child(player)
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	player.position=Vector3(0.5,0.02,0.5)
	for frame in range(5):
		await physics_frame
		player.velocity=Vector3(0,-1,0)
		player.move_and_slide()
	for frame in range(120):
		await physics_frame
		player.update_crouch(1.0/60,true)
		player.velocity=Vector3(Player.CROUCH_SPEED,-0.1,Player.CROUCH_SPEED)
		player.guard_crouch_edges(1.0/60)
		player.move_with_fence_guard()
	expect(player.position.x>1.05 and player.position.x<1.26 and player.position.z<1.26,"Crouch permits controlled overhang but prevents falling at diagonal corner")
	expect(absf(player.position.y)<0.05 and player.supported_floor(),"Crouching player stays on starting block")
	expect(absf(player.camera.position.y-Player.CROUCH_EYE_HEIGHT)<0.01,"Crouching lowers camera")
	for frame in range(60):
		await physics_frame
		player.update_crouch(1.0/60,false)
		player.velocity=Vector3(3,player.velocity.y-20.0/60,0)
		player.guard_crouch_edges(1.0/60)
		player.move_with_fence_guard()
	expect(player.position.y< -0.5,"Releasing Shift permits ordinary walking off edge")
	expect(absf(player.camera.position.y-Player.STANDING_EYE_HEIGHT)<0.01,"Camera returns on release")
	player.queue_free()
	body.queue_free()
	await process_frame
	var world=load("res://scenes/main.tscn").instantiate()
	world.testing=true
	root.add_child(world)
	await process_frame
	world.set_process(false)
	world.set_physics_process(false)
	world.set_process_input(false)
	world.set_process_unhandled_input(false)
	world.player.set_physics_process(false)
	world.player.set_process_unhandled_input(false)
	world.model.set_block(Vector3i(0,34,0),"dirt")
	world.streamer.build_now(Vector3i(0,2,0))
	world.player.position=Vector3(1.2,35.01,0.5)
	world.player.update_crouch(1,true)
	world.inventory.slots[27]=Registry.stack("dirt",3)
	world.select_hotbar(0)
	await physics_frame
	await physics_frame
	world.player.camera.look_at(Vector3(1,34.85,0.5))
	world.update_build_preview()
	expect(world.target_cell==Vector3i(0,34,0) and world.build_cell==Vector3i(1,34,0) and world.can_build,"Crouch overhang allows targeting support side and same-level extension")
	world.place_block()
	expect(world.model.kind_at(Vector3i(1,34,0))=="dirt","Same-level bridge block is actually placed")
	world.streamer.shutdown()
	world.queue_free()
	await process_frame
	print("CROUCH EDGE TESTS: ","PASS" if failures==0 else failures)
	quit(0 if failures==0 else 1)
