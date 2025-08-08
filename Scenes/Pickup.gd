extends Area2D

@export var pickup_groups: Array[String] = ["player"]

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
