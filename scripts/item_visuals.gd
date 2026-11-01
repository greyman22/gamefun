extends RefCounted
# Working tips in model coordinates, shared by held animation and checks.
const TOOL_TIPS := {
	"stone_sword": Vector3(0,0.4,0),
	"axe": Vector3(0.0765,0.1,0),
	"pickaxe": Vector3(0.096,0.077,0),
	"shovel": Vector3(0,0.28,0),
	"hoe": Vector3(0.1,0.09,0)
}

const Surfaces = preload("res://scripts/rendering/surface_textures.gd")
const Registry = preload("res://scripts/core/registry.gd")

const NAMES: Dictionary = {"stone": "Stenblock", "wood": "Trädstam", "planks": "Träkloss", "stick": "Träpinne", "workbench": "Arbetsbänk", "dirt": "Jordblock", "foliage": "Grenverk", "axe": "Yxa", "pickaxe": "Gruvhacka", "shovel": "Spade", "torch": "Fackla", "": "Hand"}
const TOOL_KINDS: Array[String] = ["axe", "pickaxe", "shovel", "hoe"]

static func icon(kind: String) -> Texture2D:
	if kind in ["fence","gate"]:
		var picture := Image.new()
		var svg: String = '<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96"><g stroke="#614628" stroke-width="2" stroke-linejoin="round"><path d="M16 19L25 14L25 77L16 82Z" fill="#9b6839"/><path d="M25 14L33 19L33 82L25 77Z" fill="#c59a63"/><path d="M66 35L75 30L75 85L66 90Z" fill="#9b6839"/><path d="M75 30L83 35L83 90L75 85Z" fill="#c59a63"/><path d="M12 28L21 23L87 44L78 49Z" fill="#e2bc83"/><path d="M12 28L78 49L78 58L12 37Z" fill="#b5844c"/><path d="M12 49L21 44L87 65L78 70Z" fill="#e2bc83"/><path d="M12 49L78 70L78 79L12 58Z" fill="#b5844c"/></g></svg>'
		if kind == "gate":
			svg = svg.replace("</g>",'<path d="M45 40L45 72M50 42L50 74" stroke="#614628"/><path d="M40 51L55 56L55 62L40 57Z" fill="#414850"/></g>')
		if kind == "fence":
			svg = svg.replace('<g stroke=','<g transform="translate(14.4 0) scale(0.7 1)" stroke=')
		picture.load_svg_from_string(svg)
		return ImageTexture.create_from_image(picture)
	var detailed: Texture2D = Surfaces.icon(kind)
	if detailed != null:
		return detailed
	if kind == "foliage":
		var picture := Image.new()
		var paths: String = ""
		for face in [[Vector2(48,12),Vector2(2.25,1.125),Vector2(-2.25,1.125),Color("61913e")],[Vector2(12,30),Vector2(2.125,1.125),Vector2(0,2.25),Color("426d2e")],[Vector2(46,48),Vector2(2.375,-1.125),Vector2(0,2.25),Color("345824")]]:
			for y in range(16):
				for x in range(16):
					var h: int = absi((x/2)*1619 ^ (y/2)*31337 ^ 4*6971)
					if h%100 >= 80:
						continue
					var point: Vector2 = face[0]+face[1]*x+face[2]*y
					var shade: Color = face[3]*(0.85+float(h%10)/50)
					paths += '<path d="M%f %f l%f %f %f %f %f %fZ" fill="#%s"/>'%[point.x,point.y,face[1].x,face[1].y,face[2].x,face[2].y,-face[1].x,-face[1].y,shade.to_html(false)]
		picture.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96">'+paths+'</svg>')
		return ImageTexture.create_from_image(picture)
	if kind == "door":
		var picture := Image.new()
		var detail: String = '<path d="M23 8H73V88H23Z" fill="#b98b54" stroke="#674523" stroke-width="4"/><path d="M32 18H64V44H32Z" fill="#536d70" stroke="#674523" stroke-width="5"/><path d="M48 18V44M32 31H64M32 55H64V78H32Z" fill="none" stroke="#76522e" stroke-width="3"/><circle cx="65" cy="52" r="4" fill="#edc76d"/>' if kind == "door" else '<path d="M12 42L58 19L84 33L38 56Z" fill="#d9ac72"/><path d="M12 42V54L38 68V56Z" fill="#b68650"/><path d="M38 56L84 33V45L38 68Z" fill="#9b6d3e"/><path d="M24 41L57 25M36 47L69 31" stroke="#bd8b53" stroke-width="2"/>'
		picture.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96">'+detail+'</svg>')
		return ImageTexture.create_from_image(picture)
	if kind == "raw_chicken":
		var picture := Image.new()
		picture.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96"><g stroke="#a56a72" stroke-width="2.5" stroke-linejoin="round"><path d="M26 39C12 34 8 51 19 62L31 58M70 39C84 34 88 51 77 62L65 58" fill="#dca6ac"/><path d="M31 59C15 58 12 72 22 78L30 89L40 83L36 70M65 59C81 58 84 72 74 78L66 89L56 83L60 70" fill="#e6b5ba"/><path d="M40 18L39 8L56 8L55 19" fill="#f2d0cb"/><path d="M25 33C27 12 69 12 71 33L73 53C74 79 22 79 23 53Z" fill="#edc0c4"/><path d="M47 24L47 62M31 40C29 50 32 58 37 60" fill="none" stroke="#f8d9d5" stroke-width="4"/></g><path d="M29 82L25 90M67 82L71 90" stroke="#f6e8d6" stroke-width="7" stroke-linecap="round"/></svg>')
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
	if kind in ["grass_seed","grain","bread"]:
		var picture := Image.new()
		var shapes: String = {
			"grass_seed": '<path d="M27 73Q12 48 34 40Q49 65 27 73ZM55 55Q37 29 60 19Q77 42 55 55ZM64 81Q48 60 74 49Q88 72 64 81Z" fill="#b0ba46" stroke="#52652a" stroke-width="3"/>',
			"grain": '<path d="M30 85L59 17M44 66L29 51M50 52L69 44M56 37L42 24" stroke="#9b7729" stroke-width="5"/><path d="M55 20L62 8L68 20L61 34ZM43 40L31 24L28 41L42 54ZM55 44L76 29L72 48L53 58ZM36 63L19 47L21 65L33 75Z" fill="#e4bd54" stroke="#a77a28" stroke-width="2"/>',
			"bread": '<path d="M12 60Q6 30 33 23Q75 9 87 41L87 66Q48 87 13 73Z" fill="#b96f2e" stroke="#75401d" stroke-width="3"/><path d="M15 54Q10 31 36 27Q73 14 84 44Q50 64 15 64Z" fill="#dfa452"/><path d="M34 30L41 45M51 26L59 40M68 25L75 36" stroke="#f3d28a" stroke-width="5"/>'
		}[kind]
		picture.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96">'+shapes+'</svg>')
		return ImageTexture.create_from_image(picture)
	if kind in TOOL_KINDS:
		var head: String = {
			"hoe": '<path d="M20 19L75 19L75 49L60 49L60 31L20 31Z" fill="#b8d0d9" stroke="#506978" stroke-width="3"/>',
			"axe": '<path d="M46 14L81 14L81 49L66 49L54 35L45 31Z" fill="#b8d0d9" stroke="#506978" stroke-width="3"/>',
			"pickaxe": '<path d="M16 31L34 13L60 12L82 29L84 43L61 29L41 27L19 43Z" fill="#b8d0d9" stroke="#506978" stroke-width="3"/>',
			"shovel": '<path d="M32 50L62 50L67 70L48 88L28 70Z" fill="#b8d0d9" stroke="#506978" stroke-width="3"/><path d="M37 8L58 8L56 22L40 22Z" fill="none" stroke="#b8d0d9" stroke-width="5"/>'
		}[kind]
		var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96"><path d="M44 18L54 18L50 82L40 82Z" fill="#b57b40" stroke="#634020" stroke-width="2"/>%s</svg>' % head
		if kind=="hoe":
			svg=svg.replace('<path d="M44','<g transform="rotate(22 48 48)"><path d="M44').replace("</svg>","</g></svg>")
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
	if kind == "dirt":
		colors[0] = "#72b33b"
	var detail: String = ""
	if kind == "wood":
		detail = '<path d="M15 30L48 14L81 30L46 46Z" fill="#5d3c25"/><path d="M20 30L48 17L76 30L46 42Z" fill="#dfb47b"/><path d="M18 39L18 63M29 46L29 70M57 49L57 75M75 39L75 65" stroke="#71492a" stroke-width="2"/>'
	elif kind == "soul_block":
		detail = '<path d="M22 45L32 48L40 61L35 73L26 71L19 58Z" fill="#3c1559"/><path d="M25 48L31 51L36 60L32 67L25 64L23 56Z" fill="#c878f4"/><path d="M26 51L30 53L30 59L26 58Z" fill="#f4d5ff"/><path d="M57 52L67 46L75 53L74 66L64 74L56 66Z" fill="#a45de5"/>'
	elif kind == "stone":
		detail = '<path d="M17 44L29 49L26 60L38 64M57 46L68 48L73 40M35 24L43 29L53 25" fill="none" stroke="#414c57" stroke-width="2"/>'
	elif kind == "dirt":
		detail = '<path d="M12 30L46 46L84 30L84 34L71 39L57 45L46 52L32 45L12 34Z" fill="#609c30"/><path d="M20 55L26 58M34 67L39 69M57 68L63 65M72 53L77 50" stroke="#c28c53" stroke-width="3"/>'
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
	var material := Surfaces.material("wood",1)
	tool_part(parent, Vector3.ZERO, Vector3(0.025, 0.2, 0.025), material)

static func workbench_details(parent: Node3D, size: float) -> void:
	tool_part(parent,Vector3(0,0.504,0)*size,Vector3(0.98,0.008,0.98)*size,Surfaces.material("workbench",1))

static func torch_model(parent: Node3D, scale_factor: float = 1.0) -> Node3D:
	var model := Node3D.new()
	model.scale = Vector3.ONE * scale_factor
	parent.add_child(model)
	var wood := Surfaces.material("wood")
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
	light.light_color = Color(1, 1, 1)
	light.light_energy = 0.4875
	light.omni_range = 4.0 * sqrt(2.0)
	light.omni_attenuation = 0.65
	light.light_specular = 0.0
	light.shadow_opacity = 0.3
	light.shadow_enabled = true
	model.add_child(light)
	return model

static func tool_model(parent: Node3D, kind: String, scale_factor: float = 1.0) -> Node3D:
	var model := Node3D.new()
	model.scale = Vector3.ONE * scale_factor
	parent.add_child(model)
	var handle := Surfaces.material("wood").duplicate() as StandardMaterial3D
	var metal := Surfaces.material("stone").duplicate() as StandardMaterial3D
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
		"hoe":
			tool_part(model,Vector3(0.035,0.08,0),Vector3(0.15,0.035,0.04),metal)
			tool_part(model,Vector3(0.1,0.035,0),Vector3(0.035,0.1,0.06),metal)
		"shovel":
			spade_blade(model,metal)
			tool_part(model, Vector3(0, 0.09, -0.012), Vector3(0.065, 0.07, 0.045), metal)
			tool_part(model, Vector3(0, -0.12, 0), Vector3(0.075, 0.024, 0.035), metal)
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
	meat.albedo_color = Color("edc0c4")
	var darker := StandardMaterial3D.new()
	darker.albedo_color = Color("dba5ae")
	var bone := StandardMaterial3D.new()
	bone.albedo_color = Color("f6e8d6")
	# A plucked whole bird: rounded breast, two wings, two thighs and exposed leg tips.
	for spec in [[Vector3.ZERO,Vector3(0.24,0.18,0.3),meat],[Vector3(-0.13,0,0),Vector3(0.09,0.1,0.2),darker],[Vector3(0.13,0,0),Vector3(0.09,0.1,0.2),darker],[Vector3(-0.1,-0.01,0.16),Vector3(0.12,0.12,0.18),meat],[Vector3(0.1,-0.01,0.16),Vector3(0.12,0.12,0.18),meat]]:
		var part := MeshInstance3D.new()
		var oval := SphereMesh.new()
		oval.radius = 0.5
		oval.height = 1
		oval.radial_segments = 12
		oval.rings = 6
		part.mesh = oval
		part.position = spec[0]
		part.scale = spec[1]
		part.material_override = spec[2]
		parent.add_child(part)
	for side in [-1,1]:
		tool_part(parent,Vector3(side * 0.11,-0.01,0.26),Vector3(0.04,0.04,0.08),bone)
	tool_part(parent,Vector3(0,0,-0.16),Vector3(0.06,0.06,0.08),meat)

static func door_model(parent: Node3D, factor: float = 1.0) -> void:
	var wood := Surfaces.material("planks")
	var frame := Surfaces.material("wood")
	for spec in [[Vector3(0.42,0.52,0.04),Vector3(0.84,1.04,0.12),wood],[Vector3(0.04,1.5,0.04),Vector3(0.08,1,0.12),frame],[Vector3(0.8,1.5,0.04),Vector3(0.08,1,0.12),frame],[Vector3(0.42,1.96,0.04),Vector3(0.84,0.08,0.12),frame],[Vector3(0.42,1.5,0.04),Vector3(0.05,0.9,0.1),frame],[Vector3(0.42,1.53,0.04),Vector3(0.84,0.05,0.1),frame]]:
		tool_part(parent,spec[0]*factor,spec[1]*factor,spec[2])
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color("edc76d")
	tool_part(parent,Vector3(0.71,0.95,-0.05)*factor,Vector3(0.09,0.07,0.08)*factor,brass)

static func plank_model(parent: Node3D) -> void:
	var wood := Surfaces.material("planks")
	tool_part(parent,Vector3.ZERO,Vector3(0.28,0.05,0.13),wood)
	var grain := StandardMaterial3D.new()
	grain.albedo_color = Color("bd8b53")
	for z in [-0.035,0.03]:
		tool_part(parent,Vector3(0,0.026,z),Vector3(0.23,0.003,0.006),grain)

static func log_details(parent: Node3D, size: float) -> void:
	var timber := Surfaces.material("wood",1)
	for y in [-1,1]:
		tool_part(parent,Vector3(0,y*0.501,0)*size,Vector3(0.86,0.003,0.86)*size,timber)

static func soul_block_details(parent: Node3D, size: float) -> void:
	var soul := StandardMaterial3D.new()
	soul.albedo_color = Color("ce88f8")
	var light := StandardMaterial3D.new()
	light.albedo_color = Color("f3dfff")
	for side in [-1,1]:
		tool_part(parent,Vector3(0,0,side*0.502)*size,Vector3(0.42,0.54,0.003)*size,soul)
		tool_part(parent,Vector3(-0.06,0.07,side*0.506)*size,Vector3(0.12,0.17,0.004)*size,light)

static func branch_model(parent: Node3D) -> void:
	tool_part(parent,Vector3.ZERO,Vector3.ONE*0.25,Surfaces.material("foliage"))

static func torch_anchor(cell: Vector3i, normal: Vector3) -> Vector3:
	if absf(normal.y) > 0.5:
		return Vector3(cell) + Vector3(0.5,0.25,0.5)
	var support := cell - Vector3i(normal)
	return Vector3(support) + Vector3.ONE*0.5 + normal*0.64

static func torch_tilt(normal: Vector3) -> Quaternion:
	return Quaternion(Vector3.UP,(Vector3.UP+normal*0.45).normalized()) if absf(normal.y)<0.5 else Quaternion.IDENTITY

static func spade_blade(parent: Node3D, material: Material) -> void:
	var outline := PackedVector2Array([Vector2(-0.065,0.1),Vector2(0.065,0.1),Vector2(0.065,0.2),Vector2(0,0.28),Vector2(-0.065,0.2)])
	var triangles := Geometry2D.triangulate_polygon(outline)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in [-0.025,0.025]:
		for index in range(0,triangles.size(),3):
			for corner in ([0,1,2] if z>0 else [2,1,0]):
				var point := outline[triangles[index+corner]]
				surface.add_vertex(Vector3(point.x,point.y,z))
	for index in range(outline.size()):
		var a := outline[index]
		var b := outline[(index+1)%outline.size()]
		for point: Vector3 in [Vector3(a.x,a.y,-0.025),Vector3(b.x,b.y,-0.025),Vector3(b.x,b.y,0.025),Vector3(a.x,a.y,-0.025),Vector3(b.x,b.y,0.025),Vector3(a.x,a.y,0.025)]:
			surface.add_vertex(point)
	surface.generate_normals()
	var blade := MeshInstance3D.new()
	blade.mesh = surface.commit()
	blade.material_override = material
	parent.add_child(blade)

static func fence_model(parent: Node3D, factor: float = 1.0, connections: Array[Vector3i] = []) -> void:
	var wood := Surfaces.material("planks")
	tool_part(parent,Vector3(0,0.5,0)*factor,Vector3(0.16,1.0,0.16)*factor,wood)
	# Each neighbour owns only its half of the connection. End posts never
	# grow rails on the unconnected side; corners and T-junctions follow suit.
	for direction in connections:
		for y in [0.45,0.77]:
			var center: Vector3 = Vector3(direction)*0.25+Vector3(0,y,0)
			var size := Vector3(0.5,0.13,0.1) if direction.x!=0 else Vector3(0.1,0.13,0.5)
			tool_part(parent,center*factor,size*factor,wood)

static func gate_leaf(parent: Node3D, side: int, factor: float = 1.0) -> void:
	var wood := Surfaces.material("planks")
	for x in [0.03,0.42]:
		tool_part(parent,Vector3(-side*x,0.5,0)*factor,Vector3(0.07,1,0.1)*factor,wood)
	for y in [0.45,0.77]:
		tool_part(parent,Vector3(-side*0.23,y,0)*factor,Vector3(0.46,0.13,0.1)*factor,wood)
	var latch := StandardMaterial3D.new()
	latch.albedo_color = Color("414850")
	tool_part(parent,Vector3(-side*0.4,0.61,-0.065)*factor,Vector3(0.09,0.08,0.035)*factor,latch)

static func gate_model(parent: Node3D, factor: float = 1.0) -> void:
	for side in [-1,1]:
		var hinge := Node3D.new()
		hinge.position.x = side*0.46*factor
		parent.add_child(hinge)
		gate_leaf(hinge,side,factor)

static func farm_item_model(parent: Node3D, kind: String) -> void:
	var material := StandardMaterial3D.new()
	material.roughness=1
	material.albedo_color=Color("b6b34c") if kind=="grass_seed" else Color("dfb457")
	if kind=="bread":
		material.albedo_color=Color("c58c45")
		tool_part(parent,Vector3.ZERO,Vector3(0.21,0.11,0.12),material)
		var crust := StandardMaterial3D.new()
		crust.albedo_color=Color("f3d29a")
		for x in [-0.065,0.0,0.065]:
			tool_part(parent,Vector3(x,0.058,0),Vector3(0.018,0.006,0.085),crust)
	elif kind=="grass_seed":
		for i in range(4):
			tool_part(parent,Vector3((i%2)*0.04-0.02,(i/2)*0.02,0),Vector3(0.025,0.035,0.018),material)
	else:
		for i in range(3):
			tool_part(parent,Vector3((i-1)*0.035,0,0),Vector3(0.012,0.17,0.012),material)
			tool_part(parent,Vector3((i-1)*0.035,0.1,0),Vector3(0.03,0.06,0.025),material)
