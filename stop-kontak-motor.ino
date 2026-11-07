#include <ESP8266WiFi.h>
#include <ESP8266WebServer.h>

// --- GANTI NAMA WIFI & PASSWORD SESUAI SELERA ANDA ---
const char* ssid = "MotorKu_Aman"; 
const char* password = "password123"; // Password minimal 8 karakter!

ESP8266WebServer server(80);

// Pin D1 (GPIO5) akan disambung ke pin IN pada Relay
const int RELAY_PIN = 5; 

// Tampilan antarmuka (UI) sederhana untuk di HP
String htmlPage = "<!DOCTYPE html><html><head><meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">"
                  "<style>body{font-family:Arial; text-align:center; margin-top:50px;} "
                  "button{padding:20px; font-size:24px; font-weight:bold; border-radius:10px; width:80%; margin:10px; border:none;} "
                  ".btn-on{background-color:#4CAF50; color:white;} "
                  ".btn-off{background-color:#f44336; color:white;}</style></head>"
                  "<body><h1>Kunci Rahasia Motor</h1>"
                  "<a href=\"/on\"><button class=\"btn-on\">NYALAKAN MOTOR</button></a><br>"
                  "<a href=\"/off\"><button class=\"btn-off\">MATIKAN MOTOR</button></a>"
                  "</body></html>";

void setup() {
  pinMode(RELAY_PIN, OUTPUT);
  digitalWrite(RELAY_PIN, HIGH); // Default: Relay MATI saat alat baru nyala (Modul relay biasanya Active-Low)

  // Buat WiFi Hotspot dari NodeMCU
  WiFi.softAP(ssid, password);

  // Atur URL Perintah
  server.on("/", [](){
    server.send(200, "text/html", htmlPage);
  });
  server.on("/on", [](){
    digitalWrite(RELAY_PIN, LOW); // Menyalakan Relay
    server.send(200, "text/html", htmlPage + "<h2>Status: 🟢 MOTOR HIDUP</h2>");
  });
  server.on("/off", [](){
    digitalWrite(RELAY_PIN, HIGH); // Mematikan Relay
    server.send(200, "text/html", htmlPage + "<h2>Status: 🔴 MOTOR MATI</h2>");
  });

  server.begin();
}

void loop() {
  server.handleClient();
}
