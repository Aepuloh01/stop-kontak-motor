#include <ESP8266WiFi.h>
#include <ESP8266WebServer.h>

// --- KONFIGURASI WIFI AP ---
const char* ssid = "SMART_VARIO_125"; 
const char* password = "password123"; // Minimal 8 karakter

ESP8266WebServer server(80);

// --- PIN HARDWARE ---
const int RELAY_KONTAK  = 5;  // D1 (GPIO5)  - Relay 1: Kunci Kontak Motor
const int RELAY_STARTER = 4;  // D2 (GPIO4)  - Relay 2: Dinamo/ACG Starter
const int BUZZER_PIN    = 14; // D5 (GPIO14) - Indikator Suara

// --- PENGATURAN WAKTU OTOMATIS (Milidetik) ---
const int JEDA_FUEL_PUMP = 3000; // 3000 ms = 3 detik tunggu fuel pump naik
const int DURASI_STARTER = 1000; // 1000 ms = 1 detik durasi starter

// Dynamic Status State (false = Mati, true = Hidup)
bool isEngineOn = false;

// --- FUNGSI NADA BUZZER NYARING (2000 Hz) ---
void soundBeep(int count, int delayMs) {
  for (int i = 0; i < count; i++) {
    tone(BUZZER_PIN, 2000); // Frekuensi 2000 Hz (Paling nyaring di buzzer)
    delay(delayMs);
    noTone(BUZZER_PIN);     // Mematikan nada
    if (i < count - 1) delay(delayMs);
  }
}

// --- GENERATOR HALAMAN WEB UI (DARK MODE MODERN) ---
String buildHtmlPage(String statusText, bool isOn) {
  String page = "<!DOCTYPE html><html lang=\"id\"><head>";
  page += "<meta charset=\"UTF-8\">";
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

// --- HANDLER URL ENGINE START (KONTAK -> JEDA 3 DETIK -> STARTER) ---
void handleOn() {
  // Cegah starter berputar ulang jika mesin sudah dalam kondisi menyala
  if (isEngineOn) {
    server.send(200, "text/html; charset=utf-8", buildHtmlPage("🟢 ENGINE RUNNING", true));
    return;
  }

  // 1. Nyalakan Relay 1 (Kunci Kontak ON -> Fuel pump bekerja)
  pinMode(RELAY_KONTAK, OUTPUT);
  digitalWrite(RELAY_KONTAK, LOW);
  isEngineOn = true;
  soundBeep(1, 150); // Bunyi Beep 1x nyaring (2000 Hz)

  // Kirim respon 200 OK ke HP lebih dulu agar aplikasi tidak loading lama
  server.send(200, "text/html; charset=utf-8", buildHtmlPage("🟢 ENGINE RUNNING", true));

  // 2. Tunggu 3 detik (Fuel pump naik & jarum speedometer kalibrasi)
  delay(JEDA_FUEL_PUMP);

  // 3. Nyalakan Relay 2 (Starter otomatis menyala 1 detik)
  pinMode(RELAY_STARTER, OUTPUT);
  digitalWrite(RELAY_STARTER, LOW);
  delay(DURASI_STARTER);

  // 4. Matikan Relay 2 (Lepas tombol starter otomatis)
  pinMode(RELAY_STARTER, INPUT);
}

// --- HANDLER URL ENGINE STOP ---
void handleOff() {
  pinMode(RELAY_STARTER, INPUT); // Pastikan Relay Starter mati total
  pinMode(RELAY_KONTAK, INPUT);  // Matikan Relay Kontak (Mode INPUT memutus arus 5V)
  isEngineOn = false;
  soundBeep(2, 80);              // Bunyi Beep 2x pendek nyaring (2000 Hz)
  server.send(200, "text/html; charset=utf-8", buildHtmlPage("🔴 ENGINE OFF", false));
}

void setup() {
  // Kondisi awal saat booting: Set ke INPUT agar kedua relay mati total
  pinMode(RELAY_KONTAK, INPUT);
  pinMode(RELAY_STARTER, INPUT);
  pinMode(BUZZER_PIN, OUTPUT);

  // Jalankan WiFi Access Point
  WiFi.softAP(ssid, password);

  // Router URL
  server.on("/", [](){
    server.send(200, "text/html; charset=utf-8", buildHtmlPage(isEngineOn ? "🟢 ENGINE RUNNING" : "🔴 ENGINE OFF", isEngineOn));
  });
  server.on("/on", handleOn);
  server.on("/off", handleOff);

  server.begin();

  // Indikator Suara saat NodeMCU siap/menyala
  soundBeep(3, 60); // Beep 3x cepat nyaring (2000 Hz)
}

void loop() {
  server.handleClient();
}
