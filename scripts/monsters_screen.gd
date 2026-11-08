extends Control
## Mostri Cosmici: isola (raccogli monete e fai cantare i mostri), negozio,
## squadra (potenzia) e battaglie a turni.

const ACCENT := Color(0.4, 1.0, 0.5)
const TABS := [["island", "ISOLA"], ["shop", "NEGOZIO"], ["team", "SQUADRA"], ["battle", "BATTAGLIA"]]

var content: VBoxContainer
var coins_label: Label
var tab_buttons: Dictionary = {}
var current := "island"
var island_views: Array = []
var players: Array[AudioStreamPlayer] = []
var save_t := 0.0

# stato battaglia
var b_id := 0
var bp: Dictionary = {}
var be: Dictionary = {}
var b_busy := false
var b_over := false
var b_cd := 0
var b_heals := 2
var p_view: MonsterView
var e_view: MonsterView
var p_bar: ProgressBar
var e_bar: ProgressBar
var b_log: Label
var b_actions: HBoxContainer
var btn_super: Button
var btn_heal: Button


func _ready() -> void:
	MonsterData.ensure_loaded()
	add_child(Starfield.new())
	for i in 6:
		var ap := AudioStreamPlayer.new()
		add_child(ap)
		players.append(ap)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 20)
	margin.add_child(root)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 30)
	root.add_child(top)
	top.add_child(UiKit.label("MOSTRI COSMICI", 56, Color(0.6, 1.0, 0.7)))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	coins_label = UiKit.label("", 48, Color(1.0, 0.85, 0.3))
	# Larghezza fissa e testo a destra: il numero non viene più tagliato quando cresce.
	coins_label.custom_minimum_size = Vector2(560, 0)
	coins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	coins_label.clip_text = false
	top.add_child(coins_label)
	var reset := UiKit.button("Reset", Color(1.0, 0.75, 0.3), 34)
	reset.pressed.connect(_on_reset.bind(reset))
	top.add_child(reset)
	var back := UiKit.button("Hub", Color(1.0, 0.5, 0.6), 34)
	back.pressed.connect(func() -> void:
		MonsterData.save()
		Game.open("hub"))
	top.add_child(back)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 16)
	root.add_child(tabs)
	for t in TABS:
		var b := UiKit.button(t[1], ACCENT, 36)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_tab.bind(t[0]))
		tabs.add_child(b)
		tab_buttons[t[0]] = b

	content = VBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 16)
	root.add_child(content)

	_refresh_coins()
	_tab("island")


func _exit_tree() -> void:
	MonsterData.save()


func _refresh_coins() -> void:
	coins_label.text = "Monete: %d" % MonsterData.coins


## Primo tocco: chiede conferma; secondo tocco (entro 3 secondi): azzera tutto.
func _on_reset(btn: Button) -> void:
	if btn.text == "Reset":
		btn.text = "Sicuro?"
		get_tree().create_timer(3.0).timeout.connect(func() -> void:
			if is_instance_valid(btn):
				btn.text = "Reset")
		return
	btn.text = "Reset"
	MonsterData.coins = 30
	MonsterData.stage = 1
	MonsterData.monsters = [{"sp": 0, "lv": 1, "stock": 0.0}]
	MonsterData.save()
	_refresh_coins()
	_tab("island")


func _play_freq(freq: float) -> void:
	for p in players:
		if not p.playing:
			p.stream = Synth.note(freq)
			p.play()
			return


func _play_species(sp: int) -> void:
	_play_freq(MonsterData.SPECIES[sp]["freq"])


func _clear() -> void:
	for c in content.get_children():
		content.remove_child(c)
		c.queue_free()


func _tab(id: String) -> void:
	b_id += 1
	MonsterData.save()
	current = id
	island_views = []
	_clear()
	for k in tab_buttons:
		tab_buttons[k].modulate = Color(1, 1, 1, 1) if k == id else Color(0.65, 0.65, 0.7, 1)
	if id == "island":
		_build_island()
	elif id == "shop":
		_build_shop()
	elif id == "team":
		_build_team()
	else:
		_build_pick()


func _scroll() -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.scroll_deadzone = 16  # permette di scorrere col dito anche partendo da un mostro o da un pulsante
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(sc)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 16)
	sc.add_child(vb)
	return vb


# ------------------------------------------------------------ isola

func _build_island() -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.box(ACCENT, 0.3, 28))
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(panel)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	panel.add_child(grid)
	for i in MonsterData.monsters.size():
		var m: Dictionary = MonsterData.monsters[i]
		var v := MonsterView.new(int(m["sp"]))
		v.custom_minimum_size = Vector2(260, 260)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.tapped.connect(_on_island_tap.bind(i))
		grid.add_child(v)
		island_views.append(v)
	var hint := UiKit.label("Tocca i mostri: raccogli le monete e falli cantare!", 34, Color(0.7, 0.85, 1.0))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(hint)


func _on_island_tap(i: int) -> void:
	var m: Dictionary = MonsterData.monsters[i]
	var n := int(float(m["stock"]))
	if n > 0:
		MonsterData.coins += n
		m["stock"] = float(m["stock"]) - n
		_refresh_coins()
	var v: MonsterView = island_views[i]
	v.bump = 1.0
	_play_species(int(m["sp"]))


func _process(delta: float) -> void:
	for i in MonsterData.monsters.size():
		var m: Dictionary = MonsterData.monsters[i]
		var sp: int = m["sp"]
		var lv: int = m["lv"]
		m["stock"] = minf(float(m["stock"]) + MonsterData.income(sp, lv) * delta, MonsterData.stock_cap(sp, lv))
		if current == "island" and i < island_views.size():
			var v: MonsterView = island_views[i]
			v.coins_ready = int(float(m["stock"]))
	save_t += delta
	if save_t > 10.0:
		save_t = 0.0
		MonsterData.save()


# ------------------------------------------------------------ negozio

func _build_shop() -> void:
	var vb := _scroll()
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 20)
	vb.add_child(grid)
	for sp in MonsterData.SPECIES.size():
		grid.add_child(_shop_card(sp))


func _shop_card(sp: int) -> Control:
	var d: Dictionary = MonsterData.SPECIES[sp]
	var cost: int = d["cost"]
	var pc := PanelContainer.new()
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pc.add_theme_stylebox_override("panel", UiKit.box(d["color"], 0.8, 20))
	var vb := VBoxContainer.new()
	pc.add_child(vb)
	var v := MonsterView.new(sp)
	v.custom_minimum_size = Vector2(0, 220)
	v.tapped.connect(_play_species.bind(sp))
	vb.add_child(v)
	var n := UiKit.label(d["name"], 42)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(n)
	var semis := int(roundf(12.0 * log(float(d["freq"]) / 440.0) / log(2.0)))
	var names := ["La", "La#", "Si", "Do", "Do#", "Re", "Re#", "Mi", "Fa", "Fa#", "Sol", "Sol#"]
	var oct := 4 + int(floorf((semis + 9) / 12.0))
	var note := UiKit.label("Nota: %s%d" % [names[posmod(semis, 12)], oct], 32, d["color"])
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(note)
	var s := UiKit.label("PV %d   ATT %d   +%.0f monete/s" % [d["hp"], d["atk"], d["inc"]], 28, Color(0.7, 0.8, 1.0))
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(s)
	var full := MonsterData.monsters.size() >= MonsterData.MAX_SLOTS
	var txt := "Isola piena" if full else ("Compra  %d" % cost)
	var b := UiKit.button(txt, d["color"], 34)
	b.disabled = full or MonsterData.coins < cost
	if b.disabled:
		b.modulate = Color(1, 1, 1, 0.5)
	b.pressed.connect(func() -> void:
		MonsterData.coins -= cost
		MonsterData.monsters.append({"sp": sp, "lv": 1, "stock": 0.0})
		MonsterData.save()
		_refresh_coins()
		_play_species(sp)
		_tab("shop"))
	vb.add_child(b)
	return pc


# ------------------------------------------------------------ squadra

func _row(i: int, btn_text: String, enabled: bool, cb: Callable) -> Control:
	var m: Dictionary = MonsterData.monsters[i]
	var sp: int = m["sp"]
	var lv: int = m["lv"]
	var d: Dictionary = MonsterData.SPECIES[sp]
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UiKit.box(d["color"], 0.75, 16))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 24)
	pc.add_child(hb)
	var v := MonsterView.new(sp)
	v.custom_minimum_size = Vector2(160, 160)
	v.tapped.connect(_play_species.bind(sp))
	hb.add_child(v)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_child(UiKit.label("%s   Lv %d" % [d["name"], lv], 44))
	info.add_child(UiKit.label("PV %d   ATT %d   Monete/s %.1f" % [
		MonsterData.max_hp(sp, lv), MonsterData.atk(sp, lv), MonsterData.income(sp, lv)], 30, Color(0.7, 0.8, 1.0)))
	hb.add_child(info)
	var b := UiKit.button(btn_text, d["color"], 36)
	b.custom_minimum_size = Vector2(340, 0)
	b.disabled = not enabled
	if not enabled:
		b.modulate = Color(1, 1, 1, 0.5)
	b.pressed.connect(cb)
	hb.add_child(b)
	return pc


func _build_team() -> void:
	var vb := _scroll()
	for i in MonsterData.monsters.size():
		var m: Dictionary = MonsterData.monsters[i]
		var sp: int = m["sp"]
		var lv: int = m["lv"]
		var cost := MonsterData.upgrade_cost(sp, lv)
		if lv >= MonsterData.MAX_LV:
			vb.add_child(_row(i, "MASSIMO", false, func() -> void: pass))
		else:
			vb.add_child(_row(i, "Potenzia  %d" % cost, MonsterData.coins >= cost, func() -> void:
				MonsterData.coins -= cost
				m["lv"] = lv + 1
				MonsterData.save()
				_refresh_coins()
				_play_species(sp)
				_tab("team")))


# ------------------------------------------------------------ battaglia

func _build_pick() -> void:
	var t := UiKit.label("Livello %d — scegli il tuo combattente" % MonsterData.stage, 44, Color(1.0, 0.85, 0.4))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(t)
	var vb := _scroll()
	for i in MonsterData.monsters.size():
		vb.add_child(_row(i, "Combatti!", true, _start_battle.bind(i)))


func _bar(color: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0, 38)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(10)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.1, 0.2, 0.9)
	bg.set_corner_radius_all(10)
	b.add_theme_stylebox_override("fill", fill)
	b.add_theme_stylebox_override("background", bg)
	return b


func _fighter_box(d: Dictionary, is_player: bool) -> VBoxContainer:
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var l := UiKit.label("%s  Lv %d" % [d["name"], d["lv"]], 44)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(l)
	var bar := _bar(Color(0.3, 0.9, 0.4) if is_player else Color(1.0, 0.35, 0.4))
	vb.add_child(bar)
	var v := MonsterView.new(int(d["sp"]))
	v.clickable = false
	v.look = 1.0 if is_player else -1.0
	v.custom_minimum_size = Vector2(0, 420)
	v.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(v)
	if is_player:
		p_view = v
		p_bar = bar
	else:
		e_view = v
		e_bar = bar
	return vb


func _start_battle(i: int) -> void:
	b_id += 1
	var m: Dictionary = MonsterData.monsters[i]
	var sp: int = m["sp"]
	var lv: int = m["lv"]
	bp = {"sp": sp, "lv": lv, "name": MonsterData.SPECIES[sp]["name"],
		"max": MonsterData.max_hp(sp, lv), "atk": MonsterData.atk(sp, lv)}
	bp["hp"] = bp["max"]
	var st := MonsterData.stage
	var esp := randi_range(0, mini(MonsterData.SPECIES.size() - 1, 1 + (st >> 1)))
	var elv := 1 + ((st - 1) >> 1)
	be = {"sp": esp, "lv": elv, "name": MonsterData.SPECIES[esp]["name"],
		"max": MonsterData.max_hp(esp, elv), "atk": MonsterData.atk(esp, elv)}
	be["hp"] = be["max"]
	b_busy = false
	b_over = false
	b_cd = 0
	b_heals = 2

	_clear()
	var title := UiKit.label("Livello %d" % st, 44, Color(1.0, 0.85, 0.4))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	var arena := HBoxContainer.new()
	arena.size_flags_vertical = Control.SIZE_EXPAND_FILL
	arena.add_theme_constant_override("separation", 80)
	content.add_child(arena)
	arena.add_child(_fighter_box(bp, true))
	arena.add_child(_fighter_box(be, false))

	b_log = UiKit.label("Un mostro selvatico appare!", 38, Color(1.0, 0.95, 0.7))
	b_log.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(b_log)

	b_actions = HBoxContainer.new()
	b_actions.add_theme_constant_override("separation", 20)
	content.add_child(b_actions)
	var atk_b := UiKit.button("Attacco", Color(1.0, 0.5, 0.4), 40)
	atk_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	atk_b.pressed.connect(_player_act.bind("attack"))
	b_actions.add_child(atk_b)
	btn_super = UiKit.button("", Color(1.0, 0.8, 0.2), 40)
	btn_super.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_super.pressed.connect(_player_act.bind("super"))
	b_actions.add_child(btn_super)
	btn_heal = UiKit.button("", ACCENT, 40)
	btn_heal.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_heal.pressed.connect(_player_act.bind("heal"))
	b_actions.add_child(btn_heal)
	_update_battle_ui()


func _update_battle_ui() -> void:
	p_bar.max_value = bp["max"]
	p_bar.value = bp["hp"]
	e_bar.max_value = be["max"]
	e_bar.value = be["hp"]
	btn_super.text = "SUPER" if b_cd == 0 else "Super (%d)" % b_cd
	btn_heal.text = "Cura (%d)" % b_heals


func _player_act(kind: String) -> void:
	if b_busy or b_over:
		return
	var token := b_id
	var atk: int = bp["atk"]
	var dmg := 0
	if kind == "super":
		if b_cd > 0:
			return
		dmg = roundi(atk * 2.2 * randf_range(0.9, 1.1))
		b_cd = 3
		b_log.text = "%s usa SUPER! %d danni!" % [bp["name"], dmg]
	elif kind == "heal":
		if b_heals <= 0:
			return
		b_heals -= 1
		var h := int(float(bp["max"]) * 0.3)
		bp["hp"] = mini(int(bp["max"]), int(bp["hp"]) + h)
		b_log.text = "%s si cura di %d PV." % [bp["name"], h]
	else:
		dmg = roundi(atk * randf_range(0.85, 1.15))
		b_log.text = "%s attacca: %d danni!" % [bp["name"], dmg]
	if kind != "super":
		b_cd = maxi(b_cd - 1, 0)
	b_busy = true
	if dmg > 0:
		be["hp"] = maxi(0, int(be["hp"]) - dmg)
		e_view.hurt = 1.0
		p_view.bump = 1.0
		_play_freq(float(MonsterData.SPECIES[int(bp["sp"])]["freq"]))
	else:
		p_view.bump = 0.6
		_play_freq(660.0)
	_update_battle_ui()
	if int(be["hp"]) <= 0:
		_end_battle(true)
		return
	await get_tree().create_timer(0.9).timeout
	if token != b_id or not is_inside_tree():
		return
	_enemy_act()
	if int(bp["hp"]) <= 0:
		_end_battle(false)
		return
	b_busy = false


func _enemy_act() -> void:
	var atk: int = be["atk"]
	var strong := randf() < 0.25
	var dmg := roundi(atk * (1.6 if strong else 1.0) * randf_range(0.85, 1.15))
	bp["hp"] = maxi(0, int(bp["hp"]) - dmg)
	p_view.hurt = 1.0
	e_view.bump = 1.0
	_play_freq(float(MonsterData.SPECIES[int(be["sp"])]["freq"]) * 0.5)
	b_log.text = "%s %s: %d danni!" % [be["name"], "sferra un attacco potente" if strong else "attacca", dmg]
	_update_battle_ui()


func _end_battle(won: bool) -> void:
	b_over = true
	b_busy = false
	for c in b_actions.get_children():
		b_actions.remove_child(c)
		c.queue_free()
	if won:
		var reward := 25 + MonsterData.stage * 12
		MonsterData.coins += reward
		MonsterData.stage += 1
		MonsterData.save()
		_refresh_coins()
		b_log.text = "VITTORIA! +%d monete" % reward
		var nxt := UiKit.button("Prossimo livello", ACCENT, 40)
		nxt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nxt.pressed.connect(_tab.bind("battle"))
		b_actions.add_child(nxt)
	else:
		b_log.text = "Sconfitta... potenzia i tuoi mostri e riprova!"
		var again := UiKit.button("Riprova", Color(1.0, 0.5, 0.4), 40)
		again.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		again.pressed.connect(_tab.bind("battle"))
		b_actions.add_child(again)
	var team := UiKit.button("Squadra", Color(0.5, 0.8, 1.0), 40)
	team.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	team.pressed.connect(_tab.bind("team"))
	b_actions.add_child(team)
