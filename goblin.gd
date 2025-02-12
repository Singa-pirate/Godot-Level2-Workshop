extends CharacterBody2D

const MAX_HEALTH = 100
const KNOCK_BACK_DISTANCE = 50
const damage = 10
const ATTACK_COOLDOWN_SECONDS = 0.5
const ATTACK_CAST_DELAY_SECONDS = 0.5

enum GOBLIN_STATE { IDLE, RUN, ATTACK_COOLDOWN, ATTACK_CASTING, ATTACKING, HURT }

@onready var SPEED = randi_range(70, 130)
@onready var health = MAX_HEALTH
@onready var state = GOBLIN_STATE.IDLE : set = set_state

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
		
	if navigation_agent.is_navigation_finished():
		if state == GOBLIN_STATE.RUN:
			state = GOBLIN_STATE.IDLE
	else:
		if state == GOBLIN_STATE.IDLE:
			state = GOBLIN_STATE.RUN
	
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
		velocity = lerp(velocity, Vector2(0, 0), 0.1)
	
	move_and_slide()
	

func navigation_setup():
	target = player


func follow_player():
	if target:
		navigation_agent.target_position = target.global_position


func take_damage(damage, source: Node2D):
	health = max(health - damage, 0)
	animation_player.play("hurt")
	state = GOBLIN_STATE.HURT
	velocity = source.position.direction_to(position) * KNOCK_BACK_DISTANCE
	print(health)
	

func die():
	queue_free()


func set_state(new_state: GOBLIN_STATE):
	var prev_state = state
	state = new_state
	
	if prev_state == GOBLIN_STATE.ATTACKING:
		attack_collision.disabled = true
		
	
	match new_state:
		GOBLIN_STATE.IDLE:
			sprite.play("idle")
			attack_cooldown_timer.start(ATTACK_COOLDOWN_SECONDS)
		
		GOBLIN_STATE.RUN:
			sprite.play("run")
		
		GOBLIN_STATE.ATTACK_COOLDOWN:
			sprite.play("idle")
		
		GOBLIN_STATE.ATTACK_CASTING:
			sprite.play("attack_casting")
			attack_cast_delay_timer.start(ATTACK_CAST_DELAY_SECONDS)
		
		GOBLIN_STATE.ATTACKING:
			sprite.play("attacking")
			attack_collision.disabled = false
		
		GOBLIN_STATE.HURT:
			sprite.play("hurt")

func _on_navigation_agent_2d_velocity_computed(safe_velocity: Vector2) -> void:
	if state == GOBLIN_STATE.RUN:
		velocity = safe_velocity


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
