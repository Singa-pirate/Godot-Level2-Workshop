extends CharacterBody2D

const MAX_HEALTH = 100
const KNOCK_BACK_DISTANCE = 200
const SPEED = 300.0
const ATTACK_1_DAMAGE = 10
const ATTACK_2_DAMAGE = 15
const ATTACK_3_DAMAGE = 25

enum PLAYER_STATE { IDLE, RUN, ATTACK_1, ATTACK_2, ATTACK_3, HURT }

@onready var state: PLAYER_STATE = PLAYER_STATE.IDLE : set = set_state

var prev_attack_state: PLAYER_STATE

@onready var health = MAX_HEALTH
@onready var health_bar = $UI/HealthBar
@onready var name_label = $UI/NameLabel
@onready var sprite = $Sprite
@onready var animation_player = $AnimationPlayer
@onready var attack1_collision = $Attack1_Hitbox/CollisionPolygon2D
@onready var attack2_collision = $Attack2_Hitbox/CollisionPolygon2D
@onready var attack3_collision = $Attack3_Hitbox/CollisionPolygon2D
# preserve prev attack state to facilitate combo attack
@onready var prev_attack_state_timer = $prev_attack_state_timer

var player_name: String

func _ready():
	var game_node = get_tree().get_current_scene()
	var player_id = int(str(self.name))
	set_multiplayer_authority(player_id)
	global_position = Vector2(randi_range(200, 1000), randi_range(200, 1000))
	var name_provided = game_node.get_player_info(player_id)["name"]
	if name_provided:
		name_label.text = name_provided
	else:
		name_label.text = "Player%d" % player_id

func _physics_process(delta: float) -> void:
	if multiplayer.get_unique_id() != get_multiplayer_authority():
		return
	
	if health <= 0:
		die()
	
	var direction_x := Input.get_axis("ui_left", "ui_right")
	var direction_y = Input.get_axis("ui_up", "ui_down")
	
	# check transition between idle and run
	if state == PLAYER_STATE.IDLE and (direction_x or direction_y):
		state = PLAYER_STATE.RUN
	elif state == PLAYER_STATE.RUN and not (direction_x or direction_y):
		state = PLAYER_STATE.IDLE
	
	# only in run state, player can control movement with input
	if state == PLAYER_STATE.RUN:
		velocity = Vector2(direction_x, direction_y) * SPEED
		state = PLAYER_STATE.RUN
		
		if direction_x < 0:
			sprite.flip_h = true
			attack1_collision.scale.x = -1
			attack2_collision.scale.x = -1
			attack3_collision.scale.x = -1
			
		elif direction_x > 0:
			sprite.flip_h = false
			attack1_collision.scale.x = 1
			attack2_collision.scale.x = 1
			attack3_collision.scale.x = 1
	else:
		# in other states, character passively stops with friction
		velocity = lerp(velocity, Vector2.ZERO, 0.2)
	
	if Input.is_action_just_pressed("attack"):
		# only in idle or run state, player can attack with input
		if state not in [PLAYER_STATE.IDLE, PLAYER_STATE.RUN]:
			return
		# change state based on combo attack progress
		match prev_attack_state:
			PLAYER_STATE.ATTACK_1:
				state = PLAYER_STATE.ATTACK_2
			PLAYER_STATE.ATTACK_2:
				state = PLAYER_STATE.ATTACK_3
			_:
				state = PLAYER_STATE.ATTACK_1
	
	move_and_collide(velocity * delta)

func take_damage(damage, source: Node2D):
	health = max(health - damage, 0)
	health_bar.value = float(health) / MAX_HEALTH * 100
	velocity = source.position.direction_to(position) * KNOCK_BACK_DISTANCE
	animation_player.play("hurt")
	state = PLAYER_STATE.HURT

func die():
	queue_free()
	
func set_state(new_state: PLAYER_STATE):
	var prev_state = state
	state = new_state
	
	# events that happen once during state change
	match prev_state:
		# disable collision shape of attack
		# on player attack finish / interrupt
		PLAYER_STATE.ATTACK_1:
			attack1_collision.disabled = true
			record_temp_prev_attack_state(prev_state)
		PLAYER_STATE.ATTACK_2:
			attack2_collision.disabled = true
			record_temp_prev_attack_state(prev_state)
			
		PLAYER_STATE.ATTACK_3:
			attack3_collision.disabled = true
			record_temp_prev_attack_state(prev_state)
		
		# to handle an edge case (player hurt while attacking)
		PLAYER_STATE.HURT:
			attack1_collision.disabled = true
			attack2_collision.disabled = true
			attack3_collision.disabled = true
	
	match new_state:
		PLAYER_STATE.IDLE:
			sprite.play("idle")
			velocity = Vector2.ZERO
		
		PLAYER_STATE.RUN:
			sprite.play("run")
		
		PLAYER_STATE.ATTACK_1:
			attack1_collision.disabled = false
			sprite.play("attack_1")
		
		PLAYER_STATE.ATTACK_2:
			attack2_collision.disabled = false
			sprite.play("attack_2")
		
		PLAYER_STATE.ATTACK_3:
			attack3_collision.disabled = false
			sprite.play("attack_3")
			
		PLAYER_STATE.HURT:
			sprite.play("hurt")
		
func record_temp_prev_attack_state(state: PLAYER_STATE):
	prev_attack_state = state
	prev_attack_state_timer.start() # to clear this temp record

func clear_prev_attack_state():
	prev_attack_state = PLAYER_STATE.IDLE

func _on_sprite_animation_finished() -> void:
	# means this state should end, switch back to (default) idle state
	if state in [PLAYER_STATE.ATTACK_1, PLAYER_STATE.ATTACK_2,
				PLAYER_STATE.ATTACK_3, PLAYER_STATE.HURT]:
		state = PLAYER_STATE.IDLE

func _on_attack_1_hitbox_body_entered(body: Node2D) -> void:
	if "enemy" in body.get_groups():
		body.take_damage(ATTACK_1_DAMAGE, self)


func _on_attack_2_hitbox_body_entered(body: Node2D) -> void:
	if "enemy" in body.get_groups():
		body.take_damage(ATTACK_2_DAMAGE, self)


func _on_attack_3_hitbox_body_entered(body: Node2D) -> void:
	if "enemy" in body.get_groups():
		body.take_damage(ATTACK_3_DAMAGE, self)


func _on_prev_attack_state_timer_timeout() -> void:
	clear_prev_attack_state()
