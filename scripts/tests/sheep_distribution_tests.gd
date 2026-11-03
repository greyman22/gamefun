extends SceneTree
const Data=preload("res://scripts/core/world_data.gd")
const Sheep=preload("res://scripts/core/sheep.gd")
# Deterministic dry flat land isolates placement from lake/terrain availability.
class FlatLand extends RefCounted:
	var version: int=1
	const SEA_LEVEL: int=-2
	func height(_x: int,_z: int) -> int:
		return 0
	func world_limit() -> int:
		return 10000
	func hash_at(x: int,z: int,salt: int) -> int:
		return absi(x*1619+z*31337+salt*6971)
	func ground(cell: Vector3i) -> int:
		return 2 if cell.y<0 else 0
	func trees_in_chunk(_key: Vector3i) -> Array[Dictionary]:
		return []
	func tree_kind(_cell: Vector3i,_tree: Dictionary) -> int:
		return 0
	func trim_caches() -> void:
		pass
var failures: int=0
func expect(ok: bool,text: String) -> void:
	if not ok:
		failures+=1
		push_error(text)
func _initialize() -> void:
	for mode in ["debug","play"]:
		var model=Data.new(42)
		model.generator=FlatLand.new()
		Sheep.ensure_nearby(model,Vector3(33,0,34),mode)
		expect(model.entities.size()>=6 and model.entities.size()<=8,"A pairing contains two flocks of three to four sheep")
		var records: Array=model.entities.values()
		var centers: Dictionary={}
		for i in range(records.size()):
			var a: Dictionary=records[i]
			centers[a.group_center]=int(centers.get(a.group_center,0))+1
			expect(a.home==a.position,"Each sheep has its own spread-out home position")
			for j in range(i+1,records.size()):
				var b: Dictionary=records[j]
				expect(Vector2(a.position.x-b.position.x,a.position.z-b.position.z).length()>=10,"Natural sheep begin at least ten metres apart")
		expect(centers.size()==2,"There are two separate flock centers")
		var pair: Array[Vector3]=Sheep.group_centers(model,0,0,mode)
		var adjacent: Array[Vector3]=Sheep.group_centers(model,1,0,mode)
		expect(pair[0].distance_to(pair[1])==50,"Paired flock centers are fifty metres apart")
		expect(pair[1].distance_to(adjacent[0])==Sheep.grouping_gap(mode),"Separate pairings retain doubled gaps")
		var before: int=model.entities.size()
		Sheep.ensure_nearby(model,Vector3(33,0,34),mode)
		expect(model.entities.size()==before,"Revisiting does not respawn the flocks")
		var restored=Data.new()
		expect(restored.import_state(model.export_state()),"Grouping metadata and separate homes save correctly")
	var legacy=Data.new(42)
	legacy.generator=FlatLand.new()
	legacy.landmarks.sheep_groups={"debug:0,0":Vector3(33,0,34)}
	Sheep.ensure_nearby(legacy,Vector3(33,0,34),"debug")
	expect(legacy.entities.is_empty(),"Previously populated areas are not double-populated")
	print("SHEEP DISTRIBUTION TESTS ","PASS" if failures==0 else "FAIL %d"%failures)
	quit(0 if failures==0 else 1)
