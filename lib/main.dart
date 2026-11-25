import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:async';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
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
        scaffoldBackgroundColor: const Color(0xFF0D0E12),
        colorScheme: const ColorScheme.dark(
          primary: Colors.greenAccent,
          secondary: Colors.lightBlueAccent,
        ),
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

class _MotorDashboardState extends State<MotorDashboard>
    with SingleTickerProviderStateMixin {
  // =========================================================================
  // KONFIGURASI KONEKSI & KEAMANAN (HARUS SAMA DENGAN KODE NODEMCU)
  // =========================================================================
  static const String nodeIp = "10.20.30.1";
  static const int nodePort = 8745;
  static const String secretToken = "Smart_motor_corporation";
  static const String wifiSsid = "SMART_VARIO_125";
  // =========================================================================

  // Status Mesin & Koneksi
  String statusSistem = "STANDBY";
  Color warnaStatus = Colors.grey;
  bool isConnected = false;
  bool isEngineOn = false;
  bool isStarting = false;
  bool isCheckingConn = false;

  // Status Alarm
  bool isAlarmArmed = false;

  // Log & Detektif Error
  String detailError = "Siap terhubung ke WiFi $wifiSsid ($nodeIp:$nodePort)";

  // Animasi Denyut Cahaya (Breathing Glow)
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.25, end: 0.75).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // Fungsi Kirim Perintah Terautentikasi ke NodeMCU
  Future<bool> kirimPerintah(
    String endpoint, {
    String? statusBaru,
    Color? warnaBaru,
    bool? engineStateBaru,
    bool? alarmStateBaru,
  }) async {
    final cleanEndpoint = endpoint.isEmpty ? "" : "/$endpoint";
    final uri = Uri.parse(
      'http://$nodeIp:$nodePort$cleanEndpoint?token=$secretToken',
    );

    setState(() {
      detailError = "Mengirim ke $nodeIp:$nodePort$cleanEndpoint ...";
    });

    try {
      final response = await http.get(
        uri,
        headers: {
          'X-Auth-Token': secretToken,
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200 || response.statusCode == 303) {
        HapticFeedback.mediumImpact();
        setState(() {
          isConnected = true;
          if (statusBaru != null) statusSistem = statusBaru;
          if (warnaBaru != null) warnaStatus = warnaBaru;
          if (engineStateBaru != null) isEngineOn = engineStateBaru;
          if (alarmStateBaru != null) isAlarmArmed = alarmStateBaru;
          detailError =
              "Sukses! Respon 200 OK (${endpoint.isEmpty ? 'PING' : '/$endpoint'})";
        });
        return true;
      } else if (response.statusCode == 403) {
        HapticFeedback.heavyImpact();
        setState(() {
          isConnected = false;
          detailError =
              "Ditolak (403 Forbidden): Token aplikasi tidak cocok dengan motor!";
        });
        return false;
      } else {
        setState(() {
          isConnected = false;
          detailError = "Gagal: Server membalas kode ${response.statusCode}";
        });
        return false;
      }
    } catch (e) {
      HapticFeedback.heavyImpact();
      setState(() {
        isConnected = false;
        statusSistem = "TERPUTUS";
        warnaStatus = Colors.redAccent;
        detailError = "Tidak terhubung ke $nodeIp:$nodePort (Cek WiFi $wifiSsid)";
      });
      return false;
    }
  }

  // Cek Koneksi & Token Tanpa Mengubah Status Mesin
  void cekKoneksiMotor() async {
    if (isCheckingConn || isStarting) return;
    setState(() => isCheckingConn = true);

    bool ok = await kirimPerintah(
      "",
      statusBaru: isEngineOn ? "ENGINE RUNNING" : "TERHUBUNG",
      warnaBaru: isEngineOn ? Colors.greenAccent : Colors.cyanAccent,
    );

    if (!ok && mounted) {
      setState(() {
        statusSistem = "TERPUTUS";
        warnaStatus = Colors.redAccent;
      });
    }

    if (mounted) {
      setState(() => isCheckingConn = false);
    }
  }

  // Proses Engine Start (Sinkron dengan jeda 3 detik Fuel Pump + 1 detik Starter)
  void prosesEngineStart() async {
    if (isStarting) return;

    setState(() {
      isStarting = true;
      statusSistem = "FUEL PUMP & STARTING...";
      warnaStatus = Colors.amber;
    });

    bool sukses = await kirimPerintah(
      "on",
      alarmStateBaru: false,
    );

    if (sukses) {
      await Future.delayed(const Duration(milliseconds: 350));
      if (mounted) {
        HapticFeedback.heavyImpact();
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
      HapticFeedback.vibrate();
      setState(() {
        detailError =
            "Matikan mesin (ENGINE STOP) dulu sebelum mengaktifkan alarm!";
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

  // Widget Tombol Utama Besar dengan Animasi Sentuh & Progress Bar
  Widget tombolUtama({
    required String label,
    required String subLabel,
    required IconData icon,
    required Color warnaGlow,
    required VoidCallback onTap,
    required bool isCompact,
    bool isLoading = false,
    bool isActiveHighlight = false,
  }) {
    return _TactileScaleButton(
      onTap: isLoading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          vertical: isCompact ? 14 : 18,
          horizontal: 18,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isActiveHighlight
                ? [
                    warnaGlow.withOpacity(0.22),
                    const Color(0xFF191B24),
                  ]
                : [
                    const Color(0xFF1D1F29),
                    const Color(0xFF15161E),
                  ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: warnaGlow.withOpacity(isActiveHighlight ? 0.75 : 0.35),
            width: isActiveHighlight ? 1.8 : 1.3,
          ),
          boxShadow: [
            BoxShadow(
              color: warnaGlow.withOpacity(isActiveHighlight ? 0.28 : 0.14),
              blurRadius: isActiveHighlight ? 22 : 14,
              offset: const Offset(0, 6),
            ),
            const BoxShadow(
              color: Colors.black87,
              blurRadius: 10,
              offset: Offset(3, 4),
            ),
          ],
        ),
        child: isLoading
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.amber,
                          strokeWidth: 2.8,
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        "FUEL PUMP & STARTER...",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.amber,
                          letterSpacing: 1.3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 4200),
                    builder: (context, value, _) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: value,
                          minHeight: 5,
                          backgroundColor: Colors.white10,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Colors.amber,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              )
            : Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: EdgeInsets.all(isCompact ? 10 : 12),
                    decoration: BoxDecoration(
                      color: warnaGlow.withOpacity(0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: warnaGlow.withOpacity(0.3),
                      ),
                    ),
                    child: Icon(
                      icon,
                      color: warnaGlow,
                      size: isCompact ? 24 : 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: isCompact ? 16 : 18,
                            fontWeight: FontWeight.w900,
                            color: warnaGlow,
                            letterSpacing: 1.4,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subLabel,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: isCompact ? 11 : 12,
                            color: Colors.white60,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: warnaGlow.withOpacity(0.75),
                    size: 26,
                  ),
                ],
              ),
      ),
    );
  }

  // Widget Tombol Keamanan (Alarm On / Off) dengan Animasi Halus
  Widget tombolAlarm({
    required String label,
    required IconData icon,
    required Color warna,
    required bool isActive,
    required VoidCallback onTap,
    required bool isCompact,
  }) {
    return _TactileScaleButton(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          vertical: isCompact ? 13 : 16,
          horizontal: 10,
        ),
        decoration: BoxDecoration(
          color: isActive ? warna.withOpacity(0.18) : const Color(0xFF171821),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isActive ? warna : Colors.white12,
            width: isActive ? 1.6 : 1,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: warna.withOpacity(0.25),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  )
                ]
              : [],
        ),
        child: Column(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: Icon(
                icon,
                key: ValueKey<bool>(isActive),
                color: isActive ? warna : Colors.white54,
                size: isCompact ? 23 : 26,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isCompact ? 11 : 12,
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
    final Color warnaAlarm =
        isAlarmArmed ? Colors.lightBlueAccent : Colors.grey;

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
                fontSize: 19,
                letterSpacing: 2.2,
              ),
            ),
            Text(
              "ENCRYPTED KEYLESS & SECURITY",
              style: TextStyle(
                fontSize: 9.5,
                color: Colors.white54,
                letterSpacing: 2.3,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton(
              tooltip: "Tes Koneksi NodeMCU",
              onPressed: cekKoneksiMotor,
              icon: isCheckingConn
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.cyanAccent,
                      ),
                    )
                  : Icon(
                      isConnected ? Icons.wifi_lock : Icons.wifi_find_rounded,
                      color: isConnected
                          ? Colors.greenAccent
                          : Colors.white70,
                    ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool isCompact = constraints.maxHeight < 680;
            final double horizontalPad =
                constraints.maxWidth > 500 ? 28 : 20;

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPad,
                vertical: isCompact ? 8 : 14,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- PANEL DASHBOARD STATUS (MESIN & ALARM) ---
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          final bool shouldPulse =
                              isEngineOn || isAlarmArmed || isStarting;
                          final Color activeGlowColor = isEngineOn
                              ? Colors.greenAccent
                              : (isStarting
                                  ? Colors.amber
                                  : (isAlarmArmed
                                      ? Colors.lightBlueAccent
                                      : Colors.white10));

                          return Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(isCompact ? 14 : 18),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFF1A1C26),
                                  Color(0xFF13141B),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: shouldPulse
                                    ? activeGlowColor
                                        .withOpacity(_pulseAnimation.value)
                                    : Colors.white12,
                                width: shouldPulse ? 1.5 : 1,
                              ),
                              boxShadow: shouldPulse
                                  ? [
                                      BoxShadow(
                                        color: activeGlowColor.withOpacity(
                                            _pulseAnimation.value * 0.25),
                                        blurRadius: 20,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                  : [],
                            ),
                            child: child,
                          );
                        },
                        child: Column(
                          children: [
                            // Baris Info IP & Keamanan Token
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.verified_user_rounded,
                                      size: 13,
                                      color: isConnected
                                          ? Colors.greenAccent
                                          : Colors.white38,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      "$nodeIp:$nodePort",
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontFamily: 'monospace',
                                        color: Colors.white54,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.06),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    "TOKEN PROTECTED",
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.cyanAccent,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            Padding(
                              padding: EdgeInsets.symmetric(
                                vertical: isCompact ? 10 : 12,
                              ),
                              child: const Divider(
                                color: Colors.white10,
                                height: 1,
                              ),
                            ),

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
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: warnaStatus.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: warnaStatus.withOpacity(0.55),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.power_settings_new,
                                        color: warnaStatus,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 6),
                                      AnimatedSwitcher(
                                        duration:
                                            const Duration(milliseconds: 220),
                                        child: Text(
                                          statusSistem,
                                          key: ValueKey<String>(statusSistem),
                                          style: TextStyle(
                                            color: warnaStatus,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            Padding(
                              padding: EdgeInsets.symmetric(
                                vertical: isCompact ? 10 : 12,
                              ),
                              child: const Divider(
                                color: Colors.white10,
                                height: 1,
                              ),
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
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: warnaAlarm.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: warnaAlarm.withOpacity(0.55),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isAlarmArmed
                                            ? Icons.shield
                                            : Icons.shield_outlined,
                                        color: warnaAlarm,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 6),
                                      AnimatedSwitcher(
                                        duration:
                                            const Duration(milliseconds: 220),
                                        child: Text(
                                          isAlarmArmed
                                              ? "ALARM AKTIF"
                                              : "ALARM NONAKTIF",
                                          key: ValueKey<bool>(isAlarmArmed),
                                          style: TextStyle(
                                            color: warnaAlarm,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11.5,
                                          ),
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

                      SizedBox(height: isCompact ? 18 : 24),

                      // --- SEKSI 1: KONTROL MESIN ---
                      const Text(
                        "KONTROL MESIN",
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.white54,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 10),

                      tombolUtama(
                        label: "ENGINE START",
                        subLabel: "Kontak ON • Fuel Pump 3s • Auto Starter",
                        icon: Icons.bolt_rounded,
                        warnaGlow: Colors.greenAccent,
                        isLoading: isStarting,
                        isActiveHighlight: isEngineOn,
                        isCompact: isCompact,
                        onTap: prosesEngineStart,
                      ),

                      SizedBox(height: isCompact ? 12 : 16),

                      tombolUtama(
                        label: "ENGINE STOP",
                        subLabel: "Matikan mesin & kelistrikan motor",
                        icon: Icons.power_off_rounded,
                        warnaGlow: Colors.redAccent,
                        isCompact: isCompact,
                        onTap: prosesEngineStop,
                      ),

                      SizedBox(height: isCompact ? 20 : 26),

                      // --- SEKSI 2: KEAMANAN & ALARM ---
                      const Text(
                        "SMART ALARM & ANSWER BACK",
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.white54,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 10),

                      Row(
                        children: [
                          Expanded(
                            child: tombolAlarm(
                              label: "AKTIFKAN\nALARM",
                              icon: Icons.lock_outline_rounded,
                              warna: Colors.lightBlueAccent,
                              isActive: isAlarmArmed,
                              isCompact: isCompact,
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
                              isCompact: isCompact,
                              onTap: prosesMatikanAlarm,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // Tombol Cari Motor / Tes Sirine
                      _TactileScaleButton(
                        onTap: () => kirimPerintah("panic"),
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(
                            vertical: isCompact ? 12 : 14,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orangeAccent.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.orangeAccent.withOpacity(0.45),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.notifications_active_outlined,
                                color: Colors.orangeAccent,
                                size: 20,
                              ),
                              SizedBox(width: 10),
                              Text(
                                "CARI MOTOR / TES SIRINE",
                                style: TextStyle(
                                  color: Colors.orangeAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12.5,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: isCompact ? 16 : 22),

                      // --- KOTAK DETEKTIF ERROR / LOG ---
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.terminal_rounded,
                              color: Colors.yellowAccent,
                              size: 16,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                child: Text(
                                  "Log: $detailError",
                                  key: ValueKey<String>(detailError),
                                  style: const TextStyle(
                                    color: Colors.yellowAccent,
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                  ),
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
          },
        ),
      ),
    );
  }
}

// =============================================================================
// WIDGET TOMBOL INTERAKTIF DENGAN EFEK TEKANAN MEMBAL (TACTILE SCALE)
// =============================================================================
class _TactileScaleButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _TactileScaleButton({
    required this.child,
    this.onTap,
  });

  @override
  State<_TactileScaleButton> createState() => _TactileScaleButtonState();
}

class _TactileScaleButtonState extends State<_TactileScaleButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null
          ? null
          : (_) {
              HapticFeedback.lightImpact();
              setState(() => _isPressed = true);
            },
      onTapUp: widget.onTap == null
          ? null
          : (_) {
              setState(() => _isPressed = false);
              widget.onTap?.call();
            },
      onTapCancel: () {
        if (_isPressed) {
          setState(() => _isPressed = false);
        }
      },
      child: AnimatedScale(
        scale: _isPressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
