extends Node2D

@onready var horse = $Horse
@onready var horse_info_panel = $UI/HorseInfoPanel

func _ready():
	var horse_button = TextureButton.new()

	# Set the button's image
	horse_button.texture_normal = load("res://assets/sprites/Horses/Mystery Horse.png")
	horse_button.texture_hover = load("res://assets/sprites/Horses/MysteryHorseOutline.png")

	# Position it in the stable
	horse_button.position = Vector2(200, 150)

	# Make the 32x32 pixel art appear at 128x128
	horse_button.scale = Vector2(6, 6)

	# Connect the click
	horse_button.pressed.connect(_on_horse_pressed)

	# Add it to the scene
	add_child(horse_button)
	
	
func _on_horse_pressed():
	print("THEY FUCKING CLICKED ME~!!!!")
