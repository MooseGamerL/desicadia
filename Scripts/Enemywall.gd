extends StaticBody2D

@export var turn_around_groups: Array[String] = ["enemy"]

func _ready() -> void:
	collision_layer = 4  
	collision_mask = 0 
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.bounce = 0
	connect("body_entered", Callable(self, "_on_body_entered"))

func _on_body_entered(body: Node) -> void:
	for group in turn_around_groups:
		if body.is_in_group(group):
			if body.has_method("change_direction"):
				body.change_direction()
			break
