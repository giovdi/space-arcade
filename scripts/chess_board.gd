class_name ChessBoard
extends Control
## Scacchiera disegnata a mano (pezzi vettoriali stile sci-fi), tocco per muovere.

signal status_changed(text: String)

const LIGHT_SQ := Color(0.16, 0.22, 0.48)
const DARK_SQ := Color(0.08, 0.1, 0.28)
const NEON := Color(0.3, 0.95, 1.0)

const BASE: Array[Vector2] = [Vector2(-0.6, 0.78), Vector2(0.6, 0.78), Vector2(0.5, 0.5), Vector2(-0.5, 0.5)]
const PAWN_BODY: Array[Vector2] = [Vector2(-0.28, 0.5), Vector2(0.28, 0.5), Vector2(0.12, 0.05), Vector2(-0.12, 0.05)]
const ROOK_BODY: Array[Vector2] = [Vector2(-0.4, 0.5), Vector2(0.4, 0.5), Vector2(0.32, -0.3), Vector2(-0.32, -0.3)]
const ROOK_TOP: Array[Vector2] = [
	Vector2(-0.46, -0.3), Vector2(0.46, -0.3), Vector2(0.46, -0.72), Vector2(0.26, -0.72),
	Vector2(0.26, -0.52), Vector2(0.09, -0.52), Vector2(0.09, -0.72), Vector2(-0.09, -0.72),
	Vector2(-0.09, -0.52), Vector2(-0.26, -0.52), Vector2(-0.26, -0.72), Vector2(-0.46, -0.72),
]
const KNIGHT: Array[Vector2] = [
	Vector2(-0.4, 0.55), Vector2(0.45, 0.55), Vector2(0.4, 0.0), Vector2(0.25, -0.45),
	Vector2(0.05, -0.75), Vector2(-0.1, -0.6), Vector2(-0.55, -0.15), Vector2(-0.5, 0.0),
	Vector2(-0.2, -0.1), Vector2(0.0, 0.1),
]
const BISHOP_BODY: Array[Vector2] = [Vector2(-0.4, 0.5), Vector2(0.4, 0.5), Vector2(0.2, -0.1), Vector2(-0.2, -0.1)]
const BISHOP_HEAD: Array[Vector2] = [
	Vector2(0, -0.8), Vector2(0.28, -0.4), Vector2(0.2, -0.1), Vector2(-0.2, -0.1), Vector2(-0.28, -0.4),
]
const QUEEN_BODY: Array[Vector2] = [Vector2(-0.45, 0.5), Vector2(0.45, 0.5), Vector2(0.25, -0.2), Vector2(-0.25, -0.2)]
const QUEEN_CROWN: Array[Vector2] = [
	Vector2(-0.5, -0.2), Vector2(0.5, -0.2), Vector2(0.55, -0.7), Vector2(0.25, -0.45),
	Vector2(0, -0.8), Vector2(-0.25, -0.45), Vector2(-0.55, -0.7),
]
const KING_HEAD: Array[Vector2] = [Vector2(-0.4, -0.2), Vector2(0.4, -0.2), Vector2(0.3, -0.6), Vector2(-0.3, -0.6)]

var engine := ChessEngine.new()
var player := 1
var level := 2
var selected := -1
var sel_moves: Array = []
var last_move: Dictionary = {}
var thinking := false
var over := false
var game_id := 0


func _ready() -> void:
	custom_minimum_size = Vector2(400, 400)
	new_game(player)


func new_game(side: int) -> void:
	game_id += 1
	player = side
	engine.reset()
	selected = -1
	sel_moves = []
	last_move = {}
	thinking = false
	over = false
	_announce()
	queue_redraw()
	if engine.turn != player:
		_ai_turn()


func _announce() -> void:
	var st := engine.status()
	var text := "Tocca a te" if engine.turn == player else "Turno dell'alieno"
	if st == "check":
		text = "Scacco! " + text
	elif st == "checkmate":
		over = true
		text = "Scacco matto! Hai vinto!" if engine.turn != player else "Scacco matto. L'alieno vince."
	elif st == "stalemate":
		over = true
		text = "Stallo: patta."
	elif st == "draw":
		over = true
		text = "Materiale insufficiente: patta."
	status_changed.emit(text)


func _cell() -> float:
	return minf(size.x, size.y) / 8.0


func _origin() -> Vector2:
	var side := minf(size.x, size.y)
	return Vector2((size.x - side) / 2.0, (size.y - side) / 2.0)


func _sq_pos(sq: int) -> Vector2:
	var r: int = sq >> 3
	var c: int = sq & 7
	var dr: int = r if player == 1 else 7 - r
	var dc: int = c if player == 1 else 7 - c
	return _origin() + Vector2(dc, dr) * _cell()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_tap(event.position)


func _tap(pos: Vector2) -> void:
	if over or thinking or engine.turn != player:
		return
	var cell := _cell()
	var rel := pos - _origin()
	if rel.x < 0 or rel.y < 0 or rel.x >= cell * 8 or rel.y >= cell * 8:
		return
	var dc := int(rel.x / cell)
	var dr := int(rel.y / cell)
	var r: int = dr if player == 1 else 7 - dr
	var c: int = dc if player == 1 else 7 - dc
	var sq := r * 8 + c
	for m in sel_moves:
		if m["t"] == sq and (not m.has("promo") or m["promo"] == ChessEngine.Q):
			_play(m)
			return
	var p: int = engine.board[sq]
	selected = -1
	sel_moves = []
	if p != 0 and signi(p) == player:
		selected = sq
		for m in engine.legal_moves(player):
			if m["f"] == sq:
				sel_moves.append(m)
	queue_redraw()


func _play(m: Dictionary) -> void:
	engine.make(m)
	last_move = m
	selected = -1
	sel_moves = []
	_announce()
	queue_redraw()
	if not over and engine.turn != player:
		_ai_turn()


func _ai_turn() -> void:
	var gid := game_id
	thinking = true
	status_changed.emit("L'alieno sta pensando…")
	await get_tree().create_timer(0.4).timeout
	if gid != game_id:
		return
	var m := engine.best_move(level)
	thinking = false
	if not m.is_empty():
		_play(m)


# ---------------------------------------------------------------- disegno

func _draw() -> void:
	var cell := _cell()
	var origin := _origin()
	for sq in 64:
		var r: int = sq >> 3
		var c: int = sq & 7
		var pos := _sq_pos(sq)
		var rect := Rect2(pos, Vector2(cell, cell))
		draw_rect(rect, LIGHT_SQ if (r + c) % 2 == 0 else DARK_SQ)
		if not last_move.is_empty() and (sq == last_move["f"] or sq == last_move["t"]):
			draw_rect(rect, Color(1.0, 0.85, 0.2, 0.22))
		if sq == selected:
			draw_rect(rect, Color(0.3, 0.95, 1.0, 0.35))
		if engine.board[sq] == engine.turn * ChessEngine.K and engine.in_check(engine.turn):
			draw_rect(rect, Color(1.0, 0.15, 0.2, 0.45))
	draw_rect(Rect2(origin, Vector2(cell * 8, cell * 8)), NEON, false, 4.0)

	for sq in 64:
		var p: int = engine.board[sq]
		if p != 0:
			var ctr := _sq_pos(sq) + Vector2(cell, cell) * 0.5
			var white := p > 0
			var fill := Color(0.88, 0.96, 1.0) if white else Color(0.2, 0.12, 0.38)
			var line := Color(0.1, 0.2, 0.4) if white else Color(0.85, 0.5, 1.0)
			_piece(absi(p), ctr, cell * 0.42, fill, line)

	for m in sel_moves:
		if m.has("promo") and m["promo"] != ChessEngine.Q:
			continue
		var ctr: Vector2 = _sq_pos(m["t"]) + Vector2(cell, cell) * 0.5
		if engine.board[m["t"]] != 0 or m.has("ep"):
			draw_arc(ctr, cell * 0.42, 0, TAU, 32, Color(1, 0.4, 0.4, 0.9), 5.0, true)
		else:
			draw_circle(ctr, cell * 0.12, Color(0.3, 0.95, 1.0, 0.75))

	var font := ThemeDB.fallback_font
	var fs := int(cell * 0.2)
	for i in 8:
		var file_idx: int = i if player == 1 else 7 - i
		var rank_idx: int = 8 - i if player == 1 else i + 1
		draw_string(font, origin + Vector2(i * cell + 5, 8 * cell - 5), char(97 + file_idx),
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.7, 0.8, 1.0, 0.6))
		draw_string(font, origin + Vector2(5, i * cell + fs + 2), str(rank_idx),
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.7, 0.8, 1.0, 0.6))


func _poly(pts: Array[Vector2], ctr: Vector2, s: float, fill: Color, line: Color) -> void:
	var arr := PackedVector2Array()
	for p in pts:
		arr.append(ctr + p * s)
	draw_colored_polygon(arr, fill)
	arr.append(arr[0])
	draw_polyline(arr, line, maxf(2.0, s * 0.06), true)


func _ball(pos: Vector2, r: float, fill: Color, line: Color) -> void:
	draw_circle(pos, r, fill)
	draw_arc(pos, r, 0, TAU, 24, line, maxf(2.0, r * 0.2), true)


func _piece(kind: int, ctr: Vector2, s: float, fill: Color, line: Color) -> void:
	_poly(BASE, ctr, s, fill, line)
	if kind == ChessEngine.P:
		_poly(PAWN_BODY, ctr, s, fill, line)
		_ball(ctr + Vector2(0, -0.22) * s, 0.3 * s, fill, line)
	elif kind == ChessEngine.R:
		_poly(ROOK_BODY, ctr, s, fill, line)
		_poly(ROOK_TOP, ctr, s, fill, line)
	elif kind == ChessEngine.N:
		_poly(KNIGHT, ctr, s, fill, line)
		draw_circle(ctr + Vector2(-0.02, -0.45) * s, 0.06 * s, line)
	elif kind == ChessEngine.B:
		_poly(BISHOP_BODY, ctr, s, fill, line)
		_poly(BISHOP_HEAD, ctr, s, fill, line)
		_ball(ctr + Vector2(0, -0.88) * s, 0.09 * s, fill, line)
	elif kind == ChessEngine.Q:
		_poly(QUEEN_BODY, ctr, s, fill, line)
		_poly(QUEEN_CROWN, ctr, s, fill, line)
	elif kind == ChessEngine.K:
		_poly(QUEEN_BODY, ctr, s, fill, line)
		_poly(KING_HEAD, ctr, s, fill, line)
		draw_rect(Rect2(ctr + Vector2(-0.06, -0.98) * s, Vector2(0.12, 0.4) * s), line)
		draw_rect(Rect2(ctr + Vector2(-0.2, -0.86) * s, Vector2(0.4, 0.12) * s), line)
