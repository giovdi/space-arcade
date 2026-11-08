class_name MonsterData
extends RefCounted
## Dati e salvataggio dei Mostri Cosmici (stato statico condiviso tra le schermate).

const MAX_SLOTS := 12
const MAX_LV := 10
const SAVE_PATH := "user://monsters.cfg"

const SPECIES: Array[Dictionary] = [
	{"name": "Lumo", "color": Color(0.4, 0.85, 0.4), "cost": 0, "hp": 40, "atk": 6, "inc": 1.0, "freq": 261.63},
	{"name": "Cornix", "color": Color(1.0, 0.6, 0.2), "cost": 50, "hp": 55, "atk": 8, "inc": 2.0, "freq": 329.63},
	{"name": "Spikon", "color": Color(0.65, 0.4, 0.95), "cost": 150, "hp": 50, "atk": 12, "inc": 3.0, "freq": 392.0},
	{"name": "Ciclope", "color": Color(0.3, 0.6, 1.0), "cost": 300, "hp": 80, "atk": 10, "inc": 5.0, "freq": 440.0},
	{"name": "Nebulo", "color": Color(1.0, 0.45, 0.75), "cost": 600, "hp": 70, "atk": 16, "inc": 8.0, "freq": 523.25},
	{"name": "Draco Stellare", "color": Color(1.0, 0.82, 0.25), "cost": 1500, "hp": 120, "atk": 22, "inc": 15.0, "freq": 659.25},
	{"name": "Gelato", "color": Color(0.55, 0.9, 1.0), "cost": 2500, "hp": 100, "atk": 20, "inc": 22.0, "freq": 293.66},
	{"name": "Fungo", "color": Color(0.9, 0.3, 0.3), "cost": 4000, "hp": 110, "atk": 24, "inc": 30.0, "freq": 349.23},
	{"name": "Fantasmino", "color": Color(0.85, 0.88, 1.0), "cost": 6500, "hp": 90, "atk": 30, "inc": 42.0, "freq": 493.88},
	{"name": "Robo-Luna", "color": Color(0.6, 0.65, 0.72), "cost": 10000, "hp": 170, "atk": 28, "inc": 58.0, "freq": 587.33},
	{"name": "Vulcano", "color": Color(0.75, 0.25, 0.15), "cost": 16000, "hp": 160, "atk": 38, "inc": 80.0, "freq": 698.46},
	{"name": "Re Galassia", "color": Color(0.5, 0.3, 0.85), "cost": 25000, "hp": 230, "atk": 44, "inc": 120.0, "freq": 783.99},
	# Note diesis (tasti neri): la nota è in "freq", il costo li mette in mezzo agli altri nel negozio.
	{"name": "Bubbo", "color": Color(0.3, 0.9, 0.8), "cost": 800, "hp": 75, "atk": 14, "inc": 10.0, "freq": 277.18},
	{"name": "Pulsar", "color": Color(0.95, 0.95, 0.5), "cost": 2000, "hp": 105, "atk": 21, "inc": 18.0, "freq": 311.13},
	{"name": "Cometa", "color": Color(0.4, 0.4, 0.95), "cost": 5000, "hp": 105, "atk": 27, "inc": 36.0, "freq": 369.99},
	{"name": "Orbitus", "color": Color(1.0, 0.4, 0.5), "cost": 12000, "hp": 150, "atk": 33, "inc": 68.0, "freq": 415.30},
	{"name": "Tentacolo", "color": Color(0.7, 0.95, 0.2), "cost": 20000, "hp": 190, "atk": 41, "inc": 100.0, "freq": 466.16},
]

static var coins := 30
static var stage := 1
static var monsters: Array = []
static var loaded := false


static func mult(lv: int) -> float:
	return 1.0 + 0.25 * (lv - 1)


static func max_hp(sp: int, lv: int) -> int:
	return int(float(SPECIES[sp]["hp"]) * mult(lv))


static func atk(sp: int, lv: int) -> int:
	return int(float(SPECIES[sp]["atk"]) * mult(lv))


static func income(sp: int, lv: int) -> float:
	return float(SPECIES[sp]["inc"]) * mult(lv)


static func stock_cap(sp: int, lv: int) -> float:
	return maxf(income(sp, lv) * 120.0, 10.0)


static func upgrade_cost(sp: int, lv: int) -> int:
	return int(maxf(float(SPECIES[sp]["cost"]), 40.0) * 0.5 * lv)


static func ensure_loaded() -> void:
	if loaded:
		return
	loaded = true
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) == OK:
		coins = int(cf.get_value("p", "coins", 30))
		stage = int(cf.get_value("p", "stage", 1))
		monsters = cf.get_value("p", "monsters", [])
		var last := int(cf.get_value("p", "last", 0))
		if last > 0:
			var elapsed := clampf(Time.get_unix_time_from_system() - last, 0.0, 28800.0)
			for m in monsters:
				var sp: int = m["sp"]
				var lv: int = m["lv"]
				m["stock"] = minf(float(m["stock"]) + income(sp, lv) * elapsed, stock_cap(sp, lv))
	if monsters.is_empty():
		monsters = [{"sp": 0, "lv": 1, "stock": 0.0}]


static func save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("p", "coins", coins)
	cf.set_value("p", "stage", stage)
	cf.set_value("p", "monsters", monsters)
	cf.set_value("p", "last", int(Time.get_unix_time_from_system()))
	cf.save(SAVE_PATH)
