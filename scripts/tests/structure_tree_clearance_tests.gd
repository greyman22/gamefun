extends SceneTree
const Data=preload("res://scripts/core/world_data.gd")
const Generator=preload("res://scripts/core/generator.gd")
const Trees=preload("res://scripts/core/structure_trees.gd")
const House=preload("res://scripts/core/zombie_house.gd")
const DebugHouse=preload("res://scripts/core/debug_house.gd")
const DebugWater=preload("res://scripts/core/debug_water.gd")
class Forest extends Generator:
	var forest: Array[Dictionary]=[]
	func _init(version_value: int=5) -> void:
		super(42,version_value)
		for base in [Vector3i(15,0,15),Vector3i(45,0,45)]:
			forest.append(make_tree(base,6) if version_value>=2 else {"base":base,"height":4})
	func height(_x: int,_z: int) -> int:
		return 0
	func ground(cell: Vector3i) -> int:
		return 2 if cell.y<0 else 0
	func trees_in_chunk(_key: Vector3i) -> Array[Dictionary]:
		return forest
var failures: int=0
func _initialize() -> void:
	call_deferred("run")
func expect(ok: bool,text: String) -> void:
	if not ok:
		failures+=1
		push_error(text)
func run() -> void:
	for version in [1,5]:
		var model=Data.new(42)
		model.generator=Forest.new(version)
		var tree: Dictionary=model.generator.forest[0]
		var points: Array[Vector3i]=Trees.cells(model,tree)
		var leaf:=Vector3i.ZERO
		for point in points:
			if point.x>=16 and model.generator.tree_kind(point,tree)==4:
				leaf=point
				break
		expect(leaf!=Vector3i.ZERO,"Fixture crown crosses a chunk boundary")
		var edited: Vector3i=tree.base+Vector3i.UP
		model.set_block(edited,"planks")
		var writer=House.new()
		writer.data=model
		var count: int=Trees.clear_area(model,Vector2i(leaf.x,leaf.z),Vector2i(leaf.x+1,leaf.z+1),writer.write)
		model.cache.clear()
		expect(count>0 and writer.touched.size()>=2,"Clearing a crown edge includes the rest of its tree across chunk boundaries")
		for point in points:
			expect(model.kind_at(point)==("planks" if point==edited else "air"),"No stump, branch or leaf slice survives initial site clearing")
		expect(model.kind_at(tree.base+Vector3i.DOWN)=="dirt","Tree clearing preserves the ground")
		expect(model.kind_at(model.generator.forest[1].base)=="wood","A separate tree outside the site remains intact")
		var loaded=Data.new(42)
		expect(loaded.import_state(model.export_state()),"Structure clearance edits can be saved")
		for point in points:
			expect(loaded.kind_at(point)==("planks" if point==edited else "air"),"Cleared tree cannot regenerate on loading")
	# Reproduce known problem seeds through the actual new-world builders.
	for seed_value in [1938830592,42,123,20261030]:
		var model=Data.new(seed_value)
		House.new().place(model,true)
		DebugHouse.new().place(model)
		DebugWater.place(model)
		var broken: int=0
		for x in range(-8,9):
			for z in range(-8,9):
				var tree: Dictionary=model.generator.tree_info(x,z)
				if tree.is_empty() or model.supported(tree):
					continue
				for point in Trees.cells(model,tree):
					if model.sample_kind(point)=="foliage":
						broken+=1
		expect(broken==0,"New-world buildings and debug earthworks leave no unsupported crowns for seed %d"%seed_value)
		var fallen: Dictionary={"count":0}
		model.foliage_fell.connect(func(_cell: Vector3i,_kind: String) -> void: fallen.count+=1)
		model.advance(91)
		expect(fallen.count==0,"New-world site preparation does not create delayed leaf drops")
	# Gameplay chopping still uses the original timed falling/drop mechanic.
	var chopped=Data.new(42)
	chopped.generator=Forest.new(5)
	var tree: Dictionary=chopped.generator.forest[0]
	chopped.set_block(tree.base,"air")
	expect(not chopped.decay.is_empty(),"Player chopping still schedules foliage decay")
	var drops: Dictionary={"count":0}
	chopped.foliage_fell.connect(func(_cell: Vector3i,_kind: String) -> void: drops.count+=1)
	chopped.advance(91)
	expect(drops.count>0,"Chopped trees still shed collectible foliage/sticks/saplings")
	print("STRUCTURE TREE CLEARANCE TESTS ","PASS" if failures==0 else "FAIL %d"%failures)
	quit(0 if failures==0 else 1)
