extends CharacterBody2D


const SPEED = 300.0
@onready var sprite = $Sprite


func _physics_process(delta: float) -> void:
	
	var direction_x := Input.get_axis("ui_left", "ui_right")
	var direction_y = Input.get_axis("ui_up", "ui_down")
	
	if not direction_x and not direction_y:
		velocity = Vector2.ZERO
		sprite.play("idle")
	else:
		velocity = Vector2(direction_x, direction_y) * SPEED
		
		sprite.play("run")
		
		if direction_x < 0:
			sprite.flip_h = true
		else:
			sprite.flip_h = false
			
	
	move_and_collide(velocity * delta)
