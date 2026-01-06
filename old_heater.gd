extends Node3D

# --- Variables exportées ---
@export var light_node : OmniLight3D  # Référence à la lumière du radiateur
@export var mqtt_topic := "home/appart/cmd"  # Topic MQTT à écouter

# --- Etat de la lumière ---
var is_on := true

# --- MQTT ---
var MQTT_instance: Node = null
var mqtt_connected := false
func _ready():
	# Récupérer la lumière si non assignée
	if not light_node:
		light_node = $OmniLight3D
	if light_node:
		light_node.visible = is_on
	else:
		push_error("Erreur : light_node non assigné !")

	# --- Configuration MQTT ---
	MQTT_instance = preload("res://addons/mqtt/mqtt.gd").new()
	add_child(MQTT_instance)

	# Connexion aux signaux MQTT
	MQTT_instance.broker_connected.connect(_on_mqtt_connected)
	MQTT_instance.broker_connection_failed.connect(_on_mqtt_failed)
	MQTT_instance.received_message.connect(_on_mqtt_message)

	# Connexion au broker MQTT
	MQTT_instance.connect_to_broker("tcp://test.mosquitto.org:1883/")

# --- Signaux MQTT ---
func _on_mqtt_connected():
	print("✅ Heater Connecté au broker MQTT")
	mqtt_connected = true
	MQTT_instance.subscribe(mqtt_topic)
	print("Souscrit au topic:", mqtt_topic)

func _on_mqtt_failed():
	print("❌ Échec de connexion au broker MQTT")

func _on_mqtt_message(topic, message):
	if topic != mqtt_topic:
		return  # Ignorer les autres topics
	
	# Convertir le message en booléen
	# On accepte "1"/"on" comme allumé, "0"/"off" comme éteint
	var msg_lower = message.to_lower()
	if msg_lower == "1" or msg_lower == "on":
		is_on = true
	elif msg_lower == "0" or msg_lower == "off":
		is_on = false
	else:
		print("Message MQTT invalide:", message)
		return

	# Appliquer l'état à la lumière
	if light_node:
		light_node.visible = is_on
		print("💡 Lumière radiateur :", is_on)

# --- Méthode pour toggle manuel si nécessaire ---
func toggle_heater():
	is_on = !is_on
	if light_node:
		light_node.visible = is_on
	if MQTT_instance == null or not mqtt_connected:
		return
	var payload = JSON.stringify({"heater": is_on})
	MQTT_instance.publish(mqtt_topic, payload, true)
	print("📤 MQTT state:", payload)


func _on_static_body_3d_input_event(camera: Node, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		toggle_heater()
