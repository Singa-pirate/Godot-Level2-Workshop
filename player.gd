extends CharacterBody2D

const MAX_HEALTH = 100
const KNOCK_BACK_DISTANCE = 200
const SPEED = 300.0
const ATTACK_1_DAMAGE = 5
const ATTACK_2_DAMAGE = 10
const ATTACK_3_DAMAGE = 20

enum PLAYER_STATE { IDLE, RUN, ATTACK_1, ATTACK_2, ATTACK_3, HURT }

@onready var state: PLAYER_STATE = PLAYER_STATE.IDLE : set = set_state

var prev_attack_state: PLAYER_STATE

@onready var health = MAX_HEALTH
@onready var sprite = $Sprite
@onready var animation_player = $AnimationPlayer
@onready var attack1_collision = $Attack1_Hitbox/CollisionPolygon2D
@onready var attack2_collision = $Attack2_Hitbox/CollisionPolygon2D
@onready var attack3_collision = $Attack3_Hitbox/CollisionPolygon2D
# preserve prev attack state to facilitate combo attack
@onready var prev_attack_state_timer = $prev_attack_state_timer


func _physics_process(delta: float) -> void:
	var direction_x := Input.get_axis("ui_left", "ui_right")
	var direction_y = Input.get_axis("ui_up", "ui_down")
	
	if state == PLAYER_STATE.IDLE and (direction_x or direction_y):
		state = PLAYER_STATE.RUN
	elif state == PLAYER_STATE.RUN and not (direction_x or direction_y):
		state = PLAYER_STATE.IDLE
		
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
		velocity = lerp(velocity, Vector2.ZERO, 0.2)
	
	if Input.is_action_just_pressed("attack"):
		if state not in [PLAYER_STATE.IDLE, PLAYER_STATE.RUN]:
			return
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
	velocity = source.position.direction_to(position) * KNOCK_BACK_DISTANCE
	animation_player.play("hurt")
	state = PLAYER_STATE.HURT
	
	
func set_state(new_state: PLAYER_STATE):
	var prev_state = state
	state = new_state
	
	match prev_state:
		PLAYER_STATE.ATTACK_1:
			attack1_collision.disabled = true
			record_temp_prev_attack_state(prev_state)
		PLAYER_STATE.ATTACK_2:
			attack2_collision.disabled = true
			record_temp_prev_attack_state(prev_state)
			
		PLAYER_STATE.ATTACK_3:
			attack3_collision.disabled = true
			record_temp_prev_attack_state(prev_state)
			
	
	# events that happen once during state change
	match new_state:
		PLAYER_STATE.IDLE:
			velocity = Vector2.ZERO
			sprite.play("idle")
		
		PLAYER_STATE.RUN:
			sprite.play("run")
		
		PLAYER_STATE.ATTACK_1:
			sprite.play("attack_1")
			attack1_collision.disabled = false
		
		PLAYER_STATE.ATTACK_2:
			sprite.play("attack_2")
			attack2_collision.disabled = false
		
		PLAYER_STATE.ATTACK_3:
			sprite.play("attack_3")
			attack3_collision.disabled = false
			
		PLAYER_STATE.HURT:
			sprite.play("hurt")

func record_temp_prev_attack_state(state: PLAYER_STATE):
	prev_attack_state = state
	prev_attack_state_timer.start()

func clear_prev_attack_state():
	prev_attack_state = PLAYER_STATE.IDLE

func _on_sprite_animation_finished() -> void:
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
