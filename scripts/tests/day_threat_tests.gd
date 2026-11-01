extends SceneTree
const Cycle = preload("res://scripts/core/day_cycle.gd")
const Data = preload("res://scripts/core/world_data.gd")
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func expect(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	var model := Data.new(123)
	var state: Dictionary = Cycle.state(model)
	for value in [[0,"Natt",true],[239,"Natt",true],[240,"Gryning",false],[300,"Dag",false],[1260,"Skymning",true],[1320,"Natt",true],[1439,"Natt",true]]:
		state.minute = float(value[0])
		expect(Cycle.phase(model) == value[1] and Cycle.can_sleep(model) == value[2],"Day phase and sleep boundaries")
	expect(Cycle.clock_text(model) == "23:59","Clock displays final minute correctly")
	state.minute = 480.0
	Cycle.advance(model,1440,false)
	expect(state.minute == 480 and state.day == 1,"One day lasts 24 real minutes")
	state.paused = true
	Cycle.advance(model,60,true)
	expect(state.minute == 480,"Debug pause freezes only day clock")
	Cycle.advance(model,60,false)
	expect(state.minute == 540,"Play cannot inherit debug time freeze")
	state.minute = 21*60
	expect(Cycle.sleep_to_dawn(model) and state.minute == 240 and state.day == 2,"Evening sleep advances to next dawn")
	state.minute = 120
	expect(Cycle.sleep_to_dawn(model) and state.minute == 240 and state.day == 2,"After-midnight sleep stays on current day")
	state.paused = false
	state.minute = 480.0
	Cycle.advance(model,360,true)
	expect(state.minute == 480,"Debug day lasts six real minutes")
	var world = load("res://scripts/world.gd").new()
	world.testing = true
	root.add_child(world)
	await process_frame
	world.set_process(false)
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	world.new_world(123,"debug")
	var clock: Dictionary = Cycle.state(world.model)
	clock.minute = 720.0
	world.daylight_amount = 1
	world.update_daylight(0)
	var day_energy: float = world.sky_environment.ambient_light_energy
	var day_rotation: Vector3 = world.sun_light.rotation
	clock.minute = 0.0
	world.update_daylight(0)
	expect(world.sky_environment.ambient_light_energy > 0.1 and world.sky_environment.ambient_light_energy < day_energy,"Night remains visible at lower brightness")
	expect(world.moon_disc.visible and world.moon_light.light_energy > 0 and world.moon_disc.position.distance_to(world.player.camera.global_position) < world.player.camera.far,"Visible moon lights night inside far plane")
	expect(world.sun_light.light_energy == 0,"Sun does not shine upward through terrain at night")
	clock.minute = 360.0
	world.update_daylight(0)
	expect(world.sun_disc.visible and world.sun_disc.position.distance_to(world.player.camera.global_position) < world.player.camera.far,"Sun is visible inside camera far plane")
	expect(world.sun_light.rotation.distance_to(day_rotation) > 0.1,"Sun travels across sky")
	clock.minute = 1300.0
	world.day_hud.refresh(0)
	expect(not world.day_hud.sleep_button.disabled,"Sleep enabled after dusk")
	world.day_hud.sleep()
	expect(clock.minute == 240 and world.day_hud.sleep_button.disabled,"Sleep button moves to dawn and disables")
	world.day_hud.toggle_pause()
	var saved: Dictionary = world.snapshot()
	expect(world.restore_snapshot(saved) and Cycle.state(world.model).paused and Cycle.hour(world.model) == 4,"Clock and pause survive full save")
	world.player.paused = false
	world.player.inventory_open = false
	world.player.movement_blocked = false
	var old_time: float = world.model.game_time
	world._physics_process(0.1)
	expect(Cycle.state(world.model).minute == 240 and world.model.game_time > old_time,"Pausing daylight leaves world simulation running")
	world.day_hud.refresh(0)
	expect(world.day_hud.indicators.size() == 5,"Exactly five monster indicators")
	var zombies: Array[String] = []
	for id: String in world.entity_system.active:
		if world.model.entities[id].type == "zombie":
			world.entity_system.active[id].behavior = "wander"
			zombies.append(id)
	expect(zombies.size() >= 2,"Test has active zombies")
	world.entity_system.active[zombies[0]].behavior = "chase"
	world.entity_system.active[zombies[1]].behavior = "chase"
	world.day_hud.refresh(0.1)
	expect(world.day_hud.threats.get("zombie",0) == 2,"All pursuers counted regardless of camera direction")
	var first_alpha: float = world.day_hud.indicators[0].modulate.a
	world.day_hud.refresh(0.34)
	expect(world.day_hud.indicators[0].modulate.a != first_alpha,"Pursuit indicator blinks")
	world.entity_system.active[zombies[0]].behavior = "return"
	world.day_hud.refresh(0)
	expect(world.day_hud.threats.get("zombie",0) == 1,"Indicator stays on while another zombie chases")
	if "--capture-ui" in OS.get_cmdline_user_args():
		for hour in [12,23]:
			Cycle.state(world.model).minute = hour*60.0
			world.update_daylight(0)
			world.day_hud.refresh(0.1)
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://day-cycle-%d-preview.png" % hour)
	if "--capture-ui" in OS.get_cmdline_user_args():
		for hour in [12,0]:
			Cycle.state(world.model).minute = hour * 60.0
			world.update_daylight(0)
			world.player.camera.look_at(world.sun_disc.global_position if hour == 12 else world.moon_disc.global_position)
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://sun-direct-preview.png" if hour == 12 else "res://moon-direct-preview.png")
	world.entity_system.active[zombies[1]].behavior = "return"
	world.day_hud.refresh(0)
	expect(not world.day_hud.threats.has("zombie"),"Indicator greys out after last pursuer stops")
	world.game_mode = "play"
	world.day_hud.refresh(0)
	expect(not world.day_hud.pause_button.visible and not world.day_hud.sleep_button.visible,"Debug controls hidden in play")
	world.streamer.shutdown()
	world.queue_free()
	await process_frame
	print("DAY AND THREAT TESTS: ","PASS" if failures == 0 else failures)
	quit(0 if failures == 0 else 1)
