extends RefCounted

const Registry = preload("res://scripts/core/registry.gd")

static func material() -> ShaderMaterial:
	var columns: int = 16
	var rows: int = ceili(float(Registry.catalog.blocks.size() * 3) / columns)
	var image := Image.create(columns * 20, rows * 20, false, Image.FORMAT_RGBA8)
	for kind: String in Registry.catalog.blocks:
		var definition: Dictionary = Registry.catalog.blocks[kind]
		for face in range(3):
			var tile: int = Registry.tiles[int(definition.id)] + face
			for y in range(20):
				for x in range(20):
					var px: int = clampi(x - 2, 0, 15)
					var py: int = clampi(y - 2, 0, 15)
					var base := Color(definition.color)
					var h: int = absi(px * 1619 ^ py * 31337 ^ int(definition.id) * 6971)
					base *= 0.8 + float(h % 100) / 400.0
					if definition.get("grass", false) and (face == 1 or (face == 0 and py < 3)):
						base = Color(0.32, 0.57, 0.17) * (0.85 + float(h % 100) / 400)
					if kind == "wood" and face == 1:
						var ring: int = maxi(absi(px - 8), absi(py - 8))
						base = Color(0.65, 0.43, 0.21) * (0.7 if ring % 3 == 0 else 1.1)
					elif kind == "wood" and px % 4 == 0:
						base *= 0.65
					if kind == "planks" and py % 5 == 0:
						base *= 0.55
					if kind == "workbench" and face == 1 and (px % 5 == 0 or py % 5 == 0):
						base *= 0.4
					image.set_pixel((tile % columns) * 20 + x, (tile / columns) * 20 + y, Color(base.r, base.g, base.b, 1))
	image.generate_mipmaps()
	var shader := Shader.new()
	shader.code = """shader_type spatial;
uniform sampler2D atlas_texture : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec2 atlas_grid;
varying flat float tile_number;
void vertex() { tile_number = round(COLOR.r * 255.0) + round(COLOR.g * 255.0) * 256.0; }
void fragment() {
 vec2 tile = vec2(mod(tile_number, atlas_grid.x), floor(tile_number / atlas_grid.x));
 vec2 pixel = vec2(0.1) + fract(UV) * 0.8;
 ALBEDO = textureGrad(atlas_texture, (tile + pixel) / atlas_grid, dFdx(UV) * 0.8 / atlas_grid, dFdy(UV) * 0.8 / atlas_grid).rgb;
 ROUGHNESS = 0.95;
}
"""
	var result := ShaderMaterial.new()
	result.shader = shader
	result.set_shader_parameter("atlas_texture", ImageTexture.create_from_image(image))
	result.set_shader_parameter("atlas_grid", Vector2(columns, rows))
	return result
