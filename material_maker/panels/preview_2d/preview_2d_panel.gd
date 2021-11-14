extends "res://material_maker/panels/preview_2d/preview_2d.gd"

export(String, MULTILINE) var shader_accumulate : String = ""
export(String, MULTILINE) var shader_divide : String = ""

var center : Vector2 = Vector2(0.5, 0.5)
var scale : float = 1.2

var view_mode : int = 0

var temporal_aa : bool = false
var temporal_aa_current : bool = false


func _ready():
	update_shader_options()
	update_view_menu()
	update_axes_menu()
	update_export_menu()
	$ContextMenu.add_check_item("Temporal AA", MENU_TEMPORAL_AA)
	$ContextMenu.set_item_checked(MENU_TEMPORAL_AA, temporal_aa)

func update_view_menu() -> void:
	$ContextMenu.add_submenu_item("View", "View")

func update_axes_menu() -> void:
	$ContextMenu/Axes.clear()
	for s in $Axes.STYLES:
		$ContextMenu/Axes.add_item(s)
	$ContextMenu/Axes.add_separator()
	$ContextMenu/Axes.add_item("Change color", 1000)
	$ContextMenu.add_submenu_item("Axes", "Axes")

func set_generator(g : MMGenBase, o : int = 0, force : bool = false) -> void:
	#center = Vector2(0.5, 0.5)
	#scale = 1.2
	.set_generator(g, o, force)
	setup_controls()
	update_shader_options()

func update_material(source):
	temporal_aa_current = temporal_aa
	# Here we could detect $time to disable temporal AA
	if temporal_aa_current:
		do_update_material(source, $Accumulate/Iteration.material, shader_context_defs+shader_accumulate)
		material.shader.code = shader_divide
		material.set_shader_param("sum", $Accumulate.get_texture())
		start_accumulate()
	else:
		.update_material(source)
		material.set_shader_param("mode", view_mode)
		material.set_shader_param("background_color_1", Color(0.4, 0.4, 0.4))
		material.set_shader_param("background_color_2", Color(0.6, 0.6, 0.6))

var started : bool = false
var divide : int = 0

func set_temporal_aa(v : bool):
	if v == temporal_aa:
		return
	temporal_aa = v
	if ! temporal_aa:
		# stop AA loop
		started = false
		yield(get_tree(), "idle_frame")
		yield(get_tree(), "idle_frame")
		yield(get_tree(), "idle_frame")
	set_generator(generator, output, true)

var start_accumulate_trigger : bool = false

func start_accumulate():
	if !temporal_aa_current:
		return
	if !start_accumulate_trigger:
		start_accumulate_trigger = true
		call_deferred("do_start_accumulate")

func do_start_accumulate():
	started = false
	yield(get_tree(), "idle_frame")
	yield(get_tree(), "idle_frame")
	start_accumulate_trigger = false
	$Accumulate/Iteration.material.set_shader_param("sum", $Accumulate.get_texture())
	$Accumulate/Iteration.material.set_shader_param("clear", true)
	divide = 1
	started = true
	while started:
		$Accumulate.render_target_update_mode = Viewport.UPDATE_ONCE
		$Accumulate.update_worlds()
		material.set_shader_param("divide", divide)
		yield(get_tree(), "idle_frame")
		yield(get_tree(), "idle_frame")
		$Accumulate/Iteration.material.set_shader_param("clear", false)
		divide += 1
		if divide > 100000:
			started = false
			break

func get_preview_material():
	return $Accumulate/Iteration.material if temporal_aa_current else material

func on_float_parameters_changed(parameter_changes : Dictionary) -> bool:
	if .on_float_parameters_changed(parameter_changes):
		start_accumulate()
		return true
	return false

func setup_controls() -> void:
	var param_defs = generator.get_parameter_defs() if is_instance_valid(generator) else []
	for c in get_children():
		if c.has_method("setup_control"):
			c.setup_control(generator, param_defs)

func value_to_pos(value : Vector2) -> Vector2:
	return (value-center+Vector2(0.5, 0.5))*min(rect_size.x, rect_size.y)/scale+0.5*rect_size

func value_to_offset(value : Vector2) -> Vector2:
	return value*min(rect_size.x, rect_size.y)/scale

func pos_to_value(pos : Vector2) -> Vector2:
	return (pos-0.5*rect_size)*scale/min(rect_size.x, rect_size.y)+center-Vector2(0.5, 0.5)

func update_shader_options() -> void:
	on_resized()

func on_resized() -> void:
	.on_resized()
	$Accumulate.size = rect_size
	$Accumulate/Iteration.rect_position = Vector2(0, 0)
	$Accumulate/Iteration.rect_size = rect_size
	material.set_shader_param("preview_2d_center", center)
	material.set_shader_param("preview_2d_scale", scale)
	$Accumulate/Iteration.material.set_shader_param("preview_2d_center", center)
	$Accumulate/Iteration.material.set_shader_param("preview_2d_scale", scale)
	$Accumulate/Iteration.material.set_shader_param("preview_2d_size", rect_size)
	setup_controls()
	$Axes.update()
	start_accumulate()

var dragging : bool = false
var zooming : bool = false

func _on_gui_input(event):
	var need_update : bool = false
	var new_center : Vector2 = center
	var multiplier : float = min(rect_size.x, rect_size.y)
	var image_rect : Rect2 = get_global_rect()
	var offset_from_center : Vector2 = get_global_mouse_position()-(image_rect.position+0.5*image_rect.size)
	var new_scale : float = scale
	if event is InputEventMouseButton:
		if event.pressed:
			if event.button_index == BUTTON_WHEEL_DOWN:
				new_scale = min(new_scale*1.05, 5.0)
			elif event.button_index == BUTTON_WHEEL_UP:
				new_scale = max(new_scale*0.95, 0.005)
			elif event.button_index == BUTTON_MIDDLE:
				dragging = true
			elif event.button_index == BUTTON_LEFT:
				if event.shift:
					dragging = true
				elif event.command:
					zooming = true
		else:
			dragging = false
			zooming = false
	elif event is InputEventMouseMotion:
		if dragging:
			new_center = center-event.relative*scale/multiplier
		elif zooming:
			new_scale = clamp(new_scale*(1.0+0.01*event.relative.y), 0.005, 5.0)
	if new_scale != scale:
		new_center = center+offset_from_center*(scale-new_scale)/multiplier
		scale = new_scale
		need_update = true
	if new_center != center:
		center.x = clamp(new_center.x, 0.0, 1.0)
		center.y = clamp(new_center.y, 0.0, 1.0)
		need_update = true
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == BUTTON_RIGHT:
			$ContextMenu.popup(Rect2(get_global_mouse_position(), $ContextMenu.get_minimum_size()))
	if need_update:
		on_resized()

func _on_ContextMenu_id_pressed(id) -> void:
	match id:
		0:
			center = Vector2(0.5, 0.5)
			scale = 1.2
			update_shader_options()
		MENU_EXPORT_AGAIN:
			export_again()
		MENU_EXPORT_ANIMATION:
			export_animation()
		MENU_TEMPORAL_AA:
			var index : int = $ContextMenu.get_item_index(id)
			var v = ! $ContextMenu.is_item_checked(index)
			$ContextMenu.set_item_checked(index, v)
			set_temporal_aa(v)
		_:
			print("unsupported id "+str(id))

func _on_View_id_pressed(id):
	view_mode = id
	material.set_shader_param("mode", view_mode)

func _on_Axes_id_pressed(id):
	if id == 1000:
		var color_picker_popup = preload("res://material_maker/widgets/color_picker_popup/color_picker_popup.tscn").instance()
		add_child(color_picker_popup)
		var color_picker = color_picker_popup.get_node("ColorPicker")
		color_picker.color = $Axes.color
		color_picker.connect("color_changed", $Axes, "set_color")
		color_picker_popup.rect_position = get_global_mouse_position()
		color_picker_popup.connect("popup_hide", color_picker_popup, "queue_free")
		color_picker_popup.popup()
	else:
		$Axes.style = id
