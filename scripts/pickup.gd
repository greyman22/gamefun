extends Node3D

const Surfaces = preload("res://scripts/rendering/surface_textures.gd")
const Registry = preload("res://scripts/core/registry.gd")
const Visuals = preload("res://scripts/item_visuals.gd")

var resource_kind: String = "axe"
var collected: bool = false
var soul_visual: Node3D
var float_phase: float = 0

func configure(kind: String) -> void:
	resource_kind = kind
	if kind=="grass_seed":
		scale=Vector3.ONE*4.0
	if kind in ["stick","foliage","wood","dirt","stone"]:
		scale = Vector3.ONE*1.25
	if kind == "gate":
		Visuals.gate_model(self,0.2)
	elif kind == "fence":
		Visuals.fence_model(self,0.2)
	elif kind == "foliage":
		Visuals.branch_model(self)
	elif kind == "planks":
		Visuals.plank_model(self)
	elif kind == "door":
		Visuals.door_model(self,0.13)
	elif kind == "raw_chicken":
		Visuals.raw_chicken_model(self)
	elif kind == "egg":
		Visuals.egg_model(self)
	elif kind in ["grass_seed","grain","bread"]:
		Visuals.farm_item_model(self,kind)
	elif kind == "blueberry":
		Visuals.blueberry_model(self)
	elif kind == "soul_remnant":
		soul_visual = Visuals.soul_remnant_model(self)
		soul_visual.position.y = 0.18
	elif Registry.tool(kind):
		Visuals.tool_model(self, kind, 3.0)
	elif kind == "torch":
		Visuals.torch_model(self, 0.8)
	elif kind == "stick":
		Visuals.stick_model(self)
	else:
		var definition: Dictionary = Registry.catalog.blocks.get(kind, {})
		var material := Surfaces.material(kind,2 if kind=="dirt" else 0)
		Visuals.tool_part(self, Vector3.ZERO, Vector3.ONE * 0.25, material)
		if kind == "wood":
			Visuals.log_details(self,0.25)
		elif kind == "soul_block":
			Visuals.soul_block_details(self,0.25)
		if kind == "dirt":
			var grass := Surfaces.material("dirt",1)
			Visuals.tool_part(self, Vector3(0, 0.126, 0), Vector3(0.25, 0.008, 0.25), grass)
		elif kind == "workbench":
			Visuals.workbench_details(self, 0.25)

func _process(delta: float) -> void:
	if not is_instance_valid(soul_visual):
		return
	float_phase += delta * 2.5
	soul_visual.position.y = 0.18 + sin(float_phase) * 0.035
	soul_visual.rotation.y += delta * 0.8
