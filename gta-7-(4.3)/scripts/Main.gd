extends Node

var current_scene: Node
signal open_stable


func _ready():
	show_scene("MainMenu")

func show_scene(scene_name: String):
	print("Loading scene: ", scene_name)

	if current_scene:
		current_scene.queue_free()

	var scene = load("res://scenes/" + scene_name + ".tscn")
	current_scene = scene.instantiate()
	$SceneContainer.add_child(current_scene)
	if scene_name == "MainMenu":
		print("Connecting MainMenu signal")
		current_scene.open_stable.connect(_on_open_stable)
	elif scene_name == "Stable":
		print("Connecting Stable signal")
		current_scene.start_chase.connect(_on_start_chase)
		
func _on_open_stable():
	print("Main received open_stable!")
	show_scene("Stable")

func _on_start_chase():
	print("Main received start_chase!")
	show_scene("Chase")
