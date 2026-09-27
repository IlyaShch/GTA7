extends Control

signal open_stable

var gif_frames: Array[Texture2D] = []
var gif_frame_index: int = 0
var gif_display: TextureRect

func _ready():
	
	var stableButton = TextureButton.new()
	stableButton.texture_normal = load("res://assets/sprites/Button/play_button.png")
	stableButton.ignore_texture_size = true
	stableButton.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	stableButton.position = Vector2(550, 200)
	stableButton.size = Vector2(640, 260)
	stableButton.pivot_offset = stableButton.size / 2.0
	stableButton.pressed.connect(_on_stable_button_pressed)
	stableButton.mouse_entered.connect(_on_stable_button_hover.bind(stableButton, true))
	stableButton.mouse_exited.connect(_on_stable_button_hover.bind(stableButton, false))

	add_child(stableButton)

	_setup_title_gif()


func _setup_title_gif():
	var frame_paths = [
		"res://assets/backgrounds/ezgif-split/frame_0_delay-0.1s.png",
		"res://assets/backgrounds/ezgif-split/frame_1_delay-0.1s.png",
		"res://assets/backgrounds/ezgif-split/frame_2_delay-0.1s.png",
	]

	for path in frame_paths:
		var image = Image.new()
		if image.load(path) == OK:
			gif_frames.append(ImageTexture.create_from_image(image))
		else:
			push_warning("Failed to load title gif frame: " + path)

	if gif_frames.is_empty():
		return

	gif_display = TextureRect.new()
	gif_display.texture = gif_frames[0]
	gif_display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	gif_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gif_display.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(gif_display)
	# Draw the background behind the label/button, which were added first
	move_child(gif_display, 0)

	var frame_timer = Timer.new()
	frame_timer.wait_time = 0.1
	frame_timer.autostart = true
	frame_timer.timeout.connect(_on_gif_frame_timeout)
	add_child(frame_timer)


func _on_gif_frame_timeout():
	gif_frame_index = (gif_frame_index + 1) % gif_frames.size()
	gif_display.texture = gif_frames[gif_frame_index]


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass



func _on_stable_button_pressed():
	print("button pressed")
	open_stable.emit()


func _on_stable_button_hover(button: TextureButton, is_hovering: bool):
	var target_scale = Vector2(1.15, 1.15) if is_hovering else Vector2(1, 1)
	var hover_tween = create_tween()
	hover_tween.tween_property(button, "scale", target_scale, 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
