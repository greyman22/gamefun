extends SceneTree
const Data = preload("res://scripts/core/world_data.gd")
const House = preload("res://scripts/core/zombie_house.gd")
const Registry = preload("res://scripts/core/registry.gd")
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func expect(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	Registry.initialize()
	for seed_value in [123, 41829, 20261030, 98765]:
		for debug_mode in [true, false]:
			var model := Data.new(seed_value)
			var record: Dictionary = House.new().place(model, debug_mode)
			var base: Vector3i = record.base
			var heights: Array[int] = []
			for x in range(-5, 6):
				for z in range(-4, 5):
					heights.append(model.generator.height(base.x+x,base.z+z))
			heights.sort()
			expect(base.y == maxi(0, heights[heights.size()/2] - 1), "Floor follows median terrain rather than highest corner")
			for x in [-4,0,4]:
				for z in [5,8,12]:
					expect(model.kind_at(base + Vector3i(x,0,z)) == "dirt" and model.kind_at(base + Vector3i(x,1,z)) == "air", "Ground ahead of door matches floor height")
			expect(Vector2(base.x,base.z-12).length() >= (39 if debug_mode else 199), "Requested house distance preserved")
			print("HOUSE ",seed_value," debug=",debug_mode," floor=",base.y," natural median=",heights[heights.size()/2])
	print("HOUSE TERRAIN TESTS: ", "PASS" if failures == 0 else failures)
	quit(0 if failures == 0 else 1)
