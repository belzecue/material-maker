extends ViewportContainer


export var control_target : NodePath
export(int, "SDF2D", "SDF3D") var mode = 1 setget set_mode

onready var viewport = $Viewport
onready var camera_position = $Viewport/CameraPosition
onready var camera_rotation1 = $Viewport/CameraPosition/CameraRotation1
onready var camera_rotation2 = $Viewport/CameraPosition/CameraRotation1/CameraRotation2
onready var camera : Camera = $Viewport/CameraPosition/CameraRotation1/CameraRotation2/Camera
onready var plane : MeshInstance = $Viewport/CameraPosition/CameraRotation1/CameraRotation2/Camera/Plane
onready var gizmo : Spatial = $Viewport/Gizmo

var generator : MMGenBase = null

var gizmo_is_local = false

func _ready():
	_on_Preview3D_resized()

func set_mode(m):
	mode = m
	$Viewport/Gizmo.mode = mode

func set_generator(g : MMGenBase, o : int = 0, force : bool = false) -> void:
	if is_instance_valid(g) and (force or g != generator):
		generator = g
		var context : MMGenContext = MMGenContext.new()
		var source = g.get_shader_code("uv", o, context)
		assert(!(source is GDScriptFunctionState))
		if source.empty():
			source = MMGenBase.DEFAULT_GENERATED_SHADER
		var material = plane.get_surface_material(0)
		var variables : Dictionary = {}
		variables.GENERATED_GLOBALS = PoolStringArray(source.globals).join("\n")
		variables.GENERATED_INSTANCE = source.defs
		variables.GENERATED_CODE = source.code
		variables.GENERATED_OUTPUT = source.sdf3d
		material.shader.code = mm_preprocessor.preprocess_file("res://material_maker/windows/sdf_builder/preview_3d.shader", variables)

var setup_controls_filter : String = ""
func setup_controls(filter : String = "") -> void:
	if filter == "previous":
		filter = setup_controls_filter
	else:
		setup_controls_filter = filter
	var param_defs = []
	if is_instance_valid(generator):
		if filter != "":
			param_defs = generator.get_filtered_parameter_defs(filter)
		else:
			param_defs = generator.get_parameter_defs()

var parent_transform : Transform
var local_transform : Transform
var euler_2d : Vector3 = Vector3(0, 0, 0)

func update_gizmo_position():
	gizmo.translation = (parent_transform*local_transform).origin
	if gizmo_is_local:
		gizmo.transform.basis = Basis((parent_transform.basis*local_transform.basis).get_euler())
	else:
		gizmo.transform.basis = Basis(euler_2d)

func set_local_transform(t : Transform):
	local_transform = t
	update_gizmo_position()

func set_parent_transform(t : Transform):
	parent_transform = t
	update_gizmo_position()

func set_2d_orientation(e : Vector3):
	euler_2d = e
	update_gizmo_position()

func _on_Gizmo_translated(_v : Vector3):
	var local_position : Vector3 = parent_transform.affine_inverse().xform(gizmo.translation)
	var parameters : Dictionary = {}
	parameters[setup_controls_filter+"_position_x"] = local_position.x
	parameters[setup_controls_filter+"_position_y"] = local_position.y
	parameters[setup_controls_filter+"_position_z"] = local_position.z
	get_node(control_target).set_node_parameters(generator, parameters)

func _on_Gizmo_rotated(v, a):
	var axis : Vector3 = parent_transform.affine_inverse().basis.xform(v).normalized()
	var local_rotation : Vector3 = local_transform.basis.rotated(axis, a).get_euler()
	var parameters : Dictionary = {}
	parameters[setup_controls_filter+"_angle_x"] = rad2deg(local_rotation.x)
	parameters[setup_controls_filter+"_angle_y"] = rad2deg(local_rotation.y)
	parameters[setup_controls_filter+"_angle_z"] = rad2deg(local_rotation.z)
	parameters[setup_controls_filter+"_angle"] = rad2deg(local_rotation.z)
	get_node(control_target).set_node_parameters(generator, parameters)

func on_float_parameters_changed(parameter_changes : Dictionary) -> bool:
	var return_value : bool = false
	var m : ShaderMaterial = plane.get_surface_material(0)
	for n in parameter_changes.keys():
		for p in VisualServer.shader_get_param_list(m.shader.get_rid()):
			if p.name == n:
				return_value = true
				m.set_shader_param(n, parameter_changes[n])
				break
	return return_value


func _on_Preview3D_resized():
	if viewport != null:
		viewport.size = rect_size

func _input(ev):
	_unhandled_input(ev)
	
func navigation_input(ev) -> bool:
	if ev is InputEventMouseMotion:
		if ev.button_mask & BUTTON_MASK_MIDDLE != 0:
			if ev.shift:
				var factor = 0.0025*camera.translation.z
				camera_position.translate(-factor*ev.relative.x*camera.global_transform.basis.x)
				camera_position.translate(factor*ev.relative.y*camera.global_transform.basis.y)
			else:
				camera_rotation2.rotate_x(-0.01*ev.relative.y)
				camera_rotation1.rotate_y(-0.01*ev.relative.x)
			return true
	elif ev is InputEventMouseButton:
		if ev.control:
			if ev.button_index == BUTTON_WHEEL_UP:
				camera.fov += 1
			elif ev.button_index == BUTTON_WHEEL_DOWN:
				camera.fov -= 1
			else:
				return false
			return true
		else:
			var zoom = 0.0
			if ev.button_index == BUTTON_WHEEL_UP:
				zoom -= 1.0
			elif ev.button_index == BUTTON_WHEEL_DOWN:
				zoom += 1.0
			if zoom != 0.0:
				camera.translate(Vector3(0.0, 0.0, zoom*(1.0 if ev.shift else 0.1)))
			return true
	return false


func _on_Background_input_event(camera, event, position, normal, shape_idx):
	if navigation_input(event):
		accept_event()

func _on_GizmoButton_toggled(button_pressed):
	gizmo.visible = button_pressed

func _on_LocalButton_toggled(button_pressed):
	gizmo_is_local = button_pressed
	update_gizmo_position()
