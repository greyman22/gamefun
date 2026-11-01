extends SceneTree
const Registry=preload("res://scripts/core/registry.gd")
const Farm=preload("res://scripts/core/farming.gd")
var failures:=0
func _initialize() -> void:
	call_deferred("run")
func expect(ok: bool, message: String) -> void:
	if not ok:
		failures+=1
		push_error(message)
func aim(world: Node, x: int, height: float=35.1) -> void:
	world.player.position=Vector3(x+0.5,35,6)
	await process_frame
	world.player.camera.look_at(Vector3(x+0.5,height,3.5))
	world.update_build_preview()
func mouse(world: Node, button: int, pressed: bool) -> void:
	var event:=InputEventMouseButton.new()
	event.button_index=button
	event.pressed=pressed
	world._unhandled_input(event)
func run() -> void:
	var world=load("res://scenes/main.tscn").instantiate()
	world.testing=true
	root.add_child(world)
	await process_frame
	world.set_process(false)
	world.set_process_input(false)
	world.set_process_unhandled_input(false)
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	world.player.set_process_unhandled_input(false)
	world.player.paused=false
	world.player.movement_blocked=false
	for x in range(0,8):
		for z in range(0,8):
			world.model.set_block(Vector3i(x,34,z),"dirt")
	for x in [3,4,5]:
		world.model.set_block(Vector3i(x,34,3),"farmland")
	world.streamer.build_now(Vector3i(0,2,0))
	world.inventory.slots[27]=Registry.stack("grass_seed",5)
	world.select_hotbar(0)
	await physics_frame
	await physics_frame
	await aim(world,3)
	mouse(world,MOUSE_BUTTON_RIGHT,true)
	expect(world.planting_held and world.inventory.slots[27].count==4,"Press plants first seed")
	for x in [4,5]:
		await aim(world,x)
		world.update_held_planting()
		var before: int=world.inventory.slots[27].count
		world.update_held_planting()
		expect(world.inventory.slots[27].count==before,"Holding over same cell does not consume another seed")
		expect(not Farm.crop_at(world.model,Vector3i(x,35,3)).is_empty(),"Moving while holding plants next cell")
	expect(world.inventory.slots[27].count==2,"Three different cells consume three seeds")
	mouse(world,MOUSE_BUTTON_RIGHT,false)
	expect(not world.planting_held and not world.update_held_planting(),"Release stops continuous sowing")
	for x in [3,4]:
		var id: String=Farm.crop_at(world.model,Vector3i(x,35,3))
		world.model.entities[id].ripe_at=world.model.game_time
		world.model.entities[id].planted_at=world.model.game_time-120
	await aim(world,3,35.4)
	mouse(world,MOUSE_BUTTON_LEFT,true)
	world.update_plant_harvest(3.01)
	expect(world.mining_held and Farm.crop_at(world.model,Vector3i(3,35,3)).is_empty(),"Harvest retains held left button")
	await aim(world,4,35.4)
	world.update_plant_harvest(3.01)
	expect(world.mining_held and Farm.crop_at(world.model,Vector3i(4,35,3)).is_empty(),"Harvest continues on next cell while moving")
	await aim(world,3)
	world._physics_process(4)
	expect(world.model.kind_at(Vector3i(3,34,3))=="farmland" and world.mining_held,"Held harvest never mines soil between plants")
	mouse(world,MOUSE_BUTTON_LEFT,false)
	expect(not world.mining_held,"Release stops harvesting")
	world.day_hud.refresh(0)
	await process_frame
	expect(world.day_hud.clock.get_parent()==world.day_hud.strip.get_parent(),"Clock and day indicator share one row")
	expect(world.day_hud.clock.get_theme_font_size("font_size")==13,"Clock font is compact")
	expect(world.day_hud.clock.get_parent().get_parent().size.y<=26,"Time panel stays low with clock beside strip")
	var focus: StandardMaterial3D=world.preview.get_child(0).get_child(0).material_override
	expect(focus.albedo_color.a<=0.5,"Focus outline is subdued")
	world.streamer.shutdown()
	world.queue_free()
	await process_frame
	print("CONTINUOUS FARMING AND HUD TESTS: ","PASS" if failures==0 else failures)
	quit(0 if failures==0 else 1)
