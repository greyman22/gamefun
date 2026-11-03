extends RefCounted
const Registry=preload("res://scripts/core/registry.gd")
const Water=preload("res://scripts/core/water.gd")
static func land_points(model: RefCounted, origin: Vector3, radius: float) -> Array[Vector3]:
	var points: Array[Vector3]=[]
	var reach: int=ceili(radius)
	for dx in range(-reach,reach+1):
		for dz in range(-reach,reach+1):
			var x: int=floori(origin.x)+dx
			var z: int=floori(origin.z)+dz
			if Vector2(x+0.5-origin.x,z+0.5-origin.z).length()>radius-0.2:
				continue
			var top: int=mini(model.generator.max_y(),maxi(model.generator.height(x,z)+10,ceili(origin.y)+4))
			if model.generator.version>=3:
				top=maxi(top,model.generator.SEA_LEVEL+4)
			for y in range(top,-65,-1):
				var cell:=Vector3i(x,y,z)
				if model.kind_at(cell) not in ["dirt","stone","lakebed","farmland","planks","wood","bedrock"]:
					continue
				if model.generator.version>=3 and y+1<model.generator.SEA_LEVEL and model.generator.height(x,z)<model.generator.SEA_LEVEL:
					continue
				if model.kind_at(cell+Vector3i.UP)=="air" and model.kind_at(cell+Vector3i.UP*2)=="air":
					points.append(Vector3(cell)+Vector3(0.5,1.16,0.5))
					break
	return points
static func spill(world: Node, origin: Vector3) -> int:
	var stacks: Array=[]
	for slot in world.inventory.slots+world.crafting.slots+[world.stack_cursor.held]:
		if int(slot.count)>0:
			stacks.append(slot.duplicate(true))
	var pool: Array[int]=[]
	for i in range(stacks.size()):
		for n in range(int(stacks[i].count)):
			pool.append(i)
	if pool.is_empty():
		return 0
	var in_water: bool=not world.mounted_boat.is_empty() or world.model.water.contains(origin+Vector3.UP*0.5) or world.model.water.contains(origin-Vector3.UP*0.3)
	var points: Array[Vector3]=land_points(world.model,origin,10 if in_water else 4)
	if points.is_empty():
		return 0
	pool.shuffle()
	var low: int=ceili(pool.size()*0.7)
	var high: int=floori(pool.size()*0.9)
	var count: int=randi_range(low,high) if high>=low else clampi(roundi(pool.size()*0.8),1,pool.size())
	var chosen: Dictionary={}
	for n in range(count):
		chosen[pool[n]]=int(chosen.get(pool[n],0))+1
	for index in chosen:
		var slot: Dictionary=stacks[index]
		var point: Vector3=points.pick_random()+Vector3(randf_range(-0.12,0.12),0,randf_range(-0.12,0.12))
		var id: String=world.entity_system.spawn_drop(slot.kind,point,int(chosen[index]))
		var record: Dictionary=world.model.entities[id]
		record.item=Registry.stack(slot.kind,int(chosen[index]),slot)
		record.state.velocity_x=0
		record.state.velocity_z=0
		record.state.velocity_y=0
		record.state.grounded=true
	return count
