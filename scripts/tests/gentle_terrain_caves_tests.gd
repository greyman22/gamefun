extends SceneTree
const G=preload("res://scripts/core/generator.gd")
const Data=preload("res://scripts/core/world_data.gd")
var failures: int=0
func _initialize() -> void:
	call_deferred("run")
func expect(ok: bool,text: String) -> void:
	if not ok:
		failures+=1
		push_error(text)
func run() -> void:
	var old=G.new(42,4)
	var fresh=G.new(42)
	for biome in range(3):
		var bounds: Rect2i=fresh.zones.nearest_rect(Vector2.ZERO,biome)
		var center: Vector2i=bounds.get_center()
		var old_sum: float=0
		var new_sum: float=0
		for x in range(center.x-300,center.x+301,30):
			for z in range(center.y-300,center.y+301,30):
				old_sum+=absf(old.zones.profile(x,z).height)
				new_sum+=absf(fresh.zones.profile(x,z).height)
		expect(new_sum<old_sum*0.75,"Each terrain class is appreciably gentler than v4")
	var new_trees: int=0
	var old_trees: int=0
	var empty_patches: int=0
	for gx in range(-60,40):
		for gz in range(-50,70):
			if old.zones.info(gx*10,gz*10).kind!=0:
				continue
			if not old.tree_info(gx,gz).is_empty():
				old_trees+=1
			if not fresh.tree_info(gx,gz).is_empty():
				new_trees+=1
		expect(new_trees<old_trees*0.5 and new_trees>0,"Grassland has fewer trees, with some remaining woods")
	for block_x in range(-500,401,100):
		for block_z in range(-500,601,100):
			var count: int=0
			for x in range(block_x/10,block_x/10+10):
				for z in range(block_z/10,block_z/10+10):
					if not fresh.tree_info(x,z).is_empty():
						count+=1
			if count==0:
				empty_patches+=1
	expect(empty_patches>0,"Entire hundred-metre grassland patches can be treeless")
	var shapes: Dictionary={}
	var branches: int=0
	for location in [Vector2.ZERO,Vector2(-3000,0),Vector2(3000,2000)]:
		var bounds: Rect2i=fresh.zones.nearest_rect(location,2)
		var found: int=0
		var start:=Vector2i(floori(float(bounds.position.x+100)/64),floori(float(bounds.position.y+100)/64))
		var finish:=Vector2i(floori(float(bounds.end.x-100)/64),floori(float(bounds.end.y-100)/64))
		for x in range(start.x,finish.x+1):
			for z in range(start.y,finish.y+1):
				var c: Dictionary=fresh.cave_for_tile(x,z)
				if c.is_empty():
					continue
				found+=1
				shapes[c.shape]=true
				branches+=c.branches.size()
				for point in c.path:
					expect(fresh.ground(Vector3i(point.x,c.floor+1,point.y))==0,"Main curved route is fully open")
				for branch in c.branches:
					expect(fresh.height(branch[-1].x,branch[-1].y)>c.floor+c.height,"Blind branch terminates under rock")
		expect(found>0,"Every sampled mountain region has caves")
	expect(shapes.has("u") and shapes.has("winding") and branches>0,"Caves include U-turns, winding routes and blind branches")
	var data=Data.new(42)
	data.generator=G.new(42,4)
	var restored=Data.new()
	expect(restored.import_state(data.export_state()) and restored.generator.version==4,"Existing v4 terrain remains unchanged on load")
	print("GENTLE TERRAIN / CAVES TESTS ","PASS" if failures==0 else "FAIL: %d"%failures," trees ",new_trees,"/",old_trees," empty patches ",empty_patches)
	quit(0 if failures==0 else 1)
