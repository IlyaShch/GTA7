extends Node2D

@onready var horse = $Horse
@onready var horse_info_panel = $UI/HorseInfoPanel

var horse_button: TextureButton
var is_revealing: bool = false

func _ready():
	
	
	var background = TextureRect.new()

	background.texture = load("res://assets/backgrounds/Stable.png")

	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE

	add_child(background)

	
	horse_button = TextureButton.new()

	# Set the button's image
	horse_button.texture_normal = load("res://assets/sprites/Horses/Mystery Horse.png")
	horse_button.texture_hover = load("res://assets/sprites/Horses/MysteryHorseOutline.png")

	# Position it in the stable
	horse_button.position = Vector2(400, 300)

	# Make the 32x32 pixel art appear at 128x128
	horse_button.scale = Vector2(6, 6)

	# Connect the click
	horse_button.pressed.connect(_on_horse_pressed)

	# Add it to the scene
	add_child(horse_button)
	
	
func _on_horse_pressed():
	if is_revealing:
		return
	is_revealing = true
	_play_reveal_animation()


func _play_reveal_animation():
	var start_pos = horse_button.position
	var float_height = 30.0

	# Beams of colorful light shooting up from underneath the horse
	var beam_colors = [Color(1, 0.3, 0.3), Color(0.3, 1, 0.4), Color(0.3, 0.6, 1), Color(1, 0.9, 0.2), Color(0.8, 0.3, 1)]
	var beams: Array[ColorRect] = []
	var beam_count = beam_colors.size()

	for i in range(beam_count):
		var beam = ColorRect.new()
		beam.color = beam_colors[i]
		beam.size = Vector2(6, 0)
		beam.pivot_offset = Vector2(3, 0)
		var offset_x = (i - (beam_count - 1) / 2.0) * 14.0
		beam.position = start_pos + Vector2(offset_x - 3, 10)
		beam.modulate.a = 0.0
		beam.z_index = -1
		add_child(beam)
		beams.append(beam)

	# Float the horse upward while the beams grow and glow beneath it
	var rise_tween = create_tween()
	rise_tween.set_parallel(true)
	rise_tween.tween_property(horse_button, "position:y", start_pos.y - float_height, 1.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)

	for beam in beams:
		var beam_tween = create_tween()
		beam_tween.set_parallel(true)
		beam_tween.tween_property(beam, "modulate:a", 0.85, 0.3)
		beam_tween.tween_property(beam, "size:y", 80.0, 1.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	await rise_tween.finished

	# Flash and resolve into the revealed Stable Horse texture
	var flash_tween = create_tween()
	flash_tween.tween_property(horse_button, "modulate", Color(2, 2, 2), 0.15)
	await flash_tween.finished

	horse_button.texture_normal = load("res://assets/sprites/Horses/StableHorse.png")
	horse_button.texture_hover = load("res://assets/sprites/Horses/StableHorseOutline.png")

	var settle_tween = create_tween()
	settle_tween.set_parallel(true)
	settle_tween.tween_property(horse_button, "modulate", Color(1, 1, 1), 0.3)
	settle_tween.tween_property(horse_button, "position:y", start_pos.y, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE)

	# Fade out the light beams as the horse settles
	for beam in beams:
		var fade_tween = create_tween()
		fade_tween.tween_property(beam, "modulate:a", 0.0, 0.5)
		fade_tween.tween_callback(beam.queue_free)

	await settle_tween.finished
	is_revealing = false
