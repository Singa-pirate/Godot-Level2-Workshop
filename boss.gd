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

@export var state = BOSS_STATE.IDLE : set = set_state
@onready var health = MAX_HEALTH
@onready var target = null
@onready var remaining_dynamites = 0
@onready var remaining_goblins_to_spawn = 0

@onready var players = get_parent().get_node("Players")
@onready var dynamites = get_parent().get_node("Dynamites")
@onready var health_bar = $UI/HealthBar
@onready var sprite = $Sprite
@onready var ray_cast = $RayCast2D
@onready var player_detection = $PlayerDetection
@onready var navigation_agent = $NavigationAgent2D
@onready var animation_hurt = $AnimationHurt
@onready var animation_throw = $AnimationThrow
@onready var idle_timer = $IdleTimer
@onready var chase_timer = $ChaseTimer
@onready var spawn_timer = $SpawnTimer
@onready var DYNAMITE = preload("res://dynamite.tscn")
@onready var GOBLIN = preload("res://goblin.tscn")
var nearest_player

func _ready():
	await get_tree().physics_frame
	nearest_player = find_nearest_player()
	target = nearest_player

func _physics_process(delta: float) -> void:
	# TODO: check nearest player is still valid
	
	if health <= 0:
		die()
	
	# in chase state, ready to detect and attack nearby player
	if state == BOSS_STATE.CHASE:
		look_for_player()
	
	# not in dash state, where target is a position beyond player
	if state != BOSS_STATE.DASH:
		follow_player()
	
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
func follow_player():
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

func find_nearest_player():
	# TODO: correct this implementation
	return players.get_children()[0]
###

func look_for_player():
	var is_player_nearby = nearest_player in player_detection.get_overlapping_bodies()
	ray_cast.rotation = global_position.direction_to(nearest_player.global_position).angle()
	var is_player_seen = ray_cast.get_collider() == nearest_player
	
	if is_player_nearby and is_player_seen:
		state = BOSS_STATE.DASH
	elif is_player_seen:
		state = BOSS_STATE.THROW

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
			var direction = global_position.direction_to(nearest_player.global_position)
			navigation_agent.target_position = nearest_player.global_position \
										+ direction * DISTANCE_ADDITIONAL_DASH
			sprite.play("dash")
		
		BOSS_STATE.THROW:
			sprite.play("throw")
			sprite.pause()
			remaining_dynamites = randi_range(3, 5)
			animation_throw.play("throw_dynamite")
		
		BOSS_STATE.SPAWN:
			sprite.play("spawn")
			remaining_goblins_to_spawn = randi_range(2, 4)
			spawn_timer.start()

##### idle state
func _on_idle_timer_timeout() -> void:
	# spawn goblins with a probability based on number of goblins
	var goblin_count = get_parent().goblin_count
	var spawn_probability
	if goblin_count < 3:
		spawn_probability = 30
	elif goblin_count < 6:
		spawn_probability = 15
	elif goblin_count < 9:
		spawn_probability = 10
	else:
		spawn_probability = 0

	if randi() % 100 < spawn_probability:
		state = BOSS_STATE.SPAWN
		return
	
	# if player is nearby, use special skill to attack
	look_for_player()
	if state != BOSS_STATE.IDLE:
		return

	# no special skill, continue chasing
	state = BOSS_STATE.CHASE
###

##### throw state
func throw_dynamite():
	var dynamite = DYNAMITE.instantiate()
	dynamite.start_position = global_position
	dynamite.end_position = nearest_player.global_position + \
			Vector2(randi_range(-100, 100), randi_range(-50, 50))
	dynamites.add_child(dynamite, true)

func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "throw_dynamite":
		remaining_dynamites -= 1
		if remaining_dynamites > 0:
			animation_throw.play("throw_dynamite")
		else:
			state = BOSS_STATE.IDLE
###

##### spawn state
func spawn_goblin():
	var goblin = GOBLIN.instantiate()
	goblin.global_position.x = randf_range(MAP_POSITION_MIN.x, MAP_POSITION_MAX.x)
	goblin.global_position.y = randf_range(-MAP_POSITION_MIN.y, -MAP_POSITION_MAX.y)
	get_parent().update_goblin_count(1)
	# TODO: add goblin instance to the game

func _on_spawn_timer_timeout() -> void:
	if state != BOSS_STATE.SPAWN:
		return
	spawn_goblin()
	remaining_goblins_to_spawn -= 1
	if remaining_goblins_to_spawn > 0:
		spawn_timer.start()
	else:
		state = BOSS_STATE.IDLE
###

func _on_chase_timer_timeout() -> void:
	if state != BOSS_STATE.CHASE:
		return
	state = BOSS_STATE.IDLE
