extends Node
## Autoload "Game": gestisce il cambio di schermata e il tasto Indietro di Android.

const SCREENS := {
	"hub": "res://scenes/hub.tscn",
	"chess": "res://scenes/chess.tscn",
	"parkour": "res://scenes/parkour.tscn",
	"monsters": "res://scenes/monsters.tscn",
	"crossword": "res://scenes/crossword.tscn",
}

var current := "hub"


func _ready() -> void:
	_save_power("hub")


## Risparmio batteria: sulle schermate 2D si disegna solo quando qualcosa cambia e a 30 fps al massimo;
## solo il parkour 3D gira a 60.
func _save_power(id: String) -> void:
	OS.low_processor_usage_mode = true
	if id == "parkour":
		Engine.max_fps = 60
		OS.low_processor_usage_mode_sleep_usec = 16600
	else:
		Engine.max_fps = 30
		OS.low_processor_usage_mode_sleep_usec = 33000


func open(id: String) -> void:
	if not SCREENS.has(id):
		return
	current = id
	_save_power(id)
	get_tree().change_scene_to_file(SCREENS[id])


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if current == "hub":
			get_tree().quit()
		else:
			open("hub")
