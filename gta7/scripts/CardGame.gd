extends Node2D

# Simon-says style memory flip: watch the cards spin in sequence once, then
# repeat the clicks in the same order. One sequence per stop.
signal finished(success: bool)

const CARD_PATHS = [
	"res://assets/sprites/cardgame/card1.png",
	"res://assets/sprites/cardgame/card2.png",
	"res://assets/sprites/cardgame/card3.png",
	"res://assets/sprites/cardgame/card4.png",
]

const CARD_SCALE := 4.0
const CARD_SPACING := 400.0
const SEQUENCE_LENGTH := 4

# Set by whoever spawns this before it enters the tree, to ramp difficulty per stop
var flash_time := 0.5

var cards: Array[TextureButton] = []
var sequence: Array[int] = []
var player_index: int = 0
var accepting_input: bool = false


func _ready() -> void:
	var bg = Sprite2D.new()
	bg.texture = load("res://assets/sprites/cardgame/cardgamebg.png")
	bg.scale = Vector2(8, 8)
	add_child(bg)

	var half_spacing = CARD_SPACING / 2.0
	var positions = [
		Vector2(-half_spacing, -half_spacing),
		Vector2(half_spacing, -half_spacing),
		Vector2(-half_spacing, half_spacing),
		Vector2(half_spacing, half_spacing),
	]

	for i in range(4):
		var card = TextureButton.new()
		card.texture_normal = load(CARD_PATHS[i])
		card.ignore_texture_size = true
		card.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		card.size = Vector2(64, 64) * CARD_SCALE
		card.pivot_offset = card.size / 2.0
		card.position = positions[i] - card.pivot_offset
		card.pressed.connect(_on_card_pressed.bind(i))
		add_child(card)
		cards.append(card)

	randomize()
	_start_sequence()


func _start_sequence() -> void:
	accepting_input = false
	player_index = 0

	sequence.clear()
	for i in range(SEQUENCE_LENGTH):
		sequence.append(randi() % 4)

	await get_tree().create_timer(0.5).timeout
	await _play_sequence()

	accepting_input = true


func _play_sequence() -> void:
	for card_index in sequence:
		await _spin_card(cards[card_index])
		await get_tree().create_timer(flash_time * 0.3).timeout


func _spin_card(card: TextureButton) -> void:
	var tween = create_tween()
	tween.tween_property(card, "rotation", card.rotation + TAU, flash_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished


func _on_card_pressed(index: int) -> void:
	if not accepting_input:
		return

	if index != sequence[player_index]:
		accepting_input = false
		var flash_tween = create_tween()
		flash_tween.tween_property(cards[index], "modulate", Color(1, 0.3, 0.3), 0.15)
		finished.emit(false)
		return

	accepting_input = false
	await _spin_card(cards[index])

	player_index += 1
	if player_index < sequence.size():
		accepting_input = true
		return

	finished.emit(true)
