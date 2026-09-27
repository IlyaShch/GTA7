extends Node2D

const CardGameScript = preload("res://scripts/CardGame.gd")

# var backgrounds: Array[TextureRect] = []
var background_width: float = 0.0
var scroll_speed: float = 100.0

@export var player_speed := 220.0

var giraffe: AnimatedSprite2D
var crowd: AnimatedSprite2D

# The king stops every quarter of the way across the background for a minigame
var stop_sign: Sprite2D
var scroll_banner: Sprite2D
var play_button: TextureButton
var play_button_bob_tween: Tween
var minigame_bg: Sprite2D
var minigame_bg_frames: Array[Texture2D] = []
var minigame_bg_frame_index: int = 0
var minigame_bg_timer: Timer
var total_scrolled: float = 0.0
var track_distance: float = 0.0
var stop_fractions: Array[float] = [0.25, 0.5, 0.75, 1.0]
var next_stop: int = 0
var is_stopped: bool = false

var crowd_gap: float = 400.0
var fail_count: int = 0
const FAILS_BEFORE_CAUGHT := 2
const CROWD_GAP_LOSS_PER_FAIL := 150.0
const MIN_CROWD_GAP := 60.0

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
	crowd.position = giraffe.position - Vector2(crowd_gap, 0)
	crowd.scale = Vector2(2.5, 2.5)

	add_child(crowd)

	# Track how far the background can scroll before it runs out
	var bg = $Back
	track_distance = max(bg.size.x - get_viewport_rect().size.x, 0.0)

	stop_sign = Sprite2D.new()
	stop_sign.texture = load("res://assets/sprites/banners/Stopsign.png")
	stop_sign.scale = Vector2(2, 2)
	stop_sign.visible = false
	add_child(stop_sign)

	scroll_banner = Sprite2D.new()
	scroll_banner.texture = load("res://assets/sprites/banners/scroll.png")
	scroll_banner.scale = Vector2(3, 3)
	scroll_banner.position = get_viewport_rect().size / 2.0
	scroll_banner.visible = false
	add_child(scroll_banner)

	play_button = TextureButton.new()
	play_button.texture_normal = load("res://assets/sprites/Button/play_button.png")
	play_button.ignore_texture_size = true
	play_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	play_button.size = Vector2(140, 140)
	play_button.visible = false
	add_child(play_button)

	# Placeholder backdrop for whichever minigame is currently running
	_setup_minigame_bg()


func _setup_minigame_bg() -> void:
	# The sheet is one huge horizontal strip of full-screen frames, too wide for a
	# GPU to hold as a single texture. Load it as a CPU-side Image and crop each
	# frame out in software so only screen-sized textures ever reach the GPU.
	var full_image = Image.new()
	if full_image.load("res://assets/backgrounds/minigamebg.png") != OK:
		push_warning("Failed to load minigame background")
		return

	var frame_width = 1152
	var frame_height = full_image.get_height()
	var frame_count = int(full_image.get_width() / frame_width)

	for i in range(frame_count):
		var region = Rect2i(i * frame_width, 0, frame_width, frame_height)
		minigame_bg_frames.append(ImageTexture.create_from_image(full_image.get_region(region)))

	if minigame_bg_frames.is_empty():
		return

	minigame_bg = Sprite2D.new()
	minigame_bg.texture = minigame_bg_frames[0]
	minigame_bg.centered = false
	minigame_bg.position = Vector2.ZERO
	minigame_bg.visible = false
	add_child(minigame_bg)

	minigame_bg_timer = Timer.new()
	minigame_bg_timer.wait_time = 0.1
	minigame_bg_timer.timeout.connect(_on_minigame_bg_frame_timeout)
	add_child(minigame_bg_timer)


func _on_minigame_bg_frame_timeout() -> void:
	minigame_bg_frame_index = (minigame_bg_frame_index + 1) % minigame_bg_frames.size()
	minigame_bg.texture = minigame_bg_frames[minigame_bg_frame_index]


func _process(delta: float) -> void:
	if is_stopped:
		return

	var bg = $Back
	total_scrolled += scroll_speed * delta
	bg.position.x = -total_scrolled

	_move_player(delta)
	_check_stop_point()


func _move_player(delta: float) -> void:
	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var movement = direction * player_speed * delta

	giraffe.position += movement
	if direction.x != 0:
		giraffe.flip_h = direction.x < 0

	# The crowd holds a fixed gap that only shrinks when the king fails a minigame
	crowd.position = giraffe.position - Vector2(crowd_gap, 0)


func _check_stop_point() -> void:
	if next_stop >= stop_fractions.size():
		return
	if total_scrolled >= track_distance * stop_fractions[next_stop]:
		next_stop += 1
		_play_stop_sequence()


func _play_stop_sequence() -> void:
	is_stopped = true

	# The king holds up the stop sign above his head
	stop_sign.position = giraffe.position + Vector2(0, -120)
	stop_sign.scale = Vector2(0, 0)
	stop_sign.visible = true

	var pop_tween = create_tween()
	pop_tween.tween_property(stop_sign, "scale", Vector2(2, 2), 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	await pop_tween.finished

	await get_tree().create_timer(1.0).timeout

	stop_sign.visible = false

	# The scroll unrolls with the minigame's title and a bouncing play button
	scroll_banner.texture = load("res://assets/sprites/banners/scroll-memflp.png")
	scroll_banner.modulate.a = 0.0
	scroll_banner.visible = true

	var scroll_tween = create_tween()
	scroll_tween.tween_property(scroll_banner, "modulate:a", 1.0, 0.3)
	await scroll_tween.finished

	play_button.position = scroll_banner.position + Vector2(-70, 150)
	play_button.modulate.a = 0.0
	play_button.visible = true

	var button_fade = create_tween()
	button_fade.tween_property(play_button, "modulate:a", 1.0, 0.2)

	if play_button_bob_tween:
		play_button_bob_tween.kill()
	var base_y = play_button.position.y
	play_button_bob_tween = create_tween()
	play_button_bob_tween.set_loops()
	play_button_bob_tween.tween_property(play_button, "position:y", base_y - 20, 0.8).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	play_button_bob_tween.tween_property(play_button, "position:y", base_y, 0.8).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

	await play_button.pressed

	play_button_bob_tween.kill()
	play_button.visible = false
	scroll_banner.visible = false

	minigame_bg.visible = true
	minigame_bg_timer.start()

	# Same card game every stop, just faster each time
	var card_game = CardGameScript.new()
	card_game.position = get_viewport_rect().size / 2.0
	card_game.flash_time = max(0.5 - 0.08 * (next_stop - 1), 0.2)
	add_child(card_game)
	var success: bool = await card_game.finished
	card_game.queue_free()

	minigame_bg_timer.stop()
	minigame_bg.visible = false

	await _show_result_banner(success)

	if not success:
		fail_count += 1
		crowd_gap = max(crowd_gap - CROWD_GAP_LOSS_PER_FAIL, MIN_CROWD_GAP)

		var close_tween = create_tween()
		close_tween.tween_property(crowd, "position:x", giraffe.position.x - crowd_gap, 0.6).set_ease(Tween.EASE_OUT)
		await close_tween.finished

		if fail_count >= FAILS_BEFORE_CAUGHT:
			await _trigger_caught()
			return

	if next_stop >= stop_fractions.size():
		await _trigger_win()
		return

	is_stopped = false


func _show_result_banner(success: bool) -> void:
	var banner = Sprite2D.new()
	banner.texture = load("res://assets/sprites/cardgame/success.png" if success else "res://assets/sprites/cardgame/fail.png")
	banner.scale = Vector2(4, 4)
	banner.position = get_viewport_rect().size / 2.0
	banner.modulate.a = 0.0
	add_child(banner)

	var fade_in = create_tween()
	fade_in.tween_property(banner, "modulate:a", 1.0, 0.2)
	await fade_in.finished

	await get_tree().create_timer(1.0).timeout

	var fade_out = create_tween()
	fade_out.tween_property(banner, "modulate:a", 0.0, 0.3)
	await fade_out.finished

	banner.queue_free()


func _trigger_caught() -> void:
	var catch_tween = create_tween()
	catch_tween.tween_property(crowd, "position", giraffe.position, 0.4).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	await catch_tween.finished

	await _show_final_screen("res://assets/sprites/banners/game failed.png")
	# is_stopped is left true here: the chase is over


func _trigger_win() -> void:
	await _show_final_screen("res://assets/sprites/banners/finalscreen.png")
	# is_stopped is left true here: the chase is complete


func _show_final_screen(path: String) -> void:
	var screen = Sprite2D.new()
	screen.texture = load(path)
	screen.position = get_viewport_rect().size / 2.0
	screen.scale = Vector2(2, 2)
	screen.modulate.a = 0.0
	add_child(screen)

	var fade_in = create_tween()
	fade_in.tween_property(screen, "modulate:a", 1.0, 0.5)
	await fade_in.finished
