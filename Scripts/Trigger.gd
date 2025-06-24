extends Area2D

@export var turn_around_groups: Array[String] = ["enemy"]

func _ready() -> void:
	collision_layer = 2
	collision_mask = 3
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	for group in turn_around_groups:
		if body.has_method("change_direction"):
			body.change_direction()
		break
