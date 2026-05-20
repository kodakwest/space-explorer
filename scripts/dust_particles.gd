extends GPUParticles3D

func _ready() -> void:
	amount = 720
	lifetime = 18.0
	preprocess = 18.0
	visibility_aabb = AABB(Vector3(-900, -420, -900), Vector3(1800, 840, 1800))
	draw_pass_1 = _create_dust_mesh()
	process_material = _create_particle_material()
	material_override = _create_dust_material()

func _create_dust_mesh() -> Mesh:
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 0.018
	mesh.height = 0.036
	mesh.radial_segments = 6
	mesh.rings = 3
	return mesh

func _create_particle_material() -> ParticleProcessMaterial:
	var material: ParticleProcessMaterial = ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	material.emission_box_extents = Vector3(820.0, 300.0, 820.0)
	material.direction = Vector3(0.08, 0.03, -0.05)
	material.spread = 180.0
	material.initial_velocity_min = 0.04
	material.initial_velocity_max = 0.22
	material.gravity = Vector3.ZERO
	material.scale_min = 0.55
	material.scale_max = 1.85
	material.color = Color(0.38, 0.45, 0.95, 0.18)
	return material

func _create_dust_material() -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.albedo_color = Color(0.38, 0.45, 0.95, 0.12)
	material.emission_enabled = true
	material.emission = Color(0.32, 0.36, 0.85)
	material.emission_energy_multiplier = 0.18
	return material
