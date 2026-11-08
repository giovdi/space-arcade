class_name MonsterView
extends Control
## Disegna un mostro cosmico (6 specie) con animazione di rimbalzo. Toccabile.

signal tapped

var sp := 0
var look := 0.0       # -1 guarda a sinistra, +1 a destra
var coins_ready := 0  # monete da raccogliere (bolla dorata)
var bump := 0.0       # salto extra dopo un tocco/attacco
var hurt := 0.0       # lampo rosso quando colpito
var clickable := true
var t := 0.0
var press_pos := Vector2.ZERO
var pending := false


func _init(species: int = 0) -> void:
	sp = species
	t = randf() * 6.0
	mouse_filter = Control.MOUSE_FILTER_PASS


func _process(delta: float) -> void:
	t += delta
	bump = maxf(bump - delta * 2.5, 0.0)
	hurt = maxf(hurt - delta * 3.0, 0.0)
	queue_redraw()


## Suona solo con un tocco rapido sul corpo del mostro; fuori dal mostro o
## trascinando il dito l'evento passa alla lista, che scorre.
func _hit(p: Vector2) -> bool:
	var r := minf(size.x, size.y) * 0.3
	return p.distance_to(Vector2(size.x * 0.5, size.y * 0.58 + r * 0.2)) <= r * 1.15


func _gui_input(e: InputEvent) -> void:
	if not clickable:
		return
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			press_pos = e.position
			pending = _hit(e.position)
		else:
			if pending and e.position.distance_to(press_pos) < 20.0:
				tapped.emit()
			pending = false
	elif e is InputEventMouseMotion and pending:
		if e.position.distance_to(press_pos) >= 20.0:
			pending = false


func _mirror(pts: Array, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array(pts), color)
	var m := PackedVector2Array()
	for p in pts:
		var v: Vector2 = p
		m.append(Vector2(-v.x, v.y))
	draw_colored_polygon(m, color)


func _eye(p: Vector2, r: float) -> void:
	draw_circle(p, r, Color.WHITE)
	draw_circle(p + Vector2(look * r * 0.35, 0.03), r * 0.5, Color(0.05, 0.05, 0.15))


func _draw() -> void:
	var base: Color = MonsterData.SPECIES[sp]["color"]
	var col := base.lerp(Color(1.0, 0.2, 0.2), hurt * 0.6)
	var dark := base.darkened(0.55)
	var r := minf(size.x, size.y) * 0.3
	var hop := (absf(sin(t * 3.0 + sp)) * 0.12 + bump * 0.35) * r
	var sy := 1.0 + 0.05 * sin(t * 6.0 + sp) + bump * 0.12
	var sx := 1.0 / sy
	var cx := size.x * 0.5
	var cy := size.y * 0.58

	draw_set_transform(Vector2(cx, cy + r * 1.05), 0.0, Vector2(r * 0.9, r * 0.22))
	draw_circle(Vector2.ZERO, 1.0, Color(0, 0, 0, 0.35))

	draw_set_transform(Vector2(cx, cy + r * 0.2 - hop), 0.0, Vector2(r * sx, r * sy))
	# Parti dietro il corpo
	if sp == 0:
		for s in [-1.0, 1.0]:
			draw_line(Vector2(0.35 * s, -0.85), Vector2(0.65 * s, -1.5), dark, 0.08, true)
			draw_circle(Vector2(0.65 * s, -1.5), 0.15, Color(1.0, 0.95, 0.4))
	elif sp == 1:
		_mirror([Vector2(0.2, -0.8), Vector2(0.55, -1.5), Vector2(0.7, -0.6)], Color(1.0, 0.95, 0.7))
	elif sp == 2:
		for k in 5:
			var a := deg_to_rad(-150.0 + k * 30.0)
			var tri := PackedVector2Array([
				Vector2(cos(a - 0.2), sin(a - 0.2)), Vector2(cos(a + 0.2), sin(a + 0.2)),
				Vector2(cos(a), sin(a)) * 1.5])
			draw_colored_polygon(tri, base.lightened(0.45))
	elif sp == 5:
		_mirror([Vector2(0.8, -0.2), Vector2(1.8, -1.1), Vector2(1.55, 0.0), Vector2(1.75, 0.5), Vector2(0.9, 0.5)], base.darkened(0.3))
		_mirror([Vector2(0.25, -0.85), Vector2(0.4, -1.4), Vector2(0.55, -0.75)], Color(1.0, 0.95, 0.8))
	elif sp == 6:  # Gelato: cristalli di ghiaccio
		_mirror([Vector2(0.45, -0.85), Vector2(0.75, -1.5), Vector2(0.7, -0.7)], Color(0.85, 1.0, 1.0))
		draw_colored_polygon(PackedVector2Array([Vector2(-0.15, -0.95), Vector2(0, -1.7), Vector2(0.15, -0.95)]), Color(0.85, 1.0, 1.0))
	elif sp == 8:  # Fantasmino: coda ondulata
		for k in 3:
			draw_circle(Vector2((k - 1) * 0.6, 0.85 + 0.1 * (k % 2)), 0.4, col)
	elif sp == 9:  # Robo-Luna: antenna e orecchie
		draw_line(Vector2(0, -0.95), Vector2(0, -1.5), dark, 0.08, true)
		draw_circle(Vector2(0, -1.55), 0.15, Color(1.0, 0.2, 0.2))
		for s in [-1.0, 1.0]:
			draw_rect(Rect2(Vector2(0.95 * s - 0.1, -0.5), Vector2(0.2, 0.55)), dark)
	elif sp == 10:  # Vulcano: cono con lava
		draw_colored_polygon(PackedVector2Array([Vector2(-0.75, -0.55), Vector2(0, -1.5), Vector2(0.75, -0.55)]), base.darkened(0.3))
		draw_colored_polygon(PackedVector2Array([Vector2(-0.22, -1.22), Vector2(0, -1.5), Vector2(0.22, -1.22)]), Color(1.0, 0.65, 0.1))
		draw_circle(Vector2(0.1, -1.75), 0.15, Color(0.6, 0.6, 0.65, 0.5))
		draw_circle(Vector2(-0.05, -2.0), 0.2, Color(0.6, 0.6, 0.65, 0.35))

	# Corpo
	draw_circle(Vector2.ZERO, 1.0, col)
	draw_arc(Vector2.ZERO, 1.0, 0.0, TAU, 40, dark, 0.07, true)
	draw_circle(Vector2(0, 0.3), 0.62, col.lightened(0.35))
	if sp == 7:  # Fungo: cappello a pois
		var cap := PackedVector2Array()
		for k in 15:
			var a := PI + PI * k / 14.0
			cap.append(Vector2(cos(a) * 1.25, -0.55 + sin(a) * 0.75))
		draw_colored_polygon(cap, Color(0.9, 0.2, 0.25))
		draw_circle(Vector2(-0.5, -1.0), 0.17, Color.WHITE)
		draw_circle(Vector2(0.3, -1.15), 0.2, Color.WHITE)
		draw_circle(Vector2(0.75, -0.8), 0.14, Color.WHITE)
	elif sp == 11:  # Re Galassia: corona
		draw_colored_polygon(PackedVector2Array([
			Vector2(-0.6, -0.85), Vector2(-0.7, -1.4), Vector2(-0.35, -1.1), Vector2(0, -1.5),
			Vector2(0.35, -1.1), Vector2(0.7, -1.4), Vector2(0.6, -0.85)]), Color(1.0, 0.85, 0.2))
		draw_circle(Vector2(0, -1.0), 0.1, Color(0.9, 0.2, 0.4))

	# Occhi e bocca
	if sp == 3:
		_eye(Vector2(0, -0.15), 0.5)
	elif sp == 4:
		_eye(Vector2(-0.4, -0.3), 0.2)
		_eye(Vector2(0.4, -0.3), 0.2)
		_eye(Vector2(0, -0.55), 0.18)
		_eye(Vector2(-0.18, -0.1), 0.15)
		_eye(Vector2(0.18, -0.1), 0.15)
	else:
		_eye(Vector2(-0.35, -0.25), 0.22)
		_eye(Vector2(0.35, -0.25), 0.22)
	if hurt > 0.2:
		draw_circle(Vector2(0, 0.5), 0.12, dark)
	elif sp == 9:
		draw_rect(Rect2(Vector2(-0.3, 0.3), Vector2(0.6, 0.22)), dark)
		for k in 3:
			draw_line(Vector2(-0.15 + 0.15 * k, 0.3), Vector2(-0.15 + 0.15 * k, 0.52), Color(0.8, 0.85, 0.9), 0.04)
	else:
		draw_arc(Vector2(0, 0.3), 0.3, 0.25, PI - 0.25, 12, dark, 0.07, true)

	# Bolla monete
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if coins_ready > 0:
		var bp := Vector2(cx + r * 0.9, cy - r * 1.4)
		draw_circle(bp, 30.0, Color(1.0, 0.82, 0.2))
		draw_arc(bp, 30.0, 0.0, TAU, 24, Color(0.6, 0.4, 0.0), 3.0, true)
		draw_string(ThemeDB.fallback_font, bp + Vector2(-30, 9), str(coins_ready),
			HORIZONTAL_ALIGNMENT_CENTER, 60.0, 26, Color(0.25, 0.15, 0.0))
