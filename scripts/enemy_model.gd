extends Node3D
## Volumetric cartoon cyborg rigs. Meshes are cached by kind; six animated parts per enemy.
const Art = preload("res://scripts/art.gd")
static var cache: Dictionary = {}
var parts: Dictionary = {}
var body_material: ShaderMaterial
var kind := 0

static func paint_shader() -> Shader:
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode unshaded;
uniform float flash = 0.0;
uniform float angry = 0.0;
void fragment() {
 vec3 tint = mix(COLOR.rgb, COLOR.rgb * vec3(1.18,0.83,0.72), angry);
 ALBEDO = mix(tint, vec3(1.0,0.97,0.80), flash);
}
"""
	return shader

static func primitive(st: SurfaceTool, mesh: PrimitiveMesh, pos: Vector3, size: Vector3, color: Color, rotation: Vector3 = Vector3.ZERO) -> void:
	var arrays := mesh.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var basis := Basis.from_euler(rotation).scaled(size)
	var normal_basis := basis.inverse().transposed()
	for i in indices:
		var normal := (normal_basis*normals[i]).normalized()
		# Directional color bands provide a legible 3D volume without dynamic lights.
		var illumination := normal.dot(Vector3(-0.5,0.8,0.6).normalized())
		var shade := 1.0 if illumination>0.42 else (0.83 if illumination>-0.20 else 0.62)
		st.set_color(Color(color.r*shade,color.g*shade,color.b*shade,1))
		st.set_normal(normal)
		st.add_vertex(pos+basis*vertices[i])

static func orb(st: SurfaceTool, pos: Vector3, size: Vector3, color: Color) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 1
	mesh.height = 2
	mesh.radial_segments = 16
	mesh.rings = 8
	primitive(st,mesh,pos,size,color)

static func block(st: SurfaceTool, pos: Vector3, size: Vector3, color: Color, angle: float = 0.0) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	primitive(st,mesh,pos,size,color,Vector3(0,0,angle))

static func cone(st: SurfaceTool, pos: Vector3, size: Vector3, color: Color, rotation: Vector3 = Vector3.ZERO) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0
	mesh.bottom_radius = 1
	mesh.height = 2
	mesh.radial_segments = 7
	primitive(st,mesh,pos,size,color,rotation)

static func build_meshes(type: int) -> Dictionary:
	# 0 scout (cyclops eye, energy baton), 1 tank (visor slit, riot shield),
	# 2 sprayer (goggles, coolant canister), 3 bender elite (red visor, arm blaster).
	var plate: Color = [Color("8fa3b8"),Color("c7834a"),Color("8a7fb0"),Color("aab6bd")][type]
	var frame: Color = [Color("26304a"),Color("3a2f2a"),Color("2f2a45"),Color("3d4852")][type]
	var glow: Color = [Color("2fd3e6"),Color("ff7a2f"),Color("7dff6a"),Color("ff4a3d")][type]
	var steel := Color("56616a")
	var core := Color("5ef2ff")
	var meshes := {}
	for part in ["body","head","arm_l","arm_r","leg_l","leg_r"]:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		if part == "body":
			orb(st,Vector3(0,0.71,0),Vector3(0.43,0.45,0.30),frame)
			# Chest armour with a glowing power cell and status lights.
			block(st,Vector3(0,0.74,0.24),Vector3(0.48,0.36,0.10),plate)
			block(st,Vector3(0,0.74,0.30),Vector3(0.28,0.22,0.03),Art.INK)
			orb(st,Vector3(0,0.74,0.32),Vector3.ONE*0.07,glow)
			for side in [-1,1]:
				orb(st,Vector3(side*0.18,0.62,0.30),Vector3.ONE*0.022,glow)
				orb(st,Vector3(side*0.40,0.92,0.0),Vector3(0.14,0.11,0.16),plate)
			block(st,Vector3(0,0.46,0.02),Vector3(0.76,0.105,0.52),Art.INK)
			block(st,Vector3(0,0.46,0.299),Vector3(0.15,0.12,0.04),glow)
			block(st,Vector3(0,0.46,0.325),Vector3(0.085,0.06,0.02),Art.INK)
			if type == 2:
				# Coolant tank on the back.
				orb(st,Vector3(0,0.78,-0.32),Vector3(0.20,0.30,0.14),glow.darkened(0.35))
				block(st,Vector3(0,0.78,-0.40),Vector3(0.05,0.40,0.05),steel)
			if type == 1:
				for side in [-1,1]:
					cone(st,Vector3(side*0.45,1.02,0),Vector3(0.09,0.14,0.09),steel,Vector3(0,0,side*-0.6))
		elif part == "head":
			orb(st,Vector3.ZERO,Vector3(0.37,0.33,0.29),plate)
			# Jaw plate with a speaker grill instead of teeth.
			block(st,Vector3(0,-0.15,0.20),Vector3(0.34,0.12,0.16),frame)
			for n in range(5):
				block(st,Vector3(-0.12+n*0.06,-0.15,0.285),Vector3(0.025,0.08,0.02),glow.darkened(0.2))
			for side in [-1,1]:
				orb(st,Vector3(side*0.37,0.0,0.0),Vector3(0.07,0.11,0.11),steel)
				orb(st,Vector3(side*0.42,0.0,0.0),Vector3.ONE*0.03,glow)
			match type:
				0:
					orb(st,Vector3(0,0.07,0.23),Vector3(0.21,0.21,0.10),Art.INK)
					orb(st,Vector3(0,0.07,0.28),Vector3(0.17,0.17,0.08),glow)
					orb(st,Vector3(0,0.07,0.335),Vector3(0.07,0.07,0.04),Art.INK)
					orb(st,Vector3(-0.04,0.11,0.36),Vector3.ONE*0.022,Color.WHITE)
					block(st,Vector3(0,0.36,0),Vector3(0.025,0.22,0.025),steel)
					orb(st,Vector3(0,0.48,0),Vector3.ONE*0.045,glow)
				1:
					orb(st,Vector3(0,0.13,-0.02),Vector3(0.40,0.24,0.31),steel)
					block(st,Vector3(0,0.06,0.28),Vector3(0.52,0.10,0.06),Art.INK)
					block(st,Vector3(0,0.06,0.31),Vector3(0.44,0.04,0.03),glow)
					block(st,Vector3(0,0.33,0),Vector3(0.08,0.12,0.36),frame)
				2:
					for side in [-1,1]:
						orb(st,Vector3(side*0.15,0.08,0.24),Vector3(0.13,0.13,0.08),Art.INK)
						orb(st,Vector3(side*0.15,0.08,0.28),Vector3(0.10,0.10,0.06),glow)
						orb(st,Vector3(side*0.15,0.08,0.32),Vector3.ONE*0.035,Art.INK)
					block(st,Vector3(0,0.08,0.26),Vector3(0.10,0.03,0.04),steel)
					orb(st,Vector3(0,0.20,-0.01),Vector3(0.30,0.20,0.24),Color(glow.r,glow.g,glow.b).darkened(0.45))
				3:
					block(st,Vector3(0,0.085,0.31),Vector3(0.54,0.19,0.05),Art.INK)
					block(st,Vector3(0,0.085,0.33),Vector3(0.48,0.10,0.03),glow)
					orb(st,Vector3(0,0.22,-0.01),Vector3(0.37,0.16,0.28),Color("7d8a93"))
					block(st,Vector3(0.10,0.46,-0.02),Vector3(0.03,0.22,0.03),Color("c9d3d8"))
					orb(st,Vector3(0.10,0.57,-0.02),Vector3.ONE*0.04,glow)
		elif part.begins_with("arm"):
			var side := -1 if part == "arm_l" else 1
			orb(st,Vector3(0,-0.13,0),Vector3(0.13,0.22,0.13),frame)
			block(st,Vector3(0,-0.14,0),Vector3(0.20,0.20,0.20),plate)
			orb(st,Vector3(0,-0.31,0.04),Vector3(0.14,0.12,0.14),steel)
			block(st,Vector3(0,-0.26,0),Vector3(0.24,0.05,0.22),glow.darkened(0.3))
			if side == -1 and type == 0:
				block(st,Vector3(0,-0.28,0.22),Vector3(0.05,0.05,0.55),Art.INK)
				block(st,Vector3(0,-0.28,0.42),Vector3(0.08,0.08,0.22),glow)
			if side == 1 and type == 1:
				block(st,Vector3(0,-0.24,0.20),Vector3(0.44,0.58,0.05),Art.INK)
				block(st,Vector3(0,-0.24,0.23),Vector3(0.38,0.52,0.02),Color("4b5670"))
				block(st,Vector3(0,-0.24,0.25),Vector3(0.30,0.06,0.02),glow)
			if side == -1 and type == 2:
				block(st,Vector3(0,-0.40,0.15),Vector3(0.10,0.10,0.36),steel)
				orb(st,Vector3(0,-0.40,0.35),Vector3(0.06,0.06,0.03),glow)
			if side == 1 and type == 3:
				block(st,Vector3(0,-0.30,0.17),Vector3(0.13,0.13,0.42),steel)
				orb(st,Vector3(0,-0.30,0.40),Vector3(0.075,0.075,0.03),core)
		else:
			orb(st,Vector3(0,-0.10,0),Vector3(0.13,0.20,0.13),frame)
			block(st,Vector3(0,-0.08,0.04),Vector3(0.18,0.16,0.14),plate)
			orb(st,Vector3(0,-0.24,0.085),Vector3(0.18,0.10,0.235),Art.INK)
			block(st,Vector3(0,-0.235,0.285),Vector3(0.20,0.06,0.035),glow.darkened(0.25))
		st.index()
		meshes[part] = st.commit()
	return meshes

func setup(type: int, size: float = 1.0) -> void:
	kind = type
	if not cache.has(type):
		cache[type] = build_meshes(type)
	body_material = ShaderMaterial.new()
	body_material.shader = paint_shader()
	var positions := {"body":Vector3.ZERO,"head":Vector3(0,1.18,0.02),
		"arm_l":Vector3(-0.43,0.97,0),"arm_r":Vector3(0.43,0.97,0),
		"leg_l":Vector3(-0.21,0.34,0),"leg_r":Vector3(0.21,0.34,0)}
	for name_key in positions:
		var mesh := MeshInstance3D.new()
		mesh.name = name_key
		mesh.mesh = cache[type][name_key]
		mesh.material_override = body_material
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.position = positions[name_key]
		add_child(mesh)
		parts[name_key] = mesh
	scale = Vector3.ONE*size
	var shadow := Art.ball(self,1.0,Vector3(0,0.012,0),Color("0b0f1c"))
	shadow.scale = Vector3(0.47,0.008,0.34)

func animate(age: float, rage: bool, flash: float, moving: bool = true) -> void:
	var stride := sin(age*(9.0 if rage else 6.5))*(1.0 if moving else 0.1)
	parts.leg_l.rotation.x = stride*0.48
	parts.leg_r.rotation.x = -stride*0.48
	parts.arm_l.rotation.x = -stride*0.35
	parts.arm_r.rotation.x = stride*0.35
	parts.body.position.y = absf(stride)*0.025
	parts.head.position.y = 1.18+absf(stride)*0.035
	parts.head.rotation.z = stride*0.055
	body_material.set_shader_parameter("angry",1.0 if rage else 0.0)
	body_material.set_shader_parameter("flash",clampf(flash/0.15,0,1))
