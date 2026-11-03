extends SceneTree
const Log=preload("res://scripts/core/performance_log.gd")
var failures: int=0
func expect(ok: bool, text: String) -> void:
	if not ok:
		failures+=1
		push_error(text)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	expect(Log.begin()==0,"Disabled measurement does not time activities")
	Log.start()
	var stamp: int=Log.begin()
	Log.finish("test_activity",stamp)
	Log.frame({"paused":false})
	Log.previous_frame-=60000
	Log.frame({"paused":false})
	var path: String=Log.stop()
	expect(not Log.active and FileAccess.file_exists(path),"Stop writes a report and disables recording")
	var report: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	expect(report.activities.test_activity.calls==1,"Activity count saved")
	expect(report.slow_frames.size()==1 and report.samples.size()==1,"Slow frames and periodic context recorded")
	Log.start()
	expect(Log.metrics.is_empty() and Log.frames==0,"New recording clears previous session")
	Log.stop()
	# Load the complete scene to catch integration and inherited-script errors.
	var world=load("res://scenes/main.tscn").instantiate()
	world.testing=true
	root.add_child(world)
	await process_frame
	world.new_world(42,"debug")
	world.combat_debug.refresh()
	world.combat_debug.toggle_measurement()
	expect(Log.active,"F3 starts recording")
	world.combat_debug.hide()
	await process_frame
	await process_frame
	expect(Log.frames>0,"Recording continues with F3 closed")
	world.combat_debug.refresh()
	world.combat_debug.toggle_measurement()
	expect(not Log.active,"F3 stops recording after refresh")
	var old: Dictionary=world.snapshot()
	old.erase("view_distance_policy")
	old.view_distance=128
	expect(world.restore_snapshot(old) and world.view_distance==96,"Old high view distance migrates to 96 once")
	var chosen: Dictionary=world.snapshot()
	chosen.view_distance=128
	expect(world.restore_snapshot(chosen) and world.view_distance==128,"New explicit view-distance choices persist")
	world.streamer.shutdown()
	world.queue_free()
	await process_frame
	print("PERFORMANCE LOG TESTS ","PASS" if failures==0 else "FAIL")
	quit(0 if failures==0 else 1)
