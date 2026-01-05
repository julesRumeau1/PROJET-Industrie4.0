extends Node3D

@export var angle_open := 30.0
@export var speed := 0.1

var is_open := false
var target_angle := 0.0

# temporaire
func _ready():
	toggle()


func open():
	is_open = true
	target_angle = angle_open

func close():
	is_open = false
	target_angle = 0.0

func toggle():
	if is_open:
		close()
	else:
		open()

func _process(delta):
	rotation_degrees.y = lerp(
		rotation_degrees.y,
		target_angle,
		delta * speed
	)
