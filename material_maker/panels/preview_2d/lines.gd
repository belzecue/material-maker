extends Control

export var style : int = 1 setget set_style
export var color : Color = Color(0.5, 0.5, 0.5) setget set_color

const STYLES : Array = [ "None", "Corners", "Lines", "Grid4x4", "Grid16x16" ]

func draw_grid(size : int) -> void:
	var parent = get_parent()
	for i in range(size+1):
		var x = float(i) / float(size) - 0.5
		var p = parent.value_to_pos(Vector2(x, x))
		draw_line(Vector2(p.x, 0), Vector2(p.x, rect_size.y), color)
		draw_line(Vector2(0, p.y), Vector2(rect_size.x, p.y), color)

func _draw() -> void:
	var parent = get_parent()
	var p
	match style:
		1:
			p = parent.value_to_pos(Vector2(-0.5, -0.52))
			draw_line(p, Vector2(p.x, 0), color)
			p = parent.value_to_pos(Vector2(0.5, -0.52))
			draw_line(p, Vector2(p.x, 0), color)
			p = parent.value_to_pos(Vector2(-0.52, -0.5))
			draw_line(p, Vector2(0, p.y), color)
			p = parent.value_to_pos(Vector2(-0.52, 0.5))
			draw_line(p, Vector2(0, p.y), color)
			p = parent.value_to_pos(Vector2(-0.5, 0.52))
			draw_line(p, Vector2(p.x, rect_size.y), color)
			p = parent.value_to_pos(Vector2(0.5, 0.52))
			draw_line(p, Vector2(p.x, rect_size.y), color)
			p = parent.value_to_pos(Vector2(0.52, -0.5))
			draw_line(p, Vector2(rect_size.x, p.y), color)
			p = parent.value_to_pos(Vector2(0.52, 0.5))
			draw_line(p, Vector2(rect_size.x, p.y), color)
		2:
			draw_grid(1)
		3:
			draw_grid(4)
		4:
			draw_grid(16)

func set_style(s : int) -> void:
	style = s
	update()

func set_color(c : Color) -> void:
	color = c
	update()
