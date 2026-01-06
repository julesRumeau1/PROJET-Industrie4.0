import paho.mqtt.client as mqtt
import json
import os
import threading
import time
# ====== CONFIG ======
MAX_HISTORY = 1000
MQTT_BROKER = "test.mosquitto.org"
MQTT_PORT = 1883
TOPICS = ["home/appart/cmd", "home/appart/state"]
STATE_FILE = "state.json"
SAVE_INTERVAL = 5
# ====================

lock = threading.Lock()
state = {}

# ------------------ Gestion état ------------------
def load_state():
    global state
    if os.path.exists(STATE_FILE):
        try:
            with open(STATE_FILE, "r") as f:
                state = json.load(f)
                print("State loaded:", state)
        except json.JSONDecodeError:
            print("State file corrupted, starting empty")
            state = {}
    else:
        save_state()

def save_state():
    with lock:
        with open(STATE_FILE, "w") as f:
            json.dump(state, f, indent=2)

def auto_save(interval=SAVE_INTERVAL):
    while True:
        time.sleep(interval)
        save_state()

# ------------------ MQTT ------------------
mqtt_client = None
mqtt_connected = False

def init_mqtt():
    global mqtt_client, mqtt_connected
    mqtt_client = mqtt.Client()

    def on_connect(client, userdata, flags, rc):
        global mqtt_connected
        mqtt_connected = True
        print("MQTT connected with result code", rc)
        for t in TOPICS:
            client.subscribe(t, qos=1)
            print("Subscribed to", t)

    def on_disconnect(client, userdata, rc):
        global mqtt_connected
        mqtt_connected = False
        print("MQTT disconnected, trying to reconnect...")
        try:
            client.reconnect()
        except Exception as e:
            print("Reconnect failed:", e)

    def on_message(client, userdata, msg):
        print(f"\nMessage received on topic '{msg.topic}': {msg.payload}")
        global state
        ts = time.time()
        try:
            payload = msg.payload.decode()
            try:
                data = json.loads(payload)
                data['ts'] = ts
            except json.JSONDecodeError:
                data = payload  # Garde la chaîne brute si JSON invalide
            with lock:
                if msg.topic not in state:
                    state[msg.topic] = []
                state[msg.topic].append(data)
                if len(state[msg.topic]) > MAX_HISTORY:
                    state[msg.topic].pop(0)  # supprime le plus ancien
            print("Updated state:", state[msg.topic])
        except Exception as e:
            print("Error processing message:", e)

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
    print("MQTT logger running...")
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        print("Exiting...")