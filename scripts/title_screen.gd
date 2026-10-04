extends Node3D
const Art = preload("res://scripts/art.gd")
var clock := 0.0
var bubbles: MultiMeshInstance3D
var logo: Node3D
var animation: Tween

func build(animate_title: bool = true) -> void:
	var backdrop := MeshInstance3D.new()
	var plane := QuadMesh.new()
	plane.size = Vector2(5.8,3.8)
	backdrop.mesh = plane
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode unshaded;
void fragment() {
 vec2 p = (UV-0.5)*vec2(1.35,1.0);
 float halo = exp(-dot(p,p)*7.0);
 float stripe = step(0.95, fract(atan(p.y,p.x)*7.0));
 ALBEDO = mix(vec3(0.025,0.052,0.066), vec3(0.07,0.19,0.20), halo);
 ALBEDO += stripe*halo*0.018;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	backdrop.material_override = mat
	backdrop.position = Vector3(0,0.1,-0.22)
	add_child(backdrop)
	# Quiet framing and rays are baked into one draw call.
	var art := Art.new()
	for side in [-1,1]:
		art.raw_box(Vector3(side*1.93,0.06,-0.1),Vector3(0.014,2.61,0.02),Art.YELLOW.darkened(0.45))
		for n in range(4):
			art.raw_box(Vector3(side*(1.61+n*0.075),0.65-n*0.19,-0.1),Vector3(0.038,0.07,0.02),Art.ORANGE)
	for y in [-1.30,1.31]:
		art.raw_box(Vector3(0,y,-0.1),Vector3(3.88,0.014,0.02),Art.YELLOW.darkened(0.45))
	art.surface.generate_normals()
	var frame := MeshInstance3D.new()
	frame.mesh = art.surface.commit()
	var frame_mat := Art.material(Color.WHITE)
	frame_mat.vertex_color_use_as_albedo = true
	frame.material_override = frame_mat
	add_child(frame)
	logo = Node3D.new()
	add_child(logo)
	logo.position.y = 0.42
	var top := Art.label(logo,"LAST",Vector3(0,0.57,0.06),39,Art.CREAM,0.0031)
	top.outline_size = 6
	for item in [["CHAYKA",0.23,Art.CREAM],["BENDER",-0.18,Art.YELLOW]]:
		var shadow := Art.label(logo,item[0],Vector3(0.032,item[1]-0.039,0.025),106,Color("7f4337"),0.0046)
		shadow.outline_size = 13
		var text_node := Art.label(logo,item[0],Vector3(0,item[1],0.08),106,item[2],0.0046)
		text_node.outline_size = 10
		text_node.rotation.z = 0.025 if item[0]=="CHAYKA" else -0.025
	var badge := Art.label(logo,"+ КИБОРГ\nБЕНДЪРИ!",Vector3(1.02,0.40,0.1),40,Art.ORANGE,0.0032)
	badge.outline_size = 8
	badge.rotation.z = -0.22
	Art.label(self,"СПАСЕНИЕТО НА ДЕСНИСЛАВА",Vector3(0,-0.055,0.1),31,Art.ORANGE,0.0028)
	Art.label(self,"Съдбата е в твоите ръце",Vector3(0,-0.19,0.1),25,Art.CREAM,0.0026)
	bubbles = MultiMeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.017
	mesh.height = 0.034
	mesh.radial_segments = 8
	mesh.rings = 4
	bubbles.multimesh = MultiMesh.new()
	bubbles.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	bubbles.multimesh.mesh = mesh
	bubbles.multimesh.instance_count = 38
	bubbles.material_override = Art.material(Color("adc8ba"))
	add_child(bubbles)
	if animate_title:
		logo.scale = Vector3.ONE*0.08
		logo.rotation.z = -0.14
		animation = create_tween().set_parallel(true)
		animation.tween_property(logo,"scale",Vector3.ONE,1.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		animation.tween_property(logo,"rotation:z",0.0,1.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		animation.tween_property(logo,"position:y",0.42,1.15).from(0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _process(delta: float) -> void:
	clock += delta
	if not bubbles:
		return
	for i in range(38):
		var side := -1.0 if i%2==0 else 1.0
		var p := Vector3(side*(1.44+0.32*sin(i*2.399+clock*0.2)),fmod(i*0.173+clock*0.10,2.25)-1.1,0.1)
		bubbles.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*(0.6+(i%4)*0.35)),p))
