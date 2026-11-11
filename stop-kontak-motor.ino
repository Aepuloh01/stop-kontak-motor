#include <ESP8266WiFi.h>
#include <ESP8266WebServer.h>

// --- KONFIGURASI WIFI AP ---
const char* ssid = "SMART_VARIO_125"; 
const char* password = "password123"; // Minimal 8 karakter

ESP8266WebServer server(80);

// --- PIN HARDWARE ---
const int RELAY_PIN  = 5;  // D1 (GPIO5) - Relay Kontak Motor
const int BUZZER_PIN = 14; // D5 (GPIO14) - Indikator Suara

// Dynamic Status State (false = Mati, true = Hidup)
bool isEngineOn = false;

// --- FUNGSI NADA BUZZER ---
void soundBeep(int count, int delayMs) {
  for (int i = 0; i < count; i++) {
    digitalWrite(BUZZER_PIN, HIGH);
    delay(delayMs);
    digitalWrite(BUZZER_PIN, LOW);
    if (i < count - 1) delay(delayMs);
  }
}

// --- GENERATOR HALAMAN WEB UI (DARK MODE MODERN) ---
String buildHtmlPage(String statusText, bool isOn) {
  String page = "<!DOCTYPE html><html lang=\"id\"><head>";
  page += "<meta charset=\"UTF-8\">"; // MEMPERBAIKI KARAKTER ANEH / EMOJI
  page += "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">";
  page += "<title>Smart Vario 125 Keyless</title>";
  page += "<style>";
  page += "body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #121212; color: #ffffff; text-align: center; margin: 0; padding: 20px; display: flex; flex-direction: column; align-items: center; justify-content: center; min-height: 90vh; }";
  page += ".card { background: #1e1e1e; border-radius: 20px; padding: 30px; box-shadow: 0 8px 24px rgba(0,0,0,0.5); width: 100%; max-width: 360px; border: 1px solid #2a2a2a; }";
  page += "h1 { font-size: 22px; margin-bottom: 5px; color: #e0e0e0; letter-spacing: 1px; }";
  page += "h3 { font-size: 13px; color: #888; text-transform: uppercase; margin-bottom: 25px; letter-spacing: 2px; }";
  page += ".status-box { padding: 12px 20px; border-radius: 50px; font-weight: bold; font-size: 15px; margin-bottom: 30px; display: inline-block; transition: all 0.3s ease; }";
  page += isOn ? ".status-on { background: rgba(76, 175, 80, 0.15); color: #4CAF50; border: 1px solid #4CAF50; box-shadow: 0 0 15px rgba(76,175,80,0.3); }" 
               : ".status-off { background: rgba(244, 67, 54, 0.15); color: #f44336; border: 1px solid #f44336; }";
  page += ".btn { display: block; width: 100%; padding: 18px 0; margin: 12px 0; font-size: 16px; font-weight: bold; border-radius: 12px; text-decoration: none; border: none; cursor: pointer; transition: transform 0.1s ease, box-shadow 0.2s ease; box-sizing: border-box; }";
  page += ".btn:active { transform: scale(0.97); }";
  page += ".btn-start { background: linear-gradient(135deg, #2e7d32, #4caf50); color: white; box-shadow: 0 4px 15px rgba(76,175,80,0.4); }";
  page += ".btn-stop { background: linear-gradient(135deg, #c62828, #ef5350); color: white; box-shadow: 0 4px 15px rgba(244,67,54,0.4); }";
  page += "</style></head><body>";
  page += "<div class=\"card\">";
  page += "<h1>SMART VARIO 125</h1>";
  page += "<h3>Keyless Control</h3>";
  page += "<div class=\"status-box " + String(isOn ? "status-on" : "status-off") + "\">" + statusText + "</div>";
  page += "<a href=\"/on\" class=\"btn btn-start\">ENGINE START</a>";
  page += "<a href=\"/off\" class=\"btn btn-stop\">ENGINE STOP</a>";
  page += "</div></body></html>";
  return page;
}

void setup() {
  pinMode(RELAY_PIN, OUTPUT);
  pinMode(BUZZER_PIN, OUTPUT);

  // Relay Active-LOW (HIGH = OFF, LOW = ON)
  digitalWrite(RELAY_PIN, HIGH); 
  digitalWrite(BUZZER_PIN, LOW);

  // Jalankan WiFi Access Point
  WiFi.softAP(ssid, password);

  // Handler URL Halaman Utama
  server.on("/", [](){
    server.send(200, "text/html; charset=utf-8", buildHtmlPage(isEngineOn ? "🟢 ENGINE RUNNING" : "🔴 ENGINE OFF", isEngineOn));
  });

  // Handler URL Menyala (/on)
  server.on("/on", [](){
    digitalWrite(RELAY_PIN, LOW); // Relay ON (Active LOW)
    isEngineOn = true;
    soundBeep(1, 150);            // Beep 1x panjang
    server.send(200, "text/html; charset=utf-8", buildHtmlPage("🟢 ENGINE RUNNING", true));
  });

  // Handler URL Mematikan (/off)
  server.on("/off", [](){
    digitalWrite(RELAY_PIN, HIGH); // Relay OFF (Active LOW)
    isEngineOn = false;
    soundBeep(2, 80);              // Beep 2x pendek
    server.send(200, "text/html; charset=utf-8", buildHtmlPage("🔴 ENGINE OFF", false));
  });

  server.begin();

  // Indikator Suara saat NodeMCU siap/menyala
  soundBeep(3, 60); // Beep 3x cepat
}

void loop() {
  server.handleClient();
}
