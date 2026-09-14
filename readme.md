# Automated Laptop Charging — Sonoff S20 + Tasmota + MQTT

A fully local (no cloud, no internet) setup that turns my laptop charger on/off
based on battery level, using a Tasmota-flashed Sonoff S20 smart plug. Includes
a manual override for gaming sessions where the charger should just stay on.

## The idea

- Battery ≤ 20% → plug turns **ON**
- Battery ≥ 80% → plug turns **OFF**
- Between 20–80% → leave the plug alone (hysteresis, so it doesn't flip-flop)
- **Gaming override**: force the plug **ON** regardless of battery %

## References / where I learned this

- Tasmota official docs for the Sonoff S20 (flashing, GPIO template, initial setup): [tasmota.github.io/docs/devices/Sonoff-S20](https://tasmota.github.io/docs/devices/Sonoff-S20/)
- CH340 USB-to-serial driver (needed to flash the S20 over USB): [sparks.gogo.co.nz/ch340.html](https://sparks.gogo.co.nz/ch340.html)
  - ⚠️ The **latest** driver version didn't work for me — use the specific driver version linked on that page instead.

## Why local-only works here

The S20 sits on my laptop's mobile hotspot, and the *S20's* IP can change
whenever it reconnects. But since my **laptop is the one hosting the
hotspot**, my laptop's own address on that network is fixed — it's the
gateway IP (`192.168.137.1` for Windows Mobile Hotspot). So instead of
chasing IPs, everything talks through a small MQTT broker running on the
laptop itself:

```
[S20 / Tasmota]  --MQTT-->  [Mosquitto broker, on laptop, 192.168.137.1:1883]  <--MQTT--  [Python daemon, on laptop]
```

- The S20 always finds the broker at the same fixed hotspot gateway IP.
- The Python daemon talks to the broker over `127.0.0.1` (same machine).
- No internet, no cloud broker, nothing leaves the laptop.

## Components

| File | Purpose |
|---|---|
| `laptop-charge-automation.py` | Reads battery %, applies the 20/80 hysteresis logic, publishes ON/OFF to the S20 over MQTT. Also listens for mode changes (`auto` / `force_on`). |
| Mosquitto (installed separately) | Local MQTT broker. Configured with a username/password, no anonymous access. |
| `batt_monitor.bat` | The one button I press at the start of the day. Self-elevates to admin, prompts me to confirm the hotspot is on, starts the broker + daemon **hidden in the background** (no windows, no taskbar clutter), and sets mode to `auto`. |
| `game.bat` | Publishes `force_on` — charger stays on regardless of battery, for gaming sessions. |
| `stop_batt_monitor.bat` | Kills the background broker + daemon when I want everything off. Self-elevates too. |
| `run_hidden.vbs` | Small helper — launches a command with no visible window at all (used internally by `batt_monitor.bat`). |
| `start_mosquitto.bat` / `start_batt_daemon.bat` | Internal "worker" scripts that actually launch Mosquitto / the Python daemon. Not run directly — only ever called hidden by `batt_monitor.bat`. |
| `start_daemon.ps1` | Internal helper called by `start_batt_daemon.bat` — launches the daemon fully detached/hidden and writes its PID to `batt_monitor.pid`. |
| `batt_monitor.pid` | Generated at runtime — PID of the currently running daemon launcher process. Used by `batt_monitor.bat` (to know whether the daemon is already running) and `stop_batt_monitor.bat` (to kill exactly that process). Safe to delete when nothing is running. |

All the batch/vbs files live together in one folder — `batt_monitor.bat` finds
its siblings automatically using its own folder path.

## One-time setup

### 1. Tasmota / S20
- Flash Tasmota (already done).
- Configure MQTT in the Tasmota web console:
  - Host: `192.168.137.1` (the hotspot gateway IP — check with `ipconfig`, look for the hotspot virtual adapter)
  - Port: `1883`
  - User / Password: matches the Mosquitto password file
  - Topic: `sonoff_s20`

### 2. Mosquitto broker
- Install Mosquitto on Windows.
- Create a password file:
  ```
  mosquitto_passwd.exe -c pwfile.txt YOUR_USERNAME
  ```
- `mosquitto.conf`:
  ```
  listener 1883
  allow_anonymous false
  password_file C:\Program Files\mosquitto\pwfile.txt
  ```

### 3. Firewall
So the S20 (a different device on the hotspot network) can actually reach the broker:
```powershell
New-NetFirewallRule -DisplayName "Mosquitto MQTT" -Direction Inbound -Protocol TCP -LocalPort 1883 -Action Allow -Profile Any
```
(`Any` profile matters — Windows often classifies the Mobile Hotspot adapter as "Public", so a rule scoped to "Private" silently doesn't apply.)

### 4. Python daemon
```
pip install paho-mqtt psutil
```
Config lives at the top of `laptop-charge-automation.py`: broker host/port/credentials, the Tasmota topic, and the 20/80 thresholds.

### 5. Batch files
Fill in the placeholder values at the top of each `.bat`:
- `MOSQUITTO_DIR`, `MQTT_USER`, `MQTT_PASS`
- `SCRIPT_PATH` inside `start_batt_daemon.bat`

## Daily usage

1. **Start of day** → double-click `batt_monitor.bat` → click "Yes" on the UAC prompt → confirm the hotspot is on → it silently spins up the broker + daemon in the background and sets mode to `auto`. Window closes itself after a few seconds.
2. **Gaming session** → double-click `game.bat` → charger forced ON regardless of battery.
3. **Back to normal** → double-click `batt_monitor.bat` again — it detects the broker/daemon are already running, skips restarting them, and just flips the mode back to `auto`.
4. **Shutting everything down** → double-click `stop_batt_monitor.bat`.

## How mode switching actually works

The daemon subscribes to a retained MQTT topic, `home/laptop_charger/mode`.
`batt_monitor.bat` and `game.bat` are really just thin wrappers around:
```
mosquitto_pub.exe -h 127.0.0.1 -p 1883 -u USER -P PASS -t home/laptop_charger/mode -m auto -r
mosquitto_pub.exe -h 127.0.0.1 -p 1883 -u USER -P PASS -t home/laptop_charger/mode -m force_on -r
```
The `-r` (retain) flag means the mode persists even across a daemon restart.

## Logs

Since everything runs hidden with no visible console, output goes to files instead:
- `mosquitto_log.txt` — next to `mosquitto.exe`
- `batt_monitor_log.txt` — next to `laptop-charge-automation.py`

Check these if something seems off (e.g. "battery=100% mode=auto relay=OFF" lines confirm it's working correctly).

## Troubleshooting

### S20 stuck retrying MQTT: `Connect failed to 192.168.137.1:1883, rc -2`

`rc -2` from Tasmota means the TCP connection itself failed — the S20 couldn't
even open a socket to the broker, as opposed to an auth error (which shows up
as `rc 4`/`rc 5` instead). If the S20's console shows this in a loop (Wi-Fi
otherwise connected fine, good RSSI), and Mosquitto looks correctly configured
on the laptop (listening on `0.0.0.0:1883`, firewall rule present, works fine
when tested locally via `mosquitto_sub.exe`), check the **Windows Firewall
profile policy**, not just the per-app rule:

```powershell
Get-NetFirewallProfile | Select-Object Name, AllowInboundRules
```

If `AllowInboundRules` is `False` for the active profile (usually **Public**,
since Windows tends to classify the Mobile Hotspot adapter as Public), that's
Windows Security's **"Block all incoming connections, including those in the
list of allowed apps"** toggle. When it's on, it silently overrides *every*
inbound Allow rule — including the Mosquitto one from setup step 3 — even
though the rule itself looks perfectly correct. This is different from (and
in addition to) the Any-vs-Private profile scoping issue mentioned in setup
step 3.

Loopback connections to the broker (e.g. `mosquitto_sub.exe -h 192.168.137.1`
run from the laptop itself, or the Python daemon connecting over
`127.0.0.1`) keep working even with this toggle on, since loopback traffic
isn't subject to it — that's what makes this failure mode confusing: the
broker looks completely healthy from the laptop while every external device
gets refused.

**Fix**: Windows Security → Firewall & network protection → click the active
network (e.g. **Public network**) → turn off "Block all incoming
connections, including those in the list of allowed apps." The S20 should
connect within its next retry cycle (backoff grows up to ~120s, so give it a
couple of minutes).

## Known caveats

- `batt_monitor.bat`'s "already running" check and `stop_batt_monitor.bat`'s stop both use the tracked PID in `batt_monitor.pid`, not a generic `python.exe` scan — this avoids false positives from unrelated `python.exe` processes (VS Code's Python extension language servers, Jupyter, etc.). If `batt_monitor.pid` is ever missing or stale, `stop_batt_monitor.bat` falls back to killing all `python.exe`, which **will** hit unrelated Python processes.
- The Mobile Hotspot toggle itself isn't automated — Windows doesn't expose a simple, reliable command-line switch for it, so `batt_monitor.bat` just opens the settings page and waits for a keypress.
- UAC prompt still appears on `batt_monitor.bat` / `stop_batt_monitor.bat` — that's a Windows security boundary that can't be silently bypassed by a script without a pre-configured Scheduled Task (possible future upgrade if a zero-click experience is wanted).

## Possible future improvements

- Move the Mobile Hotspot toggle into a Scheduled Task for full silent auto-elevation.
- Add a low-battery notification separate from the charger automation.