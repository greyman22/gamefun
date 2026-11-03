extends SceneTree
const Registry=preload("res://scripts/core/registry.gd")
const Craft=preload("res://scripts/crafting.gd")
const Data=preload("res://scripts/core/world_data.gd")
const Flat=preload("res://scripts/tests/night_population_tests.gd")
const System=preload("res://scripts/core/entity_system.gd")
const Hens=preload("res://scripts/core/hens.gd")
const Visuals=preload("res://scripts/item_visuals.gd")
var failures: int=0
func expect(ok: bool,label: String) -> void:
	if not ok:
		failures+=1
		push_error(label)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	Registry.initialize()
	for entry: Dictionary in Registry.catalog.recipes:
		if entry.kind not in ["thread","bow","arrow"]:
			continue
		for offset in ([0,3] if entry.kind=="thread" else [0]):
			var craft=Craft.new(3)
			var rows: PackedStringArray=entry.pattern.split("/")
			for y in range(rows.size()):
				var cells: PackedStringArray=rows[y].split(",")
				for x in range(cells.size()):
					if cells[x]!=".":
						craft.slots[y*3+x+offset]=Registry.stack(cells[x],1)
			var result: Dictionary=craft.recipe()
			expect(result.get("kind")==entry.kind and result.get("count")==entry.count,"Recipe matches requested layout and output")
			var bag=load("res://scripts/inventory.gd").new()
			expect(craft.craft(bag) and bag.count_item(entry.kind)==entry.count and craft.recipe().is_empty(),"Craft consumes all ingredients once")
	for kind in ["cotton","thread","feather"]:
		expect(Registry.stack_limit(kind)==64 and Visuals.icon(kind)!=null,"New materials stack to 64 and have icons")
		var pickup=load("res://scripts/pickup.gd").new()
		root.add_child(pickup)
		pickup.configure(kind)
		expect(pickup.get_child_count()>0,"Material has a world model")
		pickup.queue_free()
	var data=Data.new(42)
	data.generator=Flat.FlatLand.new()
	var system=System.new()
	system.configure(data,"debug")
	root.add_child(system)
	var yields: Dictionary={}
	for i in range(60):
		var id: String="hen_test_%d"%i
		Hens.create(data,id,Vector3(0.5,0,0.5),Vector3(0.5,0,0.5),"debug",false)
		system.activate(id,data.entities[id])
		var old_ids: Array=data.entities.keys()
		system.damage_actor(id,1000,60)
		var feathers: int=0
		for drop_id: String in data.entities.keys():
			if drop_id not in old_ids and data.entities[drop_id].get("kind","")=="feather":
				feathers+=int(data.entities[drop_id].count)
				expect(data.entities[drop_id].state.falling and data.entities[drop_id].ground_before_pickup,"Feathers fall to the ground before collection")
		expect(feathers>=0 and feathers<=2,"Adult hen drops zero to two feathers")
		yields[feathers]=true
	expect(yields.size()==3,"All feather yield outcomes occur")
	system.queue_free()
	await process_frame
	print("BOW RECIPES TESTS ","PASS" if failures==0 else failures)
	quit(0 if failures==0 else 1)
