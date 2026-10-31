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
					if kind == "soul_block":
						var radius: float = Vector2(px - 7.5, py - 7.5).length()
						base = Color(0.7, 0.25, 0.95) if radius < 4 else Color(0.26, 0.08, 0.4)
						if px in [5, 6] and py in [4, 5, 6]:
							base = Color(0.94, 0.75, 1)
					if kind == "planks" and py % 5 == 0:
						base *= 0.55
					if kind == "workbench":
						if face == 1:
							base = Color("dfb578") if (px / 4 + py / 4) % 2 == 0 else Color("55331d")
						elif px < 3 or px > 12 or py < 3 or py in [10, 11]:
							base = Color("4c301e")
					if kind == "chest":
						if px < 2 or px > 13 or py < 2 or py > 13 or (face != 1 and py in [5, 6]):
							base = Color("55351e")
						if face == 0 and px in [7, 8] and py in [5, 6, 7, 8, 9]:
							base = Color("efcf62")
					image.set_pixel((tile % columns) * 20 + x, (tile / columns) * 20 + y, Color(base.r, base.g, base.b, 1))
	image.generate_mipmaps()
	var shader := Shader.new()
	shader.code = """shader_type spatial;
uniform sampler2D atlas_texture : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec2 atlas_grid;
varying flat float tile_number;
varying flat float block_outline;
void vertex() { block_outline = COLOR.b; tile_number = round(COLOR.r * 255.0) + round(COLOR.g * 255.0) * 256.0; }
void fragment() {
 vec2 tile = vec2(mod(tile_number, atlas_grid.x), floor(tile_number / atlas_grid.x));
 vec2 pixel = vec2(0.1) + fract(UV) * 0.8;
 ALBEDO = textureGrad(atlas_texture, (tile + pixel) / atlas_grid, dFdx(UV) * 0.8 / atlas_grid, dFdy(UV) * 0.8 / atlas_grid).rgb;
 // Faint metre grid stays on the merged surface, with no overlay/z-fighting.
 vec2 edge_distance = min(fract(UV), vec2(1.0) - fract(UV));
 vec2 footprint = fwidth(UV);
 vec2 interior = smoothstep(vec2(0.0), footprint * 0.6 + vec2(0.006), edge_distance);
 float edge = 1.0 - min(interior.x, interior.y);
 float fade = clamp(1.0 - max(footprint.x, footprint.y) * 4.0, 0.0, 1.0);
 ALBEDO *= 1.0 - edge * 0.18 * block_outline * fade;
 ROUGHNESS = 0.95;
}
"""
	var result := ShaderMaterial.new()
	result.shader = shader
	result.set_shader_parameter("atlas_texture", ImageTexture.create_from_image(image))
	result.set_shader_parameter("atlas_grid", Vector2(columns, rows))
	return result
