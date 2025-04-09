extends CharacterBody2D

const MAX_HEALTH = 100
const KNOCK_BACK_DISTANCE = 50
const damage = 5
const ATTACK_COOLDOWN_SECONDS = 0.5
const ATTACK_CAST_DELAY_SECONDS = 0.5

enum GOBLIN_STATE { IDLE, RUN, ATTACK_CASTING, ATTACKING, HURT }

@onready var SPEED = randi_range(70, 200)
@onready var health = MAX_HEALTH
@onready var state = GOBLIN_STATE.IDLE : set = set_state

@onready var players = get_parent().get_parent().get_node("Players")
@onready var navigation_agent = $NavigationAgent2D
@onready var target
@onready var health_bar = $UI/HealthBar
@onready var sprite = $Sprite
@onready var animation_player = $AnimationPlayer
@onready var attack_cooldown_timer = $AttackCooldownTimer
@onready var attack_cast_delay_timer = $AttackCastDelayTimer
@onready var attack_collision = $Attack_hitbox/CollisionPolygon2D

var nearest_player

func _ready():
	nearest_player = find_nearest_player()
	call_deferred("navigation_setup")

func _physics_process(delta: float) -> void:
	if health <= 0:
		die()
	
	follow_player()
	
	# transition between idle and run based on navigation finished
	if navigation_agent.is_navigation_finished():
		if state == GOBLIN_STATE.RUN:
			state = GOBLIN_STATE.IDLE
	else:
		if state == GOBLIN_STATE.IDLE:
			state = GOBLIN_STATE.RUN
	
	# only in run state, move in navigation direction
	if state == GOBLIN_STATE.RUN:
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
	else:
		# in other states, passively stop with friction
		velocity = lerp(velocity, Vector2(0, 0), 0.1)
	
	move_and_slide()
	

func navigation_setup():
	target = nearest_player

func find_nearest_player():
	return players.get_children()[0]

func follow_player():
	if target:
		navigation_agent.target_position = target.global_position


func take_damage(damage, source: Node2D):
	health = max(health - damage, 0)
	health_bar.value = float(health) / MAX_HEALTH * 100
	state = GOBLIN_STATE.HURT
	velocity = source.position.direction_to(position) * KNOCK_BACK_DISTANCE
	animation_player.play("hurt")


func die():
	get_parent().get_parent().update_goblin_count(-1)
	queue_free()


func set_state(new_state: GOBLIN_STATE):
	var prev_state = state
	state = new_state
	
	# events that happen once during state change
	
	# disable attack collision shape
	# when exiting attack state, finished or interrupted
	# or when exiting hurt state, to handle edge case
	if prev_state in [GOBLIN_STATE.ATTACKING, GOBLIN_STATE.HURT]:
		attack_collision.disabled = true
	
	# when entering each new state, play animation. In addition:
	# - idle: prepare for casting
	# - casting: prepare for attacking
	# - attacking: enable attack collision shape
	match new_state:
		GOBLIN_STATE.IDLE:
			attack_cooldown_timer.start(ATTACK_COOLDOWN_SECONDS)
			sprite.play("idle")
		
		GOBLIN_STATE.RUN:
			sprite.play("run")
		
		GOBLIN_STATE.ATTACK_CASTING:
			sprite.play("attack_casting")
			attack_cast_delay_timer.start(ATTACK_CAST_DELAY_SECONDS)
		
		GOBLIN_STATE.ATTACKING:
			attack_collision.disabled = false
			sprite.play("attacking")
		
		GOBLIN_STATE.HURT:
			sprite.play("hurt")

func _on_navigation_agent_2d_velocity_computed(safe_velocity: Vector2) -> void:
	# careful, only move in run state
	if state == GOBLIN_STATE.RUN:
		velocity = safe_velocity

# for states that should end after its animation,
# signal from animation finished, to switch back to (default) idle state
func _on_sprite_animation_finished() -> void:
	if state in [GOBLIN_STATE.ATTACKING, GOBLIN_STATE.HURT]:
		state = GOBLIN_STATE.IDLE

func _on_attack_cooldown_timer_timeout() -> void:
	if state == GOBLIN_STATE.IDLE:
		state = GOBLIN_STATE.ATTACK_CASTING

func _on_attack_cast_delay_timer_timeout() -> void:
	if state == GOBLIN_STATE.ATTACK_CASTING:
		state = GOBLIN_STATE.ATTACKING

func _on_attack_hitbox_body_entered(body: Node2D) -> void:
	if "player" in body.get_groups():
		body.take_damage(damage, self)
