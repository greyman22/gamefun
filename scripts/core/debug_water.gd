extends RefCounted
const StructureTrees=preload("res://scripts/core/structure_trees.gd")
static func place(model: RefCounted) -> void:
	if model.landmarks.has("debug_water"):
		return
	var ground: int=maxi(0,model.generator.height(0,12))
	var pit:=Vector3i(-8,ground,5)
	StructureTrees.clear_area(model,Vector2i(pit.x-2,pit.z-3),Vector2i(pit.x+3,pit.z+4),model.set_block)
	StructureTrees.clear_area(model,Vector2i(-22,10),Vector2i(-5,27),model.set_block)
	StructureTrees.clear_area(model,Vector2i(-28,15),Vector2i(-22,22),model.set_block)
	for dx in range(-2,3):
		for dz in range(-3,4):
			for y in range(ground-4,maxi(ground+6,model.generator.height(pit.x+dx,pit.z+dz)+9)):
				var inside: bool=absi(dx)<=1 and absi(dz)<=1
				model.set_block(Vector3i(pit.x+dx,y,pit.z+dz),"stone" if y<ground and (not inside or y==ground-4) else "air")
	for dx in range(-1,2):
		for dz in range(-1,2):
			for dy in range(-3,0):
				model.water.source(pit+Vector3i(dx,dy,dz))
	# A modest soil hill attaches to the familiar hill, with stone on its far face.
	var center:=Vector2(-14,18)
	for x in range(-22,-5):
		for z in range(10,27):
			var height: int=maxi(0,roundi(7-Vector2(x-center.x,z-center.y).length()*0.7))
			for y in range(ground+height,maxi(ground+height+4,model.generator.height(x,z)+9)):
				model.set_block(Vector3i(x,y,z),"air")
			for y in range(ground-1,ground+height):
				var rock: bool=x<= -17 and z>=15 and z<=21
				model.set_block(Vector3i(x,y,z),"stone" if rock else "dirt")
	# Clear the receiving side too, so seed-specific high ground cannot bury the outlet.
	for x in range(-28,-22):
		for z in range(15,22):
			model.set_block(Vector3i(x,ground-1,z),"stone")
			for y in range(ground,maxi(ground+8,model.generator.height(x,z)+9)):
				model.set_block(Vector3i(x,y,z),"air")
	var source:=Vector3i(-18,ground+3,18)
	for x in range(-22,-17):
		for y in range(source.y,source.y+3):
			model.set_block(Vector3i(x,y,source.z),"air")
	# The outlet faces west, away from the start at (0,12).
	model.water.source(source)
	model.landmarks.debug_water={"pits":[pit],"waterfall":source,"version":2}
	model.water.process_pending(32768)
