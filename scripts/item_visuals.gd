extends RefCounted

const Registry = preload("res://scripts/core/registry.gd")

const NAMES: Dictionary = {"stone": "Stenblock", "wood": "Trädstam", "planks": "Träkloss", "stick": "Träpinne", "workbench": "Arbetsbänk", "dirt": "Jordblock", "foliage": "Grenverk", "axe": "Yxa", "pickaxe": "Hacka", "shovel": "Spade", "torch": "Fackla", "": "Hand"}
const TOOL_KINDS: Array[String] = ["axe", "pickaxe", "shovel"]

static func icon(kind: String) -> Texture2D:
	if kind == "stick":
		var picture := Image.new()
		picture.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96"><path d="M22 77L64 13L76 20L34 85Z" fill="#b68143" stroke="#674021" stroke-width="3"/><path d="M32 73L67 21" stroke="#e1b36c" stroke-width="4"/></svg>')
		return ImageTexture.create_from_image(picture)
	if kind == "torch":
		var fire := Image.new()
		fire.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96"><path d="M39 44L56 44L53 88L41 88Z" fill="#986131"/><path d="M29 39L35 20L45 30L51 5L67 31L64 48L47 60L30 50Z" fill="#ff8528"/><path d="M39 44L48 26L57 43L48 53Z" fill="#ffe77b"/></svg>')
		return ImageTexture.create_from_image(fire)
	if kind in TOOL_KINDS:
		var head: String = {
			"axe": '<path d="M47 13L78 17L83 44L64 50L53 36L43 32Z" fill="#b8d0d9" stroke="#506978" stroke-width="3"/>',
			"pickaxe": '<path d="M16 31L34 13L60 12L82 29L84 43L61 29L41 27L19 43Z" fill="#b8d0d9" stroke="#506978" stroke-width="3"/>',
			"shovel": '<path d="M32 50L62 50L67 70L48 88L28 70Z" fill="#b8d0d9" stroke="#506978" stroke-width="3"/><path d="M37 8L58 8L56 22L40 22Z" fill="none" stroke="#b8d0d9" stroke-width="5"/>'
		}[kind]
		var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96"><path d="M44 18L54 18L50 82L40 82Z" fill="#b57b40" stroke="#634020" stroke-width="2"/>%s</svg>' % head
		var picture := Image.new()
		picture.load_svg_from_string(svg)
		return ImageTexture.create_from_image(picture)
	# Code-native vector artwork matches the three block materials in the world.
	var colors: Array = {
		"stone": ["#b6bec6", "#7b8792", "#515e69"],
		"wood": ["#d0a061", "#9a6534", "#694021"],
		"planks": ["#e3ba7d", "#c39255", "#9e713f"],
		"workbench": ["#c99d63", "#926438", "#634525"],
		"dirt": ["#81be42", "#986b40", "#69462e"]
	}.get(kind, ["#edbd97", "#c18d68", "#946143"])
	if Registry.catalog.blocks.has(kind):
		var base := Color(Registry.catalog.blocks[kind].color)
		colors = ["#" + base.lightened(0.2).to_html(false), "#" + base.to_html(false), "#" + base.darkened(0.3).to_html(false)]
	var detail: String = ""
	if kind == "wood":
		detail = '<path d="M18 39L18 62M27 44L27 68M37 50L37 73M54 49L54 73M66 43L66 65M76 37L76 59" stroke="#593619" stroke-width="3"/><path d="M24 26L48 16L68 26L46 36Z M34 26L47 21L58 26L46 31Z" fill="none" stroke="#9a6534" stroke-width="2"/>'
	elif kind == "stone":
		detail = '<path d="M17 44L29 49L26 60L38 64M57 46L68 48L73 40M35 24L43 29L53 25" fill="none" stroke="#414c57" stroke-width="2"/>'
	elif kind == "dirt":
		detail = '<path d="M12 30L46 46L84 30L84 39L71 43L67 49L57 51L46 58L36 51L29 53L22 44L12 40Z" fill="#609c30"/><path d="M20 55L26 58M34 67L39 69M57 68L63 65M72 53L77 50" stroke="#c28c53" stroke-width="3"/>'
	elif kind == "planks":
		detail = '<path d="M13 42L46 59L83 42M13 54L46 71L83 54M30 39L30 50M62 51L62 63M30 64L30 76" fill="none" stroke="#76502c" stroke-width="2"/>'
	elif kind == "workbench":
		detail = '<path d="M24 24L61 41M36 18L73 35M24 36L61 18M35 42L73 24" stroke="#654422" stroke-width="2"/><path d="M19 48L19 66M38 57L38 76M55 58L55 76M76 47L76 66" stroke="#cfaa72" stroke-width="5"/>'
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96" viewBox="0 0 96 96"><path d="M12 30L48 12L84 30L46 48Z" fill="%s"/><path d="M12 30L46 48L46 84L12 66Z" fill="%s"/><path d="M46 48L84 30L84 66L46 84Z" fill="%s"/>%s</svg>' % [colors[0], colors[1], colors[2], detail]
	var image := Image.new()
	image.load_svg_from_string(svg)
	return ImageTexture.create_from_image(image)

static func stick_model(parent: Node3D) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.65, 0.42, 0.2)
	tool_part(parent, Vector3.ZERO, Vector3(0.025, 0.2, 0.025), material)

static func workbench_details(parent: Node3D, size: float) -> void:
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.24, 0.14, 0.07)
	for offset in [-0.166, 0.166]:
		tool_part(parent, Vector3(offset, 0.502, 0) * size, Vector3(0.018, 0.006, 0.98) * size, dark)
		tool_part(parent, Vector3(0, 0.502, offset) * size, Vector3(0.98, 0.006, 0.018) * size, dark)

static func torch_model(parent: Node3D, scale_factor: float = 1.0) -> Node3D:
	var model := Node3D.new()
	model.scale = Vector3.ONE * scale_factor
	parent.add_child(model)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.4, 0.22, 0.09)
	tool_part(model, Vector3(0, -0.02, 0), Vector3(0.028, 0.16, 0.028), wood)
	var flame := StandardMaterial3D.new()
	flame.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame.albedo_color = Color(1, 0.36, 0.035)
	flame.emission_enabled = true
	flame.emission = Color(1, 0.4, 0.05)
	tool_part(model, Vector3(0, 0.075, 0), Vector3(0.05, 0.065, 0.05), flame)
	var core := flame.duplicate() as StandardMaterial3D
	core.albedo_color = Color(1, 0.9, 0.35)
	tool_part(model, Vector3(0, 0.11, 0), Vector3(0.026, 0.04, 0.026), core)
	var light := OmniLight3D.new()
	light.scale = Vector3.ONE / scale_factor
	light.position.y = 0.12
	light.light_color = Color(1, 0.72, 0.38)
	light.light_energy = 0.7
	light.omni_range = 4.0
	light.omni_attenuation = 1.5
	light.shadow_enabled = true
	model.add_child(light)
	return model

static func tool_model(parent: Node3D, kind: String, scale_factor: float = 1.0) -> Node3D:
	var model := Node3D.new()
	model.scale = Vector3.ONE * scale_factor
	parent.add_child(model)
	var handle := StandardMaterial3D.new()
	handle.albedo_color = Color(0.5, 0.29, 0.12)
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.58, 0.72, 0.78)
	metal.metallic = 0.6
	metal.roughness = 0.4
	tool_part(model, Vector3(0, -0.015, 0), Vector3(0.022, 0.19, 0.025), handle)
	match kind:
		"axe":
			tool_part(model, Vector3(0.026, 0.063, 0), Vector3(0.085, 0.06, 0.024), metal)
			tool_part(model, Vector3(0.069, 0.061, 0), Vector3(0.015, 0.078, 0.03), metal)
		"pickaxe":
			tool_part(model, Vector3(0, 0.078, 0), Vector3(0.14, 0.027, 0.028), metal)
			for side in [-1, 1]:
				var tip := tool_part(model, Vector3(side * 0.078, 0.064, 0), Vector3(0.045, 0.022, 0.025), metal)
				tip.rotation.z = -side * 0.6
		"shovel":
			tool_part(model, Vector3(0, -0.09, 0), Vector3(0.068, 0.064, 0.018), metal)
			tool_part(model, Vector3(0, -0.124, 0), Vector3(0.043, 0.012, 0.018), metal)
			tool_part(model, Vector3(0, 0.088, 0), Vector3(0.055, 0.018, 0.025), metal)
	return model

static func tool_part(parent: Node3D, center: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	var geometry := BoxMesh.new()
	geometry.size = size
	part.mesh = geometry
	part.material_override = material
	part.position = center
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(part)
	return part
