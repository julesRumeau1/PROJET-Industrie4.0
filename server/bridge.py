import paho.mqtt.client as mqtt
import json
import os
import threading
import time
import requests

# ====== CONFIG ======
MAX_HISTORY = 1000

MQTT_BROKER = "test.mosquitto.org"
MQTT_PORT = 1883

TOPICS = [
    "home/appart/cmd",
    "home/appart/state"
]

WEATHER_TOPIC = "weather/rodez"
WEATHER_INTERVAL = 600  # 10 minutes

STATE_FILE = "state.json"
WEATHER_FILE = "weather_history.json"
SAVE_INTERVAL = 5

LAT, LON = 44.33, 2.56

HEATER_CMD_TOPIC = "home/appart/cmd"

TEMP_ON = 14
TEMP_OFF = 20.0



# ====================

lock = threading.Lock()
state = {}
weather_history = []

mqtt_client = None
mqtt_connected = False

# ------------------ Chargement fichiers ------------------
def load_json_file(path, default):
    if os.path.exists(path):
        try:
            with open(path, "r") as f:
                return json.load(f)
        except json.JSONDecodeError:
            print(f"{path} corrupted, starting empty")
    return default

def save_json_file(path, data):
    with open(path, "w") as f:
        json.dump(data, f, indent=2)

def load_state():
    global state, weather_history

    state = load_json_file(STATE_FILE, {})
    weather_history = load_json_file(WEATHER_FILE, [])

    # SÉCURITÉ DE TYPE
    if not isinstance(weather_history, list):
        print("weather_history was not a list, resetting")
        weather_history = []

    print("State and weather history loaded")


def auto_save():
    while True:
        time.sleep(SAVE_INTERVAL)
        with lock:
            save_json_file(STATE_FILE, state)
            save_json_file(WEATHER_FILE, weather_history)

# ------------------ Météo (Open-Meteo) ------------------
def fetch_weather():
    url = "https://api.open-meteo.com/v1/forecast"
    params = {
        "latitude": LAT,
        "longitude": LON,
        "current": [
            "precipitation",
            "rain",
            "snowfall",
            "cloudcover",
            "windspeed_10m",
            "temperature_2m"
        ]
    }

    r = requests.get(url, params=params, timeout=10)
    r.raise_for_status()
    data = r.json()["current"]

    return {
        "rain_mm": data.get("rain", 0.0),
        "precipitation": data.get("precipitation", 0.0),
        "snow_mm": data.get("snowfall", 0.0),
        "clouds": data.get("cloudcover", 0),
        "wind": data.get("windspeed_10m", 0.0),
        "temp": data.get("temperature_2m", 0.0),
        "ts": int(time.time())
    }

def heater_control(weather):
    heater_on = 0
    temp = weather.get("temp")
    if temp is None:
        return

    # Décision avec hystérésis
    if temp <= TEMP_ON:
        heater_on = True

    elif temp >= TEMP_OFF:
        heater_on = False

    # Envoi MQTT (si connecté)
    if mqtt_connected:
        payload = json.dumps({"heater": heater_on})
        mqtt_client.publish(
            HEATER_CMD_TOPIC,
            payload,
            qos=1,
            retain=True
        )

        print("Heater cmd sent:", payload)



def weather_publisher():
    global mqtt_client, mqtt_connected

    print("Weather publisher thread started")

    while True:
        try:
            payload = fetch_weather()
            heater_control(payload)
            # Sauvegarde météo TOUJOURS
            with lock:
                weather_history.append(payload)
                if len(weather_history) > MAX_HISTORY:
                    weather_history.pop(0)

            # Publication MQTT SI connecté
            if mqtt_connected:
                mqtt_client.publish(
                    WEATHER_TOPIC,
                    json.dumps(payload),
                    qos=1,
                    retain=True
                )
                print("Weather published to MQTT:", payload)
            else:
                print("MQTT not connected, weather saved only")

        except Exception as e:
            print("Weather error:", e)

        time.sleep(WEATHER_INTERVAL)


# ------------------ MQTT ------------------
def init_mqtt():
    global mqtt_client, mqtt_connected

    mqtt_client = mqtt.Client()

    def on_connect(client, userdata, flags, rc):
        global mqtt_connected
        mqtt_connected = True
        print("MQTT connected:", rc)
        for t in TOPICS:
            client.subscribe(t, qos=1)
            print("Subscribed to", t)

    def on_disconnect(client, userdata, rc):
        global mqtt_connected
        mqtt_connected = False
        print("MQTT disconnected, reconnecting...")
        try:
            client.reconnect()
        except Exception as e:
            print("Reconnect failed:", e)

    def on_message(client, userdata, msg):
        ts = time.time()
        try:
            payload = msg.payload.decode()
            try:
                data = json.loads(payload)
            except json.JSONDecodeError:
                data = {"raw": payload}

            data["ts"] = ts

            with lock:
                if msg.topic not in state or not isinstance(state[msg.topic], list):
                    state[msg.topic] = []

                    state[msg.topic].append(data)

                if len(state[msg.topic]) > MAX_HISTORY:
                    state[msg.topic].pop(0)
            print(f"Message [{msg.topic}]:", data)

        except Exception as e:
            print("Message error:", e)

    mqtt_client.on_connect = on_connect
    mqtt_client.on_disconnect = on_disconnect
    mqtt_client.on_message = on_message

    mqtt_client.connect_async(MQTT_BROKER, MQTT_PORT, 60)
    mqtt_client.loop_start()

# ------------------ Main ------------------
if __name__ == "__main__":
    load_state()

    threading.Thread(target=auto_save, daemon=True).start()
    init_mqtt()
    threading.Thread(target=weather_publisher, daemon=True).start()

    print("MQTT + Open-Meteo + weather logging running")

    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        print("Exiting...")
