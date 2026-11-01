extends RefCounted

const Registry = preload("res://scripts/core/registry.gd")

const Surfaces = preload("res://scripts/rendering/surface_textures.gd")
const PADDING: int = 8
const STRIDE: int = 272
static var cache_key: String = ""
static var cached: ShaderMaterial

static func material() -> ShaderMaterial:
	var signature := JSON.stringify(Registry.saved_ids())
	if cached != null and signature == cache_key:
		return cached
	var columns: int = 8
	var rows: int = ceili(float(Registry.catalog.blocks.size()*3)/columns)
	var image := Image.create(columns*STRIDE,rows*STRIDE,false,Image.FORMAT_RGBA8)
	var detail := Image.create(columns*STRIDE,rows*STRIDE,false,Image.FORMAT_RGBA8)
	for kind: String in Registry.catalog.blocks:
		var definition: Dictionary = Registry.catalog.blocks[kind]
		for face in range(3):
			var tile: int = Registry.tiles[int(definition.id)]+face
			var destination := Vector2i((tile%columns)*STRIDE,(tile/columns)*STRIDE)
			stamp(image,Surfaces.tile(kind,face),destination)
			stamp(detail,Surfaces.tile(kind,face,true),destination)
	image.generate_mipmaps()
	detail.generate_mipmaps()
	var shader := Shader.new()
	shader.code = """shader_type spatial;
uniform sampler2D atlas_texture : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D detail_texture : filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec2 atlas_grid;
uniform float gutter;
uniform float content_span;
varying flat float tile_number;
varying flat float block_outline;
void vertex() { block_outline = COLOR.b; tile_number = round(COLOR.r * 255.0) + round(COLOR.g * 255.0) * 256.0; }
void fragment() {
 vec2 tile = vec2(mod(tile_number, atlas_grid.x), floor(tile_number / atlas_grid.x));
 vec2 pixel = vec2(gutter) + fract(UV) * content_span;
 vec4 sampled = textureGrad(atlas_texture, (tile + pixel) / atlas_grid, dFdx(UV) * content_span / atlas_grid, dFdy(UV) * content_span / atlas_grid);
 ALBEDO = sampled.rgb;
 if (sampled.a < 0.5) { discard; }
 // Faint metre grid stays on the merged surface, with no overlay/z-fighting.
 vec2 edge_distance = min(fract(UV), vec2(1.0) - fract(UV));
 vec2 footprint = fwidth(UV);
 vec2 interior = smoothstep(vec2(0.0), footprint * 0.6 + vec2(0.006), edge_distance);
 float edge = 1.0 - min(interior.x, interior.y);
 float fade = clamp(1.0 - max(footprint.x, footprint.y) * 4.0, 0.0, 1.0);
 ALBEDO *= 1.0 - edge * 0.18 * block_outline * fade;
 vec3 maps = textureGrad(detail_texture, (tile + pixel) / atlas_grid, dFdx(UV) * content_span / atlas_grid, dFdy(UV) * content_span / atlas_grid).rgb;
 // View-space bump from the height map; works on greedy meshes without tangent arrays.
 float height = maps.r * 0.012;
 vec3 px = dFdx(VERTEX);
 vec3 py = dFdy(VERTEX);
 vec3 n = normalize(NORMAL);
 vec3 rx = cross(py,n);
 vec3 ry = cross(n,px);
 float determinant = dot(px,rx);
 if (abs(determinant) > 0.0000001) {
  NORMAL = normalize(abs(determinant)*n - sign(determinant)*(dFdx(height)*rx+dFdy(height)*ry));
 }
 SPECULAR = 0.0;
 ROUGHNESS = maps.g;
}
"""
	var result := ShaderMaterial.new()
	result.shader = shader
	result.set_shader_parameter("atlas_texture", ImageTexture.create_from_image(image))
	result.set_shader_parameter("atlas_grid", Vector2(columns, rows))
	result.set_shader_parameter("detail_texture",ImageTexture.create_from_image(detail))
	result.set_shader_parameter("gutter",float(PADDING)/STRIDE)
	result.set_shader_parameter("content_span",256.0/STRIDE)
	cache_key = signature
	cached = result
	return result

static func stamp(atlas: Image, source: Image, destination: Vector2i) -> void:
	atlas.blit_rect(source,Rect2i(0,0,256,256),destination+Vector2i(PADDING,PADDING))
	# Extrude edge texels into the gutters to prevent filtering neighbouring materials.
	for edge in range(PADDING):
		atlas.blit_rect(source,Rect2i(0,0,1,256),destination+Vector2i(edge,PADDING))
		atlas.blit_rect(source,Rect2i(255,0,1,256),destination+Vector2i(264+edge,PADDING))
		atlas.blit_rect(source,Rect2i(0,0,256,1),destination+Vector2i(PADDING,edge))
		atlas.blit_rect(source,Rect2i(0,255,256,1),destination+Vector2i(PADDING,264+edge))
	for x in range(PADDING):
		for y in range(PADDING):
			atlas.set_pixelv(destination+Vector2i(x,y),source.get_pixel(0,0))
			atlas.set_pixelv(destination+Vector2i(264+x,y),source.get_pixel(255,0))
			atlas.set_pixelv(destination+Vector2i(x,264+y),source.get_pixel(0,255))
			atlas.set_pixelv(destination+Vector2i(264+x,264+y),source.get_pixel(255,255))
