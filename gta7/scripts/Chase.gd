extends Node2D

# var backgrounds: Array[TextureRect] = []
var background_width: float = 0.0
var scroll_speed: float = 100.0

@export var player_speed := 220.0
@export var crowd_base_speed := 160.0
@export var catch_distance := 60.0

var giraffe: AnimatedSprite2D
var crowd: AnimatedSprite2D
var caught: bool = false

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

	giraffe = AnimatedSprite2D.new()
	giraffe.sprite_frames = sprite_frames
	giraffe.animation = "run"
	giraffe.play()
	giraffe.position = Vector2(500, 300)
	giraffe.scale = Vector2(3, 3)

	add_child(giraffe)

	# The crowd chases the giraffe in from behind (screen scrolls left, so "behind" is left)
	var crowd_sheet = load("res://assets/sprites/Chasing/crowdchasinganimated.png")

	var crowd_frame_size = 100
	var crowd_frame_count = 2

	var crowd_frames = SpriteFrames.new()
	crowd_frames.add_animation("run")
	crowd_frames.set_animation_speed("run", 6.0)
	crowd_frames.set_animation_loop("run", true)

	for i in range(crowd_frame_count):
		var atlas = AtlasTexture.new()
		atlas.atlas = crowd_sheet
		atlas.region = Rect2(i * crowd_frame_size, 0, crowd_frame_size, crowd_frame_size)
		crowd_frames.add_frame("run", atlas)

	crowd = AnimatedSprite2D.new()
	crowd.sprite_frames = crowd_frames
	crowd.animation = "run"
	crowd.play()
	crowd.position = giraffe.position - Vector2(220, 0)
	crowd.scale = Vector2(2.5, 2.5)

	add_child(crowd)


func _process(delta: float) -> void:
	# Slide the background to the right, wrapping the two copies to loop seamlessly
	var bg=$Back

	bg.position.x -= scroll_speed * delta

	if caught:
		return

	_move_player(delta)
	_move_crowd(delta)
	_check_catch()


func _move_player(delta: float) -> void:
	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	giraffe.position += direction * player_speed * delta
	if direction.x != 0:
		giraffe.flip_h = direction.x < 0


func _move_crowd(delta: float) -> void:
	var to_player = giraffe.position - crowd.position
	var distance = to_player.length()
	if distance < 1.0:
		return

	# Rubber-band: the farther the crowd falls behind, the faster it closes the gap
	var speed = crowd_base_speed * clamp(distance / 200.0, 0.6, 2.0)
	crowd.position += to_player.normalized() * speed * delta


func _check_catch() -> void:
	if giraffe.position.distance_to(crowd.position) <= catch_distance:
		caught = true
		_on_caught()


func _on_caught() -> void:
	var label = Label.new()
	label.text = "CAUGHT!"
	label.add_theme_font_size_override("font_size", 48)
	label.position = giraffe.position + Vector2(-70, -90)
	add_child(label)
