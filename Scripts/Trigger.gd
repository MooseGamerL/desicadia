extends Area2D

@export var turn_around_groups: Array[String] = ["enemy"]

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("enemy"):
		if body.has_method("change_direction"):
			body.change_direction()
