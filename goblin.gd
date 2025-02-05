extends CharacterBody2D


@onready var SPEED = randi_range(70, 130)

@onready var player : CharacterBody2D = get_parent().get_node("Player")
@onready var sprite = $Sprite

func _ready():
	
	# set up navigation agent
	
	pass

func _physics_process(delta: float) -> void:
	# check navigation finished
	
	# follow player
	
	# add avoidance
	
	if velocity.x < 0:
		sprite.flip_h = true
	else:
		sprite.flip_h = false
	
	move_and_slide()
