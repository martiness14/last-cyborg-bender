extends Node3D
## Volumetric cartoon rigs. Meshes are cached by kind; six animated parts per enemy.
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
	var skin: Color = [Color("a6c843"),Color("e59056"),Color("a887bb"),Color("aab6bd")][type]
	var cloth: Color = [Color("785947"),Color("437b90"),Color("5f7878"),Color("3d4852")][type]
	var glow := Color("ff4a3d")
	var core := Color("5ef2ff")
	var meshes := {}
	for part in ["body","head","arm_l","arm_r","leg_l","leg_r"]:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		if part == "body":
			orb(st,Vector3(0,0.71,0),Vector3(0.43,0.45,0.30),cloth)
			orb(st,Vector3(0,0.80,0.19),Vector3(0.31,0.29,0.16),skin)
			block(st,Vector3(0,0.46,0.02),Vector3(0.76,0.105,0.52),Art.INK)
			block(st,Vector3(0,0.46,0.299),Vector3(0.15,0.12,0.04),Art.YELLOW)
			block(st,Vector3(0,0.46,0.325),Vector3(0.085,0.06,0.02),Art.INK)
			for side in [-1,1]:
				block(st,Vector3(side*0.21,0.91,0.22),Vector3(0.08,0.40,0.07),cloth,side*0.15)
				orb(st,Vector3(side*0.21,0.84,0.274),Vector3.ONE*0.028,Art.YELLOW)
			if type == 2:
				block(st,Vector3(0,0.67,0.33),Vector3(0.23,0.22,0.025),Art.CREAM,0.18)
				block(st,Vector3(0,0.67,0.35),Vector3(0.13,0.035,0.018),Art.INK,0.18)
			if type == 3:
				# Chest plate with a glowing reactor core.
				block(st,Vector3(0,0.70,0.31),Vector3(0.30,0.26,0.04),Color("7d8a93"))
				orb(st,Vector3(0,0.70,0.34),Vector3.ONE*0.075,core)
				for side in [-1,1]:
					orb(st,Vector3(side*0.11,0.60,0.33),Vector3.ONE*0.022,glow)
		elif part == "head":
			orb(st,Vector3.ZERO,Vector3(0.39,0.34,0.29),skin)
			for side in [-1,1]:
				cone(st,Vector3(side*0.42,0.09,-0.01),Vector3(0.14,0.24,0.075),skin,Vector3(0,0,side*-0.95))
				orb(st,Vector3(side*0.17,0.075,0.245),Vector3(0.157,0.177,0.073),Art.INK)
				orb(st,Vector3(side*0.17,0.083,0.290),Vector3(0.137,0.152,0.069),Art.CREAM)
				orb(st,Vector3(side*0.135,0.083,0.350),Vector3(0.054,0.085,0.026),Art.INK)
				orb(st,Vector3(side*0.135-0.016,0.115,0.373),Vector3.ONE*0.019,Color.WHITE)
				block(st,Vector3(side*0.17,0.235,0.30),Vector3(0.27,0.055,0.08),Art.INK,side*0.22)
			orb(st,Vector3(0,-0.12,0.25),Vector3(0.25,0.125,0.082),Art.INK)
			for tooth in range(5):
				block(st,Vector3(-0.17+tooth*0.083,-0.069,0.318),Vector3(0.062,0.063,0.025),Art.CREAM,(tooth-2)*0.08)
			orb(st,Vector3(0,-0.17,0.318),Vector3(0.12,0.035,0.02),Color("d0786c"))
			orb(st,Vector3(0,-0.015,0.355),Vector3(0.10 if type!=1 else 0.16,0.075,0.09),skin.lightened(0.12))
			if type == 1:
				for side in [-1,1]:
					orb(st,Vector3(side*0.067,-0.012,0.437),Vector3(0.022,0.034,0.012),Art.INK)
				orb(st,Vector3(0,0.28,-0.01),Vector3(0.38,0.10,0.28),Color("708a91"))
				block(st,Vector3(0,0.31,0),Vector3(0.32,0.07,0.10),Art.INK)
			elif type == 3:
				# Red visor across the eyes, metal skull cap, bolts and an antenna.
				block(st,Vector3(0,0.085,0.385),Vector3(0.54,0.19,0.05),Art.INK)
				block(st,Vector3(0,0.085,0.405),Vector3(0.48,0.10,0.03),glow)
				orb(st,Vector3(0,0.22,-0.01),Vector3(0.37,0.16,0.28),Color("7d8a93"))
				for side in [-1,1]:
					orb(st,Vector3(side*0.36,-0.04,0.06),Vector3.ONE*0.045,Color("56616a"))
				block(st,Vector3(0.10,0.46,-0.02),Vector3(0.03,0.22,0.03),Color("c9d3d8"))
				orb(st,Vector3(0.10,0.57,-0.02),Vector3.ONE*0.04,glow)
			else:
				for n in range(4):
					cone(st,Vector3(-0.20+n*0.12,0.32,-0.05),Vector3(0.10,0.13+n*0.012,0.13),Art.INK,Vector3(-0.3,0,-0.3))
		elif part.begins_with("arm"):
			var side := -1 if part == "arm_l" else 1
			orb(st,Vector3(0,-0.13,0),Vector3(0.145,0.23,0.145),skin)
			orb(st,Vector3(0,-0.31,0.04),Vector3(0.16,0.14,0.15),skin)
			block(st,Vector3(0,-0.22,0),Vector3(0.28,0.07,0.26),cloth)
			if side == -1 and type == 0:
				block(st,Vector3(0,-0.28,0.19),Vector3(0.055,0.065,0.6),Color("725342"))
				orb(st,Vector3(0,-0.28,0.50),Vector3(0.15,0.15,0.25),Art.ORANGE)
				for n in range(5):
					orb(st,Vector3(sin(n*2.4)*0.11,-0.17,0.37+n*0.06),Vector3.ONE*0.034,Color("b96531"))
			if side == 1 and type == 1:
				orb(st,Vector3(0,-0.24,0.19),Vector3(0.25,0.32,0.055),Art.INK)
				orb(st,Vector3(0,-0.24,0.235),Vector3(0.21,0.27,0.025),Art.BLUE)
				orb(st,Vector3(0,-0.24,0.26),Vector3.ONE*0.075,Art.YELLOW)
			if side == 1 and type == 3:
				block(st,Vector3(0,-0.30,0.17),Vector3(0.13,0.13,0.42),Color("56616a"))
				orb(st,Vector3(0,-0.30,0.40),Vector3(0.075,0.075,0.03),core)
			if side == -1 and type == 2:
				block(st,Vector3(0,-0.46,0.13),Vector3(0.27,0.3,0.27),Color("6b8996"))
				orb(st,Vector3(0,-0.30,0.13),Vector3(0.15,0.035,0.15),Color("bfda4b"))
		else:
			orb(st,Vector3(0,-0.10,0),Vector3(0.15,0.22,0.15),cloth)
			orb(st,Vector3(0,-0.24,0.085),Vector3(0.18,0.10,0.235),Art.INK)
			block(st,Vector3(0,-0.235,0.285),Vector3(0.20,0.06,0.035),Color("716353"))
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
	var shadow := Art.ball(self,1.0,Vector3(0,0.012,0),Color("35473b"))
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
