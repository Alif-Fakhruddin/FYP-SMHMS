#include <Arduino.h>
#include <WiFi.h>
#include <HTTPClient.h>
#include <WiFiClientSecure.h>
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>

// ==========================================
// 1. TETAPAN UTAMA
// ==========================================

// Tetapan Wi-Fi / Hotspot
const char* ssid = "abcd";           // Nama Wi-Fi / Hotspot
const char* password = "12345678";   // Kata laluan Wi-Fi

// URL Pelayan Flask (Menggunakan Ngrok)
const char* serverName = "https://tamper-neon-stays.ngrok-free.dev/api/sensor-data"; 

// Kunci API Rahsia
const char* apiKey = "SMHMS_SECRET_API_KEY_2026";

// ==========================================
// 2. TETAPAN SKRIN OLED & PIN HARDWARE
// ==========================================
#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 64
#define OLED_RESET -1
#define SCREEN_ADDRESS 0x3C
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);

// Tetapan Pin Sensor
const int mqPin = 34;        // MQ135 Analog Pin
const int flamePin = 18;     // Flame Sensor Digital Pin
const int trigPin = 23;      // Ultrasonic Trig Pin
const int echoPin = 19;      // Ultrasonic Echo Pin

// Tetapan Pin LED & Buzzer
const int ledGreen = 2;      // LED Hijau (Normal)
const int ledYellow = 4;     // LED Kuning (Awas)
const int ledRed = 5;        // LED Merah (Bahaya)
const int buzzerPin = 13;    // Buzzer

// Pemasa hantar data (Setiap 3 saat)
unsigned long lastTime = 0;
const unsigned long timerDelay = 30; 

void setup() {
  Serial.begin(115200);

  // Penetapan Mod Pin
  pinMode(mqPin, INPUT);
  pinMode(flamePin, INPUT);
  pinMode(trigPin, OUTPUT);
  pinMode(echoPin, INPUT);

  pinMode(ledGreen, OUTPUT);
  pinMode(ledYellow, OUTPUT);
  pinMode(ledRed, OUTPUT);
  pinMode(buzzerPin, OUTPUT);

  // Tutup semua LED & Buzzer pada awal
  digitalWrite(ledGreen, LOW);
  digitalWrite(ledYellow, LOW);
  digitalWrite(ledRed, LOW);
  digitalWrite(buzzerPin, LOW);

  // Inisialisasi Skrin OLED
  if (!display.begin(SSD1306_SWITCHCAPVCC, SCREEN_ADDRESS)) {
    Serial.println(F("Gagal mengesan OLED Display!"));
  } else {
    display.clearDisplay();
    display.setTextSize(1);
    display.setTextColor(SSD1306_WHITE);
    display.setCursor(0, 10);
    display.println("SMHMS Booting...");
    display.display();
  }

  // Sambungan ke Wi-Fi
  WiFi.begin(ssid, password);
  Serial.print("Menyambung ke Wi-Fi");
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nWi-Fi Berjaya Disambungkan!");
  Serial.print("IP Address ESP32: ");
  Serial.println(WiFi.localIP());

  if (display.begin(SSD1306_SWITCHCAPVCC, SCREEN_ADDRESS)) {
    display.clearDisplay();
    display.setCursor(0, 10);
    display.println("Wi-Fi Connected!");
    display.println(WiFi.localIP());
    display.display();
    delay(1000);
  }
}

void loop() {
  // Hanya hantar data setiap 3 saat
  if ((millis() - lastTime) > timerDelay) {
    if (WiFi.status() == WL_CONNECTED) {
      
      // --------------------------------------------------
      // 1. BACA DATA SENSOR
      // --------------------------------------------------
      
      // Baca MQ135 / MQ-2 (Gas)
      int gasLevel = analogRead(mqPin);

      // Baca Flame Sensor (Api: LOW = Ada Api, HIGH = Tiada Api)
      int flameRaw = digitalRead(flamePin);
      int fireDetected = (flameRaw == LOW) ? 1 : 0;

      // Baca Ultrasonic (BACAAN JARAK SAHAJA)
      digitalWrite(trigPin, LOW);
      delayMicroseconds(2);
      digitalWrite(trigPin, HIGH);
      delayMicroseconds(10);
      digitalWrite(trigPin, LOW);
      
      long duration = pulseIn(echoPin, HIGH, 30000); // Timeout 30ms
      float distance = duration * 0.034 / 2.0;

      // Jika tiada balasan echo / ralat
      if (duration == 0 || distance < 0) {
        distance = 0.0;
      }

      // --------------------------------------------------
      // 2. LOGIK STATUS HAZARD & LED / BUZZER
      // --------------------------------------------------
      String statusHazard = "NORMAL";

      // Amaran jika ada Api, Gas > 3500, atau Objek terlalu dekat (Jarak <= 10.0 cm)
      if (fireDetected == 1 || gasLevel > 3500 || (distance > 0 && distance <= 10.0)) {
        statusHazard = "DANGER";
        digitalWrite(ledRed, HIGH);
        digitalWrite(ledYellow, LOW);
        digitalWrite(ledGreen, LOW);
        digitalWrite(buzzerPin, HIGH); // Buzzer Berbunyi
      } else if (gasLevel > 2500 || (distance > 10.0 && distance <= 20.0)) {
        statusHazard = "WARNING";
        digitalWrite(ledRed, LOW);
        digitalWrite(ledYellow, HIGH);
        digitalWrite(ledGreen, LOW);
        digitalWrite(buzzerPin, LOW);
      } else {
        statusHazard = "NORMAL";
        digitalWrite(ledRed, LOW);
        digitalWrite(ledYellow, LOW);
        digitalWrite(ledGreen, HIGH);
        digitalWrite(buzzerPin, LOW);
      }

      // --------------------------------------------------
      // 3. PAPARAN PADA SKRIN OLED
      // --------------------------------------------------
      display.clearDisplay();
      display.setCursor(0, 0);
      display.print("Status : "); display.println(statusHazard);
      display.print("Jarak  : "); display.print(distance, 1); display.println(" cm");
      display.print("Gas    : "); display.print(gasLevel); display.println(" ppm");
      display.print("Api    : "); display.println(fireDetected == 1 ? "DIKESAN!" : "Selamat");
      display.display();

      // --------------------------------------------------
      // 4. HANTAR DATA KE FLASK (HTTP POST)
      // --------------------------------------------------
      WiFiClientSecure client;
      client.setInsecure(); // Abaikan semakan SSL Certificate Ngrok

      HTTPClient http;
      http.begin(client, serverName);
      http.addHeader("Content-Type", "application/json");

      // Format JSON Payload (Menghantar jarak terus dalam field water_level)
      String jsonPayload = "{";
      jsonPayload += "\"api_key\":\"" + String(apiKey) + "\",";
      jsonPayload += "\"water_level\":" + String(distance, 2) + ",";
      jsonPayload += "\"gas_level\":" + String(gasLevel) + ",";
      jsonPayload += "\"fire_detected\":" + String(fireDetected) + ",";
      jsonPayload += "\"status_hazard\":\"" + statusHazard + "\"";
      jsonPayload += "}";

      Serial.println("\nHantar data ke server...");
      Serial.println(jsonPayload);

      int httpResponseCode = http.POST(jsonPayload);

      if (httpResponseCode > 0) {
        String response = http.getString();
        Serial.print("Kod Respons HTTP: ");
        Serial.println(httpResponseCode);
        Serial.print("Balasan Server: ");
        Serial.println(response);
      } else {
        Serial.print("Ralat Hantar Data. Kod Error: ");
        Serial.println(httpResponseCode);
      }

      http.end(); // Bebaskan memori HTTP
    } else {
      Serial.println("Wi-Fi Terputus! Mengelak terputus sambungan...");
      WiFi.reconnect();
    }

    lastTime = millis();
  }
}