extends RefCounted
const Registry=preload("res://scripts/core/registry.gd")
const Farming=preload("res://scripts/core/farming.gd")
const Berries=preload("res://scripts/core/berries.gd")
static func foliage_drop() -> String:
	var roll: float=randf()
	return "sapling" if roll<0.2 else ("stick" if roll<0.45 else "foliage")
static func id_for(model: RefCounted, cell: Vector3i) -> String:
	return "sapling_"+model.text_key(cell)
static func plant(model: RefCounted, cell: Vector3i, mode: String) -> String:
	if model.kind_at(cell)!="air" or model.kind_at(cell+Vector3i.DOWN) not in ["dirt","farmland"] or not Farming.crop_at(model,cell).is_empty() or not Berries.at_cell(model,cell).is_empty():
		return ""
	var id: String=id_for(model,cell)
	var duration: int=randi_range(120,180) if mode=="debug" else randi_range(300,600)
	model.entities[id]={"type":"sapling","kind":"sapling","cell":cell,"position":Vector3(cell)+Vector3(0.5,0,0.5),"grow_at":model.game_time+duration,"height":randi_range(3,6),"state":{}}
	model.set_block(cell,"sapling")
	return id
static func owner(model: RefCounted, cell: Vector3i) -> Dictionary:
	for tree in model.landmarks.get("planted_trees",{}).values():
		if model.generator.tree_kind(cell,tree)!=0 or cell==tree.base+Vector3i.DOWN:
			return tree
	return {}
static func grow(model: RefCounted, id: String) -> bool:
	var record: Dictionary=model.entities[id]
	var tree: Dictionary=model.generator.make_tree(record.cell,int(record.height))
	var changes: Dictionary={}
	for y in range(tree.height+2):
		for x in range(-4,5):
			for z in range(-4,5):
				var cell: Vector3i=tree.base+Vector3i(x,y,z)
				var value: int=model.generator.tree_kind(cell,tree)
				if value==0:
					continue
				if cell.y>63 or model.kind_at(cell) not in ["air","sapling","foliage"]:
					return false
				changes[cell]=Registry.kind(value)
	# Wait for animals/monsters to move out of the trunk before growing.
	var trunk:=AABB(Vector3(tree.base),Vector3(1,tree.height,1))
	for actor in model.entities.values():
		if actor.type in ["hen","zombie"] and trunk.grow(0.35).has_point(actor.position):
			return false
	model.landmarks.get_or_add("planted_trees",{})[model.text_key(tree.base)]=tree
	model.entities.erase(id)
	for cell in changes:
		model.set_block(cell,changes[cell])
	return true
static func tick(model: RefCounted) -> void:
	for id in model.entities.keys():
		var record: Dictionary=model.entities[id]
		if record.type!="sapling":
			continue
		if model.kind_at(record.cell)!="sapling":
			model.entities.erase(id)
		elif model.kind_at(record.cell+Vector3i.DOWN) not in ["dirt","farmland"]:
			model.set_block(record.cell,"air")
			model.entities.erase(id)
			model.foliage_fell.emit(record.cell,"sapling")
		elif model.game_time>=float(record.grow_at):
			grow(model,id)
