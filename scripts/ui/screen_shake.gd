class_name ScreenShake
extends Node

## Hệ thống rung lắc màn hình (Screen Shake) tăng cảm giác va đập (Game Feel)
## Sử dụng cơ chế Trauma lũy thừa bậc 2 (Trauma-based screen shake)

@export var target_node: Control
@export var max_offset: Vector2 = Vector2(16.0, 16.0)
@export var max_roll: float = 0.05
@export var decay: float = 2.5

var trauma: float = 0.0
var trauma_power: float = 2.0
var original_position: Vector2 = Vector2.ZERO
var original_rotation: float = 0.0
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	if target_node:
		original_position = target_node.position
		original_rotation = target_node.rotation

func _process(delta: float) -> void:
	if not target_node:
		return
		
	if trauma > 0.0:
		trauma = maxf(0.0, trauma - decay * delta)
		_apply_shake()
	elif target_node.position != original_position or target_node.rotation != original_rotation:
		target_node.position = original_position
		target_node.rotation = original_rotation

func add_trauma(amount: float) -> void:
	trauma = minf(1.0, trauma + amount)

func _apply_shake() -> void:
	var shake_amount := pow(trauma, trauma_power)
	var offset_x := max_offset.x * shake_amount * rng.randf_range(-1.0, 1.0)
	var offset_y := max_offset.y * shake_amount * rng.randf_range(-1.0, 1.0)
	var angle := max_roll * shake_amount * rng.randf_range(-1.0, 1.0)
	
	target_node.position = original_position + Vector2(offset_x, offset_y)
	target_node.rotation = original_rotation + angle
