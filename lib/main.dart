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
  bool isStarting = false; // Deteksi apakah sedang proses jeda injeksi

  // Fungsi Kirim Perintah ke NodeMCU
  Future<void> kirimPerintah(String endpoint, String statusSukses, Color warna) async {
    try {
      final response = await http
          .get(Uri.parse('http://192.168.4.1/$endpoint'))
          .timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        setState(() {
          statusSistem = statusSukses;
          warnaStatus = warna;
        });
      }
    } catch (e) {
      setState(() {
        statusSistem = "GAGAL TERHUBUNG";
        warnaStatus = Colors.orangeAccent;
      });
    }
  }

  // Fungsi Khusus Engine Start (Dengan Jeda Injeksi 3 Detik)
  void prosesEngineStart() async {
    setState(() {
      isStarting = true;
      statusSistem = "CHECKING INJECTION...";
      warnaStatus = Colors.amber; // Warna kuning indikator injeksi
    });

    // Jeda otomatis 3 detik menunggu fuel pump Vario
    await Future.delayed(const Duration(seconds: 3));

    // Eksekusi dinamo starter
    await kirimPerintah("on", "ENGINE RUNNING", Colors.greenAccent);

    setState(() {
      isStarting = false;
    });
  }

  // Desain Tombol Utama (Motor)
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

  // Desain Tombol Grid (Smart Home)
  Widget tombolGrid(String iconUrl, String title, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(15),
        boxShadow: const [
          BoxShadow(color: Colors.black87, blurRadius: 10, offset: Offset(4, 4)),
          BoxShadow(color: Colors.white10, blurRadius: 10, offset: Offset(-4, -4)),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 40, color: Colors.blueAccent),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
        ],
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
              // Panel Status
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
              const SizedBox(height: 40),

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
              
              const SizedBox(height: 40),
              const Divider(color: Colors.white24, thickness: 1),
              const SizedBox(height: 20),
              
              // Judul Menu Tambahan
              const Align(
                alignment: Alignment.centerLeft,
                child: Text("SMART HOME DEVICES", style: TextStyle(color: Colors.grey, letterSpacing: 2, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 20),

              // Grid Menu Masa Depan
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 20,
                  mainAxisSpacing: 20,
                  childAspectRatio: 1.1,
                  children: [
                    tombolGrid("lampu", "Lampu Teras", Icons.lightbulb_outline),
                    tombolGrid("pagar", "Pagar Garasi", Icons.door_sliding_outlined),
                    tombolGrid("cctv", "CCTV Kamera", Icons.videocam_outlined),
                    tombolGrid("kipas", "Kipas Angin", Icons.air),
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
