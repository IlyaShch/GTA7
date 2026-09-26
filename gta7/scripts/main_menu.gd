extends Control

signal open_stable

func _ready():
	var label = Label.new()
	label.text = "My Horse Game"
	label.position = Vector2(100, 100)
	add_child(label)
	var stableButton = Button.new()
	stableButton.text = "Enter The Stable"
	stableButton.position =Vector2(100, 200)
	stableButton.pressed.connect(_on_stable_button_pressed)	

	add_child(stableButton)
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass



func _on_stable_button_pressed():
	print("button pressed")
	open_stable.emit()
