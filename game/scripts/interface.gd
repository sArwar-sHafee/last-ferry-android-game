extends Control

const SERIF = preload("res://art/fonts/Yrsa-Medium.ttf")
const MONO = preload("res://art/fonts/LiberationMono-Regular.ttf")
const PAPER := Color("#eee9d8")
const BRASS := Color("#e6bd83")
const MUTE := Color("#aec0b8")
const INK := Color("#142527")
const BOARD := Color("#203435")

func rect(parent: Control, at: Rect2, color: Color) -> ColorRect:
	var n := ColorRect.new()
	n.position = at.position
	n.size = at.size
	n.color = color
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(n)
	return n

func label(parent: Control, at: Rect2, value: String, font: Font, px: int, color := PAPER, wrap := false) -> Label:
	var n := Label.new()
	n.position = at.position
	n.size = at.size
	n.text = value
	n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	n.add_theme_font_override("font",font)
	n.add_theme_font_size_override("font_size",px)
	n.add_theme_color_override("font_color",color)
	if wrap:
		n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(n)
	return n

func skin(fill: Color,edge: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = edge
	s.set_border_width_all(1)
	s.set_corner_radius_all(3)
	s.content_margin_left = 12
	s.content_margin_right = 12
	return s

func button(parent: Control,at: Rect2,caption: String, action: Callable, primary := false) -> Button:
	var b := Button.new()
	b.position = at.position
	b.size = at.size
	b.text = caption
	b.add_theme_font_size_override("font_size",17)
	b.add_theme_color_override("font_color",INK if primary else PAPER)
	b.add_theme_color_override("font_hover_color",INK if primary else Color.WHITE)
	b.add_theme_color_override("font_pressed_color",INK)
	b.add_theme_stylebox_override("normal",skin(BRASS if primary else Color("#1e3233"),BRASS if primary else Color("#67817b")))
	b.add_theme_stylebox_override("hover",skin(Color("#f0d2a4") if primary else Color("#344a49"),BRASS))
	b.add_theme_stylebox_override("pressed",skin(Color("#c1b18f"),BRASS))
	var outline := skin(Color.TRANSPARENT,BRASS)
	outline.set_border_width_all(2)
	b.add_theme_stylebox_override("focus",outline)
	b.pressed.connect(action)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	parent.add_child(b)
	return b

func clear_children() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
