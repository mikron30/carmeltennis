# ESP32 physical video button

This firmware sends a signed request to the existing Carmel Tennis physical
button endpoint. It is intended for a classic **ESP32-WROOM-32 DevKit**. If the
module is marked C3, S2, S3, C6, or something else, confirm that board's GPIO
layout before wiring it.

The physical path is intentionally different from the manager's manual form:
it does not accept a chosen email or past time. On a press, the server uses its
current Israel time, finds the active reservation for the configured court,
and sends the forty seconds immediately before the server-recorded press to the
two registered players.

Reservation lookup uses the current court/hour, then the previous hour, then
the next hour. The 21:00-22:00 players remain selected until 22:30. When the
current or next reservation is selected, presses during the first 40 seconds
of an hour are rejected because the requested interval would cross into the
previous reservation.

## 1. Wire the button

Disconnect USB power first. Use a normally-open momentary button:

```text
ESP32-WROOM-32 DevKit       Momentary N.O. button
GPIO27  ------------------- one terminal
GND     ------------------- other terminal
```

The firmware uses `INPUT_PULLUP`, so released is HIGH and pressed is LOW. No
external resistor is needed for short indoor prototype wires. On a four-leg
tactile switch, use one leg from each side of the center gap; the two legs on
one side are normally already connected.

Optional status LED:

```text
GPIO26 ---- 470 ohm resistor ---- LED anode (+, long leg)
GND    -------------------------- LED cathode (-, short/flat side)
```

GPIO25, 26, 32, or 33 are reasonable button alternatives on the classic board.
Avoid GPIO0, 2, 5, 12, and 15 (boot-strapping), GPIO1 and 3 (serial), GPIO6-11
(flash), and GPIO34-39 (no internal pull-up). ESP32 GPIO is **3.3 V only**;
never connect this input to 5 V.

For a long/outdoor cable, use a twisted GPIO/GND pair, an external 4.7-10 kOhm
pull-up to 3.3 V, ESD/surge protection, a weatherproof enclosure, and preferably
an isolated dry-contact input. Keep it away from mains wiring.

## 2. Provision one device

The live Firebase secret currently needs a real per-device entry. On the
project machine, run PowerShell from the repository root. Choose the physical
court deliberately:

```powershell
powershell -ExecutionPolicy Bypass -File .\firmware\esp32_video_button\provision-device.ps1 `
  -DeviceId court-1-button `
  -CourtNumber 1
```

When provisioning another court on the same Wi-Fi, reuse the credentials from
the existing ignored `device_config.h` without showing or retyping them:

```powershell
powershell -ExecutionPolicy Bypass -File .\firmware\esp32_video_button\provision-device.ps1 `
  -DeviceId court-2-button `
  -CourtNumber 2 `
  -ReuseWifiFromConfig
```

This preserves every previously registered device in Secret Manager, but the
local `device_config.h` is replaced with the most recently provisioned device.

Without `-ReuseWifiFromConfig`, the script prompts for the 2.4 GHz Wi-Fi
credentials without echoing the password. It generates a random device key,
preserves other device entries, publishes a new Secret Manager version,
redeploys only `requestVideoClip`, and creates the ignored `device_config.h`
used by the sketch. It never prints the device key. The computer must already
be authenticated with `gcloud.cmd` and `firebase.cmd` for project
`potent-howl-228108`.

Do not rerun with the same device ID unless intentionally rotating its key;
that requires `-Rotate` and makes the previously flashed firmware stop working.
Use a unique device ID/key for every physical ESP32.

Manual alternative: copy `device_config.example.h` to `device_config.h`, fill
in the values, add the exact same device ID/key/court mapping to the
`ESP32_VIDEO_DEVICE_KEYS` Firebase secret, then redeploy `requestVideoClip`.
Never commit `device_config.h`.

## 3. Install and flash with Arduino IDE

1. Install Arduino IDE.
2. In **File > Preferences > Additional Boards Manager URLs**, add:

   ```text
   https://espressif.github.io/arduino-esp32/package_esp32_index.json
   ```

3. In **Tools > Board > Boards Manager**, install `esp32` by Espressif Systems.
4. Connect the ESP32 with a USB **data** cable.
5. Open `esp32_video_button.ino` in this directory.
6. Select **Tools > Board > ESP32 Arduino > ESP32 Dev Module** and the correct
   COM port. No third-party Arduino libraries are needed.
7. Click **Upload**. If it remains at `Connecting...`, hold **BOOT**, start the
   upload, and release BOOT when writing begins. A tap on **EN/RESET** may also
   be necessary on some boards.
8. Open **Serial Monitor** at `115200` baud and press EN/RESET.

If no COM port appears, try another cable or install the USB chip's CP210x/CH340
driver. Espressif's official installation guide is:
https://docs.espressif.com/projects/arduino-esp32/en/latest/installing.html

## 4. Test

Before pressing, create a current reservation for that court and make sure both
players have valid email records. The board should print:

```text
Wi-Fi connected
Clock synchronized.
Ready. Press the physical button to request a clip.
```

A successful press produces `HTTP 202`. With the optional LED, it remains on
while sending, flashes twice on acceptance, and flashes five times on failure.
The firmware debounces the switch, creates a cryptographically random nonce,
signs the exact server `v1` format with HMAC-SHA-256, validates Google's TLS
certificate, and safely retries an uncertain network/5xx response using the
same nonce for backend deduplication.

Common responses:

| Result | Meaning |
| --- | --- |
| `202` | Request accepted and queued. |
| `401 stale_request` | NTP/clock is not synchronized. |
| `401 unauthorized` | Device ID, court, key, or signature does not match Firebase. |
| `404 reservation_not_found` | No current, previous, or next reservation can own this press, or it is outside 07:00-22:30. |
| `404 player_not_found` | A reserved player has no usable user/email record. |
| `409` | Reservation/player data is incomplete/conflicting, or a 40-second clip would cross into different players' hour. |
| `429` | The same court was pressed too recently. |
| `503` | Video processing/queue is temporarily unavailable. |

The secret is still recoverable by someone with physical access to an ordinary
Arduino-flashed ESP32. Install the device in a locked enclosure and rotate its
key immediately if it is lost or replaced.
