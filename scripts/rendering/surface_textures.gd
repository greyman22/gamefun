extends RefCounted
const Registry = preload("res://scripts/core/registry.gd")
const SIZE: int = 256
const ROOT: String = "res://assets/materials/"
static var manifest: Dictionary = {}
static var images: Dictionary = {}
static var textures: Dictionary = {}
static var materials: Dictionary = {}

static func initialize() -> void:
	if manifest.is_empty():
		manifest = JSON.parse_string(FileAccess.get_file_as_string(ROOT+"manifest.json"))

static func name_for(kind: String, face: int) -> String:
	initialize()
	return str(manifest[kind][face]) if manifest.has(kind) else ""

static func image_for(name: String) -> Image:
	if not images.has(name):
		var path := ROOT+name+".png"
		if not FileAccess.file_exists(path):
			var imported := load(path) as Texture2D
			images[name] = imported.get_image()
			if images[name].is_compressed():
				images[name].decompress()
		else:
			var source := Image.new()
			source.load_png_from_buffer(FileAccess.get_file_as_bytes(path))
			images[name] = source
		images[name].convert(Image.FORMAT_RGBA8)
	return images[name]

static func texture(name: String) -> Texture2D:
	if not textures.has(name):
		var image := image_for(name).duplicate() as Image
		image.generate_mipmaps()
		textures[name] = ImageTexture.create_from_image(image)
	return textures[name]

static func tile(kind: String, face: int, detail: bool = false) -> Image:
	var name := name_for(kind,face)
	if not name.is_empty():
		return image_for(name+("_detail" if detail else ""))
	var fallback := Image.create(SIZE,SIZE,false,Image.FORMAT_RGBA8)
	fallback.fill(Color(0.5,0.95,0,1) if detail else Color(Registry.catalog.blocks[kind].color))
	return fallback

static func material(kind: String, face: int = 0) -> StandardMaterial3D:
	var name := name_for(kind,face)
	if materials.has(name):
		return materials[name]
	var result := StandardMaterial3D.new()
	if name.is_empty():
		result.albedo_color = Color(Registry.catalog.blocks.get(kind,{}).get("color","888888"))
		result.roughness = 0.95
		return result
	result.albedo_texture = texture(name)
	result.normal_enabled = true
	result.normal_texture = texture(name+"_normal")
	result.normal_scale = 0.65
	result.roughness_texture = texture(name+"_detail")
	result.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	result.roughness = 1.0
	result.metallic_specular = 0.05
	result.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if kind == "foliage":
		result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		result.alpha_scissor_threshold = 0.5
		result.cull_mode = BaseMaterial3D.CULL_DISABLED
	materials[name] = result
	return result

static func icon(kind: String) -> Texture2D:
	var path := ROOT+"icon_"+kind+".png"
	if FileAccess.file_exists(path):
		return texture("icon_"+kind)
	return null
