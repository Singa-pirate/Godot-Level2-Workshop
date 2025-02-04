extends CharacterBody2D


@onready var SPEED = randi_range(70, 130)

@onready var player : CharacterBody2D = get_parent().get_node("Player")
@onready var navigation_agent = $NavigationAgent2D
@onready var target
@onready var sprite = $Sprite

func _ready():
	call_deferred("navigation_setup")

func _physics_process(delta: float) -> void:
	follow_player()
	
	if navigation_agent.is_navigation_finished():
		print("finished")
		sprite.play("idle")
		return
	
	sprite.play("run")
	
	var next_position = navigation_agent.get_next_path_position()
	var direction = global_position.direction_to(next_position)
	
	var new_velocity = direction * SPEED
	
	if navigation_agent.avoidance_enabled:
		navigation_agent.velocity = new_velocity
	else:
		velocity = new_velocity

	if velocity.x < 0:
		sprite.flip_h = true
	else:
		sprite.flip_h = false

	move_and_slide()

func navigation_setup():
	await get_tree().physics_frame
	target = player


func follow_player():
	if target:
		navigation_agent.target_position = target.global_position


func _on_navigation_agent_2d_velocity_computed(safe_velocity: Vector2) -> void:
	velocity = safe_velocity
