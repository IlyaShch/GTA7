extends CharacterBody2D

@export var speed := 160.0
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _physics_process(_delta: float) -> void:
	var direction := Input.get_vector(
		"ui_left", "ui_right", "ui_up", "ui_down"
	)

	velocity = direction * speed
	move_and_slide()

	if direction == Vector2.ZERO:
		sprite.play("idle")
	else:
		sprite.play("walk")
