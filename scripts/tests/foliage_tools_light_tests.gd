extends SceneTree
const Registry = preload("res://scripts/core/registry.gd")
const Data = preload("res://scripts/core/world_data.gd")
const System = preload("res://scripts/core/entity_system.gd")
const Visuals = preload("res://scripts/item_visuals.gd")
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func expect(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	Registry.initialize()
	var data := Data.new(123)
	var system := System.new()
	system.configure(data,"debug")
	root.add_child(system)
	for index in range(100):
		var cell := Vector3i(index,35,3)
		data.set_block(cell,"foliage")
		data.decay[cell] = {"deadline":1.0,"tree":{"base":Vector3i(index,20,3),"height":3}}
	seed(1729)
	data.advance(1.1)
	var sticks: int = 0
	for record: Dictionary in data.entities.values():
		expect(record.type=="pickup" and record.kind in ["foliage","stick"] and record.state.falling and record.expires_at==data.game_time+300,"Decay leaves falling, collectible, expiring remains")
		sticks += 1 if record.kind=="stick" else 0
	expect(data.entities.size()==100 and sticks>=10 and sticks<=40,"One drop per leaf with approximately 25% sticks")
	data.advance(1)
	expect(data.entities.size()==100,"Decay does not duplicate drops")
	var world = load("res://scripts/world.gd").new()
	world.testing = true
	root.add_child(world)
	await process_frame
	world.new_world(123,"debug")
	world.set_process(false)
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	var cell := Vector3i(3,35,3)
	var torch := {"type":"torch","kind":"torch","cell":cell,"position":Vector3(cell),"state":{}}
	world.model.entities.torch_test = torch
	world.entity_system.activate("torch_test",torch)
	var node: Node3D = world.entity_system.active.torch_test
	expect(node.collision_layer==16,"Torch does not collide with player terrain layer")
	var lights: Array[Node] = node.find_children("*","OmniLight3D",true,false)
	expect(lights.size()==1 and is_equal_approx(lights[0].omni_range,4*sqrt(2)) and lights[0].light_color==Color.WHITE,"Torch doubles lit area with neutral light")
	world.player.knockback.stop()
	var health: float = world.player.vitals.health
	world.player.receive_thorns(Vector3.ZERO)
	expect(world.player.vitals.health==health-5 and not world.player.knockback.active(),"Bush damages without blocking or bouncing player")
	world.day_hud.refresh(0)
	expect(not world.day_hud.pause_button.visible and not world.day_hud.sleep_button.visible and not world.day_hud.night_button.visible,"Timeline no longer has hard-to-reach controls")
	world.toggle_combat_debug()
	expect(world.combat_debug.visible and is_instance_valid(world.combat_debug.time_pause),"Time controls live in F3 dialog")
	if "--capture-ui" in OS.get_cmdline_user_args():
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://debug-time-controls-preview.png")
	world.toggle_combat_debug()
	world.inventory.slots[27]=Registry.stack("shovel",1)
	world.select_hotbar(0)
	world.mining_held=true
	world.target_cell=Vector3i(0,-1,12)
	world.update_daylight(0)
	world.update_hand_animation(0.12,true)
	if "--capture-ui" in OS.get_cmdline_user_args():
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://shovel-dig-preview.png")
	world.streamer.shutdown()
	world.queue_free()
	system.queue_free()
	await process_frame
	print("FOLIAGE TOOLS LIGHT TESTS: ","PASS" if failures==0 else failures)
	quit(0 if failures==0 else 1)
