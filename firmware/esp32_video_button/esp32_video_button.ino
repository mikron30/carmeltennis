#include <Arduino.h>
#include <HTTPClient.h>
#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <esp_system.h>
#include <mbedtls/md.h>
#include <time.h>

#if defined(ESP32_VIDEO_BUTTON_USE_EXAMPLE_CONFIG)
#include "device_config.example.h"
#elif __has_include("device_config.h")
#include "device_config.h"
#else
#error "Missing device_config.h. Copy device_config.example.h or run provision-device.ps1."
#endif

namespace {

constexpr char VIDEO_ENDPOINT[] =
    "https://europe-west3-potent-howl-228108.cloudfunctions.net/requestVideoClip";

constexpr uint32_t WIFI_CONNECT_TIMEOUT_MS = 30000;
constexpr uint32_t NTP_SYNC_TIMEOUT_MS = 30000;
constexpr uint32_t HTTP_TIMEOUT_MS = 15000;
constexpr uint32_t DEBOUNCE_MS = 50;
constexpr uint32_t LOCAL_PRESS_LOCKOUT_MS = 1500;
constexpr uint32_t NETWORK_MAINTENANCE_INTERVAL_MS = 30000;
constexpr time_t MIN_VALID_UNIX_TIME = 1700000000;
constexpr int MAX_SEND_ATTEMPTS = 3;

// Google Trust Services GTS Root R1, downloaded from Google's official root
// repository (https://pki.goog/roots.pem). It expires in June 2036. Do not
// replace this with client.setInsecure(): the HMAC secret must only be sent to
// the genuine Google endpoint.
constexpr char GTS_ROOT_R1[] = R"CERT(
-----BEGIN CERTIFICATE-----
MIIFVzCCAz+gAwIBAgINAgPlk28xsBNJiGuiFzANBgkqhkiG9w0BAQwFADBHMQsw
CQYDVQQGEwJVUzEiMCAGA1UEChMZR29vZ2xlIFRydXN0IFNlcnZpY2VzIExMQzEU
MBIGA1UEAxMLR1RTIFJvb3QgUjEwHhcNMTYwNjIyMDAwMDAwWhcNMzYwNjIyMDAw
MDAwWjBHMQswCQYDVQQGEwJVUzEiMCAGA1UEChMZR29vZ2xlIFRydXN0IFNlcnZp
Y2VzIExMQzEUMBIGA1UEAxMLR1RTIFJvb3QgUjEwggIiMA0GCSqGSIb3DQEBAQUA
A4ICDwAwggIKAoICAQC2EQKLHuOhd5s73L+UPreVp0A8of2C+X0yBoJx9vaMf/vo
27xqLpeXo4xL+Sv2sfnOhB2x+cWX3u+58qPpvBKJXqeqUqv4IyfLpLGcY9vXmX7w
Cl7raKb0xlpHDU0QM+NOsROjyBhsS+z8CZDfnWQpJSMHobTSPS5g4M/SCYe7zUjw
TcLCeoiKu7rPWRnWr4+wB7CeMfGCwcDfLqZtbBkOtdh+JhpFAz2weaSUKK0Pfybl
qAj+lug8aJRT7oM6iCsVlgmy4HqMLnXWnOunVmSPlk9orj2XwoSPwLxAwAtcvfaH
szVsrBhQf4TgTM2S0yDpM7xSma8ytSmzJSq0SPly4cpk9+aCEI3oncKKiPo4Zor8
Y/kB+Xj9e1x3+naH+uzfsQ55lVe0vSbv1gHR6xYKu44LtcXFilWr06zqkUspzBmk
MiVOKvFlRNACzqrOSbTqn3yDsEB750Orp2yjj32JgfpMpf/VjsPOS+C12LOORc92
wO1AK/1TD7Cn1TsNsYqiA94xrcx36m97PtbfkSIS5r762DL8EGMUUXLeXdYWk70p
aDPvOmbsB4om3xPXV2V4J95eSRQAogB/mqghtqmxlbCluQ0WEdrHbEg8QOB+DVrN
VjzRlwW5y0vtOUucxD/SVRNuJLDWcfr0wbrM7Rv1/oFB2ACYPTrIrnqYNxgFlQID
AQABo0IwQDAOBgNVHQ8BAf8EBAMCAYYwDwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4E
FgQU5K8rJnEaK0gnhS9SZizv8IkTcT4wDQYJKoZIhvcNAQEMBQADggIBAJ+qQibb
C5u+/x6Wki4+omVKapi6Ist9wTrYggoGxval3sBOh2Z5ofmmWJyq+bXmYOfg6LEe
QkEzCzc9zolwFcq1JKjPa7XSQCGYzyI0zzvFIoTgxQ6KfF2I5DUkzps+GlQebtuy
h6f88/qBVRRiClmpIgUxPoLW7ttXNLwzldMXG+gnoot7TiYaelpkttGsN/H9oPM4
7HLwEXWdyzRSjeZ2axfG34arJ45JK3VmgRAhpuo+9K4l/3wV3s6MJT/KYnAK9y8J
ZgfIPxz88NtFMN9iiMG1D53Dn0reWVlHxYciNuaCp+0KueIHoI17eko8cdLiA6Ef
MgfdG+RCzgwARWGAtQsgWSl4vflVy2PFPEz0tv/bal8xa5meLMFrUKTX5hgUvYU/
Z6tGn6D/Qqc6f1zLXbBwHSs09dR2CQzreExZBfMzQsNhFRAbd03OIozUhfJFfbdT
6u9AWpQKXCBfTkBdYiJ23//OYb2MI3jSNwLgjt7RETeJ9r/tSQdirpLsQBqvFAnZ
0E6yove+7u7Y/9waLd64NnHi/Hm3lCXRSHNboTXns5lndcEZOitHTtNCjv0xyBZm
2tIMPNuzjsmhDYAPexZ3FL//2wmUspO8IFgV6dtxQ/PeEMMA3KgqlbbC1j+Qa3bb
bP6MvPJwNQzcmRk13NfIRmPVNnGuV/u3gm3c
-----END CERTIFICATE-----
)CERT";

struct SignedRequest {
  int64_t timestamp;
  char nonce[33];
  char signature[65];
  char json[384];
};

bool lastRawButtonState = HIGH;
bool stableButtonState = HIGH;
bool deviceReady = false;
volatile uint8_t lastWifiDisconnectReason = 0;
uint32_t rawStateChangedAt = 0;
uint32_t lastHandledPressAt = 0;
uint32_t lastNetworkMaintenanceAt = 0;

void setStatusLed(bool on) {
  if (STATUS_LED_GPIO < 0) return;
  const bool pinLevel = STATUS_LED_ACTIVE_HIGH ? on : !on;
  digitalWrite(STATUS_LED_GPIO, pinLevel ? HIGH : LOW);
}

void blinkStatus(int count, uint32_t onMs, uint32_t offMs) {
  if (STATUS_LED_GPIO < 0) return;
  for (int index = 0; index < count; ++index) {
    setStatusLed(true);
    delay(onMs);
    setStatusLed(false);
    if (index + 1 < count) delay(offMs);
  }
}

bool isDeviceIdCharacter(char value) {
  return (value >= 'A' && value <= 'Z') ||
         (value >= 'a' && value <= 'z') ||
         (value >= '0' && value <= '9') || value == '_' || value == '-';
}

bool configurationLooksValid() {
  const size_t deviceIdLength = strlen(DEVICE_ID);
  if (strlen(WIFI_SSID) == 0 || strncmp(WIFI_SSID, "REPLACE_", 8) == 0) {
    Serial.println("Configuration error: Wi-Fi SSID is not provisioned.");
    return false;
  }
  if (COURT_NUMBER < 1 || COURT_NUMBER > 3) {
    Serial.println("Configuration error: court number must be 1, 2, or 3.");
    return false;
  }
  if (deviceIdLength == 0 || deviceIdLength > 64) {
    Serial.println("Configuration error: device ID length is invalid.");
    return false;
  }
  for (size_t index = 0; index < deviceIdLength; ++index) {
    if (!isDeviceIdCharacter(DEVICE_ID[index])) {
      Serial.println("Configuration error: device ID contains an invalid character.");
      return false;
    }
  }
  if (strlen(DEVICE_SECRET) < 16 ||
      strncmp(DEVICE_SECRET, "REPLACE_", 8) == 0) {
    Serial.println("Configuration error: device secret is not provisioned.");
    return false;
  }
  if (BUTTON_GPIO == STATUS_LED_GPIO) {
    Serial.println("Configuration error: button and LED cannot share a GPIO.");
    return false;
  }
  return true;
}

bool hmacSha256Hex(const char* key, const char* message, char output[65]) {
  const mbedtls_md_info_t* algorithm =
      mbedtls_md_info_from_type(MBEDTLS_MD_SHA256);
  if (algorithm == nullptr) return false;

  uint8_t digest[32];
  const int result = mbedtls_md_hmac(
      algorithm,
      reinterpret_cast<const unsigned char*>(key),
      strlen(key),
      reinterpret_cast<const unsigned char*>(message),
      strlen(message),
      digest);
  if (result != 0) return false;

  constexpr char HEX_DIGITS[] = "0123456789abcdef";
  for (size_t index = 0; index < sizeof(digest); ++index) {
    output[index * 2] = HEX_DIGITS[digest[index] >> 4];
    output[index * 2 + 1] = HEX_DIGITS[digest[index] & 0x0F];
  }
  output[64] = '\0';
  return true;
}

bool runSigningSelfTest() {
  constexpr char TEST_KEY[] = "test-only-device-secret-at-least-16";
  constexpr char TEST_MESSAGE[] =
      "v1\ncourt-one-button\n1\n1785837600\nnonce_for_test_0001";
  constexpr char EXPECTED[] =
      "723b94c4aebdcb2d0a1fe459975387ad1c1f21fc932a09fb5e1063a44bd39179";
  char actual[65];
  return hmacSha256Hex(TEST_KEY, TEST_MESSAGE, actual) &&
         strcmp(actual, EXPECTED) == 0;
}

void createNonce(char output[33]) {
  uint8_t randomBytes[16];
  esp_fill_random(randomBytes, sizeof(randomBytes));
  constexpr char HEX_DIGITS[] = "0123456789abcdef";
  for (size_t index = 0; index < sizeof(randomBytes); ++index) {
    output[index * 2] = HEX_DIGITS[randomBytes[index] >> 4];
    output[index * 2 + 1] = HEX_DIGITS[randomBytes[index] & 0x0F];
  }
  output[32] = '\0';
}

void onWifiDisconnected(WiFiEvent_t event, WiFiEventInfo_t info) {
  if (event == ARDUINO_EVENT_WIFI_STA_DISCONNECTED) {
    const uint8_t reason = info.wifi_sta_disconnected.reason;
    // Do not overwrite a useful failure reason with the deliberate cleanup
    // performed immediately before an explicit retry.
    if (reason != WIFI_REASON_ASSOC_LEAVE) {
      lastWifiDisconnectReason = reason;
    }
  }
}

void reportConfiguredNetworkVisibility() {
  Serial.print("Scanning for configured 2.4 GHz network");
  const int16_t count =
      WiFi.scanNetworks(false, true, false, 300, 0, WIFI_SSID);
  Serial.println();
  if (count <= 0) {
    Serial.println("Configured Wi-Fi network is not visible to the ESP32.");
  } else {
    Serial.print("Configured network is visible; signal RSSI: ");
    Serial.print(WiFi.RSSI(0));
    Serial.print(" dBm, channel: ");
    Serial.println(WiFi.channel(0));
  }
  WiFi.scanDelete();
}

bool connectToWifi(uint32_t timeoutMs) {
  if (WiFi.status() == WL_CONNECTED) return true;

  // Cancel a previous asynchronous connection before applying the same
  // configuration again. This avoids ESP-IDF's "sta is connecting" error.
  WiFi.disconnect(false, false, 1000);
  delay(100);
  lastWifiDisconnectReason = 0;
  Serial.print("Connecting to 2.4 GHz Wi-Fi");
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  const uint32_t startedAt = millis();
  while (WiFi.status() != WL_CONNECTED &&
         static_cast<uint32_t>(millis() - startedAt) < timeoutMs) {
    Serial.print('.');
    delay(500);
  }
  Serial.println();

  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("Wi-Fi connection failed.");
    const uint8_t failureReason = lastWifiDisconnectReason;
    if (failureReason != 0) {
      Serial.print("Last Wi-Fi disconnect reason code: ");
      Serial.println(failureReason);
    }
    WiFi.disconnect(false, false, 1000);
    reportConfiguredNetworkVisibility();
    return false;
  }
  Serial.print("Wi-Fi connected; signal RSSI: ");
  Serial.print(WiFi.RSSI());
  Serial.println(" dBm");
  return true;
}

bool clockIsValid() {
  return time(nullptr) >= MIN_VALID_UNIX_TIME;
}

bool synchronizeClock(uint32_t timeoutMs) {
  if (clockIsValid()) return true;
  if (WiFi.status() != WL_CONNECTED) return false;

  Serial.print("Synchronizing UTC clock");
  configTime(0, 0, "time.google.com", "pool.ntp.org", "time.cloudflare.com");
  const uint32_t startedAt = millis();
  while (!clockIsValid() &&
         static_cast<uint32_t>(millis() - startedAt) < timeoutMs) {
    Serial.print('.');
    delay(500);
  }
  Serial.println();

  if (!clockIsValid()) {
    Serial.println("NTP synchronization failed; request not sent.");
    return false;
  }
  Serial.println("Clock synchronized.");
  return true;
}

bool ensureNetworkAndClock() {
  return connectToWifi(WIFI_CONNECT_TIMEOUT_MS) &&
         synchronizeClock(NTP_SYNC_TIMEOUT_MS);
}

bool buildSignedRequest(SignedRequest& request) {
  request.timestamp = static_cast<int64_t>(time(nullptr));
  if (request.timestamp < MIN_VALID_UNIX_TIME) return false;
  createNonce(request.nonce);

  char canonicalMessage[256];
  const int canonicalLength = snprintf(
      canonicalMessage,
      sizeof(canonicalMessage),
      "v1\n%s\n%u\n%lld\n%s",
      DEVICE_ID,
      static_cast<unsigned>(COURT_NUMBER),
      static_cast<long long>(request.timestamp),
      request.nonce);
  if (canonicalLength <= 0 ||
      static_cast<size_t>(canonicalLength) >= sizeof(canonicalMessage)) {
    return false;
  }
  if (!hmacSha256Hex(DEVICE_SECRET, canonicalMessage, request.signature)) {
    return false;
  }

  const int jsonLength = snprintf(
      request.json,
      sizeof(request.json),
      "{\"courtNumber\":%u,\"deviceId\":\"%s\",\"timestamp\":%lld,"
      "\"nonce\":\"%s\",\"signature\":\"%s\"}",
      static_cast<unsigned>(COURT_NUMBER),
      DEVICE_ID,
      static_cast<long long>(request.timestamp),
      request.nonce,
      request.signature);
  return jsonLength > 0 &&
         static_cast<size_t>(jsonLength) < sizeof(request.json);
}

int postSignedRequest(const SignedRequest& request, String& responseBody) {
  WiFiClientSecure tlsClient;
  tlsClient.setCACert(GTS_ROOT_R1);
  tlsClient.setTimeout(HTTP_TIMEOUT_MS);

  HTTPClient http;
  http.setTimeout(HTTP_TIMEOUT_MS);
  if (!http.begin(tlsClient, VIDEO_ENDPOINT)) {
    Serial.println("Could not initialize the HTTPS request.");
    return -1000;
  }
  http.addHeader("Content-Type", "application/json");
  http.addHeader("Accept", "application/json");

  const int status = http.POST(String(request.json));
  if (status > 0) responseBody = http.getString();
  http.end();
  return status;
}

bool shouldRetry(int httpStatus) {
  return httpStatus <= 0 || httpStatus >= 500;
}

void printResponseGuidance(int httpStatus, const String& responseBody) {
  Serial.print("Video endpoint returned HTTP ");
  Serial.println(httpStatus);
  if (!responseBody.isEmpty()) {
    Serial.print("Response: ");
    Serial.println(responseBody.substring(0, 300));
  }
  if (httpStatus == 401) {
    Serial.println("Check NTP, device ID, court number, and matching device secret.");
  } else if (httpStatus == 404) {
    Serial.println("No active reservation/player email was found for this court and time.");
  } else if (httpStatus == 409) {
    Serial.println("The reservation or player data is incomplete or ambiguous.");
  } else if (httpStatus == 429) {
    Serial.println("The court button was pressed too recently; wait before retrying.");
  } else if (httpStatus >= 500) {
    Serial.println("The video queue is temporarily unavailable.");
  } else if (httpStatus <= 0) {
    Serial.println("No HTTP response; check Wi-Fi, DNS, TLS, and power stability.");
  }
}

bool sendVideoRequest() {
  if (!ensureNetworkAndClock()) return false;

  SignedRequest request{};
  if (!buildSignedRequest(request)) {
    Serial.println("Could not build the signed video request.");
    return false;
  }

  // Retries deliberately reuse the exact timestamp, nonce, and signature.
  // The backend deduplicates that nonce if the first response was lost.
  for (int attempt = 1; attempt <= MAX_SEND_ATTEMPTS; ++attempt) {
    if (WiFi.status() != WL_CONNECTED &&
        !connectToWifi(WIFI_CONNECT_TIMEOUT_MS)) {
      if (attempt == MAX_SEND_ATTEMPTS) return false;
      delay(1000U << attempt);
      continue;
    }

    Serial.print("Sending video request (attempt ");
    Serial.print(attempt);
    Serial.print('/');
    Serial.print(MAX_SEND_ATTEMPTS);
    Serial.println(")...");

    String responseBody;
    const int status = postSignedRequest(request, responseBody);
    if (status == 202) {
      Serial.println("Video request accepted (HTTP 202).");
      return true;
    }

    printResponseGuidance(status, responseBody);
    if (!shouldRetry(status) || attempt == MAX_SEND_ATTEMPTS) break;
    delay(1000U << attempt);
  }
  return false;
}

void handleButtonPress() {
  const uint32_t now = millis();
  if (lastHandledPressAt != 0 &&
      static_cast<uint32_t>(now - lastHandledPressAt) <
          LOCAL_PRESS_LOCKOUT_MS) {
    return;
  }
  lastHandledPressAt = now;
  Serial.println("Button pressed.");

  if (!configurationLooksValid()) {
    blinkStatus(5, 80, 120);
    return;
  }

  setStatusLed(true);
  const bool accepted = sendVideoRequest();
  setStatusLed(false);
  if (accepted) {
    blinkStatus(2, 180, 160);
  } else {
    blinkStatus(5, 80, 120);
  }
}

void pollButton() {
  const bool rawState = digitalRead(BUTTON_GPIO);
  const uint32_t now = millis();
  if (rawState != lastRawButtonState) {
    lastRawButtonState = rawState;
    rawStateChangedAt = now;
  }
  if (rawState != stableButtonState &&
      static_cast<uint32_t>(now - rawStateChangedAt) >= DEBOUNCE_MS) {
    stableButtonState = rawState;
    if (stableButtonState == LOW) handleButtonPress();
  }
}

void maintainNetwork() {
  const uint32_t now = millis();
  if (static_cast<uint32_t>(now - lastNetworkMaintenanceAt) <
      NETWORK_MAINTENANCE_INTERVAL_MS) {
    return;
  }
  lastNetworkMaintenanceAt = now;
  if (WiFi.status() != WL_CONNECTED) {
    connectToWifi(WIFI_CONNECT_TIMEOUT_MS);
  }
  if (WiFi.status() == WL_CONNECTED && !clockIsValid()) {
    synchronizeClock(NTP_SYNC_TIMEOUT_MS);
  }
}

}  // namespace

void setup() {
  Serial.begin(115200);
  delay(300);
  Serial.println();
  Serial.println("Carmel Tennis ESP32 video button starting...");

  pinMode(BUTTON_GPIO, INPUT_PULLUP);
  if (STATUS_LED_GPIO >= 0) {
    pinMode(STATUS_LED_GPIO, OUTPUT);
    setStatusLed(false);
  }
  lastRawButtonState = digitalRead(BUTTON_GPIO);
  stableButtonState = lastRawButtonState;
  rawStateChangedAt = millis();

  if (!runSigningSelfTest()) {
    Serial.println("FATAL: HMAC signing self-test failed.");
    blinkStatus(10, 60, 60);
    return;
  }
  if (!configurationLooksValid()) {
    Serial.println("Provision device_config.h before use.");
    blinkStatus(5, 80, 120);
    return;
  }

  WiFi.mode(WIFI_STA);
  WiFi.persistent(false);
  // The maintenance loop owns retries so an automatic attempt cannot overlap
  // the explicit disconnect/begin sequence above.
  WiFi.setAutoReconnect(false);
  WiFi.setSleep(false);
  WiFi.onEvent(onWifiDisconnected, ARDUINO_EVENT_WIFI_STA_DISCONNECTED);
  deviceReady = true;
  if (ensureNetworkAndClock()) {
    Serial.println("Ready. Press the physical button to request a clip.");
    blinkStatus(3, 120, 120);
  } else {
    Serial.println("Not online yet; the device will retry periodically.");
    blinkStatus(5, 80, 120);
  }
}

void loop() {
  if (!deviceReady) {
    delay(100);
    return;
  }
  pollButton();
  maintainNetwork();
  delay(5);
}
