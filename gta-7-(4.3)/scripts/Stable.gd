extends Node2D

signal start_chase

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

	# A ring of large light beams that orbits around the horse's base
	var beam_ring = Node2D.new()
	beam_ring.position = start_pos + Vector2(0, 20)
	add_child(beam_ring)
	move_child(beam_ring, horse_button.get_index())

	var beam_colors = [Color(1, 0.3, 0.3), Color(0.3, 1, 0.4), Color(0.3, 0.6, 1), Color(1, 0.9, 0.2), Color(0.8, 0.3, 1), Color(1, 0.5, 0.1), Color(0.4, 0.9, 0.9), Color(1, 0.3, 0.8)]
	var beams: Array[ColorRect] = []
	var beam_count = beam_colors.size()
	var beam_width = 16.0
	var beam_height = 160.0
	var radius_x = 90.0
	var radius_y = 30.0

	for i in range(beam_count):
		var angle = (float(i) / beam_count) * TAU
		var beam = ColorRect.new()
		beam.color = beam_colors[i]
		beam.size = Vector2(beam_width, beam_height)
		# Pivot at the bottom so scaling grows the beam upward from its spot on the ring
		beam.pivot_offset = Vector2(beam_width / 2.0, beam_height)
		beam.position = Vector2(cos(angle) * radius_x - beam_width / 2.0, sin(angle) * radius_y - beam_height)
		beam.scale = Vector2(1, 0)
		beam.modulate.a = 0.0
		beam_ring.add_child(beam)
		beams.append(beam)

	# Float the horse upward while the beam ring grows and slowly spins beneath it
	var rise_tween = create_tween()
	rise_tween.set_parallel(true)
	rise_tween.tween_property(horse_button, "position:y", start_pos.y - float_height, 1.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	rise_tween.tween_property(beam_ring, "rotation", TAU, 2.4).set_trans(Tween.TRANS_LINEAR)

	for beam in beams:
		var beam_tween = create_tween()
		beam_tween.set_parallel(true)
		beam_tween.tween_property(beam, "modulate:a", 0.85, 0.3)
		beam_tween.tween_property(beam, "scale:y", 1.0, 1.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	await rise_tween.finished

	# Flash and resolve into the revealed Stable Horse texture
	var flash_tween = create_tween()
	flash_tween.tween_property(horse_button, "modulate", Color(2, 2, 2), 0.15)
	await flash_tween.finished

	horse_button.texture_normal = load("res://assets/sprites/Horses/pixil-layer-Giraffe.png")
	horse_button.texture_hover = load("res://assets/sprites/Horses/pixil-layer-Giraffe Outline.png")

	var settle_tween = create_tween()
	settle_tween.set_parallel(true)
	settle_tween.tween_property(horse_button, "modulate", Color(1, 1, 1), 0.3)
	settle_tween.tween_property(horse_button, "position:y", start_pos.y, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE)

	# Fade out the beam ring as the horse settles
	var ring_fade_tween = create_tween()
	ring_fade_tween.tween_property(beam_ring, "modulate:a", 0.0, 0.5)
	ring_fade_tween.tween_callback(beam_ring.queue_free)


	await settle_tween.finished
	is_revealing = false
	await get_tree().create_timer(2.0).timeout
	start_chase.emit()
