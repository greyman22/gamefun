extends SceneTree
const Data=preload("res://scripts/core/world_data.gd")
const Flat=preload("res://scripts/tests/night_population_tests.gd")
const Light=preload("res://scripts/core/daylight.gd")
const Registry=preload("res://scripts/core/registry.gd")
var failures: int=0
func expect(ok: bool, label: String) -> void:
	if not ok:
		failures+=1
		push_error(label)
func _initialize() -> void:
	Registry.initialize()
	var model=Data.new(42)
	model.generator=Flat.FlatLand.new()
	var light=Light.new()
	light.configure(model)
	expect(light.exposure(Vector3(0.5,1.5,0.5))==1,"Open ground has full daylight")
	model.set_block(Vector3i(0,4,0),"foliage")
	expect(light.exposure(Vector3(0.5,1.5,0.5))==1,"Tree leaves do not dim the entire outdoor scene")
	model.set_block(Vector3i(0,4,0),"stone")
	expect(light.exposure(Vector3(0.5,1.5,0.5))==1,"An open edge does not dim daylight")
	for x in range(1,20):
		for z in range(-1,2):
			model.set_block(Vector3i(x,2,z),"stone")
		for y in range(0,2):
			for z in [-1,1]:
				model.set_block(Vector3i(x,y,z),"stone")
	var near: float=light.exposure(Vector3(2.5,1.5,0.5))
	var deep: float=light.exposure(Vector3(6.5,1.5,0.5))
	expect(near<1 and deep<0.05 and deep<near,"Tunnel darkens progressively to near black at six metres")
	print("BOW LIGHT TESTS ","PASS" if failures==0 else failures)
	quit(0 if failures==0 else 1)
