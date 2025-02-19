extends Node2D

@onready var goblin_count = 0

func update_goblin_count(delta):
	goblin_count += delta
