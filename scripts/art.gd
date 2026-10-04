extends RefCounted
## Baked flat-color geometry: the entire static house renders as one surface.
const INK := Color("121729")
const CREAM := Color("e6f3ff")
const MINT := Color("46536f")
const BLUE := Color("22c7dc")
const ORANGE := Color("ff3f8e")
const YELLOW := Color("ffe14a")
var surface := SurfaceTool.new()
var rng := RandomNumberGenerator.new()

func _init() -> void:
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	rng.seed = 804

static func material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	return m

static func box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.material_override = material(color)
	parent.add_child(instance)
	instance.position = pos
	return instance

static func ball(parent: Node3D, radius: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 10
	mesh.rings = 5
	instance.mesh = mesh
	instance.material_override = material(color)
	parent.add_child(instance)
	instance.position = pos
	return instance

static func tube(parent: Node3D, radius: float, length: float, pos: Vector3, color: Color, top: float = -1) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius if top < 0 else top
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = 10
	instance.mesh = mesh
	instance.material_override = material(color)
	parent.add_child(instance)
	instance.position = pos
	instance.rotation.x = PI / 2
	return instance

static func label(parent: Node3D, text_value: String, pos: Vector3, font_size: int = 40, color: Color = CREAM, pixel: float = 0.0024) -> Label3D:
	var label_node := Label3D.new()
	label_node.text = text_value
	label_node.position = pos
	label_node.font_size = font_size
	label_node.font = load("res://assets/Neucha-Regular.ttf")
	label_node.pixel_size = pixel
	label_node.modulate = color
	label_node.outline_modulate = INK
	label_node.outline_size = 2
	label_node.no_depth_test = false
	parent.add_child(label_node)
	return label_node

func raw_box(pos: Vector3, size: Vector3, color: Color, angle: float = 0) -> void:
	var h := size / 2.0
	var vertices := [Vector3(-h.x,-h.y,-h.z), Vector3(h.x,-h.y,-h.z), Vector3(h.x,h.y,-h.z), Vector3(-h.x,h.y,-h.z),
		Vector3(-h.x,-h.y,h.z), Vector3(h.x,-h.y,h.z), Vector3(h.x,h.y,h.z), Vector3(-h.x,h.y,h.z)]
	var faces := [[0,3,2,1],[4,5,6,7],[0,4,7,3],[1,2,6,5],[3,7,6,2],[0,1,5,4]]
	var shades := [0.83,1.0,0.78,0.89,1.12,0.64]
	for f in range(6):
		surface.set_color(Color(color.r * shades[f], color.g * shades[f], color.b * shades[f], 1))
		for index in [0,1,2,0,2,3]:
			var v: Vector3 = vertices[faces[f][index]]
			surface.add_vertex(v.rotated(Vector3.UP, angle) + pos)

func ink_box(pos: Vector3, size: Vector3, color: Color, angle: float = 0) -> void:
	raw_box(pos, size, color, angle)
	var h := size / 2.0
	var w := 0.018
	for x in [-1,1]:
		for y in [-1,1]:
			raw_box(pos + Vector3(x*h.x,y*h.y,0).rotated(Vector3.UP,angle),Vector3(w,w,size.z+w),INK,angle)
	for x in [-1,1]:
		for z in [-1,1]:
			raw_box(pos + Vector3(x*h.x,0,z*h.z).rotated(Vector3.UP,angle),Vector3(w,size.y+w,w),INK,angle)
	for y in [-1,1]:
		for z in [-1,1]:
			raw_box(pos + Vector3(0,y*h.y,z*h.z).rotated(Vector3.UP,angle),Vector3(size.x+w,w,w),INK,angle)

func build_house(parent: Node3D) -> MeshInstance3D:
	# Front door and two windows are true openings, not painted walls.
	for ix in range(16):
		var x := -3.75+ix*0.5
		for iz in range(9):
			var z := -6.4+iz*1.2
			var c := Color("394259").lerp(Color("4b5670"), rng.randf()*0.6)
			raw_box(Vector3(x,-0.035,z),Vector3(0.495,0.06,1.195),c)
			raw_box(Vector3(x-0.245,0.001,z),Vector3(0.012,0.009,1.2),INK)
			raw_box(Vector3(x,0.001,z-0.59),Vector3(0.5,0.009,0.012),INK)
			if iz%2==ix%2:
				raw_box(Vector3(x+0.1,0.003,z+0.1),Vector3(0.008,0.005,0.25),BLUE)
	ink_box(Vector3(-4.1,1.7,-2),Vector3(0.16,3.4,10),MINT)
	ink_box(Vector3(4.1,1.7,-2),Vector3(0.16,3.4,10),MINT)
	ink_box(Vector3(0,1.7,3),Vector3(8.2,3.4,0.16),MINT.darkened(0.12))
	ink_box(Vector3(0,3.48,-2),Vector3(8.2,0.15,10),Color("262c40"))
	for z in [-6.7,-3.4,0,2.8]:
		ink_box(Vector3(0,3.30,z),Vector3(8.1,0.22,0.18),Color("1b2030"))
	for x in [-3.0,3.0]:
		ink_box(Vector3(x,0.45,-7),Vector3(2.0,0.9,0.18),MINT)
		ink_box(Vector3(x,3.05,-7),Vector3(2.0,0.7,0.18),MINT)
		for side in [-1,1]:
			ink_box(Vector3(x+side*0.94,1.8,-6.87),Vector3(0.12,1.85,0.17),Color("6c7a96"))
		ink_box(Vector3(x,0.96,-6.8),Vector3(2.05,0.12,0.4),Color("6c7a96"))
		ink_box(Vector3(x,2.7,-6.87),Vector3(2.05,0.16,0.18),Color("6c7a96"))
		# Flat exterior silhouettes, with generous room for entrance sprites.
		raw_box(Vector3(x,1.8,-8.1),Vector3(2.5,3.3,0.05),Color("1b2540"))
	for x in [-1.47,1.47,-4,4]:
		ink_box(Vector3(x,1.7,-7),Vector3(1.0 if absf(x)<2 else 0.2,3.4,0.2),MINT)
	ink_box(Vector3(0,2.95,-7),Vector3(1.95,0.9,0.2),MINT)
	for x in [-0.99,0.99]:
		ink_box(Vector3(x,1.22,-6.85),Vector3(0.14,2.44,0.2),Color("39415a"))
	ink_box(Vector3(0,2.45,-6.85),Vector3(2.12,0.15,0.2),Color("39415a"))
	ink_box(Vector3(-1.55,1.18,-7.4),Vector3(1.25,2.3,0.12),Color("56607a"),-0.55)
	raw_box(Vector3(0,1.7,-9),Vector3(8,3.4,0.1),Color("0d1424"))
	for x in [-3.2,-2.5,-1.4,1.8,2.5,3.5]:
		ink_box(Vector3(x,0.5,-8.8),Vector3(0.6,1.0+rng.randf(),0.12),Color("232c46"))
		ink_box(Vector3(x+0.05,1.3,-8.8),Vector3(0.8,0.45,0.14),Color("b06bff"))
	# Light-strip curtains and wall marks: baked into the same mesh.
	for x in [-3.0,3.0]:
		for side in [-1,1]:
			ink_box(Vector3(x+side*0.78,1.92,-6.68),Vector3(0.28,1.5,0.045),ORANGE)
			for n in range(3):
				raw_box(Vector3(x+side*0.78-0.08+n*0.07,1.92,-6.64),Vector3(0.016,1.42,0.012),Color("b02a6a"))
	for x in [-1.55,1.55]:
		ink_box(Vector3(x,1.6,-6.82),Vector3(0.62,0.76,0.045),INK)
		raw_box(Vector3(x,1.6,-6.78),Vector3(0.54,0.68,0.035),CREAM)
		ink_box(Vector3(x,1.58,-6.74),Vector3(0.25,0.19,0.03),ORANGE)
	for n in range(28):
		var x: float = rng.randf_range(-3.8,3.8)
		var y: float = rng.randf_range(2.88,3.20)
		raw_box(Vector3(x,y,-6.88),Vector3(0.012,0.045+rng.randf()*0.06,0.01),INK)
	# Charging pad with neon diamonds.
	ink_box(Vector3(0,0.012,-2.2),Vector3(3.6,0.018,3.4),Color("1b2034"))
	raw_box(Vector3(0,0.026,-2.2),Vector3(3.25,0.015,3.05),Color("2a3350"))
	for z in [-3.2,-2.2,-1.2]:
		for x in [-1,0,1]:
			raw_box(Vector3(x,0.04,z),Vector3(0.35,0.012,0.35),BLUE,PI/4)
	# Bulky lounge pod along the right wall, kept outside all approach lanes.
	ink_box(Vector3(3.35,0.35,0.2),Vector3(1.1,0.55,2.7),Color("4d2763"))
	ink_box(Vector3(3.83,0.86,0.2),Vector3(0.28,1.15,2.8),ORANGE)
	for z in [-0.68,0.2,1.08]:
		ink_box(Vector3(3.3,0.69,z),Vector3(0.88,0.18,0.82),Color("6e3489"))
	for z in [-1.16,1.56]:
		ink_box(Vector3(3.3,0.79,z),Vector3(1.05,0.5,0.23),ORANGE)
	# Server cabinet, data cartridges and a neon plant.
	ink_box(Vector3(-3.4,0.55,-0.4),Vector3(1.05,1.05,1.6),BLUE)
	for z in [-0.85,-0.05]:
		ink_box(Vector3(-2.86,0.62,z),Vector3(0.04,0.34,0.66),Color("1f8fa0"))
		ink_box(Vector3(-2.82,0.62,z),Vector3(0.06,0.06,0.15),INK)
	ink_box(Vector3(-3.3,1.22,-0.2),Vector3(0.3,0.34,0.3),ORANGE)
	for n in range(4):
		ink_box(Vector3(-3.35+n*0.12,1.50+n*0.08,-0.18),Vector3(0.1,0.45,0.16),Color("7dff6a"),n*0.6)
	# Desnislava's safe room at rear. Drawing, not a separate playable level.
	ink_box(Vector3(-1.6,1.2,2.82),Vector3(1.4,2.4,0.15),Color("121729"))
	for x in [-2.33,-0.87]:
		ink_box(Vector3(x,1.25,2.70),Vector3(0.14,2.5,0.16),Color("6c7a96"))
	ink_box(Vector3(-1.6,2.50,2.70),Vector3(1.6,0.13,0.15),Color("6c7a96"))
	# Crooked wall picture and chunky shelf on the back wall.
	ink_box(Vector3(1.8,2.0,2.82),Vector3(1.1,0.9,0.08),INK)
	raw_box(Vector3(1.8,2.0,2.76),Vector3(0.98,0.78,0.035),CREAM)
	ink_box(Vector3(1.8,1.3,2.55),Vector3(1.7,0.07,0.6),Color("56607a"))
	for n in range(6):
		ink_box(Vector3(1.28+n*0.19,1.55,2.6),Vector3(0.14,0.43+rng.randf()*0.1,0.28),[ORANGE,BLUE,YELLOW,MINT][n%4])
	var mesh_instance := MeshInstance3D.new()
	surface.generate_normals()
	mesh_instance.mesh = surface.commit()
	var mat := material(Color.WHITE)
	mat.vertex_color_use_as_albedo = true
	mesh_instance.material_override = mat
	parent.add_child(mesh_instance)
	return mesh_instance

static func character(parent: Node3D, kind: int, height: float) -> Sprite3D:
	var sprite := Sprite3D.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = load("res://assets/characters-r2.png")
	var half := Vector2(atlas.atlas.get_width(),atlas.atlas.get_height())/2.0
	var regions := [Rect2(Vector2.ZERO,half),Rect2(Vector2(half.x,0),half),Rect2(Vector2(0,half.y),half),Rect2(half,half)]
	atlas.region = regions[kind]
	sprite.texture = atlas
	sprite.pixel_size = height / regions[kind].size.y
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.shaded = false
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.alpha_scissor_threshold = 0.25
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	parent.add_child(sprite)
	return sprite
