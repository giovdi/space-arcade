extends Control
## Hub principale: griglia di minigiochi a tema spazio.

const GAMES := [
	{"id": "chess", "name": "SCACCHI", "desc": "Sfida l'IA aliena", "color": Color(0.2, 0.9, 1.0), "ready": true},
	{"id": "crossword", "name": "CRUCIVERBA", "desc": "Parole dalla galassia", "color": Color(1.0, 0.75, 0.2), "ready": true},
	{"id": "monsters", "name": "MOSTRI COSMICI", "desc": "Alleva e combatti", "color": Color(0.4, 1.0, 0.5), "ready": true},
	{"id": "parkour", "name": "PARKOUR 3D", "desc": "Corri tra gli asteroidi", "color": Color(1.0, 0.35, 0.8), "ready": true},
	{"id": "guess", "name": "INDOVINA IL MOSTRO", "desc": "Ascolta il canto e scegli", "color": Color(0.7, 0.55, 1.0), "ready": true},
]

var toast: Label


func _ready() -> void:
	add_child(Starfield.new())

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 60)
	add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 30)
	margin.add_child(col)

	var title := UiKit.label("SPACE ARCADE", 96, Color(0.6, 0.95, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var sub := UiKit.label("Scegli la tua missione", 36, Color(0.7, 0.75, 0.95))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 40)
	col.add_child(grid)

	for g in GAMES:
		var status := "GIOCA" if g["ready"] else "IN ARRIVO"
		var b := UiKit.button("%s\n%s\n[ %s ]" % [g["name"], g["desc"], status], g["color"], 44)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.size_flags_vertical = Control.SIZE_EXPAND_FILL
		if not g["ready"]:
			b.modulate = Color(1, 1, 1, 0.6)
		b.pressed.connect(_on_card.bind(g))
		grid.add_child(b)

	toast = UiKit.label("", 40, Color(1, 0.9, 0.5))
	toast.modulate.a = 0.0
	toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast.offset_top = -90
	add_child(toast)


func _on_card(g: Dictionary) -> void:
	if g["ready"]:
		Game.open(g["id"])
		return
	toast.text = "%s arriverà presto!" % g["name"]
	toast.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.2)
	tw.tween_property(toast, "modulate:a", 0.0, 0.6)
