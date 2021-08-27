extends Control

var last_value : int = 0
var start_time : int = 0
var max_render_queue_size : int = 0

var auto : bool = true
var fast_counter : int = 0

onready var menu : PopupMenu = $PopupMenu
onready var renderers_menu : PopupMenu = $PopupMenu/Renderers
onready var buffers_menu : PopupMenu = $PopupMenu/MaxBufferSize

const ITEM_AUTO : int           = 1000
const ITEM_RENDER_ENABLED : int = 1001

func _ready() -> void:
	menu.add_check_item("Render", ITEM_RENDER_ENABLED)
	menu.set_item_checked(menu.get_item_index(ITEM_RENDER_ENABLED), true)
	menu.add_check_item("Auto", ITEM_AUTO)
	menu.set_item_checked(menu.get_item_index(ITEM_AUTO), true)
	menu.add_submenu_item("Renderers", "Renderers")
	for i in range(8):
		renderers_menu.add_radio_check_item("%d" % (i+1), i+1)
	renderers_menu.set_item_checked(renderers_menu.get_item_index(mm_renderer.max_renderers), true)
	menu.add_separator()
	menu.add_submenu_item("Maximum buffer size", "MaxBufferSize")
	buffers_menu.add_radio_check_item("Unlimited", 0)
	for i in range(7):
		var size : int = 32 << i
		buffers_menu.add_radio_check_item("%dx%d" % [ size, size ], size)
	buffers_menu.set_item_checked(buffers_menu.get_item_index(0), true)

func on_counter_change(count : int, pending : int) -> void:
	if count == 0 and pending == 0:
		$ProgressBar.max_value = 1
		$ProgressBar.value = 1
		$ProgressBar/Label.text = ""
		start_time = OS.get_ticks_msec()
	else:
		if count > last_value:
			if $ProgressBar.value == $ProgressBar.max_value:
				$ProgressBar.value = 0
				max_render_queue_size = 1
			else:
				max_render_queue_size += 1
		else:
			$ProgressBar.value += 1
		assert(max_render_queue_size-$ProgressBar.value == count)
		$ProgressBar.max_value = max_render_queue_size + pending
		if $ProgressBar.value > 0:
			var remaining_time_msec = (OS.get_ticks_msec()-start_time)*(count+pending)/$ProgressBar.value
			$ProgressBar/Label.text = "%d/%d - %d s" % [ $ProgressBar.value, $ProgressBar.max_value, remaining_time_msec/1000 ]
		else:
			$ProgressBar/Label.text = "%d/%d - ? s" % [ $ProgressBar.value, $ProgressBar.max_value ]
	last_value = count

func _process(_delta):
	var fps : float = Performance.get_monitor(Performance.TIME_FPS)
	$FpsCounter.text = "%.1f FPS " % fps
	if auto:
		if fps > 50.0:
			fast_counter += 1
			if fast_counter > 5:
				set_max_renderers(min(mm_renderer.max_renderers+1, 8))
		else:
			fast_counter = 0
			if fps < 20.0:
				set_max_renderers(1)

func set_max_renderers(max_renderers : int):
	if mm_renderer.max_renderers == max_renderers:
		return
	renderers_menu.set_item_checked(renderers_menu.get_item_index(mm_renderer.max_renderers), false)
	mm_renderer.max_renderers = max_renderers
	renderers_menu.set_item_checked(renderers_menu.get_item_index(mm_renderer.max_renderers), true)

func _on_PopupMenu_id_pressed(id):
	var index = menu.get_item_index(id)
	match id:
		ITEM_AUTO:
			auto = ! menu.is_item_checked(index)
			menu.set_item_checked(index, auto)
		ITEM_RENDER_ENABLED:
			var b : bool = ! menu.is_item_checked(index)
			menu.set_item_checked(index, b)
			mm_renderer.enable_renderers(b)

func _on_Renderers_id_pressed(id):
	set_max_renderers(id)

func _on_MaxBufferSize_id_pressed(id):
	if mm_renderer.max_buffer_size == id:
		return
	buffers_menu.set_item_checked(buffers_menu.get_item_index(mm_renderer.max_buffer_size), false)
	mm_renderer.max_buffer_size = id
	buffers_menu.set_item_checked(buffers_menu.get_item_index(mm_renderer.max_buffer_size), true)

func _on_RenderCounter_gui_input(event):
	if event is InputEventMouseButton and event.button_index == BUTTON_RIGHT and event.pressed:
		menu.rect_global_position = get_global_mouse_position()
		menu.popup()
