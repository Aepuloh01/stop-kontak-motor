#include <ESP8266WiFi.h>
#include <ESP8266WebServer.h>

// --- KONFIGURASI WIFI AP ---
const char* ssid = "SMART_VARIO_125"; 
const char* password = "Snowboy14@"; // Minimal 8 karakter

ESP8266WebServer server(80);

// --- PIN HARDWARE ---
const int RELAY_KONTAK     = 5;  // D1 (GPIO5)  - Relay 1: Kunci Kontak
const int RELAY_STARTER    = 4;  // D2 (GPIO4)  - Relay 2: Starter Otomatis
const int RELAY_SEIN       = 13; // D7 (GPIO13) - Relay 3: Lampu Sein Depan & Belakang
const int BUZZER_PIN       = 14; // D5 (GPIO14) - Buzzer Suara Nyaring
const int SENSOR_ALARM     = 12; // D6 (GPIO12) - Sensor Getar SW-420 / Anti-Maling
const int SENSOR_JOK_PIN   = 3;  // Pin RX (GPIO3) - Bebas gagal booting meski jok terbuka/tertutup
const int SENSOR_STANG_PIN = 16; // D0 (GPIO16) - Bebas gagal booting

// 2. Ubah di dalam void setup() (ganti INPUT_PULLUP menjadi INPUT_PULLDOWN_16):
pinMode(SENSOR_STANG_PIN, INPUT_PULLDOWN_16);
// --- PENGATURAN WAKTU & SENSITIVITAS (Milidetik) ---
const int JEDA_FUEL_PUMP          = 3000;  // 3 detik tunggu fuel pump naik
const int DURASI_STARTER          = 1000;  // 1 detik durasi starter
const int DURASI_SIRINE           = 30000; // 30 detik batas maksimal sirine berbunyi
const unsigned long JEDA_SIAP_ALARM  = 2500; // 2,5 detik jeda aman setelah tombol Aktifkan Alarm ditekan
const int JUMLAH_GETAR_PICU       = 3;     // Minimal 3x getaran/ketukan untuk memicu alarm
const unsigned long RENTANG_GETAR_MS = 1500; // 3x getaran harus terjadi dalam rentang 1,5 detik

// Disesuaikan dengan modul SW-420 milikmu (LED menyala saat diam = LOW, LED padam saat diketuk = HIGH)
const bool ALARM_SENSOR_ACTIVE_LOW = false; 

// --- STATUS SISTEM ---
bool isEngineOn       = false;
bool isAlarmArmed     = false;
bool isAlarmTriggered = false;

unsigned long sirenStartTime = 0;
unsigned long sirenToneTimer = 0;
bool sirenState              = false;

// Variabel filter sensor getar SW-420
unsigned long alarmArmedTime     = 0;
int vibrationCount               = 0;
unsigned long firstVibrationTime = 0;
unsigned long lastVibrationPulse = 0;
bool lastSensorTriggered         = false;

// Variabel pembacaan sensor jok & kunci stang (Deteksi 2 Arah: Tekan & Lepas)
int lastJokState              = HIGH;
unsigned long lastJokMillis   = 0;

int lastStangState            = HIGH;
unsigned long lastStangMillis = 0;

// --- HELPER RELAY ACTIVE-LOW (Aman untuk 5V VV vs 3.3V NodeMCU) ---
void relayOn(int pin) {
  pinMode(pin, OUTPUT);
  digitalWrite(pin, LOW);
}

void relayOff(int pin) {
  pinMode(pin, INPUT); // Putus arus 5V secara total agar relay pasti mati
}

// --- FUNGSI KEDIP SEIN + BUZZER BERSAMAAN ---
void signalSeinAndBeep(int count, int durationMs) {
  for (int i = 0; i < count; i++) {
    relayOn(RELAY_SEIN);
    tone(BUZZER_PIN, 2000); // Frekuensi 2000 Hz nyaring
    delay(durationMs);
    
    relayOff(RELAY_SEIN);
    noTone(BUZZER_PIN);
    if (i < count - 1) delay(durationMs);
  }
}

// --- HELPER REDIRECT KE HALAMAN UTAMA ---
void redirectHome() {
  server.sendHeader("Location", "/");
  server.send(303);
}

// --- FUNGSI PENGECEKAN LIMIT SWITCH (JOK & KUNCI STANG) ---
void checkLimitSwitch(int pin, int &lastState, unsigned long &lastMillis, unsigned long currentMillis) {
  int currentState = digitalRead(pin);
  if (currentState != lastState && (currentMillis - lastMillis > 350)) {
    lastState  = currentState;
    lastMillis = currentMillis;

    if (isAlarmArmed && !isEngineOn) {
      // Alarm AKTIF: jok dicongkel atau stang digerakkan -> SIRINE + SEIN NYALA!
      isAlarmTriggered = true;
      sirenStartTime   = millis();
    } else if (!isAlarmArmed && !isEngineOn && !isAlarmTriggered) {
      // Alarm NONAKTIF: buka/tutup jok atau kunci stang -> Beep 1 detik + Sein nyala 1 detik
      signalSeinAndBeep(1, 1000);
      lastMillis = millis(); // Reset jeda pantulan setelah bunyi 1 detik selesai
    }
  }
}

// --- GENERATOR HALAMAN WEB UI ---
String buildHtmlPage() {
  String engineStatus = isEngineOn ? "🟢 ENGINE RUNNING" : "🔴 ENGINE OFF";
  String alarmStatus  = isAlarmTriggered ? "🚨 MALING / ALARM BUNYI!" 
                      : (isAlarmArmed ? "🛡️ ALARM AKTIF (TERKUNCI)" : "🔓 ALARM NONAKTIF");

  String page = "<!DOCTYPE html><html lang=\"id\"><head>";
  page += "<meta charset=\"UTF-8\">";
  page += "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">";
  page += "<title>Smart Beat Street Keyless</title>";
  page += "<style>";
  page += "body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #121212; color: #ffffff; text-align: center; margin: 0; padding: 20px; display: flex; flex-direction: column; align-items: center; justify-content: center; min-height: 90vh; }";
  page += ".card { background: #1e1e1e; border-radius: 20px; padding: 25px; box-shadow: 0 8px 24px rgba(0,0,0,0.5); width: 100%; max-width: 360px; border: 1px solid #2a2a2a; }";
  page += "h1 { font-size: 22px; margin-bottom: 4px; color: #e0e0e0; letter-spacing: 1px; }";
  page += "h3 { font-size: 12px; color: #888; text-transform: uppercase; margin-bottom: 20px; letter-spacing: 2px; }";
  page += ".status-box { display: block; padding: 10px 16px; border-radius: 12px; font-weight: bold; font-size: 14px; margin-bottom: 10px; }";
  page += isEngineOn ? ".status-on { background: rgba(76, 175, 80, 0.15); color: #4CAF50; border: 1px solid #4CAF50; }" 
                     : ".status-off { background: rgba(244, 67, 54, 0.15); color: #f44336; border: 1px solid #f44336; }";
  page += isAlarmTriggered ? ".alarm-alert { background: rgba(255, 23, 68, 0.25); color: #ff5252; border: 1px solid #ff1744; }"
        : (isAlarmArmed ? ".alarm-armed { background: rgba(33, 150, 243, 0.15); color: #42a5f5; border: 1px solid #2196f3; }"
                        : ".alarm-disarmed { background: rgba(158, 158, 158, 0.15); color: #bdbdbd; border: 1px solid #616161; }");
  page += ".divider { height: 1px; background: #2c2c2c; margin: 18px 0; }";
  page += ".section-label { font-size: 11px; color: #777; text-transform: uppercase; letter-spacing: 1.5px; margin-bottom: 8px; text-align: left; }";
  page += ".btn { display: block; width: 100%; padding: 16px 0; margin: 10px 0; font-size: 15px; font-weight: bold; border-radius: 12px; text-decoration: none; border: none; cursor: pointer; transition: transform 0.1s ease; box-sizing: border-box; }";
  page += ".btn:active { transform: scale(0.97); }";
  page += ".btn-start { background: linear-gradient(135deg, #2e7d32, #4caf50); color: white; box-shadow: 0 4px 15px rgba(76,175,80,0.3); }";
  page += ".btn-stop { background: linear-gradient(135deg, #c62828, #ef5350); color: white; box-shadow: 0 4px 15px rgba(244,67,54,0.3); }";
  page += ".btn-alarm-on { background: linear-gradient(135deg, #1565c0, #1e88e5); color: white; box-shadow: 0 4px 15px rgba(33,150,243,0.3); }";
  page += ".btn-alarm-off { background: #333333; color: #e0e0e0; border: 1px solid #444; }";
  page += ".btn-panic { background: linear-gradient(135deg, #e65100, #ff9800); color: white; font-size: 13px; padding: 12px 0; }";
  page += "</style></head><body>";
  page += "<div class=\"card\">";
  page += "<h1>SMART BEAT STREET</h1>";
  page += "<h3>Keyless & Security Control</h3>";
  
  page += "<div class=\"status-box " + String(isEngineOn ? "status-on" : "status-off") + "\">" + engineStatus + "</div>";
  page += "<div class=\"status-box " + String(isAlarmTriggered ? "alarm-alert" : (isAlarmArmed ? "alarm-armed" : "alarm-disarmed")) + "\">" + alarmStatus + "</div>";
  
  page += "<div class=\"divider\"></div>";
  page += "<div class=\"section-label\">Kontrol Mesin</div>";
  page += "<a href=\"/on\" class=\"btn btn-start\">ENGINE START</a>";
  page += "<a href=\"/off\" class=\"btn btn-stop\">ENGINE STOP</a>";
  
  page += "<div class=\"divider\"></div>";
  page += "<div class=\"section-label\">Menu Keamanan & Parkir</div>";
  if (isAlarmArmed || isAlarmTriggered) {
    page += "<a href=\"/alarm_off\" class=\"btn btn-alarm-off\">MATIKAN ALARM</a>";
  } else {
    page += "<a href=\"/alarm_on\" class=\"btn btn-alarm-on\">AKTIFKAN ALARM</a>";
  }
  page += "<a href=\"/panic\" class=\"btn btn-panic\">CARI MOTOR / TES SIRINE</a>";
  
  page += "</div></body></html>";
  return page;
}

// --- HANDLER URL ENGINE START ---
void handleOn() {
  isAlarmArmed        = false;
  isAlarmTriggered    = false;
  vibrationCount      = 0;
  lastSensorTriggered = false;
  noTone(BUZZER_PIN);

  if (isEngineOn) {
    redirectHome();
    return;
  }

  relayOn(RELAY_KONTAK);
  isEngineOn = true;
  signalSeinAndBeep(2, 90);

  redirectHome();

  delay(JEDA_FUEL_PUMP);

  relayOn(RELAY_STARTER);
  delay(DURASI_STARTER);
  relayOff(RELAY_STARTER);
}

// --- HANDLER URL ENGINE STOP ---
void handleOff() {
  relayOff(RELAY_STARTER);
  relayOff(RELAY_KONTAK);
  isEngineOn          = false;
  isAlarmTriggered    = false;
  vibrationCount      = 0;
  lastSensorTriggered = false;
  noTone(BUZZER_PIN);

  lastJokState   = digitalRead(SENSOR_JOK_PIN);
  lastStangState = digitalRead(SENSOR_STANG_PIN);

  signalSeinAndBeep(2, 80);
  redirectHome();
}

// --- HANDLER AKTIFKAN ALARM MANUAL ---
void handleAlarmOn() {
  if (!isEngineOn) {
    signalSeinAndBeep(1, 180);
    
    // Reset semua penghitung getaran & kunci posisi saat ini
    lastJokState        = digitalRead(SENSOR_JOK_PIN);
    lastStangState      = digitalRead(SENSOR_STANG_PIN);
    vibrationCount      = 0;
    lastSensorTriggered = false;
    isAlarmTriggered    = false;
    isAlarmArmed        = true;
    alarmArmedTime      = millis(); // Mulai hitung jeda siap 2,5 detik
  }
  redirectHome();
}

// --- HANDLER MATIKAN ALARM MANUAL ---
void handleAlarmOff() {
  isAlarmArmed        = false;
  isAlarmTriggered    = false;
  vibrationCount      = 0;
  lastSensorTriggered = false;
  noTone(BUZZER_PIN);
  relayOff(RELAY_SEIN);

  lastJokState   = digitalRead(SENSOR_JOK_PIN);
  lastStangState = digitalRead(SENSOR_STANG_PIN);

  signalSeinAndBeep(2, 80);
  redirectHome();
}

// --- HANDLER CARI MOTOR / TES SIRINE ---
void handlePanic() {
  isAlarmTriggered = true;
  sirenStartTime   = millis();
  redirectHome();
}

void setup() {
  relayOff(RELAY_KONTAK);
  relayOff(RELAY_STARTER);
  relayOff(RELAY_SEIN);
  pinMode(BUZZER_PIN, OUTPUT);

  if (ALARM_SENSOR_ACTIVE_LOW) {
    pinMode(SENSOR_ALARM, INPUT_PULLUP);
  } else {
    pinMode(SENSOR_ALARM, INPUT);
  }

  pinMode(SENSOR_JOK_PIN, INPUT_PULLUP);
  pinMode(SENSOR_STANG_PIN, INPUT_PULLUP);
  lastJokState   = digitalRead(SENSOR_JOK_PIN);
  lastStangState = digitalRead(SENSOR_STANG_PIN);

  WiFi.softAP(ssid, password);

  server.on("/", [](){
    server.send(200, "text/html; charset=utf-8", buildHtmlPage());
  });
  server.on("/on", handleOn);
  server.on("/off", handleOff);
  server.on("/alarm_on", handleAlarmOn);
  server.on("/alarm_off", handleAlarmOff);
  server.on("/panic", handlePanic);

  server.begin();

  signalSeinAndBeep(3, 70);
}

void loop() {
  server.handleClient();
  unsigned long currentMillis = millis();

  // 1. CEK LIMIT SWITCH JOK (Pin D3) & KUNCI STANG (Pin D4)
  checkLimitSwitch(SENSOR_JOK_PIN, lastJokState, lastJokMillis, currentMillis);
  checkLimitSwitch(SENSOR_STANG_PIN, lastStangState, lastStangMillis, currentMillis);

  // 2. DETEKSI SENSOR GETAR SW-420 (Pin D6 - Aktif setelah jeda 2,5 detik)
  if (isAlarmArmed && !isEngineOn && !isAlarmTriggered && (currentMillis - alarmArmedTime >= JEDA_SIAP_ALARM)) {
    int alarmSensorVal = digitalRead(SENSOR_ALARM);
    bool currentTriggered = ALARM_SENSOR_ACTIVE_LOW ? (alarmSensorVal == LOW) : (alarmSensorVal == HIGH);

    // Hitung tiap kali getaran baru terdeteksi (jeda minimal 120 ms antar ketukan)
    if (currentTriggered && !lastSensorTriggered && (currentMillis - lastVibrationPulse > 120)) {
      lastVibrationPulse = currentMillis;

      if (vibrationCount == 0 || (currentMillis - firstVibrationTime > RENTANG_GETAR_MS)) {
        vibrationCount     = 1;
        firstVibrationTime = currentMillis;
      } else {
        vibrationCount++;
      }

      if (vibrationCount >= JUMLAH_GETAR_PICU) {
        isAlarmTriggered = true;
        sirenStartTime   = currentMillis;
        vibrationCount   = 0;
      }
    }
    lastSensorTriggered = currentTriggered;
  }

  // 3. EKSEKUSI SIRINE + LAMPU SEIN BERKEDIP BERSAMAAN
  if (isAlarmTriggered) {
    if (currentMillis - sirenStartTime >= DURASI_SIRINE) {
      isAlarmTriggered = false;
      noTone(BUZZER_PIN);
      relayOff(RELAY_SEIN);
    } else {
      if (currentMillis - sirenToneTimer >= 150) {
        sirenToneTimer = currentMillis;
        sirenState     = !sirenState;
        if (sirenState) {
          relayOn(RELAY_SEIN);
          tone(BUZZER_PIN, 2500);
        } else {
          relayOff(RELAY_SEIN);
          tone(BUZZER_PIN, 2000);
        }
      }
    }
  }
}
