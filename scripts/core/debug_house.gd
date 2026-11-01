extends RefCounted
const Writer = preload("res://scripts/core/zombie_house.gd")
const Doors = preload("res://scripts/core/doors.gd")
const Visuals = preload("res://scripts/item_visuals.gd")

func place(model: RefCounted) -> Dictionary:
	if model.landmarks.has("debug_house"):
		return model.landmarks.debug_house
	var heights: Array[int] = []
	for x in range(10,17):
		for z in range(8,16):
			heights.append(model.generator.height(x,z))
	heights.sort()
	var base := Vector3i(10,maxi(0,heights[heights.size()/2]-1),8)
	var writer := Writer.new()
	writer.data = model
	# An ordinary voxel building: five by six clear interior cells, three high.
	for x in range(-2,9):
		for z in range(-2,10):
			var natural: int = model.generator.height(base.x+x,base.z+z)
			for y in range(mini(natural-1,base.y-1),base.y+1):
				writer.write(Vector3i(base.x+x,y,base.z+z),"dirt")
			for y in range(base.y+1,maxi(natural+9,base.y+9)):
				writer.write(Vector3i(base.x+x,y,base.z+z),"air")
	for x in range(7):
		for z in range(8):
			writer.write(base+Vector3i(x,0,z),"planks")
			if x in [0,6] or z in [0,7]:
				for y in range(1,4):
					writer.write(base+Vector3i(x,y,z),"wood" if x in [0,6] and z in [0,7] else "planks")
	for x in range(-1,8):
		var roof_y: int = 4 + (4-absi(x-3))/2
		for z in range(-1,9):
			writer.write(base+Vector3i(x,roof_y,z),"planks")
		for z in [0,7]:
			for y in range(4,roof_y):
				writer.write(base+Vector3i(x,y,z),"planks")
	for x in range(1,6):
		for z in range(1,7):
			writer.write(base+Vector3i(x,4,z),"planks")
	var door_cell := base+Vector3i(3,1,7)
	writer.write(door_cell,"air")
	writer.write(door_cell+Vector3i.UP,"air")
	model.cache.clear()
	Doors.place(model,door_cell,0)
	var torches: Array[String] = []
	for spec in [[Vector3i(2,2,7),Vector3.FORWARD],[Vector3i(3,2,0),Vector3.BACK],[Vector3i(0,2,3),Vector3.RIGHT],[Vector3i(6,2,3),Vector3.LEFT]]:
		for side in [1,-1]:
			var normal: Vector3 = spec[1]*side
			var cell: Vector3i = base+spec[0]+Vector3i(normal)
			writer.write(cell,"torch")
			var id: String = "torch_"+model.text_key(cell)
			torches.append(id)
			model.entities[id] = {"type":"torch","kind":"torch","cell":cell,"position":Visuals.torch_anchor(cell,normal),"normal":normal,"state":{}}
	model.cache.clear()
	for key: Vector3i in writer.touched:
		for offset in [Vector3i.ZERO,Vector3i.LEFT,Vector3i.RIGHT,Vector3i.UP,Vector3i.DOWN,Vector3i.FORWARD,Vector3i.BACK]:
			model.revisions[key+offset] = int(model.revisions.get(key+offset,0))+1
		model.block_changed.emit(key*16)
	var record := {"base":base,"interior":Vector3i(5,3,6),"door":door_cell,"torches":torches}
	model.landmarks.debug_house = record
	return record
