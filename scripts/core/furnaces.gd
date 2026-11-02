extends RefCounted
const Registry=preload("res://scripts/core/registry.gd")
const PARTS=["furnace","furnace_lit"]
static func records(model: RefCounted) -> Dictionary:
	return model.landmarks.get_or_add("furnaces",{})
static func state(model: RefCounted, cell: Vector3i) -> Dictionary:
	var all: Dictionary=records(model)
	if not all.has(cell):
		all[cell]={"slots":[{"kind":"","count":0},{"kind":"","count":0},{"kind":"","count":0}],"burn_left":0.0,"burn_total":0.0,"progress":0.0,"processing_kind":""}
	return all[cell]
static func contents(model: RefCounted, cell: Vector3i) -> Array:
	return state(model,cell).slots
static func fuel_seconds(kind: String) -> float:
	return float(Registry.catalog.items.get(kind,{}).get("burn_seconds",0))
static func recipe(kind: String) -> Dictionary:
	return Registry.catalog.get("smelting",{}).get(kind,{})
static func can_smelt(value: Dictionary) -> bool:
	var input: Dictionary=value.slots[0]
	var output: Dictionary=value.slots[2]
	var rule: Dictionary=recipe(input.kind)
	if input.count<=0 or rule.is_empty():
		return false
	return (output.count==0 or output.kind==rule.result) and int(output.count)+int(rule.count)<=Registry.stack_limit(rule.result)
static func consume(slot: Dictionary) -> void:
	slot.count-=1
	if slot.count<=0:
		Registry.clear_slot(slot)
static func advance(value: Dictionary, delta: float) -> void:
	var input: Dictionary=value.slots[0]
	if str(value.processing_kind)!=str(input.kind):
		value.progress=0.0
		value.processing_kind=input.kind
	var remaining: float=maxf(0,delta)
	while remaining>0.000001:
		if float(value.burn_left)<=0.000001:
			value.burn_left=0.0
			var fuel: Dictionary=value.slots[1]
			if not can_smelt(value) or fuel.count<=0 or fuel_seconds(fuel.kind)<=0:
				break
			value.burn_total=fuel_seconds(fuel.kind)
			value.burn_left=value.burn_total
			consume(fuel)
		if can_smelt(value):
			var rule: Dictionary=recipe(input.kind)
			var step: float=minf(remaining,minf(float(value.burn_left),float(rule.seconds)-float(value.progress)))
			value.progress+=step
			value.burn_left=maxf(0,float(value.burn_left)-step)
			remaining-=step
			if float(value.progress)>=float(rule.seconds)-0.000001:
				Registry.fill_slot(value.slots[2],Registry.stack(rule.result,int(rule.count)),int(rule.count))
				consume(input)
				value.progress=0.0
				value.processing_kind=input.kind
		else:
			var step: float=minf(remaining,float(value.burn_left))
			value.burn_left-=step
			remaining-=step
			if input.count<=0:
				value.progress=0.0
static func tick(model: RefCounted, delta: float) -> void:
	for cell in records(model).keys():
		if model.kind_at(cell) not in PARTS:
			records(model).erase(cell)
			continue
		var value: Dictionary=state(model,cell)
		advance(value,delta)
		var lit: bool=float(value.burn_left)>0.000001
		var kind: String="furnace_lit" if lit else "furnace"
		if model.kind_at(cell)!=kind:
			model.set_block(cell,kind)
static func remove(model: RefCounted, cell: Vector3i) -> Array[Dictionary]:
	var items: Array[Dictionary]=[]
	if records(model).has(cell):
		for slot in state(model,cell).slots:
			if slot.count>0:
				items.append(slot.duplicate(true))
		records(model).erase(cell)
	return items
