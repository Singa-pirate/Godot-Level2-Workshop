extends CharacterBody2D

# for initial position of spawned goblins
const MAP_POSITION_MIN = Vector2(200, -200)
const MAP_POSITION_MAX = Vector2(1700, -1200) 

const SPEED_CHASE = 50
const SPEED_DASH = 500
const DISTANCE_ADDITIONAL_DASH = 300 # dash distance beyond arriving at player
const DAMAGE_IDLE = 5
const DAMAGE_DASH = 10
const MAX_HEALTH = 500

enum BOSS_STATE { IDLE, CHASE, DASH, THROW, SPAWN }

@onready var state = BOSS_STATE.IDLE : set = set_state
@onready var health = MAX_HEALTH
@onready var target = null
@onready var remaining_dynamites = 0
@onready var remaining_goblins_to_spawn = 0

@onready var player = get_parent().get_node("Player")
@onready var health_bar = $UI/HealthBar
@onready var sprite = $Sprite
# TODO: access raycast and player detection
@onready var navigation_agent = $NavigationAgent2D
@onready var animation_hurt = $AnimationHurt
@onready var animation_throw = $AnimationThrow
@onready var idle_timer = $IdleTimer
@onready var chase_timer = $ChaseTimer
@onready var spawn_timer = $SpawnTimer
@onready var DYNAMITE = preload("res://dynamite.tscn")
@onready var GOBLIN = preload("res://goblin.tscn")

func _ready():
	await get_tree().physics_frame
	target = player


func _physics_process(delta: float) -> void:
	if health <= 0:
		die()
	
	# in chase state, ready to detect and attack nearby player
	if state == BOSS_STATE.CHASE:
		look_for_player()
	
	# not in dash state, where target is a position beyond player
	if state != BOSS_STATE.DASH:
		follow_target()
	
	# only navigate in chase or dash states
	if state in [BOSS_STATE.CHASE, BOSS_STATE.DASH]:
		if navigation_agent.is_navigation_finished():
			state = BOSS_STATE.IDLE
		
		var next_position = navigation_agent.get_next_path_position()
		var direction = global_position.direction_to(next_position)
		
		if direction.x < 0:
			sprite.flip_h = true
		else:
			sprite.flip_h = false
		
		var new_velocity
		if state == BOSS_STATE.DASH:
			new_velocity = direction * SPEED_DASH
		else:
			new_velocity = direction * SPEED_CHASE
		
		if navigation_agent.avoidance_enabled:
			navigation_agent.velocity = new_velocity
		else:
			velocity = new_velocity
		
	else:
		# in other states, gradually stop
		velocity = lerp(velocity, Vector2.ZERO, 0.1)
	
	# stop when dashing target is outside map
	if move_and_collide(velocity * delta):
		state = BOSS_STATE.IDLE
	

##### navigation
func follow_target():
	if target:
		navigation_agent.target_position = target.global_position

func _on_navigation_agent_2d_velocity_computed(safe_velocity: Vector2) -> void:
	if state in [BOSS_STATE.CHASE, BOSS_STATE.DASH]:
		velocity = safe_velocity
		if velocity.length() < 0.01:
			state = BOSS_STATE.IDLE
###

##### common character functions
func take_damage(damage, source: Node2D):
	health = max(health - damage, 0)
	health_bar.value = float(health) / MAX_HEALTH * 100
	animation_hurt.play("hurt")

func die():
	queue_free()

func _on_hitbox_body_entered(body: Node2D) -> void:
	if "player" in body.get_groups():
		body.take_damage(DAMAGE_DASH if state == BOSS_STATE.DASH else DAMAGE_IDLE, self)
###

func look_for_player():
	# TODO: mechanism to check if player is nearby & seen by boss
	var is_player_nearby
	var is_player_seen
	
	print("Player nearby: ", is_player_nearby)
	print("Player seen:", is_player_seen)
	
	# TODO: switch to dash state if nearby & seen
	# switch to throw state if not nearby but seen

func set_state(new_state: BOSS_STATE):
	var prev_state = state
	state = new_state
	
	match new_state:
		BOSS_STATE.IDLE:
			velocity = Vector2.ZERO
			idle_timer.start()
			sprite.play("idle")
			
		BOSS_STATE.CHASE:
			chase_timer.start()
			sprite.play("chase")
			
		BOSS_STATE.DASH:
			var direction = global_position.direction_to(player.global_position)
			navigation_agent.target_position = player.global_position \
										+ direction * DISTANCE_ADDITIONAL_DASH
			sprite.play("dash")
		
		BOSS_STATE.THROW:
			pass
			# TODO: actions when entering throw state
			# set remaining number of dynamites
			# switch to throw sprite and pause
			# play throw animation
		
		BOSS_STATE.SPAWN:
			sprite.play("spawn")
			# TODO: actions when entering spawn state
			# set remaining number of goblins to spawn
			# start timer

##### idle state
func enter_spawn_with_probability():
	pass
	# TODO: with a probability, switch to spawn state to summon goblins
	# probability is based on current number of goblins

func _on_idle_timer_timeout() -> void:
	enter_spawn_with_probability()
	
	if state != BOSS_STATE.IDLE:
		return

	state = BOSS_STATE.CHASE
###

##### throw state
# TODO: function to throw a dynamite towards player position

# TODO: mechanism to throw for a certain number of times
# switch to idle state after finish
###

##### spawn state
# TODO: define a function to spawn 1 goblin at random map position

# TODO: mechanism to spawn goblin for a certain number of times
# switch to idle state after finish
###

func _on_chase_timer_timeout() -> void:
	if state != BOSS_STATE.CHASE:
		return
	state = BOSS_STATE.IDLE
