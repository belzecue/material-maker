extends MMGraphNodeGeneric

var material_nodes : Array = []

func get_material_nodes() -> Array:
	if material_nodes.empty():
		material_nodes = mm_loader.get_material_nodes()
	return material_nodes

func _on_MaterialExport_gui_input(event : InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == BUTTON_RIGHT and event.pressed == true:
		accept_event()
		var menu = PopupMenu.new()
		for n in get_material_nodes():
			menu.add_item(n.label)
		var can_copy = ( generator.model == null )
		var can_paste = false
		var graph = parse_json(OS.clipboard)
		if graph != null and graph is Dictionary and graph.has("nodes"):
			if graph.nodes.size() == 1 and graph.nodes[0].type == "material_export" and graph.nodes[0].has("shader_model"):
				can_paste = true
		if can_copy:
			menu.add_separator()
			menu.add_item("Copy", 10000)
		if can_paste:
			if !can_copy:
				menu.add_separator()
			menu.add_item("Paste", 10001)
		add_child(menu)
		menu.connect("modal_closed", menu, "queue_free")
		menu.connect("id_pressed", self, "_on_menu_id_pressed")
		menu.popup(Rect2(get_global_mouse_position(), menu.get_minimum_size()))

func _on_menu_id_pressed(id : int) -> void:
	yield(get_tree(), "idle_frame")
	match id:
		10000:
			OS.clipboard = to_json(get_parent().serialize_selection([ self ]))
		10001:
			var graph = parse_json(OS.clipboard)
			if graph != null:
				if graph.nodes.size() == 1 and graph.nodes[0].type == "material_export":
					generator.model = null
					generator.editable = true
					update_generator(graph.nodes[0].shader_model)
		_:
			generator.model = get_material_nodes()[id].name
			generator.editable = false
			update_generator(mm_loader.predefined_generators[generator.model].shader_model)
