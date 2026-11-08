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
      title: 'Smart Motor 3D',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212), // Background gelap elegan
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
  String statusMotor = "STANDBY";
  Color warnaStatus = Colors.grey;

  // Fungsi untuk mengirim sinyal ke NodeMCU
  Future<void> kirimPerintah(String endpoint, String statusSukses, Color warna) async {
    setState(() {
      statusMotor = "MENGIRIM...";
      warnaStatus = Colors.orange;
    });

    try {
      // Mengirim perintah ke IP NodeMCU (192.168.4.1)
      final response = await http
          .get(Uri.parse('http://192.168.4.1/$endpoint'))
          .timeout(const Duration(seconds: 3)); // Batas waktu 3 detik

      if (response.statusCode == 200) {
        setState(() {
          statusMotor = statusSukses;
          warnaStatus = warna;
        });
      }
    } catch (e) {
      setState(() {
        statusMotor = "TIDAK ADA KONEKSI WIFI";
        warnaStatus = Colors.redAccent;
      });
    }
  }

  // Desain Tombol 3D (Neumorphism & Glowing)
  Widget tombol3D({
    required String label,
    required Color warnaGlow,
    required String endpoint,
    required String statusTeks,
  }) {
    return GestureDetector(
      onTap: () => kirimPerintah(endpoint, statusTeks, warnaGlow),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            // Efek Cahaya (Glow) di bawah tombol
            BoxShadow(
              color: warnaGlow.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
            // Bayangan Gelap 3D
            const BoxShadow(
              color: Colors.black87,
              blurRadius: 15,
              offset: Offset(5, 5),
            ),
            // Pantulan Cahaya 3D di sudut atas
            const BoxShadow(
              color: Colors.white10,
              blurRadius: 15,
              offset: Offset(-5, -5),
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: warnaGlow,
              letterSpacing: 2,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "SMART MOTOR VARIO 125",
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Indikator Status di bagian atas
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: warnaStatus.withOpacity(0.5), width: 2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.power_settings_new, color: warnaStatus),
                  const SizedBox(width: 10),
                  Text(
                    statusMotor,
                    style: TextStyle(
                      color: warnaStatus,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 60),

            // Tombol START 3D
            tombol3D(
              label: "ENGINE START",
              warnaGlow: Colors.greenAccent,
              endpoint: "on",
              statusTeks: "MOTOR HIDUP",
            ),
            const SizedBox(height: 30),

            // Tombol STOP 3D
            tombol3D(
              label: "ENGINE STOP",
              warnaGlow: Colors.redAccent,
              endpoint: "off",
              statusTeks: "MOTOR MATI",
            ),
          ],
        ),
      ),
    );
  }
}
