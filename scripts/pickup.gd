extends Node3D

const Registry = preload("res://scripts/core/registry.gd")
const Visuals = preload("res://scripts/item_visuals.gd")

var resource_kind: String = "axe"
var collected: bool = false

func configure(kind: String) -> void:
	resource_kind = kind
	if Registry.tool(kind):
		Visuals.tool_model(self, kind, 3.0)
	elif kind == "torch":
		Visuals.torch_model(self, 0.8)
	elif kind == "stick":
		Visuals.stick_model(self)
	else:
		var definition: Dictionary = Registry.catalog.blocks.get(kind, {})
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(definition.get("color", "aaaaaa"))
		material.roughness = 0.95
		Visuals.tool_part(self, Vector3.ZERO, Vector3.ONE * 0.25, material)
		if kind == "dirt":
			var grass := StandardMaterial3D.new()
			grass.albedo_color = Color(0.35, 0.6, 0.2)
			Visuals.tool_part(self, Vector3(0, 0.126, 0), Vector3(0.25, 0.008, 0.25), grass)
		elif kind == "workbench":
			Visuals.workbench_details(self, 0.25)
