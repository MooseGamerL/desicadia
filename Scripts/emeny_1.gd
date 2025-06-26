extends CharacterBody2D

@export var speed: float = 100.0
@export var move_direction: Vector2 = Vector2.RIGHT
@export var turn_delay: float = 0.3
@export var gravity: float = 980.0
@export var max_fall_speed: float = 400.0

var turn_timer := 0.0
var trigger_turn_cooldown := 0.0

func _physics_process(delta: float) -> void:
	turn_timer = max(turn_timer - delta, 0.0)
	trigger_turn_cooldown = max(trigger_turn_cooldown - delta, 0.0)
	if not is_on_floor():
		velocity.y += gravity * delta
		velocity.y = min(velocity.y, max_fall_speed)
	velocity.x = move_direction.x * speed
	move_and_slide()
	if (is_on_wall() or trigger_turn_cooldown > 0) and turn_timer <= 0:
		_change_direction()
		turn_timer = turn_delay
		trigger_turn_cooldown = 0.0

func _ready():
	collision_layer = 1
	collision_mask = 5 

func _change_direction() -> void:
	move_direction *= -1
	if has_node("Sprite2D"):
		$Sprite2D.flip_h = not $Sprite2D.flip_h
