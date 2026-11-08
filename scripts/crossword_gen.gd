class_name CrosswordGen
extends RefCounted
## Genera un cruciverba incastrando parole: ogni partita è diversa.
## dir 0 = orizzontale, 1 = verticale.

const N := 15

var grid: Array = []
var dirs := PackedInt32Array()
var words: Array = []


## Ritorna {"grid": Array[String] (N*N), "words": Array[Dictionary]} con il tentativo migliore.
static func make(pool: Array, count: int) -> Dictionary:
	var best: Dictionary = {}
	for attempt in 80:
		var g := CrosswordGen.new()
		g._build(pool, count)
		if best.is_empty() or g.words.size() > best["words"].size():
			best = {"grid": g.grid, "words": g.words}
		if g.words.size() >= count:
			break
	_number(best["words"])
	return best


func _build(pool: Array, count: int) -> void:
	grid = []
	for i in N * N:
		grid.append("")
	dirs.resize(N * N)
	var cand := pool.duplicate()
	cand.shuffle()
	var first: Array = cand[0]
	for it in cand:
		if it[0].length() >= 6 and it[0].length() <= 11:
			first = it
			break
	cand.erase(first)
	var fw: String = first[0]
	_place(first, N >> 1, (N - fw.length()) >> 1, 0)
	for item in cand:
		if words.size() >= count:
			break
		_try_place(item)


@warning_ignore("integer_division")
func _try_place(item: Array) -> bool:
	var w: String = item[0]
	var opts: Array = []
	for i in w.length():
		for idx in N * N:
			if grid[idx] != w[i]:
				continue
			var m: int = dirs[idx]
			if m == 3:
				continue
			var nd := 1 if m == 1 else 0
			var r: int = idx / N
			var c: int = idx % N
			var sr: int = r - (i if nd == 1 else 0)
			var sc: int = c - (i if nd == 0 else 0)
			if _fits(w, sr, sc, nd):
				opts.append([sr, sc, nd])
	if opts.is_empty():
		return false
	var o: Array = opts[randi() % opts.size()]
	_place(item, o[0], o[1], o[2])
	return true


func _fits(w: String, sr: int, sc: int, d: int) -> bool:
	var dr := 1 if d == 1 else 0
	var dc := 1 - dr
	var wl := w.length()
	var er := sr + dr * (wl - 1)
	var ec := sc + dc * (wl - 1)
	if sr < 0 or sc < 0 or er >= N or ec >= N:
		return false
	var br := sr - dr
	var bc := sc - dc
	if br >= 0 and bc >= 0 and grid[br * N + bc] != "":
		return false
	var ar := er + dr
	var ac := ec + dc
	if ar < N and ac < N and grid[ar * N + ac] != "":
		return false
	var cross := 0
	for k in wl:
		var r := sr + dr * k
		var c := sc + dc * k
		var idx := r * N + c
		var ch: String = grid[idx]
		if ch != "":
			if ch != w[k]:
				return false
			if dirs[idx] & (1 << d):
				return false
			cross += 1
		else:
			var r1 := r + dc
			var c1 := c + dr
			var r2 := r - dc
			var c2 := c - dr
			if r1 < N and c1 < N and grid[r1 * N + c1] != "":
				return false
			if r2 >= 0 and c2 >= 0 and grid[r2 * N + c2] != "":
				return false
	return cross >= 1


func _place(item: Array, sr: int, sc: int, d: int) -> void:
	var w: String = item[0]
	var dr := 1 if d == 1 else 0
	var dc := 1 - dr
	for k in w.length():
		var idx := (sr + dr * k) * N + (sc + dc * k)
		grid[idx] = w[k]
		dirs[idx] = dirs[idx] | (1 << d)
	words.append({"w": w, "clue": item[1], "r": sr, "c": sc, "dir": d})


## Numerazione in ordine di lettura; una cella che inizia due parole ha un solo numero.
static func _number(ws: Array) -> void:
	var starts := {}
	for w in ws:
		starts[int(w["r"]) * N + int(w["c"])] = 0
	var n := 0
	for idx in N * N:
		if starts.has(idx):
			n += 1
			starts[idx] = n
	for w in ws:
		w["num"] = starts[int(w["r"]) * N + int(w["c"])]
