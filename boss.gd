extends CharacterBody2D

const MAP_POSITION_MIN = Vector2(200, -200)
const MAP_POSITION_MAX = Vector2(1700, -1200) 

const SPEED_WALK = 50
const SPEED_DASH = 500
const DISTANCE_ADDITIONAL_DASH = 300 # dash distance beyond arriving at player
const DAMAGE_IDLE = 5
const DAMAGE_DASH = 8
const MAX_HEALTH = 1000

enum BOSS_STATE { IDLE, CHASE, DASH, THROW, SPAWN }

@onready var state = BOSS_STATE.IDLE : set = set_state
@onready var health = MAX_HEALTH
@onready var target = null
@onready var remaining_dynamites = 0
@onready var remaining_goblins_to_spawn = 0

@onready var player = get_parent().get_node("Player")
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

func _ready():
	await get_tree().physics_frame
	target = player


func _physics_process(delta: float) -> void:
	
	if state == BOSS_STATE.CHASE:
		look_for_player()
	
	if state != BOSS_STATE.DASH:
		follow_player()
	
	if state in [BOSS_STATE.CHASE, BOSS_STATE.DASH]:
		if navigation_agent.is_navigation_finished():
			state = BOSS_STATE.IDLE
		
		var next_position = navigation_agent.get_next_path_position()
		var direction = global_position.direction_to(next_position)
		
		if direction.x < 0:
			sprite.flip_h = true
		else:
			sprite.flip_h = false
		
		var new_velocity = Vector2.ZERO
		
		if state == BOSS_STATE.DASH:
			new_velocity = direction * SPEED_DASH
		else:
			new_velocity = direction * SPEED_WALK
		
		if navigation_agent.avoidance_enabled:
			navigation_agent.velocity = new_velocity
		else:
			velocity = new_velocity
		
	else:
		velocity = lerp(velocity, Vector2.ZERO, 0.1)
	
	if move_and_collide(velocity * delta):
		state = BOSS_STATE.IDLE
	

func follow_player():
	navigation_agent.target_position = target.global_position

func look_for_player():
	var is_player_nearby = player in player_detection.get_overlapping_bodies()
	ray_cast.rotation = global_position.direction_to(player.global_position).angle()
	var is_player_seen = ray_cast.get_collider() == player
	
	if is_player_nearby and is_player_seen:
		state = BOSS_STATE.DASH
	elif is_player_seen:
		state = BOSS_STATE.THROW

func take_damage(damage, source: Node2D):
	health = max(health - damage, 0)
	animation_hurt.play("hurt")

func throw_dynamite():
	var dynamite = DYNAMITE.instantiate()
	dynamite.start_position = global_position
	dynamite.end_position = player.global_position
	get_parent().add_child(dynamite)

func spawn_goblin():
	var goblin = GOBLIN.instantiate()
	goblin.global_position.x = randf_range(MAP_POSITION_MIN.x, MAP_POSITION_MAX.x)
	goblin.global_position.y = randf_range(-MAP_POSITION_MIN.y, -MAP_POSITION_MAX.y)
	get_parent().add_child(goblin)
	get_parent().update_goblin_count(1)

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
			sprite.play("walk")
			
		BOSS_STATE.DASH:
			var direction = global_position.direction_to(player.global_position)
			navigation_agent.target_position = player.global_position \
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

func _on_navigation_agent_2d_velocity_computed(safe_velocity: Vector2) -> void:
	if state in [BOSS_STATE.CHASE, BOSS_STATE.DASH]:
		velocity = safe_velocity
		if velocity.length() < 0.01:
			state = BOSS_STATE.IDLE


func _on_idle_timer_timeout() -> void:
	look_for_player()
	if state != BOSS_STATE.IDLE:
		return
	# choose next state
	var goblin_count = get_parent().goblin_count
	var spawn_probability
	if goblin_count < 4:
		spawn_probability = 100
	elif goblin_count < 8:
		spawn_probability = 30
	elif goblin_count < 12:
		spawn_probability = 10
	else:
		spawn_probability = 0

	if randi() % 100 < spawn_probability:
		state = BOSS_STATE.SPAWN
	else:
		state = BOSS_STATE.CHASE


func _on_hitbox_body_entered(body: Node2D) -> void:
	if "player" in body.get_groups():
		body.take_damage(DAMAGE_DASH if state == BOSS_STATE.DASH else DAMAGE_IDLE, self)


func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "throw_dynamite":
		remaining_dynamites -= 1
		if remaining_dynamites > 0:
			animation_throw.play("throw_dynamite")
		else:
			state = BOSS_STATE.IDLE
	

func _on_spawn_timer_timeout() -> void:
	if state != BOSS_STATE.SPAWN:
		return
	spawn_goblin()
	remaining_goblins_to_spawn -= 1
	if remaining_goblins_to_spawn > 0:
		spawn_timer.start()
	else:
		state = BOSS_STATE.IDLE


func _on_chase_timer_timeout() -> void:
	print(state)
	if state != BOSS_STATE.CHASE:
		return
	state = BOSS_STATE.IDLE
