extends CharacterBody2D

#Variables
enum State {
	IDLE,
	WALKING,
	JUMPING,
	DOUBLE_JUMPING,
	FALLING,
	WALL_SLIDING,
	DASHING,
	WALL_JUMPING,
	SLAMMING,
	STICK
}

@export var double_jump_velocity := -550.0
@export var dash_duration := 0.2
@export var dash_speed := 600
@export var dash_cooldown := 0.95

var has_double_jump := true
var can_dash := true
var dash_direction := Vector2.RIGHT
var coyote_timer := 0.0
var jump_buffer_timer := 0.0
var dash_timer := 0.0

@onready var sprite := $AnimatedSprite2D

var current_state: State = State.IDLE
var previous_state: State = State.IDLE

func reset_dash():
	can_dash = true
	dash_timer = 0
	if current_state not in [State.WALL_SLIDING, State.WALL_JUMPING]:
		$CollisionShape2D.disabled = false
		$CollisionShape2D2.disabled = true
#State changing
func change_state(new_state: State):
	match current_state:
		State.DASHING, State.STICK:
			$CollisionShape2D.disabled = false
			$CollisionShape2D2.disabled = true
		
	previous_state = current_state
	current_state = new_state
		
	match new_state:
		State.IDLE:
			sprite.play("Idle")
		State.WALKING:
			has_double_jump = true
			reset_dash()
			sprite.play("Walk")
		State.JUMPING:
			sprite.play("Jump")
		State.DOUBLE_JUMPING:
			sprite.play("jump")
			velocity.y = double_jump_velocity
			has_double_jump = false
		State.DASHING:
			sprite.play("Dash")
		State.SLAMMING:
			sprite.play("Slam")
		State.STICK:
			sprite.play("Dash")
