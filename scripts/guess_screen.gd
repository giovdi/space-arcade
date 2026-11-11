extends Control
## Indovina il mostro: senti il canto di un mostro cosmico, poi compaiono i nomi e devi scegliere.

const ACCENT := Color(0.7, 0.55, 1.0)
const ROUNDS := 10
const SAVE_PATH := "user://guess.cfg"
# [nome, numero di nomi tra cui scegliere, quanti mostri nel mazzo (i primi N della lista)]
const LEVELS := [["Facile", 3, 8], ["Medio", 4, 16], ["Difficile", 5, 24]]

var level := 0
var round_no := 0
var score := 0
var streak := 0
var target := 0
var last_target := -1
var answered := true
var token := 0
var best: Dictionary = {}

var player: AudioStreamPlayer
var view_holder: Control
var view: MonsterView
var prompt: Label
var status: Label
var options: VBoxContainer
var feedback: Label
var next_btn: Button
var listen_btn: Button
var level_btn: Button


func _ready() -> void:
	_load_best()
	add_child(Starfield.new())
	player = AudioStreamPlayer.new()
	add_child(player)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 20)
	margin.add_child(root)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 24)
	root.add_child(top)
	var title := UiKit.label("INDOVINA IL MOSTRO", 52, Color(0.85, 0.75, 1.0))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	status = UiKit.label("", 38, Color(1.0, 0.85, 0.3))
	top.add_child(status)
	level_btn = UiKit.button("", ACCENT, 34)
	level_btn.pressed.connect(func() -> void:
		level = (level + 1) % LEVELS.size()
		_start_game())
	top.add_child(level_btn)
	var back := UiKit.button("Hub", Color(1.0, 0.5, 0.6), 34)
	back.pressed.connect(func() -> void: Game.open("hub"))
	top.add_child(back)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 40)
	root.add_child(body)

	# sinistra: il mostro (sagoma finché non si risponde) e il pulsante per riascoltare
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_theme_constant_override("separation", 20)
	body.add_child(left)
	view_holder = Control.new()
	view_holder.custom_minimum_size = Vector2(0, 560)
	view_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(view_holder)
	listen_btn = UiKit.button("Riascolta", ACCENT, 44)
	listen_btn.pressed.connect(_play_target)
	left.add_child(listen_btn)

	# destra: domanda, nomi, risultato
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_theme_constant_override("separation", 18)
	body.add_child(right)
	prompt = UiKit.label("", 50)
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt.custom_minimum_size = Vector2(0, 130)
	right.add_child(prompt)
	options = VBoxContainer.new()
	options.add_theme_constant_override("separation", 14)
	right.add_child(options)
	feedback = UiKit.label("", 38, Color(0.8, 0.9, 1.0))
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(feedback)
	next_btn = UiKit.button("Avanti", Color(0.4, 1.0, 0.5), 44)
	next_btn.pressed.connect(_on_next)
	right.add_child(next_btn)

	var tip := UiKit.label("Ogni mostro ha la sua voce: ascoltali in Mostri Cosmici (Negozio) per impararle!", 28, Color(0.65, 0.72, 0.95))
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(tip)

	_start_game()


# ------------------------------------------------------------ partita

func _start_game() -> void:
	level_btn.text = LEVELS[level][0]
	round_no = 0
	score = 0
	streak = 0
	last_target = -1
	_next_round()


func _on_next() -> void:
	if round_no >= ROUNDS:
		_start_game()
	else:
		_next_round()


func _next_round() -> void:
	token += 1
	var my := token
	round_no += 1
	answered = false
	var pool_size: int = LEVELS[level][2]
	var n_opts: int = LEVELS[level][1]
	var pool: Array = range(pool_size)
	pool.erase(last_target)
	target = pool[randi() % pool.size()]
	last_target = target

	var others: Array = range(pool_size)
	others.erase(target)
	others.shuffle()
	var opts: Array = [target]
	opts.append_array(others.slice(0, n_opts - 1))
	opts.shuffle()

	_show_view(target, false)
	_update_status()
	prompt.text = "Ascolta il canto..."
	feedback.text = ""
	next_btn.visible = false
	listen_btn.disabled = true
	_clear_options()
	_build_options(opts)
	options.modulate.a = 0.0

	# due volte il canto, poi compaiono i nomi
	_play_target()
	await get_tree().create_timer(1.1).timeout
	if my != token:
		return
	_play_target()
	await get_tree().create_timer(1.1).timeout
	if my != token:
		return
	prompt.text = "Chi canta così?"
	listen_btn.disabled = false
	for b in options.get_children():
		if b is Button:
			b.disabled = false
	var tw := create_tween()
	tw.tween_property(options, "modulate:a", 1.0, 0.35)


func _clear_options() -> void:
	for c in options.get_children():
		options.remove_child(c)
		c.queue_free()


func _build_options(opts: Array) -> void:
	for sp in opts:
		var d: Dictionary = MonsterData.SPECIES[sp]
		var b := UiKit.button(d["name"], d["color"], 46)
		b.custom_minimum_size = Vector2(0, 100)
		b.disabled = true  # si attiva quando i nomi compaiono
		b.set_meta("sp", sp)
		b.pressed.connect(_on_answer.bind(sp, b))
		options.add_child(b)


func _play_target() -> void:
	player.stream = Synth.note(MonsterData.SPECIES[target]["freq"], 0.8, target)
	player.play()
	if view != null:
		view.bump = 0.6


func _on_answer(sp: int, btn: Button) -> void:
	if answered:
		return
	answered = true
	var ok := sp == target
	for b in options.get_children():
		if b is Button:
			b.disabled = true
			if int(b.get_meta("sp")) == target:
				b.modulate = Color(0.5, 1.0, 0.55)
			elif b == btn:
				b.modulate = Color(1.0, 0.45, 0.45)
			else:
				b.modulate = Color(1, 1, 1, 0.5)
	var mname: String = MonsterData.SPECIES[target]["name"]
	if ok:
		score += 1
		streak += 1
		prompt.text = "Esatto! È %s" % mname
		feedback.text = "Serie: %d" % streak if streak > 1 else ""
	else:
		streak = 0
		prompt.text = "Era %s" % mname
		feedback.text = ""
	_show_view(target, true)
	_play_target()
	_update_status()
	listen_btn.disabled = false
	if round_no >= ROUNDS:
		_finish()
	else:
		next_btn.text = "Avanti"
		next_btn.visible = true


func _finish() -> void:
	var lname: String = LEVELS[level][0]
	var old := int(best.get(lname, 0))
	var msg := "Partita finita: %d su %d." % [score, ROUNDS]
	if score > old:
		best[lname] = score
		_save_best()
		msg += " Nuovo record!"
	else:
		msg += " Record: %d." % old
	feedback.text = msg
	next_btn.text = "Gioca ancora"
	next_btn.visible = true


func _show_view(sp: int, revealed: bool) -> void:
	if view != null:
		view.queue_free()
	view = MonsterView.new(sp)
	view.clickable = false
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view_holder.add_child(view)
	# prima della risposta si vede solo la sagoma scura
	view.modulate = Color.WHITE if revealed else Color(0.04, 0.05, 0.12, 1.0)
	if revealed:
		view.bump = 1.0


func _update_status() -> void:
	status.text = "Domanda %d/%d    Punti %d" % [round_no, ROUNDS, score]


# ------------------------------------------------------------ record

func _load_best() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) == OK:
		for l in LEVELS:
			best[l[0]] = int(cf.get_value("best", l[0], 0))


func _save_best() -> void:
	var cf := ConfigFile.new()
	for k in best:
		cf.set_value("best", k, best[k])
	cf.save(SAVE_PATH)
