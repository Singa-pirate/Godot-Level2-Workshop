extends CharacterBody2D

const MAX_HEALTH = 100
const KNOCK_BACK_DISTANCE = 50
const damage = 10
const ATTACK_COOLDOWN_SECONDS = 0.5
const ATTACK_CAST_DELAY_SECONDS = 0.5

# TODO: define states

@onready var SPEED = randi_range(70, 130)
@onready var health = MAX_HEALTH
@onready var state

@onready var player : CharacterBody2D = get_parent().get_node("Player")
@onready var navigation_agent = $NavigationAgent2D
@onready var target
@onready var sprite = $Sprite
@onready var animation_player = $AnimationPlayer
@onready var attack_cooldown_timer = $AttackCooldownTimer
@onready var attack_cast_delay_timer = $AttackCastDelayTimer
@onready var attack_collision = $Attack_hitbox/CollisionPolygon2D


func _ready():
	call_deferred("navigation_setup")

func _physics_process(delta: float) -> void:
	if health <= 0:
		die()
	
	follow_player()
	
	# TODO: transition between idle and run based on navigation finished
	if navigation_agent.is_navigation_finished():
		return
	
	# TODO:only in run state, move in navigation direction
	
	var next_position = navigation_agent.get_next_path_position()
	var direction = global_position.direction_to(next_position)
	
	var new_velocity = direction * SPEED
	
	if navigation_agent.avoidance_enabled:
		navigation_agent.velocity = new_velocity
	else:
		velocity = new_velocity

	if velocity.x < 0:
		sprite.flip_h = true
		attack_collision.scale.x = -1
	else:
		sprite.flip_h = false
		attack_collision.scale.x = 1
	


	# TODO: in other states, passively stop with friction
	
	move_and_slide()
	

func navigation_setup():
	target = player


func follow_player():
	if target:
		navigation_agent.target_position = target.global_position


func take_damage(damage, source: Node2D):
	health = max(health - damage, 0)
	# TODO: transition to hurt state
	velocity = source.position.direction_to(position) * KNOCK_BACK_DISTANCE
	animation_player.play("hurt")


func die():
	queue_free()


func set_state(new_state):
	var prev_state = state
	state = new_state
	
	# TODO: events that happen once during state change
	
	# disable attack collision shape
	# when exiting attack state, finished or interrupted
	# or when exiting hurt state, to handle edge case
	
	# when entering each new state, play animation. In addition:
	# - idle: prepare for casting
	# - casting: prepare for attacking
	# - attacking: enable attack collision shape

func _on_navigation_agent_2d_velocity_computed(safe_velocity: Vector2) -> void:
	# TODO: careful, only move in run state
	velocity = safe_velocity

# TODO: for states that should end after its animation,
# signal from animation finished, to switch back to (default) idle state

func _on_attack_cooldown_timer_timeout() -> void:
	# TODO: transition to casting state
	pass

func _on_attack_cast_delay_timer_timeout() -> void:
	# TODO: transition to attacking state
	pass

func _on_attack_hitbox_body_entered(body: Node2D) -> void:
	if "player" in body.get_groups():
		body.take_damage(damage, self)
