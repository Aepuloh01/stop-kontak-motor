import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:async';

void main() {
  runApp(const SmartMotorApp());
}

class SmartMotorApp extends StatelessWidget {
  const SmartMotorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Vario 125 Keyless',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF101014),
      ),
      home: const MotorDashboard(),
    );
  }
}

class MotorDashboard extends StatefulWidget {
  const MotorDashboard({super.key});

  @override
  State<MotorDashboard> createState() => _MotorDashboardState();
}

class _MotorDashboardState extends State<MotorDashboard> {
  // Status Mesin
  String statusSistem = "STANDBY";
  Color warnaStatus = Colors.grey;
  bool isEngineOn = false;
  bool isStarting = false;

  // Status Alarm
  bool isAlarmArmed = false;

  // Log & Detektif Error
  String detailError = "Siap terhubung ke WiFi SMART_VARIO_125";

  // Fungsi Kirim Perintah ke NodeMCU
  Future<bool> kirimPerintah(
    String endpoint, {
    String? statusBaru,
    Color? warnaBaru,
    bool? engineStateBaru,
    bool? alarmStateBaru,
  }) async {
    setState(() {
      detailError = "Mengirim perintah ke 192.168.4.1/$endpoint...";
    });

    try {
      final response = await http
          .get(Uri.parse('http://192.168.4.1/$endpoint'))
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        setState(() {
          if (statusBaru != null) statusSistem = statusBaru;
          if (warnaBaru != null) warnaStatus = warnaBaru;
          if (engineStateBaru != null) isEngineOn = engineStateBaru;
          if (alarmStateBaru != null) isAlarmArmed = alarmStateBaru;
          detailError = "Sukses! Respon 200 OK (/$endpoint)";
        });
        return true;
      } else {
        setState(() {
          detailError = "Gagal: Server membalas kode ${response.statusCode}";
        });
        return false;
      }
    } catch (e) {
      setState(() {
        statusSistem = "TERPUTUS";
        warnaStatus = Colors.redAccent;
        detailError = "Error: $e";
      });
      return false;
    }
  }

  // Proses Engine Start (Sinkron dengan jeda 3 detik Fuel Pump + 1 detik Starter di NodeMCU)
  void prosesEngineStart() async {
    if (isStarting) return;

    setState(() {
      isStarting = true;
      statusSistem = "FUEL PUMP & STARTING...";
      warnaStatus = Colors.amber;
    });

    // Kirim perintah /on langsung (NodeMCU yang menjalankan jeda 3s + starter 1s)
    bool sukses = await kirimPerintah(
      "on",
      alarmStateBaru: false, // Alarm otomatis mati saat motor dinyalakan
    );

    if (sukses) {
      // Tahan animasi loading selama proses fuel pump & starter berlangsung di motor
      await Future.delayed(const Duration(milliseconds: 3800));
      if (mounted) {
        setState(() {
          statusSistem = "ENGINE RUNNING";
          warnaStatus = Colors.greenAccent;
          isEngineOn = true;
        });
      }
    }

    if (mounted) {
      setState(() {
        isStarting = false;
      });
    }
  }

  // Proses Engine Stop
  void prosesEngineStop() async {
    await kirimPerintah(
      "off",
      statusBaru: "ENGINE STOPPED",
      warnaBaru: Colors.redAccent,
      engineStateBaru: false,
    );
  }

  // Proses Aktifkan Alarm
  void prosesAktifkanAlarm() async {
    if (isEngineOn) {
      setState(() {
        detailError = "Matikan mesin (ENGINE STOP) dulu sebelum mengunci alarm!";
      });
      return;
    }

    await kirimPerintah(
      "alarm_on",
      alarmStateBaru: true,
    );
  }

  // Proses Matikan Alarm
  void prosesMatikanAlarm() async {
    await kirimPerintah(
      "alarm_off",
      alarmStateBaru: false,
    );
  }

  // Widget Tombol Utama Besar (Start / Stop)
  Widget tombolUtama({
    required String label,
    required String subLabel,
    required IconData icon,
    required Color warnaGlow,
    required VoidCallback onTap,
    bool isLoading = false,
  }) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A22),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: warnaGlow.withOpacity(0.35), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: warnaGlow.withOpacity(0.22),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
            const BoxShadow(
              color: Colors.black87,
              blurRadius: 10,
              offset: Offset(4, 4),
            ),
          ],
        ),
        child: isLoading
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      color: Colors.amber,
                      strokeWidth: 3,
                    ),
                  ),
                  SizedBox(width: 14),
                  Text(
                    "MENYALAKAN MESIN...",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              )
            : Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: warnaGlow.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: warnaGlow, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: warnaGlow,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subLabel,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white60,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: warnaGlow.withOpacity(0.7)),
                ],
              ),
      ),
    );
  }

  // Widget Tombol Keamanan (Alarm On / Off)
  Widget tombolAlarm({
    required String label,
    required IconData icon,
    required Color warna,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: isActive ? warna.withOpacity(0.18) : const Color(0xFF1A1A22),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? warna : Colors.white12,
            width: isActive ? 1.5 : 1,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: warna.withOpacity(0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ]
              : [],
        ),
        child: Column(
          children: [
            Icon(icon, color: isActive ? warna : Colors.white54, size: 26),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isActive ? warna : Colors.white70,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color warnaAlarm = isAlarmArmed ? Colors.lightBlueAccent : Colors.grey;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Column(
          children: [
            Text(
              "SMART VARIO 125",
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 20,
                letterSpacing: 2,
              ),
            ),
            Text(
              "KEYLESS & SECURITY SYSTEM",
              style: TextStyle(
                fontSize: 10,
                color: Colors.white54,
                letterSpacing: 2.5,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- PANEL DASHBOARD STATUS (MESIN & ALARM) ---
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF181820),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  children: [
                    // Indikator Status Mesin
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "STATUS MESIN",
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white54,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: warnaStatus.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: warnaStatus.withOpacity(0.5)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.power_settings_new,
                                  color: warnaStatus, size: 14),
                              const SizedBox(width: 6),
                              Text(
                                statusSistem,
                                style: TextStyle(
                                  color: warnaStatus,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Divider(color: Colors.white10, height: 1),
                    ),
                    // Indikator Status Alarm
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "KEAMANAN PARKIR",
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white54,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: warnaAlarm.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border:
                                Border.all(color: warnaAlarm.withOpacity(0.5)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isAlarmArmed ? Icons.shield : Icons.shield_outlined,
                                color: warnaAlarm,
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isAlarmArmed ? "ALARM AKTIF" : "ALARM NONAKTIF",
                                style: TextStyle(
                                  color: warnaAlarm,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // --- SEKSI 1: KONTROL MESIN ---
              const Text(
                "KONTROL MESIN",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white54,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 12),

              tombolUtama(
                label: "ENGINE START",
                subLabel: "Kontak ON • Jeda Fuel Pump 3s • Auto Starter",
                icon: Icons.bolt,
                warnaGlow: Colors.greenAccent,
                isLoading: isStarting,
                onTap: prosesEngineStart,
              ),

              const SizedBox(height: 16),

              tombolUtama(
                label: "ENGINE STOP",
                subLabel: "Matikan mesin & kelistrikan (Alarm tetap OFF)",
                icon: Icons.power_off,
                warnaGlow: Colors.redAccent,
                onTap: prosesEngineStop,
              ),

              const SizedBox(height: 26),

              // --- SEKSI 2: KEAMANAN & ALARM ---
              const Text(
                "SMART ALARM & ANSWER BACK",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white54,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: tombolAlarm(
                      label: "AKTIFKAN\nALARM",
                      icon: Icons.lock_outline,
                      warna: Colors.lightBlueAccent,
                      isActive: isAlarmArmed,
                      onTap: prosesAktifkanAlarm,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: tombolAlarm(
                      label: "MATIKAN\nALARM",
                      icon: Icons.lock_open_rounded,
                      warna: Colors.tealAccent,
                      isActive: !isAlarmArmed,
                      onTap: prosesMatikanAlarm,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Tombol Cari Motor / Tes Sirine
              GestureDetector(
                onTap: () => kirimPerintah("panic"),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.orangeAccent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.orangeAccent.withOpacity(0.45),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_active_outlined,
                          color: Colors.orangeAccent, size: 20),
                      SizedBox(width: 10),
                      Text(
                        "CARI MOTOR / TES SIRINE",
                        style: TextStyle(
                          color: Colors.orangeAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // --- KOTAK DETEKTIF ERROR / LOG ---
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.terminal,
                        color: Colors.yellowAccent, size: 16),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Log: $detailError",
                        style: const TextStyle(
                          color: Colors.yellowAccent,
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
