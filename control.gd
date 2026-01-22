extends Node3D

# --- UI ---
@onready var temperature_label: Label = $Label
@onready var weather_label: Label = $Label2

# --- MQTT ---
@export var mqtt_topic_state := "home/appart/state"
@export var mqtt_topic_weather := "weather/rodez"
var MQTT_instance: Node = null
var mqtt_connected := false

func _ready():
	print("Température : --")
	print($Label)
	# Vérification UI
	if temperature_label == null:
		push_error("❌ TemperatureLabel introuvable dans la scène")
		return

	$Label.text = "Température : --"
	$Label2.text = "Température extérieure : --"

	# --- MQTT ---
	MQTT_instance = preload("res://addons/mqtt/mqtt.gd").new()
	add_child(MQTT_instance)

	MQTT_instance.broker_connected.connect(_on_mqtt_connected)
	MQTT_instance.broker_connection_failed.connect(_on_mqtt_failed)
	MQTT_instance.received_message.connect(_on_mqtt_message)

	MQTT_instance.connect_to_broker("tcp://10.45.195.118:1883/")

# --- MQTT callbacks ---
func _on_mqtt_connected():
	print("✅ UI connectée au broker MQTT")
	mqtt_connected = true
	MQTT_instance.subscribe(mqtt_topic_state)
	MQTT_instance.subscribe(mqtt_topic_weather)

func _on_mqtt_failed():
	print("❌ Échec connexion MQTT (UI)")

func _on_mqtt_message(topic: String, message: String) -> void:
	print("Message : ", message)
	if topic == mqtt_topic_state:
		var parsed_msg = JSON.parse_string(message)
		# Extraction simple de la température (sans JSON)
		var temp = parsed_msg['temperature']
		temperature_label.text = "Température : " + str(temp)
	if topic == mqtt_topic_weather:
		var parsed_msg = JSON.parse_string(message)
		var temp = parsed_msg['temp']
		weather_label.text = "Température extérieure : " + str(temp)
