class_name UiKit
extends RefCounted
## Piccoli helper per uno stile UI sci-fi coerente.


static func box(accent: Color, fill_alpha := 0.88, radius := 20) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.08, 0.22, fill_alpha)
	sb.border_color = accent
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	return sb


static func button(text: String, accent: Color, font_size := 36) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", Color(0.92, 0.97, 1.0))
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", accent)
	b.add_theme_stylebox_override("normal", box(accent))
	var hover := box(accent.lightened(0.3))
	hover.bg_color = Color(0.1, 0.14, 0.35, 0.95)
	b.add_theme_stylebox_override("hover", hover)
	var pressed := box(accent)
	pressed.bg_color = accent.darkened(0.6)
	b.add_theme_stylebox_override("pressed", pressed)
	b.focus_mode = Control.FOCUS_NONE
	return b


static func label(text: String, font_size: int, color := Color(0.92, 0.97, 1.0)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l
