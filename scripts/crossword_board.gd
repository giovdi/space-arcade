class_name CrosswordBoard
extends Control
## Griglia del cruciverba: disegno, selezione (tocco), inserimento lettere.

signal clue_changed(text: String)
signal solved

const N := CrosswordGen.N

var words: Array = []
var sol: Array = []
var ent: Array = []
var bad: Dictionary = {}
var word_at: Dictionary = {}  # idx -> [parola orizzontale, parola verticale] (-1 se assente)
var num_at: Dictionary = {}   # idx -> numero
var sel := -1
var sdir := 0
var r0 := 0
var c0 := 0
var r1 := 0
var c1 := 0
var done := false
var given: Dictionary = {}  # celle pre-compilate (non modificabili)


func _ready() -> void:
	custom_minimum_size = Vector2(400, 400)


func load_puzzle(data: Dictionary, hint_frac: float = 0.0) -> void:
	words = data["words"]
	sol = data["grid"]
	ent = []
	for i in N * N:
		ent.append("")
	given = {}
	bad = {}
	word_at = {}
	num_at = {}
	done = false
	r0 = N
	c0 = N
	r1 = 0
	c1 = 0
	for wi in words.size():
		var w: Dictionary = words[wi]
		var d: int = w["dir"]
		var dr := 1 if d == 1 else 0
		var dc := 1 - dr
		var wl: int = String(w["w"]).length()
		num_at[int(w["r"]) * N + int(w["c"])] = w["num"]
		for k in wl:
			var r: int = int(w["r"]) + dr * k
			var c: int = int(w["c"]) + dc * k
			var idx := r * N + c
			if not word_at.has(idx):
				word_at[idx] = [-1, -1]
			word_at[idx][d] = wi
			r0 = mini(r0, r)
			c0 = mini(c0, c)
			r1 = maxi(r1, r)
			c1 = maxi(c1, c)
	# Lettere già scritte come aiuto (mai più del 40%, così non si risolve da solo).
	var filled: Array = []
	for idx in N * N:
		if sol[idx] != "":
			filled.append(idx)
	filled.shuffle()
	var n_hint := mini(int(filled.size() * hint_frac), int(filled.size() * 0.4))
	for i in n_hint:
		ent[filled[i]] = sol[filled[i]]
		given[filled[i]] = true
	select_word(0)


func word_cells(wi: int) -> Array:
	var w: Dictionary = words[wi]
	var dr := 1 if int(w["dir"]) == 1 else 0
	var dc := 1 - dr
	var out: Array = []
	for k in String(w["w"]).length():
		out.append((int(w["r"]) + dr * k) * N + (int(w["c"]) + dc * k))
	return out


func select_word(wi: int) -> void:
	var w: Dictionary = words[wi]
	sel = int(w["r"]) * N + int(w["c"])
	sdir = int(w["dir"])
	_emit_clue()
	queue_redraw()


func _active_word() -> int:
	if sel < 0 or not word_at.has(sel):
		return -1
	var a: int = word_at[sel][sdir]
	if a < 0:
		sdir = 1 - sdir
		a = word_at[sel][sdir]
	return a


func _emit_clue() -> void:
	var a := _active_word()
	if a < 0:
		return
	var w: Dictionary = words[a]
	clue_changed.emit("%d %s: %s" % [w["num"], "Orizzontale" if int(w["dir"]) == 0 else "Verticale", w["clue"]])


func _metrics() -> Dictionary:
	var cols := c1 - c0 + 1
	var rows := r1 - r0 + 1
	var cs := minf(minf(size.x / cols, size.y / rows), 120.0)
	var ox := (size.x - cs * cols) / 2.0
	var oy := (size.y - cs * rows) / 2.0
	return {"cs": cs, "ox": ox, "oy": oy}


func _gui_input(e: InputEvent) -> void:
	if words.is_empty():
		return
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		var m := _metrics()
		var cs: float = m["cs"]
		var c := c0 + int(floorf((e.position.x - float(m["ox"])) / cs))
		var r := r0 + int(floorf((e.position.y - float(m["oy"])) / cs))
		if r < r0 or r > r1 or c < c0 or c > c1:
			return
		var idx := r * N + c
		if sol[idx] == "":
			return
		if idx == sel:
			var other: int = word_at[idx][1 - sdir]
			if other >= 0:
				sdir = 1 - sdir
		else:
			sel = idx
			if int(word_at[idx][sdir]) < 0:
				sdir = 1 - sdir
		_emit_clue()
		queue_redraw()


func type_letter(ch: String) -> void:
	if done or sel < 0:
		return
	if not given.has(sel):
		ent[sel] = ch
		bad.erase(sel)
	_advance()
	_check_solved()
	queue_redraw()


func backspace() -> void:
	if done or sel < 0:
		return
	if ent[sel] != "" and not given.has(sel):
		ent[sel] = ""
		bad.erase(sel)
	else:
		var cells := word_cells(_active_word())
		var k := cells.find(sel)
		if k > 0:
			sel = cells[k - 1]
			if not given.has(sel):
				ent[sel] = ""
				bad.erase(sel)
	queue_redraw()


func _advance() -> void:
	var a := _active_word()
	if a < 0:
		return
	var cells := word_cells(a)
	var k := cells.find(sel)
	if k >= 0 and k < cells.size() - 1:
		sel = cells[k + 1]


## Segna in rosso le lettere sbagliate; ritorna quante sono.
func check() -> int:
	var n := 0
	for idx in N * N:
		if ent[idx] != "" and ent[idx] != sol[idx]:
			bad[idx] = true
			n += 1
	queue_redraw()
	return n


func reveal() -> void:
	if done or sel < 0:
		return
	ent[sel] = sol[sel]
	bad.erase(sel)
	_advance()
	_check_solved()
	queue_redraw()


func _check_solved() -> void:
	for idx in N * N:
		if sol[idx] != "" and ent[idx] != sol[idx]:
			return
	done = true
	solved.emit()


func _draw() -> void:
	if words.is_empty():
		return
	var m := _metrics()
	var cs: float = m["cs"]
	var ox: float = m["ox"]
	var oy: float = m["oy"]
	var active := {}
	var aw := _active_word()
	if aw >= 0:
		for idx in word_cells(aw):
			active[idx] = true
	var font := ThemeDB.fallback_font
	var fs := int(cs * 0.55)
	var ns := int(cs * 0.24)
	for r in range(r0, r1 + 1):
		for c in range(c0, c1 + 1):
			var idx := r * N + c
			if sol[idx] == "":
				continue
			var rect := Rect2(ox + (c - c0) * cs, oy + (r - r0) * cs, cs, cs)
			var fill := Color(0.93, 0.96, 1.0)
			if idx == sel:
				fill = Color(0.35, 0.88, 1.0)
			elif active.has(idx):
				fill = Color(0.72, 0.9, 1.0)
			draw_rect(rect, fill)
			draw_rect(rect, Color(0.1, 0.15, 0.4), false, 2.0)
			if num_at.has(idx):
				draw_string(font, rect.position + Vector2(4, ns + 1), str(num_at[idx]),
					HORIZONTAL_ALIGNMENT_LEFT, -1, ns, Color(0.25, 0.3, 0.55))
			if ent[idx] != "":
				var col := Color(0.05, 0.1, 0.35)
				if given.has(idx):
					col = Color(0.35, 0.4, 0.6)
				if bad.has(idx):
					col = Color(0.9, 0.1, 0.15)
				elif done:
					col = Color(0.0, 0.55, 0.25)
				draw_string(font, rect.position + Vector2(0, cs * 0.5 + fs * 0.36), ent[idx],
					HORIZONTAL_ALIGNMENT_CENTER, cs, fs, col)
