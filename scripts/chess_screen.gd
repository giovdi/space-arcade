extends Control
## Schermata Scacchi: scacchiera a sinistra, pannello comandi a destra.

const ACCENT := Color(0.2, 0.9, 1.0)
const LEVEL_NAMES := ["", "Facile", "Medio", "Difficile"]

var board: ChessBoard
var status_label: Label
var level_btn: Button
var side_btn: Button


func _ready() -> void:
	add_child(Starfield.new())

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 40)
	margin.add_child(row)

	board = ChessBoard.new()
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.size_flags_stretch_ratio = 2.5
	board.status_changed.connect(func(t: String) -> void: status_label.text = t)

	var panel := VBoxContainer.new()
	panel.custom_minimum_size = Vector2(460, 0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_constant_override("separation", 24)

	var title := UiKit.label("SCACCHI SPAZIALI", 52, Color(0.6, 0.95, 1.0))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(title)

	status_label = UiKit.label("", 34)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size = Vector2(0, 130)
	panel.add_child(status_label)

	var new_btn := UiKit.button("Nuova partita", ACCENT)
	new_btn.pressed.connect(func() -> void: board.new_game(board.player))
	panel.add_child(new_btn)

	level_btn = UiKit.button("", ACCENT)
	level_btn.pressed.connect(_cycle_level)
	panel.add_child(level_btn)

	side_btn = UiKit.button("", ACCENT)
	side_btn.pressed.connect(_toggle_side)
	panel.add_child(side_btn)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(spacer)

	var back := UiKit.button("Torna all'hub", Color(1.0, 0.5, 0.6))
	back.pressed.connect(func() -> void: Game.open("hub"))
	panel.add_child(back)

	row.add_child(board)
	row.add_child(panel)
	_refresh_buttons()


func _refresh_buttons() -> void:
	level_btn.text = "Livello: %s" % LEVEL_NAMES[board.level]
	side_btn.text = "Giochi con: %s" % ("Bianchi" if board.player == 1 else "Neri")


func _cycle_level() -> void:
	board.level = board.level % 3 + 1
	_refresh_buttons()


func _toggle_side() -> void:
	board.new_game(-board.player)
	_refresh_buttons()
