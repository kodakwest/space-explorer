extends MeshInstance3D

func _ready() -> void:
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 2400.0
	sphere.height = 4800.0
	sphere.radial_segments = 64
	sphere.rings = 32
	mesh = sphere
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	material_override = _create_nebula_material()

func _create_nebula_material() -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	var shader: Shader = Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += noise(p) * a;
		p *= 2.04;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec3 dir = normalize(VERTEX);
	float band = 1.0 - abs(dir.y);
	float cloud = fbm(dir.xz * 2.4 + vec2(TIME * 0.004, -TIME * 0.003));
	float veil = smoothstep(0.34, 0.88, cloud * band);
	vec3 abyss = vec3(0.031, 0.027, 0.039);
	vec3 purple = vec3(0.141, 0.086, 0.220);
	vec3 blue = vec3(0.082, 0.141, 0.278);
	vec3 cyan = vec3(0.090, 0.118, 0.180);
	vec3 magenta = vec3(0.200, 0.090, 0.169);
	vec3 nebula = mix(purple, blue, smoothstep(-0.6, 0.6, dir.x));
	nebula = mix(nebula, cyan, smoothstep(0.0, 0.9, dir.z) * 0.45);
	nebula = mix(nebula, magenta, smoothstep(0.2, 0.95, cloud) * 0.35);
	ALBEDO = mix(abyss, nebula, veil * 0.72);
	EMISSION = ALBEDO * 0.52;
}
"""
	material.shader = shader
	return material
