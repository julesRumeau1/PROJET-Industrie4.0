extends Node3D

# --- Fenêtre ---
@export var angle_open := -30.0
@export var speed := 2.0

var is_open := false
var target_angle := -90.0


# --- MQTT ---
@export var mqtt_topic := "home/appart/state"
var MQTT_instance: Node = null

func _ready():
	# --- MQTT setup ---
	MQTT_instance = preload("res://addons/mqtt/mqtt.gd").new()
	add_child(MQTT_instance)

	MQTT_instance.broker_connected.connect(_on_mqtt_connected)
	MQTT_instance.broker_connection_failed.connect(_on_mqtt_failed)
	MQTT_instance.received_message.connect(_on_mqtt_message)

	MQTT_instance.connect_to_broker("tcp://test.mosquitto.org:1883/")

func _on_mqtt_connected():
	print("✅ Fenêtre connectée au MQTT")
	MQTT_instance.subscribe(mqtt_topic)
	print("📡 Souscrit au topic :", mqtt_topic)

func _on_mqtt_failed():
	print("❌ MQTT fenêtre : échec connexion")

func _on_mqtt_message(topic, message):
	if topic != mqtt_topic:
		return

	var msg = message.to_lower()
	print('message: ')
	#print(msg)
	#var parsed_msg = JSON.parse_string(msg)
	
	# --- OUVRIR ---
	#if parsed_msg['window'] == 0:
	#	if not is_open:
	#		open()
	#		print("🪟 Fenêtre ouverte")
	#	else:
	#		print("🪟 Fenêtre déjà ouverte")

	# --- FERMER ---
	#elif parsed_msg['window'] == 1:
	#	if is_open:
	#		close()
	#		print("🪟 Fenêtre fermée")
	#	else:
	#		print("🪟 Fenêtre déjà fermée")

	#else:
	#	print("Message MQTT invalide :", message)

# --- Actions fenêtre ---
func open():
	is_open = true
	target_angle = angle_open

func close():
	is_open = false
	target_angle = -90.0

func _process(delta):
	rotation_degrees.y = lerp(
		rotation_degrees.y,
		target_angle,
		delta * speed
	)


func _on_static_body_3d_input_event(camera: Node, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if (is_open):
			close()
		else:
			open()
