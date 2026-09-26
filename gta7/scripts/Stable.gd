extends Node2D

@onready var horse = $Horse
@onready var horse_info_panel = $UI/HorseInfoPanel

func _ready():
	horse.horse_clicked.connect(_on_horse_clicked)

func _on_horse_clicked():
	horse_info_panel.visible = true
