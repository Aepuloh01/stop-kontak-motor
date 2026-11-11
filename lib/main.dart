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
      title: 'Smart Vario & Home',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
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
  String statusSistem = "STANDBY";
  Color warnaStatus = Colors.grey;
  String detailError = "Belum ada aksi"; // <-- DETEKTIF ERROR
  bool isStarting = false;

  // Fungsi Kirim Perintah dengan Penangkap Error Asli
  Future<void> kirimPerintah(String endpoint, String statusSukses, Color warna) async {
    setState(() {
      detailError = "Menghubungkan ke 192.168.4.1/$endpoint...";
    });

    try {
      final response = await http
          .get(Uri.parse('http://192.168.4.1/$endpoint'))
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        setState(() {
          statusSistem = statusSukses;
          warnaStatus = warna;
          detailError = "Sukses! Respon 200 OK dari NodeMCU";
        });
      } else {
        setState(() {
          detailError = "Gagal: Server membalas kode ${response.statusCode}";
        });
      }
    } catch (e) {
      // INI AKAR MASALAHNYA: Menampilkan teks error asli dari sistem
      setState(() {
        statusSistem = "GAGAL TERHUBUNG";
        warnaStatus = Colors.redAccent;
        detailError = "Error: $e"; 
      });
    }
  }

  void prosesEngineStart() async {
    setState(() {
      isStarting = true;
      statusSistem = "CHECKING INJECTION...";
      warnaStatus = Colors.amber;
    });

    await Future.delayed(const Duration(seconds: 3));
    await kirimPerintah("on", "ENGINE RUNNING", Colors.greenAccent);

    setState(() {
      isStarting = false;
    });
  }

  Widget tombolMotor({
    required String label,
    required Color warnaGlow,
    required VoidCallback onTap,
    bool isLoading = false,
  }) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: warnaGlow.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8)),
            const BoxShadow(color: Colors.black87, blurRadius: 15, offset: Offset(5, 5)),
            const BoxShadow(color: Colors.white10, blurRadius: 15, offset: Offset(-5, -5)),
          ],
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  height: 25, width: 25,
                  child: CircularProgressIndicator(color: Colors.amber, strokeWidth: 3),
                )
              : Text(
                  label,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: warnaGlow, letterSpacing: 2),
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
        title: const Text("SMART VARIO 125", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(25.0),
          child: Column(
            children: [
              // Panel Status Utama
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
                    Text(statusSistem, style: TextStyle(color: warnaStatus, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              
              // KOTAK DETEKTIF ERROR (Menampilkan akar masalah di layar HP)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "Log: $detailError",
                  style: const TextStyle(color: Colors.yellowAccent, fontSize: 12, fontFamily: 'monospace'),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 30),

              // Tombol Kontrol Motor
              tombolMotor(
                label: "ENGINE START",
                warnaGlow: Colors.greenAccent,
                isLoading: isStarting,
                onTap: prosesEngineStart,
              ),
              const SizedBox(height: 25),
              tombolMotor(
                label: "ENGINE STOP",
                warnaGlow: Colors.redAccent,
                onTap: () => kirimPerintah("off", "ENGINE STOPPED", Colors.redAccent),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
