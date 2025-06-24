extends CharacterBody2D

@export var speed: float = 100.0
@export var move_direction: Vector2 = Vector2.RIGHT
@export var turn_delay: float = 0.3
var turn_timer := 0.0

func _ready() -> void:
	add_to_group("enemy")
	collision_layer = 1
	collision_mask = 3

func _physics_process(delta: float) -> void:
	turn_timer = max(turn_timer - delta, 0.0)
	velocity = move_direction * speed
	move_and_slide()
	if is_on_wall() and turn_timer <= 0:
		change_direction()

func change_direction() -> void:
	if turn_timer > 0:
		return    
	move_direction *= -1
	turn_timer = turn_delay
	if has_node("Sprite2D"):
		$Sprite2D.flip_h = not $Sprite2D.flip_h
