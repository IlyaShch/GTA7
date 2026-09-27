extends Node2D

# var backgrounds: Array[TextureRect] = []
var background_width: float = 0.0
var scroll_speed: float = 100.0

func _ready():
	# var bg_texture = load("res://assets/backgrounds/Chase.png")
	# background_width = bg_texture.get_width()

	# for i in range(2):
	# 	var background = TextureRect.new()
	# 	background.texture = bg_texture
	# 	# TextureRect has no size by default, so it renders nothing without an explicit size
	# 	background.size = bg_texture.get_size()
	# 	background.position = Vector2(i * background_width, 0)
	# 	add_child(background)
	# 	move_child(background, 0)
	# 	backgrounds.append(background)

	var sheet = load("res://assets/sprites/Horses/RunningGiraffeSheet.png")

	var frame_size = 64
	var frame_count = 6

	var sprite_frames = SpriteFrames.new()
	sprite_frames.add_animation("run")
	sprite_frames.set_animation_speed("run", 10.0)
	sprite_frames.set_animation_loop("run", true)

	for i in range(frame_count):
		var atlas = AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(i * frame_size, 0, frame_size, frame_size)
		sprite_frames.add_frame("run", atlas)

	var giraffe = AnimatedSprite2D.new()
	giraffe.sprite_frames = sprite_frames
	giraffe.animation = "run"
	giraffe.play()
	giraffe.position = Vector2(400, 300)
	giraffe.scale = Vector2(3, 3)

	add_child(giraffe)

	# Drift the giraffe slowly downward while it runs
	var drift_tween = create_tween()
	drift_tween.tween_property(giraffe, "position:y", giraffe.position.y + 150, 6.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)


func _process(delta: float) -> void:
	# Slide the background to the right, wrapping the two copies to loop seamlessly
	var bg=$Back
	
	bg.position.x -= scroll_speed * delta
