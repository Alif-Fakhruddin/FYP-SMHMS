#include <Arduino.h>
#include <WiFi.h>
#include <HTTPClient.h>
#include <WiFiClientSecure.h>
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>

// ==========================================
// 1. TETAPAN TETAPAN UTAMA (UBAH DI SINI)
// ==========================================

// Tetapan Wi-Fi / Hotspot
const char* ssid = "ownerhotspot";        // Nama Wi-Fi / Hotspot
const char* password = "adibsafwan";   // Kata laluan Wi-Fi

// URL Pelayan Flask (Gunakan SALAH SATU pilihan di bawah)

// Pilihan A: Jika guna IP Laptop (Satu Rangkaian Wi-Fi)
// const char* serverName = "http://192.168.1.15:5000/api/sensor-data"; 

// Pilihan B: Jika guna URL Ngrok
const char* serverName = "https://tamper-neon-stays.ngrok-free.app/api/sensor-data"; 

// Kunci API Rahsia (Mesti sama dengan API_KEY di server Flask)
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

// Jarak Tangki Air (cm) untuk kiraan paras air
const float tankHeight = 20.0; 

// Pembendung masa hantar data (Hantar setiap 3 saat)
unsigned long lastTime = 0;
const unsigned long timerDelay = 3000;

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
      
      // 1. BACA DATA SENSOR
      
      // Baca MQ135 (Gas)
      int gasLevel = analogRead(mqPin);

      // Baca Flame Sensor (Api: LOW = Ada Api, HIGH = Tiada Api)
      int flameRaw = digitalRead(flamePin);
      int fireDetected = (flameRaw == LOW) ? 1 : 0;

      // Baca Ultrasonic (Paras Air)
      digitalWrite(trigPin, LOW);
      delayMicroseconds(2);
      digitalWrite(trigPin, HIGH);
      delayMicroseconds(10);
      digitalWrite(trigPin, LOW);
      
      long duration = pulseIn(echoPin, HIGH, 30000); // Timeout 30ms
      float distance = duration * 0.034 / 2.0;
      
      float waterLevel = tankHeight - distance;
      if (waterLevel < 0) waterLevel = 0;
      if (waterLevel > tankHeight) waterLevel = tankHeight;

      // 2. PENENTUAN STATUS HAZARD & AMARAN AMERGENSI
      String statusHazard = "NORMAL";

      if (fireDetected == 1 || gasLevel > 2000 || waterLevel > 15.0) {
        statusHazard = "DANGER";
        digitalWrite(ledRed, HIGH);
        digitalWrite(ledYellow, LOW);
        digitalWrite(ledGreen, LOW);
        
        // Bunyi Buzzer Amaran Bahaya
        digitalWrite(buzzerPin, HIGH);
      } else if (gasLevel > 1000 || waterLevel > 10.0) {
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

      // 3. PAPARKAN BACAAN PADA OLED DISPLAY
      display.clearDisplay();
      display.setCursor(0, 0);
      display.print("Status: "); display.println(statusHazard);
      display.print("Air   : "); display.print(waterLevel, 1); display.println(" cm");
      display.print("Gas   : "); display.print(gasLevel); display.println(" ppm");
      display.print("Api   : "); display.println(fireDetected == 1 ? "DIKESAN!" : "Selamat");
      display.display();

      // 4. HANTAR DATA KE SERVER FLASK VIA HTTP POST
      
      // Pengendalian SSL/TLS untuk elak Error -5
      WiFiClientSecure client;
      client.setInsecure(); // Abaikan semakan sijil SSL Ngrok

      HTTPClient http;
      http.begin(client, serverName);
      http.addHeader("Content-Type", "application/json");

      // Bina struktur format JSON
      String jsonPayload = "{";
      jsonPayload += "\"api_key\":\"" + String(apiKey) + "\",";
      jsonPayload += "\"water_level\":" + String(waterLevel, 2) + ",";
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
        Serial.println(httpResponseCode); // Jika keluar -5, semak sambungan Wi-Fi atau Ngrok
      }

      http.end(); // Bebaskan sumber HTTP
    } else {
      Serial.println("Wi-Fi terputus! Mengubungi semula...");
      WiFi.reconnect();
    }

    lastTime = millis();
  }
}