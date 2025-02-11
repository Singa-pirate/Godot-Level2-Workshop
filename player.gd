extends CharacterBody2D

const SPEED = 300.0
const ATTACK_COMMON_DAMAGE = 10
const ATTACK_3_DAMAGE = 20
# preserve prev attack state to facilitate combo attack
const PREV_ATTACK_STATE_RETENTION_SECONDS = 0.2 # before cleared

enum PLAYER_STATE { IDLE, RUN, ATTACK_1, ATTACK_2, ATTACK_3 }

@onready var state: PLAYER_STATE = PLAYER_STATE.IDLE : set = set_state

var prev_attack_state: PLAYER_STATE

@onready var sprite = $Sprite
@onready var attack1_collision = $Attack1_Hitbox/CollisionPolygon2D
@onready var attack2_collision = $Attack2_Hitbox/CollisionPolygon2D
@onready var attack3_collision = $Attack3_Hitbox/CollisionPolygon2D


func _physics_process(delta: float) -> void:
	
	if state in [PLAYER_STATE.IDLE, PLAYER_STATE.RUN]:
		var direction_x := Input.get_axis("ui_left", "ui_right")
		var direction_y = Input.get_axis("ui_up", "ui_down")
		
		if not direction_x and not direction_y:
			state = PLAYER_STATE.IDLE
		else:
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
		velocity = lerp(velocity, Vector2.ZERO, 0.05)
	
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

func set_state(new_state: PLAYER_STATE):
	state = new_state
	
	# events that happen once during state change
	match new_state:
		PLAYER_STATE.IDLE:
			velocity = Vector2.ZERO
			sprite.play("idle")
			attack1_collision.disabled = true
			attack2_collision.disabled = true
			attack3_collision.disabled = true
		
		PLAYER_STATE.RUN:
			sprite.play("run")
			attack1_collision.disabled = true
			attack2_collision.disabled = true
			attack3_collision.disabled = true
		
		PLAYER_STATE.ATTACK_1:
			sprite.play("attack_1")
			attack1_collision.disabled = false
		
		PLAYER_STATE.ATTACK_2:
			sprite.play("attack_2")
			attack2_collision.disabled = false
		
		PLAYER_STATE.ATTACK_3:
			sprite.play("attack_3")
			attack3_collision.disabled = false


func clear_prev_attack_state():
	prev_attack_state = PLAYER_STATE.IDLE

func _on_sprite_animation_finished() -> void:
	if state in [PLAYER_STATE.ATTACK_1, PLAYER_STATE.ATTACK_2, PLAYER_STATE.ATTACK_3]:
		prev_attack_state = state
		var timer = Timer.new()
		add_child(timer)
		timer.wait_time = PREV_ATTACK_STATE_RETENTION_SECONDS
		timer.one_shot = true
		timer.connect("timeout", clear_prev_attack_state)
		timer.start()
		
		state = PLAYER_STATE.IDLE


func _on_attack_1_hitbox_body_entered(body: Node2D) -> void:
	if "enemy" in body.get_groups():
		body.take_damage(ATTACK_COMMON_DAMAGE)


func _on_attack_2_hitbox_body_entered(body: Node2D) -> void:
	if "enemy" in body.get_groups():
		body.take_damage(ATTACK_COMMON_DAMAGE)


func _on_attack_3_hitbox_body_entered(body: Node2D) -> void:
	if "enemy" in body.get_groups():
		body.take_damage(ATTACK_3_DAMAGE)
