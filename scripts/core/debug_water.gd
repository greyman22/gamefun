extends RefCounted
static func place(model: RefCounted) -> void:
	if model.landmarks.has("debug_water"):
		return
	var pits: Array[Vector3i]=[]
	var ground: int=maxi(0,model.generator.height(0,12))
	# North-west of spawn, separated from the existing house to the east.
	for i in range(5):
		var x: int= -8-i*5
		var z: int=5
		var y: int=ground
		var depth: int=1+i%4
		for dx in range(-2,3):
			for dz in range(-3,4):
				for dy in range(-depth-1,maxi(6,model.generator.height(x+dx,z+dz)+9-y)):
					var cell:=Vector3i(x+dx,y+dy,z+dz)
					var inside: bool=absi(dx)<=1 and absi(dz)<=1
					var kind: String="stone" if dy<0 and (not inside or dy== -depth-1) else ("air" if inside or dy>=0 else "dirt")
					if model.kind_at(cell)!=kind:
						model.set_block(cell,kind)
		for dx in range(-1,2):
			for dz in range(-1,2):
				for dy in range(-depth,0):
					model.water.source(Vector3i(x+dx,y+dy,z+dz))
		pits.append(Vector3i(x,y,z))
	# A level path makes every pit reachable even with a mountainous seed.
	for x in range(-31,1):
		for z in range(8,13):
			for y in range(ground-1,maxi(ground+5,model.generator.height(x,z)+9)):
				var cell:=Vector3i(x,y,z)
				var kind: String="stone" if y==ground-1 else "air"
				if model.kind_at(cell)!=kind:
					model.set_block(cell,kind)
	var base:=Vector3i(-10,ground,-7)
	for dx in range(-4,5):
		for dz in range(-1,7):
			for dy in range(-1,7):
				var cell: Vector3i=base+Vector3i(dx,dy,dz)
				var kind: String="stone" if dy== -1 or (dz<=0 and dy<5) else "air"
				model.set_block(cell,kind)
	model.set_block(base+Vector3i(0,3,0),"air")
	model.water.source(base+Vector3i(0,3,0))
	model.landmarks.debug_water={"pits":pits,"waterfall":base+Vector3i(0,3,0)}
	model.water.process_pending(32768)
