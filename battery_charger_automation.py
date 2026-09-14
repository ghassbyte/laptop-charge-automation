#!/usr/bin/env python3
"""
Laptop battery -> Sonoff S20 (Tasmota/MQTT) charging automation.

Modes (controlled via a retained MQTT topic, see MODE_TOPIC below):
  auto      -> hysteresis: turn ON at/below LOW_THRESHOLD, OFF at/above
               HIGH_THRESHOLD, leave unchanged in between.
  force_on  -> ignore battery %, always keep the relay ON
               (use this for gaming sessions where you want power at all times).

Requires:
    pip install paho-mqtt psutil

Works with any MQTT broker. Since the S20 sits on a mobile hotspot whose IP
changes, point both this script and the Tasmota device at the SAME broker
hostname (a small free cloud broker like HiveMQ Cloud / EMQX Cloud is the
simplest option) rather than at each other's IPs.
"""

import time
import logging
import psutil
import paho.mqtt.client as mqtt

# ---------------- CONFIG ----------------
# Local Mosquitto broker running on this same laptop. No internet needed:
# the S20 (on your hotspot) connects to this laptop's hotspot IP, and this
# script talks to the broker over localhost.
MQTT_HOST = "127.0.0.1"
MQTT_PORT = 1883
MQTT_USER = "palzilla"
MQTT_PASS = "palzilla"
USE_TLS = False

TASMOTA_TOPIC = "sonoff_s20"        # must match "Topic" set in Tasmota console
CMND_POWER = f"cmnd/{TASMOTA_TOPIC}/POWER"
STAT_POWER = f"stat/{TASMOTA_TOPIC}/POWER"

MODE_TOPIC = "home/laptop_charger/mode"   # publish "auto" or "force_on" here (retained)

LOW_THRESHOLD = 20     # % - turn charger ON at/below this
HIGH_THRESHOLD = 80    # % - turn charger OFF at/above this
POLL_SECONDS = 60

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(message)s")

state = {"mode": "auto", "relay": None}


def on_connect(client, userdata, flags, rc, properties=None):
    logging.info("Connected to MQTT broker (rc=%s)", rc)
    client.subscribe(MODE_TOPIC)
    client.subscribe(STAT_POWER)
    # ask the plug for its current state on startup
    client.publish(f"cmnd/{TASMOTA_TOPIC}/POWER", "")


def on_message(client, userdata, msg):
    payload = msg.payload.decode().strip()
    if msg.topic == MODE_TOPIC:
        if payload in ("auto", "force_on"):
            if payload != state["mode"]:
                logging.info("Mode changed: %s -> %s", state["mode"], payload)
            state["mode"] = payload
        else:
            logging.warning("Ignoring unknown mode payload: %r", payload)
    elif msg.topic == STAT_POWER:
        state["relay"] = payload


def set_power(client, on: bool):
    desired = "ON" if on else "OFF"
    if state["relay"] != desired:
        client.publish(CMND_POWER, desired, qos=1)
        logging.info("Publishing %s (previous state: %s)", desired, state["relay"])
        # optimistic local update; will be confirmed by STAT_POWER message
        state["relay"] = desired


def build_client():
    client = mqtt.Client(callback_api_version=mqtt.CallbackAPIVersion.VERSION2)
    client.username_pw_set(MQTT_USER, MQTT_PASS)
    if USE_TLS:
        client.tls_set()
    client.on_connect = on_connect
    client.on_message = on_message
    return client


def main():
    client = build_client()
    client.connect(MQTT_HOST, MQTT_PORT, keepalive=60)
    client.loop_start()

    try:
        while True:
            batt = psutil.sensors_battery()
            if batt is None:
                logging.warning("No battery info available (desktop / VM?)")
            else:
                pct = batt.percent
                if state["mode"] == "force_on":
                    set_power(client, True)
                else:
                    if pct <= LOW_THRESHOLD:
                        set_power(client, True)
                    elif pct >= HIGH_THRESHOLD:
                        set_power(client, False)
                    # else: within the band -> leave relay as-is (hysteresis)
                logging.info(
                    "battery=%.0f%% mode=%s relay=%s",
                    pct, state["mode"], state["relay"],
                )
            time.sleep(POLL_SECONDS)
    except KeyboardInterrupt:
        logging.info("Stopping.")
    finally:
        client.loop_stop()
        client.disconnect()


if __name__ == "__main__":
    main()
