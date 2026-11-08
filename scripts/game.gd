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


func open(id: String) -> void:
	if not SCREENS.has(id):
		return
	current = id
	get_tree().change_scene_to_file(SCREENS[id])


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if current == "hub":
			get_tree().quit()
		else:
			open("hub")
