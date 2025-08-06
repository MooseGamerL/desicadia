#Code for an enemy only wall
extends Area2D

#Only group that turns around is the enemy.
@export var turn_around_groups: Array[String] = ["enemy"]

#Sets the collision layer and mask so only enemies can touch it
func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(_on_body_entered)

#This function makes enemies reverse direction when colliding with the trigger.
func _on_body_entered(body: Node) -> void:
	if body.is_in_group("enemy"):
		if body.has_method("change_direction"):
			body.change_direction()
