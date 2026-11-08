class_name Starfield
extends Control
## Sfondo spaziale animato (stelle che brillano + nebulose).

var stars: Array[Vector4] = []
var t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in 160:
		stars.append(Vector4(rng.randf(), rng.randf(), rng.randf_range(1.0, 3.2), rng.randf() * TAU))


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.1))
	draw_circle(Vector2(size.x * 0.2, size.y * 0.3), size.y * 0.5, Color(0.25, 0.1, 0.45, 0.18))
	draw_circle(Vector2(size.x * 0.85, size.y * 0.8), size.y * 0.45, Color(0.05, 0.3, 0.5, 0.15))
	for s in stars:
		var a := 0.5 + 0.5 * sin(t * 1.5 + s.w)
		draw_circle(Vector2(s.x * size.x, s.y * size.y), s.z, Color(1, 1, 1, 0.3 + 0.7 * a))
