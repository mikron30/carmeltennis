#pragma once

// Copy this file to device_config.h, or run provision-device.ps1. The real
// device_config.h is ignored by Git because it contains Wi-Fi credentials and
// the per-device HMAC secret.

constexpr char WIFI_SSID[] = "REPLACE_WITH_2_4_GHZ_WIFI_NAME";
constexpr char WIFI_PASSWORD[] = "REPLACE_WITH_WIFI_PASSWORD";

// Each installed button must have its own ID and secret. The same ID, court,
// and secret must be registered in Firebase Secret Manager.
constexpr uint8_t COURT_NUMBER = 1;
constexpr char DEVICE_ID[] = "court-1-button";
constexpr char DEVICE_SECRET[] = "REPLACE_WITH_RANDOM_DEVICE_SECRET";

// Defaults for a classic ESP32-WROOM-32 DevKit. Confirm the pinout before
// using these values on an ESP32-C3, S2, S3, C6, or another board.
constexpr int BUTTON_GPIO = 27;

// Optional external LED: GPIO26 -> 470 ohm resistor -> LED anode; LED cathode
// -> GND. Set this to -1 if no status LED is connected.
constexpr int STATUS_LED_GPIO = 26;
constexpr bool STATUS_LED_ACTIVE_HIGH = true;

