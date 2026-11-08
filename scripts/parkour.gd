extends Node3D
## Parkour 3D spaziale: corsa infinita su piattaforme a 3 corsie.
## Comandi touch: scorri sinistra/destra = cambia corsia, su = salta (o tocca), giù = scivola.
## Tastiera (per provare su PC): frecce o WASD / Spazio.

enum State { READY, PLAY, OVER }

const LANE_W := 3.0
const SEG := 6.0
const AHEAD := 22
const GRAVITY := 28.0
const JUMP_V := 10.0
const SAVE_PATH := "user://parkour.cfg"

## Modalità: velocità iniziale/massima, accelerazione per metro, moltiplicatore punti
## e pesi di generazione dei tratti di percorso.
const MODES := {
	"facile": {
		"name": "FACILE", "color": Color(0.4, 1.0, 0.5), "start": 10.0, "max": 18.0, "accel": 0.006, "mult": 1,
		"w": {"plain": 40, "block": 20, "low": 20, "beam": 10, "gap": 5, "partial": 5},
	},
	"medio": {
		"name": "MEDIO", "color": Color(0.3, 0.9, 1.0), "start": 12.0, "max": 26.0, "accel": 0.012, "mult": 2,
		"w": {"plain": 22, "block": 25, "low": 20, "beam": 15, "gap": 10, "partial": 8},
	},
	"difficile": {
		"name": "DIFFICILE", "color": Color(1.0, 0.7, 0.2), "start": 16.0, "max": 32.0, "accel": 0.016, "mult": 3,
		"w": {"plain": 8, "block": 28, "low": 20, "beam": 20, "gap": 14, "partial": 10},
	},
	"impossibile": {
		"name": "IMPOSSIBILE", "color": Color(1.0, 0.25, 0.3), "start": 22.0, "max": 42.0, "accel": 0.03, "mult": 5,
		"w": {"plain": 0, "block": 30, "low": 22, "beam": 22, "gap": 14, "partial": 12},
	},
}

## Colori base dei blocchi in stile voxel (texture 16x16 generate in codice).
const BLOCKS := {
	"grass": Color(0.35, 0.65, 0.22),
	"dirt": Color(0.47, 0.32, 0.2),
	"obsidian": Color(0.12, 0.06, 0.22),
	"lava": Color(1.0, 0.45, 0.1),
	"planks": Color(0.68, 0.52, 0.3),
	"endstone": Color(0.85, 0.85, 0.58),
}

var state := State.READY
var mode := "medio"
var mode_chosen := false
var mode_panel: VBoxContainer
var pos := Vector3.ZERO
var vy := 0.0
var grounded := true
var coyote := 0.0
var jump_buf := 0.0
var slide_t := 0.0
var lane := 0
var speed := 12.0
var coins := 0
var best := 0

var segs: Dictionary = {}
var next_seg := 0
var last_kind := "plain"
var mat_cache: Dictionary = {}

var player: Node3D
var body: Node3D
var arm_l: Node3D
var arm_r: Node3D
var leg_l: Node3D
var leg_r: Node3D
var run_t := 0.0
var cam: Camera3D
var sky: Node3D
var planet: MeshInstance3D

var hud: Label
var hint: Label
var over_panel: PanelContainer
var over_score: Label
var over_best: Label

var _press := Vector2.ZERO
var _swipe_active := false


func _ready() -> void:
	_build_world()
	_build_player()
	_build_ui()
	_load_best()
	while next_seg < AHEAD:
		_spawn_segment()
	_update_camera(1.0)


# ------------------------------------------------------------ costruzione

func _mat(color: Color, glow := 0.0) -> StandardMaterial3D:
	var key := Vector4(color.r, color.g, color.b, glow)
	if mat_cache.has(key):
		return mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = glow
	mat_cache[key] = m
	return m


func _box(parent: Node3D, size: Vector3, p: Vector3, color: Color, glow := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(color, glow)
	mi.position = p
	parent.add_child(mi)
	return mi


func _bmat(key: String, glow := 0.0) -> StandardMaterial3D:
	var ck := "b_" + key
	if mat_cache.has(ck):
		return mat_cache[ck]
	var base: Color = BLOCKS[key]
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = key.hash()
	for y in 16:
		for x in 16:
			var k := 1.0 + rng.randf_range(-0.14, 0.14)
			var c := Color(base.r * k, base.g * k, base.b * k)
			if x == 0 or y == 0:
				c = c.darkened(0.25)
			img.set_pixel(x, y, c)
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = base
		m.emission_energy_multiplier = glow
	mat_cache[ck] = m
	return m


func _block(parent: Node3D, size: Vector3, p: Vector3, key: String, glow := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _bmat(key, glow)
	mi.position = p
	parent.add_child(mi)
	return mi


func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.01, 0.01, 0.05)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.55, 0.9)
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_energy = 1.1
	add_child(sun)

	cam = Camera3D.new()
	cam.fov = 70
	cam.far = 600
	add_child(cam)

	# Stelle: un MultiMesh che segue il giocatore.
	sky = Node3D.new()
	add_child(sky)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var star := BoxMesh.new()
	star.size = Vector3(0.8, 0.8, 0.8)
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	star.material = sm
	mm.mesh = star
	mm.instance_count = 220
	for i in mm.instance_count:
		var dir := Vector3(randf_range(-1, 1), randf_range(-0.2, 1), randf_range(-1, 1)).normalized()
		mm.set_instance_transform(i, Transform3D(Basis(), dir * randf_range(180.0, 260.0)))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	sky.add_child(mmi)

	planet = MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(90, 90, 90)
	planet.mesh = pm
	planet.material_override = _mat(Color(0.15, 0.45, 0.8), 0.6)
	planet.rotation_degrees = Vector3(20, 35, 0)
	add_child(planet)


func _build_player() -> void:
	player = Node3D.new()
	add_child(player)
	body = Node3D.new()
	player.add_child(body)
	var skin := Color(0.85, 0.65, 0.5)
	# Personaggio squadrato: gambe 0.6 + torso 0.75 + testa 0.45 = 1.8.
	_box(body, Vector3(0.5, 0.75, 0.3), Vector3(0, 0.975, 0), Color(0.15, 0.7, 0.8))
	_box(body, Vector3(0.45, 0.45, 0.45), Vector3(0, 1.575, 0), skin)
	_box(body, Vector3(0.47, 0.12, 0.47), Vector3(0, 1.74, 0), Color(0.3, 0.2, 0.1))
	_box(body, Vector3(0.1, 0.08, 0.04), Vector3(-0.1, 1.58, -0.23), Color(0.1, 0.1, 0.3))
	_box(body, Vector3(0.1, 0.08, 0.04), Vector3(0.1, 1.58, -0.23), Color(0.1, 0.1, 0.3))
	_box(body, Vector3(0.4, 0.4, 0.2), Vector3(0, 1.0, 0.25), Color(0.5, 0.55, 0.7))  # zaino
	arm_l = _limb(Vector3(-0.38, 1.35, 0), Vector3(0.25, 0.7, 0.25), skin)
	arm_r = _limb(Vector3(0.38, 1.35, 0), Vector3(0.25, 0.7, 0.25), skin)
	leg_l = _limb(Vector3(-0.13, 0.6, 0), Vector3(0.24, 0.6, 0.26), Color(0.2, 0.25, 0.7))
	leg_r = _limb(Vector3(0.13, 0.6, 0), Vector3(0.24, 0.6, 0.26), Color(0.2, 0.25, 0.7))


func _limb(joint: Vector3, size: Vector3, color: Color) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = joint
	body.add_child(pivot)
	_box(pivot, size, Vector3(0, -size.y * 0.5, 0), color)
	return pivot


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var ui := Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)

	hud = UiKit.label("", 48, Color(0.8, 0.95, 1.0))
	hud.position = Vector2(40, 30)
	ui.add_child(hud)

	hint = UiKit.label("Scorri ← → per cambiare corsia\nScorri su per saltare, giù per scivolare\n\nTocca per iniziare", 44, Color(1, 0.95, 0.6))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hint.grow_vertical = Control.GROW_DIRECTION_BOTH
	hint.visible = false
	ui.add_child(hint)

	mode_panel = VBoxContainer.new()
	mode_panel.add_theme_constant_override("separation", 22)
	mode_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	mode_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	mode_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	ui.add_child(mode_panel)
	var mt := UiKit.label("SCEGLI LA DIFFICOLTÀ", 60, Color(0.8, 0.95, 1.0))
	mt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mode_panel.add_child(mt)
	for id in MODES.keys():
		var md: Dictionary = MODES[id]
		var mb := UiKit.button("%s   (punti x%d)" % [md["name"], md["mult"]], md["color"], 44)
		mb.custom_minimum_size = Vector2(620, 0)
		mb.pressed.connect(_choose_mode.bind(id))
		mode_panel.add_child(mb)

	var back := UiKit.button("Hub", Color(1.0, 0.5, 0.6), 34)
	back.anchor_left = 1.0
	back.anchor_right = 1.0
	back.offset_left = -200
	back.offset_right = -30
	back.offset_top = 30
	back.offset_bottom = 100
	back.pressed.connect(func() -> void: Game.open("hub"))
	ui.add_child(back)

	over_panel = PanelContainer.new()
	over_panel.add_theme_stylebox_override("panel", UiKit.box(Color(1.0, 0.35, 0.8), 0.95))
	over_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	over_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	over_panel.visible = false
	ui.add_child(over_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 20)
	over_panel.add_child(vb)
	var t := UiKit.label("MISSIONE FALLITA", 64, Color(1.0, 0.5, 0.85))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)
	over_score = UiKit.label("", 44)
	over_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(over_score)
	over_best = UiKit.label("", 36, Color(0.7, 0.8, 1.0))
	over_best.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(over_best)
	var retry := UiKit.button("Riprova", Color(0.4, 1.0, 0.5))
	retry.custom_minimum_size = Vector2(520, 0)
	retry.pressed.connect(func() -> void: get_tree().reload_current_scene())
	vb.add_child(retry)
	var hub_btn := UiKit.button("Torna all'hub", Color(1.0, 0.5, 0.6))
	hub_btn.pressed.connect(func() -> void: Game.open("hub"))
	vb.add_child(hub_btn)


# ------------------------------------------------------------ generazione

func _spawn_segment() -> void:
	var i := next_seg
	next_seg += 1
	var zc := -(i + 0.5) * SEG
	var node := Node3D.new()
	add_child(node)

	var kind := "plain"
	if i >= 3 and last_kind != "gap" and last_kind != "partial":
		kind = _pick_kind()
	last_kind = kind

	var mask: Array[bool] = [true, true, true]
	if kind == "gap":
		mask = [false, false, false]
	elif kind == "partial":
		mask[randi() % 3] = false

	var obs: Array = []
	var coin_list: Array = []
	var seg := {"mask": mask, "node": node, "obs": obs, "coins": coin_list}
	segs[i] = seg

	for l in 3:
		if mask[l]:
			var x := (l - 1) * LANE_W
			_block(node, Vector3(LANE_W - 0.05, 0.25, SEG), Vector3(x, -0.125, zc), "grass")
			_block(node, Vector3(LANE_W - 0.05, 0.75, SEG), Vector3(x, -0.625, zc), "dirt")

	var free_lane := randi() % 3 - 1
	if kind == "block":
		var count := 2 if mode == "impossibile" else 1 + randi() % 2
		var lanes := [-1, 0, 1]
		lanes.shuffle()
		for k in count:
			var bl: int = lanes[k]
			_add_obstacle(seg, "block", bl, zc)
		free_lane = lanes[2]
	elif kind == "low" or kind == "beam":
		for bl in [-1, 0, 1]:
			_add_obstacle(seg, kind, bl, zc)

	if kind == "plain" and i >= 2:
		for dz in [-2.0, 0.0, 2.0]:
			_add_coin(seg, free_lane, zc + dz, 1.0)
	elif kind == "block":
		for dz in [-1.5, 1.5]:
			_add_coin(seg, free_lane, zc + dz, 1.0)
	elif kind == "gap":
		for k in 3:
			var h := 1.2 + 1.2 * sin(PI * (k + 1) / 4.0)
			_add_coin(seg, free_lane, zc + (k - 1) * 2.0, h)

	if randf() < 0.5:
		# Isole fluttuanti di blocchi (pietra dell'End).
		var sgn := 1.0 if randf() < 0.5 else -1.0
		var sz := Vector3(randi_range(2, 6), randi_range(1, 3), randi_range(2, 6))
		var ip := Vector3(sgn * randi_range(9, 30), randi_range(-3, 9), roundf(zc) + randi_range(-3, 3))
		_block(node, sz, ip, "endstone")


func _pick_kind() -> String:
	var w: Dictionary = MODES[mode]["w"]
	var total := 0.0
	for k in w:
		total += float(w[k])
	var r := randf() * total
	for k in w:
		r -= float(w[k])
		if r <= 0.0:
			return k
	return "plain"


func _choose_mode(id: String) -> void:
	mode = id
	mode_chosen = true
	mode_panel.visible = false
	hint.visible = true
	# Rigenera il percorso con i pesi della modalità scelta.
	for k in segs.keys():
		segs[k]["node"].queue_free()
	segs.clear()
	next_seg = 0
	last_kind = "plain"
	while next_seg < AHEAD:
		_spawn_segment()
	_load_best()


func _add_obstacle(seg: Dictionary, type: String, l: int, zc: float) -> void:
	var node: Node3D = seg["node"]
	var x := l * LANE_W
	var hd := 0.5
	if type == "block":  # pilastro di ossidiana alto 2 blocchi: va schivato
		_block(node, Vector3(2.0, 2.0, 1.0), Vector3(x, 1.0, zc), "obsidian")
	elif type == "low":  # blocco di lava: va saltato
		_block(node, Vector3(2.0, 1.0, 1.0), Vector3(x, 0.5, zc), "lava", 0.8)
	else:  # blocco di assi sospeso: ci si scivola sotto
		_block(node, Vector3(2.0, 1.0, 1.0), Vector3(x, 1.5, zc), "planks")
	seg["obs"].append({"type": type, "lane": l, "z": zc, "hd": hd, "hw": 1.0})


func _add_coin(seg: Dictionary, l: int, z: float, y: float) -> void:
	var holder := Node3D.new()
	holder.position = Vector3(l * LANE_W, y, z)
	_box(holder, Vector3(0.45, 0.45, 0.45), Vector3.ZERO, Color(1.0, 0.85, 0.2), 2.0)  # cubo d'oro
	var node: Node3D = seg["node"]
	node.add_child(holder)
	seg["coins"].append({"node": holder, "lane": l, "z": z, "y": y, "taken": false})


# ------------------------------------------------------------ input

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		match e.keycode:
			KEY_LEFT, KEY_A:
				_cmd("left")
			KEY_RIGHT, KEY_D:
				_cmd("right")
			KEY_UP, KEY_W, KEY_SPACE:
				_cmd("jump")
			KEY_DOWN, KEY_S:
				_cmd("slide")
	elif e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_press = e.position
			_swipe_active = true
		else:
			if _swipe_active:
				_cmd("jump")
			_swipe_active = false
	elif e is InputEventMouseMotion and _swipe_active:
		var d: Vector2 = e.position - _press
		if d.length() > 70.0:
			_swipe_active = false
			if absf(d.x) > absf(d.y):
				_cmd("right" if d.x > 0 else "left")
			else:
				_cmd("jump" if d.y < 0 else "slide")


func _cmd(c: String) -> void:
	if state == State.OVER:
		return
	if state == State.READY:
		if not mode_chosen:
			return
		state = State.PLAY
		hint.visible = false
	if c == "left":
		lane = maxi(lane - 1, -1)
	elif c == "right":
		lane = mini(lane + 1, 1)
	elif c == "jump":
		jump_buf = 0.15
	elif c == "slide":
		slide_t = 0.7
		if not grounded and vy > -20.0:
			vy = -20.0


# ------------------------------------------------------------ gioco

func _cur_seg() -> int:
	return maxi(0, int(floorf(-pos.z / SEG)))


func _ground_at(x: float, z: float) -> bool:
	var i := maxi(0, int(floorf(-z / SEG)))
	if not segs.has(i):
		return true
	var li := clampi(roundi(x / LANE_W) + 1, 0, 2)
	return segs[i]["mask"][li]


func _physics_process(delta: float) -> void:
	if state != State.PLAY:
		return
	var md: Dictionary = MODES[mode]
	speed = minf(float(md["start"]) + (-pos.z) * float(md["accel"]), float(md["max"]))
	pos.z -= speed * delta
	pos.x = move_toward(pos.x, lane * LANE_W, 18.0 * delta)

	jump_buf = maxf(jump_buf - delta, 0.0)
	if jump_buf > 0.0 and (grounded or coyote > 0.0):
		vy = JUMP_V
		grounded = false
		coyote = 0.0
		jump_buf = 0.0
		slide_t = 0.0

	var prev_y := pos.y
	vy -= GRAVITY * delta
	pos.y += vy * delta
	if pos.y <= 0.0 and vy <= 0.0 and _ground_at(pos.x, pos.z) and prev_y >= -0.25:
		pos.y = 0.0
		vy = 0.0
		grounded = true
		coyote = 0.1
	else:
		grounded = false
		coyote = maxf(coyote - delta, 0.0)
	slide_t = maxf(slide_t - delta, 0.0)

	if pos.y < -7.0 or _hit_obstacle():
		_game_over()
		return
	_collect_coins()

	var ci := _cur_seg()
	while next_seg < ci + AHEAD:
		_spawn_segment()
	for k in segs.keys():
		if k < ci - 3:
			segs[k]["node"].queue_free()
			segs.erase(k)

	var dist := int(-pos.z)
	hud.text = "%s   %d m    Monete: %d" % [md["name"], dist, coins]
	_update_player(delta)


func _hit_obstacle() -> bool:
	var ci := _cur_seg()
	var sliding := slide_t > 0.0 and grounded
	for i in range(maxi(0, ci - 1), ci + 2):
		if not segs.has(i):
			continue
		for o in segs[i]["obs"]:
			if absf(pos.z - o["z"]) > o["hd"] + 0.3:
				continue
			if absf(pos.x - o["lane"] * LANE_W) > o["hw"] + 0.35:
				continue
			var t: String = o["type"]
			if t == "block" and pos.y < 2.0:
				return true
			if t == "low" and pos.y < 1.0:
				return true
			if t == "beam" and not sliding and pos.y < 2.0:
				return true
	return false


func _collect_coins() -> void:
	var ci := _cur_seg()
	for i in range(maxi(0, ci - 1), ci + 2):
		if not segs.has(i):
			continue
		for c in segs[i]["coins"]:
			if c["taken"]:
				continue
			if absf(pos.z - c["z"]) < 0.9 and absf(pos.x - c["lane"] * LANE_W) < 1.0 \
					and absf(pos.y + 0.9 - c["y"]) < 1.3:
				c["taken"] = true
				c["node"].visible = false
				coins += 1


func _process(delta: float) -> void:
	var ci := _cur_seg()
	for i in range(ci, ci + 8):
		if segs.has(i):
			for c in segs[i]["coins"]:
				if not c["taken"]:
					c["node"].rotate_y(3.0 * delta)
	sky.position = Vector3(pos.x, 0, pos.z)
	planet.position = Vector3(-110, 50, pos.z - 420)


func _update_player(delta: float) -> void:
	player.position = pos
	var sliding := slide_t > 0.0 and grounded
	body.scale.y = lerpf(body.scale.y, 0.45 if sliding else 1.0, 20.0 * delta)
	body.rotation.z = (pos.x - lane * LANE_W) * 0.12
	run_t += delta * speed * 0.9
	var swing := sin(run_t) * 0.9 if grounded else 0.0
	if not grounded:
		arm_l.rotation.x = -2.6
		arm_r.rotation.x = -2.6
		leg_l.rotation.x = 0.5
		leg_r.rotation.x = -0.5
	else:
		arm_l.rotation.x = swing
		arm_r.rotation.x = -swing
		leg_l.rotation.x = -swing
		leg_r.rotation.x = swing
	_update_camera(delta)


func _update_camera(delta: float) -> void:
	var cx := lerpf(cam.position.x, pos.x * 0.6, minf(6.0 * delta, 1.0))
	cam.position = Vector3(cx, 4.2 + maxf(pos.y, 0.0) * 0.3, pos.z + 7.5)
	cam.look_at(Vector3(cx * 0.7, 1.0, pos.z - 10.0), Vector3.UP)


func _game_over() -> void:
	state = State.OVER
	var mult: int = MODES[mode]["mult"]
	var score := (int(-pos.z) + coins * 10) * mult
	if score > best:
		best = score
		_save_best()
	over_score.text = "Distanza %d m  +  Monete %d  (x%d)  =  %d punti" % [int(-pos.z), coins, mult, score]
	over_best.text = "Record %s: %d" % [MODES[mode]["name"], best]
	over_panel.visible = true
	over_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)


func _load_best() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) == OK:
		best = cf.get_value("best", mode, 0)
	else:
		best = 0


func _save_best() -> void:
	var cf := ConfigFile.new()
	cf.load(SAVE_PATH)
	cf.set_value("best", mode, best)
	cf.save(SAVE_PATH)
