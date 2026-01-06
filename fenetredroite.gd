extends Node3D

@export var speed := 2.0
var is_open := false

# MQTT topics
@export var mqtt_cmd_topic := "home/appart/cmd"
@export var mqtt_state_topic := "home/appart/state"

var MQTT_instance: Node = null
var mqtt_connected := false

func _ready():
	MQTT_instance = preload("res://addons/mqtt/mqtt.gd").new()
	add_child(MQTT_instance)

	MQTT_instance.broker_connected.connect(_on_mqtt_connected)
	MQTT_instance.broker_connection_failed.connect(_on_mqtt_failed)
	MQTT_instance.received_message.connect(_on_mqtt_message)

	MQTT_instance.connect_to_broker("tcp://test.mosquitto.org:1883/")

func _on_mqtt_connected():
	print("✅ Fenêtre connectée au MQTT")
	mqtt_connected = true
	MQTT_instance.subscribe(mqtt_state_topic)
	publish_state() # resync

func _on_mqtt_failed():
	print("❌ MQTT fenêtre : échec connexion")
	mqtt_connected = false

func _on_mqtt_message(topic, message):
	if topic != mqtt_state_topic:
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


func publish_state():
	if MQTT_instance == null or not mqtt_connected:
		return
	var payload = JSON.stringify({"window": is_open})
	MQTT_instance.publish(mqtt_cmd_topic, payload, true)
	print("📤 MQTT state:", payload)

func open():
	if is_open:
		return
	is_open = true
	publish_state()
	print("🪟 Fenêtre ouverte")

func close():
	if not is_open:
		return
	is_open = false
	publish_state()
	print("🪟 Fenêtre fermée")

func toggle():
	if is_open:
		close()
	else:
		open()

func _process(delta):
	rotation_degrees.y = lerp(
		rotation_degrees.y,
		90.0 if not is_open else 30.0,  # juste open/close
		delta * speed
	)

func _on_static_body_3d_input_event(camera: Node, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		toggle()
