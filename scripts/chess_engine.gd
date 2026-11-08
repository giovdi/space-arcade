class_name ChessEngine
extends RefCounted
## Motore scacchi: regole complete (arrocco, en passant, promozione, scacco matto,
## stallo) + IA minimax con potatura alpha-beta.
## Scacchiera: 64 caselle, indice = riga*8 + colonna, riga 0 = ottava traversa (alto).
## Pezzi: bianchi positivi, neri negativi. 1=P 2=N 3=B 4=R 5=Q 6=K.

const P := 1
const N := 2
const B := 3
const R := 4
const Q := 5
const K := 6

const VALUES: Array[int] = [0, 100, 320, 330, 500, 900, 0]
const KN: Array[Vector2i] = [
	Vector2i(-2, -1), Vector2i(-2, 1), Vector2i(-1, -2), Vector2i(-1, 2),
	Vector2i(1, -2), Vector2i(1, 2), Vector2i(2, -1), Vector2i(2, 1),
]
const DIAG: Array[Vector2i] = [Vector2i(-1, -1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(1, 1)]
const ORTH: Array[Vector2i] = [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]

var board := PackedInt32Array()
var turn := 1
var castle: Array[bool] = [true, true, true, true]  # wK, wQ, bK, bQ
var ep := -1


func _init() -> void:
	board.resize(64)
	reset()


func reset() -> void:
	board.fill(0)
	var back: Array[int] = [R, N, B, Q, K, B, N, R]
	for c in 8:
		board[c] = -back[c]
		board[8 + c] = -P
		board[48 + c] = P
		board[56 + c] = back[c]
	turn = 1
	castle = [true, true, true, true]
	ep = -1


func clone() -> ChessEngine:
	var e := ChessEngine.new()
	e.board = board.duplicate()
	e.turn = turn
	e.castle = castle.duplicate()
	e.ep = ep
	return e


func find_king(side: int) -> int:
	for i in 64:
		if board[i] == side * K:
			return i
	return -1


func _inside(r: int, c: int) -> bool:
	return r >= 0 and r < 8 and c >= 0 and c < 8


func _slide_hits(r: int, c: int, d: Vector2i, a: int, b: int) -> bool:
	var rr: int = r + d.x
	var cc: int = c + d.y
	while _inside(rr, cc):
		var p: int = board[rr * 8 + cc]
		if p != 0:
			return p == a or p == b
		rr += d.x
		cc += d.y
	return false


func is_attacked(sq: int, by: int) -> bool:
	var r: int = sq >> 3
	var c: int = sq & 7
	var pr: int = r + by
	if pr >= 0 and pr < 8:
		for dc in [-1, 1]:
			var pc: int = c + dc
			if pc >= 0 and pc < 8 and board[pr * 8 + pc] == by * P:
				return true
	for d in KN:
		var rr: int = r + d.x
		var cc: int = c + d.y
		if _inside(rr, cc) and board[rr * 8 + cc] == by * N:
			return true
	for d in DIAG:
		if _slide_hits(r, c, d, by * B, by * Q):
			return true
	for d in ORTH:
		if _slide_hits(r, c, d, by * R, by * Q):
			return true
	for dr in [-1, 0, 1]:
		for dc in [-1, 0, 1]:
			if dr == 0 and dc == 0:
				continue
			var rr: int = r + dr
			var cc: int = c + dc
			if _inside(rr, cc) and board[rr * 8 + cc] == by * K:
				return true
	return false


func _add_pawn(f: int, t: int, promo_row: bool, out: Array) -> void:
	if promo_row:
		for pr in [Q, R, B, N]:
			out.append({"f": f, "t": t, "promo": pr})
	else:
		out.append({"f": f, "t": t})


func _pawn_moves(sq: int, r: int, c: int, side: int, out: Array) -> void:
	var dr: int = -side
	var nr: int = r + dr
	if nr < 0 or nr > 7:
		return
	var promo_row: bool = (nr == 0 or nr == 7)
	if board[nr * 8 + c] == 0:
		_add_pawn(sq, nr * 8 + c, promo_row, out)
		var start_row: int = 6 if side == 1 else 1
		if r == start_row and board[(nr + dr) * 8 + c] == 0:
			out.append({"f": sq, "t": (nr + dr) * 8 + c})
	for dc in [-1, 1]:
		var cc: int = c + dc
		if cc < 0 or cc > 7:
			continue
		var t: int = nr * 8 + cc
		var tp: int = board[t]
		if tp != 0 and signi(tp) == -side:
			_add_pawn(sq, t, promo_row, out)
		elif t == ep:
			out.append({"f": sq, "t": t, "ep": true})


func _castle_moves(side: int, out: Array) -> void:
	var base: int = 0 if side == 1 else 2
	var ks: int = 60 if side == 1 else 4
	if board[ks] != side * K or is_attacked(ks, -side):
		return
	if castle[base] and board[ks + 3] == side * R and board[ks + 1] == 0 and board[ks + 2] == 0 \
			and not is_attacked(ks + 1, -side):
		out.append({"f": ks, "t": ks + 2, "castle": true})
	if castle[base + 1] and board[ks - 4] == side * R and board[ks - 1] == 0 \
			and board[ks - 2] == 0 and board[ks - 3] == 0 and not is_attacked(ks - 1, -side):
		out.append({"f": ks, "t": ks - 2, "castle": true})


func pseudo_moves(side: int) -> Array:
	var out: Array = []
	for sq in 64:
		var p: int = board[sq]
		if p == 0 or signi(p) != side:
			continue
		var r: int = sq >> 3
		var c: int = sq & 7
		var kind: int = absi(p)
		if kind == P:
			_pawn_moves(sq, r, c, side, out)
		elif kind == N or kind == K:
			var steps: Array[Vector2i] = KN
			if kind == K:
				steps = DIAG + ORTH
			for d in steps:
				var rr: int = r + d.x
				var cc: int = c + d.y
				if not _inside(rr, cc):
					continue
				var tp: int = board[rr * 8 + cc]
				if tp == 0 or signi(tp) == -side:
					out.append({"f": sq, "t": rr * 8 + cc})
			if kind == K:
				_castle_moves(side, out)
		else:
			var dirs: Array[Vector2i] = []
			if kind == B or kind == Q:
				dirs += DIAG
			if kind == R or kind == Q:
				dirs += ORTH
			for d in dirs:
				var rr: int = r + d.x
				var cc: int = c + d.y
				while _inside(rr, cc):
					var tp: int = board[rr * 8 + cc]
					if tp == 0:
						out.append({"f": sq, "t": rr * 8 + cc})
					else:
						if signi(tp) == -side:
							out.append({"f": sq, "t": rr * 8 + cc})
						break
					rr += d.x
					cc += d.y
	return out


func make(m: Dictionary) -> void:
	var f: int = m["f"]
	var t: int = m["t"]
	var pc: int = board[f]
	var side: int = turn
	board[t] = pc
	board[f] = 0
	if m.get("ep", false):
		board[t + (8 if side == 1 else -8)] = 0
	var promo: int = m.get("promo", 0)
	if promo != 0:
		board[t] = side * promo
	if m.get("castle", false):
		if t > f:
			board[f + 1] = board[f + 3]
			board[f + 3] = 0
		else:
			board[f - 1] = board[f - 4]
			board[f - 4] = 0
	if absi(pc) == K:
		var base: int = 0 if side == 1 else 2
		castle[base] = false
		castle[base + 1] = false
	for sq in [f, t]:
		if sq == 63:
			castle[0] = false
		elif sq == 56:
			castle[1] = false
		elif sq == 7:
			castle[2] = false
		elif sq == 0:
			castle[3] = false
	ep = -1
	if absi(pc) == P and absi(t - f) == 16:
		ep = (f + t) >> 1
	turn = -side


func legal_moves(side: int) -> Array:
	var out: Array = []
	for m in pseudo_moves(side):
		var e := clone()
		e.turn = side
		e.make(m)
		if not e.is_attacked(e.find_king(side), -side):
			out.append(m)
	return out


func in_check(side: int) -> bool:
	return is_attacked(find_king(side), -side)


func _only_kings_or_minor() -> bool:
	var minors := 0
	for p in board:
		var k: int = absi(p)
		if k == 0 or k == K:
			continue
		if k == N or k == B:
			minors += 1
		else:
			return false
	return minors <= 1


## "ok", "check", "checkmate", "stalemate" oppure "draw" (materiale insufficiente).
func status() -> String:
	if _only_kings_or_minor():
		return "draw"
	var chk := in_check(turn)
	if legal_moves(turn).is_empty():
		return "checkmate" if chk else "stalemate"
	return "check" if chk else "ok"


# ---------------------------------------------------------------- IA

func evaluate() -> int:
	var s := 0
	for i in 64:
		var p: int = board[i]
		if p == 0:
			continue
		var kind: int = absi(p)
		var r: int = i >> 3
		var c: int = i & 7
		var v: int = VALUES[kind]
		if kind != K:
			v += (14 - (absi(r * 2 - 7) + absi(c * 2 - 7))) * 2
		if kind == P:
			var adv: int = (6 - r) if p > 0 else (r - 1)
			v += adv * 6
		s += signi(p) * v
	return s


func _order(moves: Array) -> void:
	for m in moves:
		var s: int = absi(board[m["t"]]) * 10 + m.get("promo", 0) * 10
		m["s"] = s
	moves.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["s"] > b["s"])


func search(depth: int, alpha: int, beta: int) -> int:
	if depth == 0:
		return evaluate() * turn
	var moves := legal_moves(turn)
	if moves.is_empty():
		return (-100000 - depth) if in_check(turn) else 0
	_order(moves)
	var best := -10000000
	for m in moves:
		var e := clone()
		e.make(m)
		var sc: int = -e.search(depth - 1, -beta, -alpha)
		if sc > best:
			best = sc
		if best > alpha:
			alpha = best
		if alpha >= beta:
			break
	return best


func best_move(depth: int) -> Dictionary:
	var moves := legal_moves(turn)
	if moves.is_empty():
		return {}
	_order(moves)
	var best: Dictionary = moves[0]
	var best_score := -10000000
	for m in moves:
		var e := clone()
		e.make(m)
		var sc: int = -e.search(depth - 1, -10000000, 10000000) + randi() % 6
		if sc > best_score:
			best_score = sc
			best = m
	return best
