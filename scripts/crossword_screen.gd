extends Control
## Schermata Cruciverba: griglia a sinistra; definizione, elenco, tastiera e comandi a destra.

const ACCENT := Color(1.0, 0.75, 0.2)
# [nome, parole, lunghezza massima, quota di lettere già scritte]
const LEVELS := [
	["Facilissimo", 4, 6, 0.4],
	["Facile", 6, 8, 0.3],
	["Medio", 9, 10, 0.15],
	["Difficile", 12, 99, 0.0],
]

var board: CrosswordBoard
var clue_label: Label
var clue_list: VBoxContainer
var level := 0
var level_btn: Button


func _ready() -> void:
	add_child(Starfield.new())
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 30)
	add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 30)
	margin.add_child(row)

	board = CrosswordBoard.new()
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.clue_changed.connect(func(t: String) -> void: clue_label.text = t)
	board.solved.connect(func() -> void: clue_label.text = "Complimenti! Cruciverba completato!")

	var panel := VBoxContainer.new()
	panel.custom_minimum_size = Vector2(700, 0)
	panel.add_theme_constant_override("separation", 12)

	var top := HBoxContainer.new()
	var title := UiKit.label("CRUCIVERBA STELLARE", 46, Color(1.0, 0.85, 0.4))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var back := UiKit.button("Hub", Color(1.0, 0.5, 0.6), 30)
	back.pressed.connect(func() -> void: Game.open("hub"))
	top.add_child(back)
	panel.add_child(top)

	clue_label = UiKit.label("", 32)
	clue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	clue_label.custom_minimum_size = Vector2(0, 100)
	panel.add_child(clue_label)

	var sc := ScrollContainer.new()
	sc.scroll_deadzone = 16
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(sc)
	clue_list = VBoxContainer.new()
	clue_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(clue_list)

	panel.add_child(_keyboard())

	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 10)
	var check := UiKit.button("Controlla", ACCENT, 28)
	check.pressed.connect(_on_check)
	btns.add_child(check)
	var hint := UiKit.button("Aiuto", ACCENT, 28)
	hint.pressed.connect(func() -> void: board.reveal())
	btns.add_child(hint)
	level_btn = UiKit.button("", ACCENT, 28)
	level_btn.pressed.connect(func() -> void:
		level = (level + 1) % LEVELS.size()
		_new_game())
	btns.add_child(level_btn)
	var again := UiKit.button("Nuovo", ACCENT, 28)
	again.pressed.connect(_new_game)
	btns.add_child(again)
	panel.add_child(btns)

	row.add_child(board)
	row.add_child(panel)
	_new_game()


func _new_game() -> void:
	level_btn.text = LEVELS[level][0]
	var lv: Array = LEVELS[level]
	var pool: Array = CrosswordData.WORDS.filter(func(it: Array) -> bool: return String(it[0]).length() <= int(lv[2]))
	board.load_puzzle(CrosswordGen.make(pool, int(lv[1])), float(lv[3]))
	_build_clues()


func _on_check() -> void:
	var n := board.check()
	if n == 0 and not board.done:
		clue_label.text = "Nessun errore, continua così!"
	elif n > 0:
		clue_label.text = "%d lettere sbagliate (in rosso)." % n


func _build_clues() -> void:
	for c in clue_list.get_children():
		clue_list.remove_child(c)
		c.queue_free()
	for d in 2:
		clue_list.add_child(UiKit.label("ORIZZONTALI" if d == 0 else "VERTICALI", 28, ACCENT))
		var items: Array = []
		for wi in board.words.size():
			if int(board.words[wi]["dir"]) == d:
				items.append(wi)
		items.sort_custom(func(a: int, b: int) -> bool: return int(board.words[a]["num"]) < int(board.words[b]["num"]))
		for wi in items:
			var w: Dictionary = board.words[wi]
			var b := Button.new()
			b.text = "%d. %s" % [w["num"], w["clue"]]
			b.flat = true
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			b.add_theme_font_size_override("font_size", 26)
			b.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0))
			b.focus_mode = Control.FOCUS_NONE
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.pressed.connect(board.select_word.bind(wi))
			clue_list.add_child(b)


func _keyboard() -> GridContainer:
	var g := GridContainer.new()
	g.columns = 9
	g.add_theme_constant_override("h_separation", 6)
	g.add_theme_constant_override("v_separation", 6)
	for i in 26:
		var ch := char(65 + i)
		var b := _key(ch)
		b.pressed.connect(board.type_letter.bind(ch))
		g.add_child(b)
	var bs := _key("<")
	bs.pressed.connect(board.backspace)
	g.add_child(bs)
	return g


func _key(text: String) -> Button:
	var b := UiKit.button(text, ACCENT, 34)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for n in ["normal", "hover", "pressed"]:
		var sb: StyleBoxFlat = b.get_theme_stylebox(n)
		sb.content_margin_left = 2
		sb.content_margin_right = 2
		sb.content_margin_top = 10
		sb.content_margin_bottom = 10
	return b


func _unhandled_key_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		if e.keycode == KEY_BACKSPACE:
			board.backspace()
		elif e.unicode >= 97 and e.unicode <= 122:
			board.type_letter(char(e.unicode - 32))
		elif e.unicode >= 65 and e.unicode <= 90:
			board.type_letter(char(e.unicode))
