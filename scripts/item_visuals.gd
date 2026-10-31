extends RefCounted

const Registry = preload("res://scripts/core/registry.gd")

const NAMES: Dictionary = {"stone": "Stenblock", "wood": "Trädstam", "planks": "Träkloss", "stick": "Träpinne", "workbench": "Arbetsbänk", "dirt": "Jordblock", "foliage": "Grenverk", "axe": "Yxa", "pickaxe": "Hacka", "shovel": "Spade", "torch": "Fackla", "": "Hand"}
const TOOL_KINDS: Array[String] = ["axe", "pickaxe", "shovel"]

static func icon(kind: String) -> Texture2D:
	if kind == "raw_chicken":
		var picture := Image.new()
		picture.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96"><path d="M64 60L82 77M78 73L86 70M78 73L76 83" stroke="#eee5d4" stroke-width="10" stroke-linecap="round"/><path d="M17 43C11 17 49 10 65 28C87 52 60 78 37 72C23 68 13 57 17 43Z" fill="#d58d8e" stroke="#8b5558" stroke-width="4"/><path d="M25 38C27 25 45 25 52 32" stroke="#f1b7b3" stroke-width="7" fill="none"/></svg>')
		return ImageTexture.create_from_image(picture)
	if kind == "egg":
		var picture := Image.new()
		picture.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96"><path d="M48 10C30 10 17 44 17 62C17 94 79 94 79 62C79 44 66 10 48 10Z" fill="#f5e9c8" stroke="#aa9870" stroke-width="4"/><path d="M38 26C29 40 27 49 28 60" fill="none" stroke="#fff9e9" stroke-width="6"/></svg>')
		return ImageTexture.create_from_image(picture)
	if kind == "blueberry":
		var berry := Image.new()
		berry.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96"><path d="M47 29C34 11 54 5 71 14L56 32" fill="#488c31"/><circle cx="45" cy="55" r="29" fill="#253ea0" stroke="#172254" stroke-width="4"/><path d="M41 31L46 38L53 31L51 41L60 43L49 47L48 55L42 47L32 45L40 40Z" fill="#455bb6"/><path d="M26 49C21 62 30 73 37 74" fill="none" stroke="#8fa6ea" stroke-width="5"/></svg>')
		return ImageTexture.create_from_image(berry)
	if kind == "soul_remnant":
		var orb := Image.new()
		orb.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96" viewBox="0 0 32 32" shape-rendering="crispEdges"><path d="M12 2H20V4H24V7H27V11H29V22H27V26H23V29H18V31H12V29H8V27H5V23H3V13H5V9H8V5H12Z" fill="#270b45"/><path d="M12 5H20V7H24V11H26V15H27V21H24V25H20V28H13V26H9V23H6V15H8V11H11Z" fill="#6031a1"/><path d="M12 8H19V10H22V13H24V19H21V22H17V25H12V22H9V18H7V14H10V11H12Z" fill="#a74aef"/><path d="M12 10H17V12H20V17H17V20H12V18H10V14H12Z" fill="#cf80ff"/><path d="M12 12H15V16H12V18H10V14H12Z" fill="#f4e3ff"/></svg>')
		return ImageTexture.create_from_image(orb)
	if kind == "stone_sword":
		var sword := Image.new()
		sword.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96"><path d="M29 68L35 62" stroke="#946039" stroke-width="10"/><path d="M27 51L47 71" stroke="#59616a" stroke-width="8"/><path d="M36 56L66 17L82 10L77 29L46 66Z" fill="#b6bec6" stroke="#56616b" stroke-width="3"/><path d="M44 57L73 22" stroke="#e3e7ea" stroke-width="3"/></svg>')
		return ImageTexture.create_from_image(sword)
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
	if kind == "stone":
		detail = '<path d="M17 44L29 49L26 60L38 64M57 46L68 48L73 40M35 24L43 29L53 25" fill="none" stroke="#414c57" stroke-width="2"/>'
	elif kind == "dirt":
		detail = '<path d="M12 30L46 46L84 30L84 39L71 43L67 49L57 51L46 58L36 51L29 53L22 44L12 40Z" fill="#609c30"/><path d="M20 55L26 58M34 67L39 69M57 68L63 65M72 53L77 50" stroke="#c28c53" stroke-width="3"/>'
	elif kind == "planks":
		detail = '<path d="M13 42L46 59L83 42M13 54L46 71L83 54M30 39L30 50M62 51L62 63M30 64L30 76" fill="none" stroke="#76502c" stroke-width="2"/>'
	elif kind == "workbench":
		for row in range(4):
			for column in range(4):
				var point := Vector2(48, 12) + Vector2(9, 4.5) * column + Vector2(-9.5, 4.5) * row
				detail += '<path d="M%f %f l9 4.5 -9.5 4.5 -9 -4.5Z" fill="%s"/>' % [point.x, point.y, "#dfb578" if (row + column) % 2 == 0 else "#55331d"]
		detail += '<path d="M18 40L18 67M39 51L39 78M54 52L54 77M77 41L77 67" stroke="#422817" stroke-width="6"/>'
	elif kind == "chest":
		detail = '<path d="M13 43L46 61L83 43M17 33L17 65M80 33L80 66" fill="none" stroke="#55351e" stroke-width="5"/><path d="M27 50L36 55L36 65L27 60Z" fill="#efcf62" stroke="#55351e" stroke-width="2"/>'
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96" viewBox="0 0 96 96"><path d="M12 30L48 12L84 30L46 48Z" fill="%s"/><path d="M12 30L46 48L46 84L12 66Z" fill="%s"/><path d="M46 48L84 30L84 66L46 84Z" fill="%s"/>%s</svg>' % [colors[0], colors[1], colors[2], detail]
	var image := Image.new()
	image.load_svg_from_string(svg)
	return ImageTexture.create_from_image(image)

static func soul_remnant_model(parent: Node3D) -> Node3D:
	var model := Node3D.new()
	parent.add_child(model)
	var orb := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.115
	sphere.height = 0.23
	sphere.radial_segments = 12
	sphere.rings = 6
	orb.mesh = sphere
	var purple := StandardMaterial3D.new()
	purple.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	purple.albedo_color = Color(0.55, 0.13, 0.88)
	purple.emission_enabled = true
	purple.emission = Color(0.6, 0.16, 1)
	orb.material_override = purple
	orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	model.add_child(orb)
	var highlight := StandardMaterial3D.new()
	highlight.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	highlight.albedo_color = Color(0.94, 0.79, 1)
	tool_part(model, Vector3(-0.035, 0.05, -0.085), Vector3(0.035, 0.045, 0.025), highlight)
	var glow_image := Image.new()
	glow_image.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96"><defs><radialGradient id="g"><stop stop-color="#cc7aff" stop-opacity="0.6"/><stop offset="0.4" stop-color="#b044ee" stop-opacity="0.35"/><stop offset="1" stop-color="#8b26d9" stop-opacity="0"/></radialGradient></defs><circle cx="48" cy="48" r="47" fill="url(#g)"/></svg>')
	var glow := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.55, 0.55)
	glow.mesh = quad
	var aura := StandardMaterial3D.new()
	aura.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	aura.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	aura.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	aura.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	aura.albedo_texture = ImageTexture.create_from_image(glow_image)
	glow.material_override = aura
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	model.add_child(glow)
	return model

static func blueberry_model(parent: Node3D) -> void:
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.08
	sphere.height = 0.16
	sphere.radial_segments = 12
	sphere.rings = 6
	mesh.mesh = sphere
	var surface := StandardMaterial3D.new()
	surface.albedo_color = Color(0.12, 0.2, 0.65)
	mesh.material_override = surface
	parent.add_child(mesh)

static func stick_model(parent: Node3D) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.65, 0.42, 0.2)
	tool_part(parent, Vector3.ZERO, Vector3(0.025, 0.2, 0.025), material)

static func workbench_details(parent: Node3D, size: float) -> void:
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.24, 0.14, 0.07)
	var light := StandardMaterial3D.new()
	light.albedo_color = Color("dfb578")
	for row in range(4):
		for column in range(4):
			tool_part(parent, Vector3(-0.375 + column * 0.25, 0.504, -0.375 + row * 0.25) * size, Vector3(0.25, 0.008, 0.25) * size, light if (row + column) % 2 == 0 else dark)

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
	if kind == "stone_sword":
		# Total length 0.5 m: wooden grip 0.05 m (10 percent).
		tool_part(model, Vector3(0, -0.075, 0), Vector3(0.026, 0.05, 0.028), handle)
	else:
		tool_part(model, Vector3(0, -0.015, 0), Vector3(0.022, 0.19, 0.025), handle)
	match kind:
		"stone_sword":
			tool_part(model, Vector3(0, -0.0375, 0), Vector3(0.13, 0.025, 0.035), metal)
			tool_part(model, Vector3(0, 0.17, 0), Vector3(0.048, 0.39, 0.018), metal)
			tool_part(model, Vector3(0, 0.3825, 0), Vector3(0.026, 0.035, 0.018), metal)
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

static func egg_model(parent: Node3D) -> void:
	var shell := StandardMaterial3D.new()
	shell.albedo_color = Color("f5e9c8")
	var mesh := MeshInstance3D.new()
	var egg := SphereMesh.new()
	egg.radius = 0.1
	egg.height = 0.27
	egg.radial_segments = 12
	egg.rings = 6
	mesh.mesh = egg
	mesh.material_override = shell
	parent.add_child(mesh)

static func raw_chicken_model(parent: Node3D) -> void:
	var meat := StandardMaterial3D.new()
	meat.albedo_color = Color("d58d8e")
	tool_part(parent, Vector3.ZERO, Vector3(0.24, 0.16, 0.2), meat)
	var bone := StandardMaterial3D.new()
	bone.albedo_color = Color("eee5d4")
	tool_part(parent, Vector3(0.16, 0, 0), Vector3(0.14, 0.055, 0.055), bone)
	tool_part(parent, Vector3(0.23, 0, 0), Vector3(0.06, 0.09, 0.09), bone)
