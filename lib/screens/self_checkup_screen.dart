import '../utils/no_anim_route.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui';
import 'package:intl/intl.dart';
import 'package:firebase_database/firebase_database.dart';
import 'appointment_page.dart';

class SelfCheckupScreen extends StatefulWidget {
  final String userId;
  final String userName;
  final bool isEnglish;
  final VoidCallback onBack;
  final Function(bool) onStateChanged;

  const SelfCheckupScreen({
    super.key,
    required this.userId,
    required this.userName,
    required this.isEnglish,
    required this.onBack,
    required this.onStateChanged,
  });

  @override
  State<SelfCheckupScreen> createState() => _SelfCheckupScreenState();
}

class _SelfCheckupScreenState extends State<SelfCheckupScreen> {
  bool _isCheckupActive = false;
  String _currentPhase = "WAIT_PERSON";
  int _scanPercentage = 0;

  Map<dynamic, dynamic>? _latestCheckupData;
  StreamSubscription<DatabaseEvent>? _sessionSub;
  StreamSubscription<DatabaseEvent>? _phaseSub;
  StreamSubscription<DatabaseEvent>? _percentSub;

  @override
  void dispose() {
    _sessionSub?.cancel();
    _phaseSub?.cancel();
    _percentSub?.cancel();
    super.dispose();
  }

  void _startSelfCheckup() async {
    setState(() {
      _isCheckupActive = true;
      _latestCheckupData = null;
      _currentPhase = "WAIT_PERSON";
      _scanPercentage = 0;
    });

    widget.onStateChanged(true);

    await FirebaseDatabase.instance
        .ref('kiosk_control/checkup_phase')
        .set("WAIT_PERSON");
    await FirebaseDatabase.instance
        .ref('kiosk_control/session_active')
        .set(true);
    await FirebaseDatabase.instance.ref('kiosk_control/scan_percentage').set(0);

    _phaseSub?.cancel();
    _phaseSub = FirebaseDatabase.instance
        .ref('kiosk_control/checkup_phase')
        .onValue
        .listen((event) {
          if (event.snapshot.exists && mounted) {
            setState(() => _currentPhase = event.snapshot.value.toString());
          }
        });

    _percentSub?.cancel();
    _percentSub = FirebaseDatabase.instance
        .ref('kiosk_control/scan_percentage')
        .onValue
        .listen((event) {
          if (event.snapshot.exists && mounted) {
            setState(
              () => _scanPercentage =
                  int.tryParse(event.snapshot.value.toString()) ?? 0,
            );
          }
        });

    _sessionSub?.cancel();
    _sessionSub = FirebaseDatabase.instance
        .ref('kiosk_control/session_active')
        .onValue
        .listen((event) async {
          if (event.snapshot.exists && event.snapshot.value == false) {
            _sessionSub?.cancel();

            var query = await FirebaseDatabase.instance
                .ref('checkups')
                .orderByChild('timestamp')
                .limitToLast(1)
                .once();
            if (query.snapshot.exists) {
              var map = query.snapshot.value as Map<dynamic, dynamic>;
              var newKey = map.keys.first;
              var newData = map[newKey] as Map<dynamic, dynamic>;

              double weight = (newData['weight'] ?? 0).toDouble();
              double height = (newData['height'] ?? 0).toDouble();
              double temp = (newData['temp'] ?? 0).toDouble();
              double bmi = height > 0
                  ? weight / ((height / 100) * (height / 100))
                  : 0;

              int heartRate = (newData['heart_rate'] ?? 0).toInt();
              int spo2 = (newData['spo2'] ?? 0).toInt();

              String todayDate = DateFormat(
                'yyyy-MM-dd',
              ).format(DateTime.now());
              String todayTime = DateFormat('hh:mm a').format(DateTime.now());

              await FirebaseDatabase.instance
                  .ref('checkups')
                  .child(newKey.toString())
                  .update({
                    'patient_id': widget.userId,
                    'patient_name': widget.userName.toUpperCase(),
                    'date': todayDate,
                    'time': todayTime,
                    'bmi': double.parse(bmi.toStringAsFixed(2)),
                    'weight': double.parse(weight.toStringAsFixed(2)),
                    'height': double.parse(height.toStringAsFixed(2)),
                    'temp': double.parse(temp.toStringAsFixed(1)),
                  });

              newData['date'] = todayDate;
              newData['time'] = todayTime;
              newData['bmi'] = bmi;
              newData['heart_rate'] = heartRate;
              newData['spo2'] = spo2;

              if (mounted) {
                setState(() {
                  _isCheckupActive = false;
                  _latestCheckupData = newData;
                });
                _phaseSub?.cancel();
                _percentSub?.cancel();
                widget.onStateChanged(false);
              }
            } else {
              if (mounted) {
                setState(() => _isCheckupActive = false);
                _phaseSub?.cancel();
                _percentSub?.cancel();
                widget.onStateChanged(false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      widget.isEnglish
                          ? "Error retrieving data."
                          : "Ralat mengambil data.",
                    ),
                  ),
                );
              }
            }
          }
        });
  }

  Future<void> _generateWalkInTicket() async {
    try {
      String queueNo =
          "W-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}";
      await FirebaseDatabase.instance.ref('walk_ins').push().set({
        'patient_id': widget.userId,
        'patient_name': widget.userName,
        'queue_number': queueNo,
        'timestamp': ServerValue.timestamp,
        'status': 'Waiting',
      });
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: const Color(0xFF133F85),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: Colors.green.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
            title: const Icon(
              Icons.check_circle_outline,
              color: Colors.green,
              size: 60,
            ),
            content: Text(
              widget.isEnglish
                  ? "Ticket pushed to mobile app.\nQueue No: $queueNo"
                  : "Tiket dihantar ke aplikasi mudah alih.\nNo Giliran: $queueNo",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
            actions: [
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onBack();
                  },
                  child: Text(
                    widget.isEnglish ? "OK" : "OK",
                    style: const TextStyle(
                      color: Colors.green,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint("Failed to generate walk-in ticket: $e");
    }
  }

  Widget _buildCheckupProgressUI() {
    int activeStep = 0;
    String title = "";
    String instructions = "";
    IconData icon = Icons.monitor_heart;

    if (_currentPhase == "WAIT_PERSON") {
      activeStep = 0;
      title = widget.isEnglish ? "STEP INTO THE KIOSK" : "MASUK KE DALAM KIOSK";
      instructions = widget.isEnglish
          ? "Please step onto the platform to begin."
          : "Sila berdiri di atas platform untuk bermula.";
      icon = Icons.scale;
    } else if (_currentPhase == "STABILIZING") {
      activeStep = 0;
      title = widget.isEnglish ? "STABILIZING..." : "MENSTABILKAN...";
      instructions = widget.isEnglish
          ? "Detecting weight and height.\nPlease stand perfectly still."
          : "Mengesan berat dan tinggi.\nSila berdiri tegak dan jangan bergerak.";
      icon = Icons.accessibility_new;
    } else if (_currentPhase == "WAIT_FINGER") {
      activeStep = 1;
      title = widget.isEnglish
          ? "PLACE FINGER ON SENSOR"
          : "LETAKKAN JARI PADA SENSOR";
      instructions = widget.isEnglish
          ? "Weight and Height recorded.\nNow, gently place your index finger on the glowing red sensor."
          : "Berat dan Tinggi direkodkan.\nSekarang, letakkan jari telunjuk anda pada sensor merah yang menyala.";
      icon = Icons.touch_app;
    } else if (_currentPhase == "SCANNING") {
      activeStep = 2;
      title = widget.isEnglish ? "SCANNING VITALS" : "MENGIMBAS VITAL";
      instructions = widget.isEnglish
          ? "Please keep your finger perfectly still."
          : "Sila pastikan jari anda pegun tanpa bergerak.";
      icon = Icons.favorite;
    } else {
      activeStep = 2;
      title = widget.isEnglish ? "FINALIZING..." : "MENYIAPKAN...";
      instructions = widget.isEnglish
          ? "Processing your health data."
          : "Memproses data kesihatan anda.";
      icon = Icons.check_circle;
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildStepDot(
              0,
              activeStep,
              Icons.accessibility_new,
              widget.isEnglish ? "Body" : "Badan",
            ),
            _buildStepLine(0, activeStep),
            _buildStepDot(
              1,
              activeStep,
              Icons.touch_app,
              widget.isEnglish ? "Finger" : "Jari",
            ),
            _buildStepLine(1, activeStep),
            _buildStepDot(
              2,
              activeStep,
              Icons.favorite,
              widget.isEnglish ? "Vitals" : "Vital",
            ),
          ],
        ),
        const SizedBox(height: 60),

        Container(
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.04),
            border: Border.all(
              color: Colors.lightBlue.withValues(alpha: 0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.lightBlue.withValues(alpha: 0.2),
                blurRadius: 40,
                spreadRadius: 10,
              ),
            ],
          ),
          child: Icon(icon, size: 100, color: Colors.lightBlue),
        ),
        const SizedBox(height: 40),

        Text(
          title,
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 20),

        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              width: 600,
              padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 40),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  if (_currentPhase == "SCANNING" ||
                      _currentPhase == "STABILIZING")
                    Padding(
                      padding: const EdgeInsets.only(bottom: 25),
                      child: Column(
                        children: [
                          if (_currentPhase == "SCANNING") ...[
                            Text(
                              "$_scanPercentage%",
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.lightBlueAccent,
                              ),
                            ),
                            const SizedBox(height: 15),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: LinearProgressIndicator(
                                value: _scanPercentage / 100.0,
                                color: Colors.lightBlueAccent,
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.1,
                                ),
                                minHeight: 12,
                              ),
                            ),
                          ] else ...[
                            LinearProgressIndicator(
                              color: Colors.lightBlueAccent,
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.1,
                              ),
                              minHeight: 6,
                            ),
                          ],
                        ],
                      ),
                    ),
                  Text(
                    instructions,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      color: Colors.white70,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStepDot(
    int stepIndex,
    int activeStep,
    IconData icon,
    String label,
  ) {
    bool isCompleted = activeStep > stepIndex;
    bool isActive = activeStep == stepIndex;
    Color color = isCompleted
        ? Colors.green
        : (isActive ? Colors.lightBlueAccent : Colors.white.withValues(alpha: 0.2));
    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: isActive
                ? color.withValues(alpha: 0.2)
                : (isCompleted
                      ? color.withValues(alpha: 0.2)
                      : Colors.transparent),
            border: Border.all(color: color, width: 2),
            shape: BoxShape.circle,
            boxShadow: isActive || isCompleted
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.4),
                      blurRadius: 10,
                    ),
                  ]
                : [],
          ),
          child: Icon(isCompleted ? Icons.check : icon, color: color, size: 24),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine(int stepIndex, int activeStep) {
    bool isCompleted = activeStep > stepIndex;
    return Container(
      width: 100,
      height: 4,
      margin: const EdgeInsets.only(bottom: 25),
      decoration: BoxDecoration(
        color: isCompleted
            ? Colors.green
            : Colors.white.withValues(alpha: 0.2),
        boxShadow: isCompleted
            ? [
                BoxShadow(
                  color: Colors.green.withValues(alpha: 0.4),
                  blurRadius: 10,
                ),
              ]
            : [],
      ),
    );
  }

  Widget _buildCheckupResults() {
    if (_latestCheckupData == null) return const SizedBox();

    double weight =
        (num.tryParse(_latestCheckupData!['weight']?.toString() ?? '0') ?? 0.0)
            .toDouble();
    double height =
        (num.tryParse(_latestCheckupData!['height']?.toString() ?? '0') ?? 0.0)
            .toDouble();
    double temp =
        (num.tryParse(_latestCheckupData!['temp']?.toString() ?? '0') ?? 0.0)
            .toDouble();
    double bmi =
        (num.tryParse(_latestCheckupData!['bmi']?.toString() ?? '0') ?? 0.0)
            .toDouble();
    int heartRate =
        (num.tryParse(_latestCheckupData!['heart_rate']?.toString() ?? '0') ??
                0)
            .toInt();
    int spo2 =
        (num.tryParse(_latestCheckupData!['spo2']?.toString() ?? '0') ?? 0)
            .toInt();

    bool tempBad = temp >= 37.5;
    bool spo2Bad = spo2 > 0 && spo2 < 95;
    bool hrBad = heartRate > 0 && (heartRate < 60 || heartRate > 100);

    bool isUnhealthy = (tempBad || spo2Bad || hrBad);
    Color borderColor = isUnhealthy
        ? Colors.amber.withValues(alpha: 0.4)
        : Colors.lightBlue.withValues(alpha: 0.3);
    Color glowColor = isUnhealthy ? Colors.amber : Colors.lightBlue;

    double score = 100;
    if (temp >= 37.5) score -= 15;
    if (temp < 36.1) score -= 5;
    if (spo2 > 0 && spo2 < 95) score -= 15;
    if (heartRate > 0 && (heartRate < 60 || heartRate > 100)) score -= 10;
    score = score.clamp(0, 100);

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isUnhealthy
                      ? Icons.warning_amber_rounded
                      : Icons.health_and_safety_outlined,
                  color: glowColor,
                  size: 35,
                ),
                const SizedBox(width: 15),
                Text(
                  widget.isEnglish ? "RESULTS" : "KEPUTUSAN",
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  padding: const EdgeInsets.all(25),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: borderColor, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: glowColor.withValues(alpha: 0.15),
                        blurRadius: 40,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Gauge
                      Expanded(
                        flex: 2,
                        child: Column(
                          children: [
                            _buildHealthGauge(score),
                            const SizedBox(height: 20),
                            Text(
                              widget.isEnglish
                                  ? "OVERALL HEALTH"
                                  : "KESIHATAN KESELURUHAN",
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                                letterSpacing: 1.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 220,
                        color: Colors.white.withValues(alpha: 0.1),
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                      ),
                      // Vitals Ranges
                      Expanded(
                        flex: 3,
                        child: Column(
                          children: [
                            _buildRangeBar(
                              "HEART RATE (BPM)",
                              heartRate.toDouble(),
                              "",
                              60,
                              100,
                              40,
                              140,
                              [
                                Colors.lightBlueAccent,
                                Colors.green,
                                Colors.redAccent,
                              ],
                            ),
                            _buildRangeBar(
                              "BODY TEMPERATURE (°C)",
                              temp,
                              "",
                              36.1,
                              37.2,
                              34,
                              40,
                              [
                                Colors.lightBlueAccent,
                                Colors.green,
                                Colors.redAccent,
                              ],
                            ),
                            _buildRangeBar(
                              "OXYGEN SATURATION (SpO2 %)",
                              spo2.toDouble(),
                              "",
                              95,
                              100,
                              80,
                              100,
                              [
                                Colors.redAccent,
                                Colors.green,
                                Colors.green,
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 220,
                        color: Colors.white.withValues(alpha: 0.1),
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                      ),
                      // Basics
                      Expanded(
                        flex: 2,
                        child: Column(
                          children: [
                            _buildMiniBentoCard(
                              "BMI",
                              bmi.toStringAsFixed(1),
                              "",
                              Colors.white,
                            ),
                            const SizedBox(height: 15),
                            _buildMiniBentoCard(
                              "WEIGHT",
                              weight.toStringAsFixed(1),
                              "KG",
                              Colors.white70,
                            ),
                            const SizedBox(height: 15),
                            _buildMiniBentoCard(
                              "HEIGHT",
                              height.toStringAsFixed(1),
                              "CM",
                              Colors.white70,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 25),

            if (!isUnhealthy) ...[
              const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 50,
              ),
              const SizedBox(height: 10),
              Text(
                widget.isEnglish
                    ? "All vitals are normal."
                    : "Semua vital adalah normal.",
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: 300,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                      side: const BorderSide(
                        color: Colors.green,
                        width: 1,
                      ),
                    ),
                    elevation: 0,
                  ),
                  onPressed: widget.onBack,
                  child: Text(
                    widget.isEnglish ? "FINISH SESSION" : "TAMAT SESI",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 15,
                ),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.amber, width: 1),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.amber, size: 30),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Text(
                        widget.isEnglish
                            ? "Vitals out of normal range. We highly recommend visiting the UniMAP Health Centre."
                            : "Vital di luar julat normal. Kami amat mengesyorkan lawatan ke Pusat Kesihatan UniMAP.",
                        style: const TextStyle(
                          color: Colors.amber,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 25),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildActionButton(
                    widget.isEnglish
                        ? "Generate Walk-In Ticket Now"
                        : "Jana Tiket Walk-In Sekarang",
                    Icons.confirmation_num_rounded,
                    Colors.amber,
                    _generateWalkInTicket,
                  ),
                  const SizedBox(width: 20),
                  _buildActionButton(
                    widget.isEnglish
                        ? "Book Clinical Appointment"
                        : "Tempah Janji Temu Klinik",
                    Icons.event_available_rounded,
                    Colors.lightBlue,
                    () {
                      Navigator.push(
                        context,
                        NoAnimRoute(
                          page: Scaffold(
                            body: Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFF0A2249),
                                    Color(0xFF133F85),
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(35),
                                child: AppointmentPage(
                                  userName: widget.userName,
                                  userId: widget.userId,
                                  isGuest: false,
                                  isEnglish: widget.isEnglish,
                                  onBack: () => Navigator.pop(context, "HOME"),
                                  onLogOut: widget.onBack,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHealthGauge(double score) {
    Color color = score >= 90 ? Colors.lightBlueAccent : Colors.amber;
    return Container(
      padding: const EdgeInsets.all(10),
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 140,
            height: 140,
            child: CircularProgressIndicator(
              value: score / 100,
              strokeWidth: 12,
              strokeCap: StrokeCap.round,
              color: color,
              backgroundColor: Colors.white.withValues(alpha: 0.05),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                score.toInt().toString(),
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontFamily: 'monospace',
                  shadows: [
                    Shadow(color: color.withValues(alpha: 0.5), blurRadius: 15),
                  ],
                ),
              ),
              const Text(
                "SCORE",
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white54,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRangeBar(
    String label,
    double value,
    String unit,
    double normalMin,
    double normalMax,
    double absMin,
    double absMax,
    List<Color> colors,
  ) {
    double clampedValue = value.clamp(absMin, absMax);
    double percentage = (clampedValue - absMin) / (absMax - absMin);
    percentage = percentage.clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white70,
                  fontFamily: 'monospace',
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                "${value == value.toInt() ? value.toInt() : value.toStringAsFixed(1)} $unit",
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 24,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    gradient: LinearGradient(colors: colors),
                  ),
                ),
                Align(
                  alignment: FractionalOffset(percentage, 0.5),
                  child: Container(
                    width: 4,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.8),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniBentoCard(
    String label,
    String value,
    String unit,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white54,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontFamily: 'monospace',
                ),
              ),
              if (unit.isNotEmpty)
                Text(
                  " $unit",
                  style: TextStyle(
                    fontSize: 12,
                    color: color.withValues(alpha: 0.7),
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    String text,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 300,
        height: 85,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.2),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0A2249), Color(0xFF133F85)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!_isCheckupActive)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(top: 20, left: 20),
                  child: TextButton.icon(
                    onPressed: () {
                      _sessionSub?.cancel();
                      _phaseSub?.cancel();
                      _percentSub?.cancel();
                      FirebaseDatabase.instance
                          .ref('kiosk_control/session_active')
                          .set(false);
                      widget.onStateChanged(false);
                      widget.onBack();
                    },
                    icon: const Icon(
                      Icons.arrow_back,
                      size: 28,
                      color: Colors.white,
                    ),
                    label: Text(
                      widget.isEnglish ? "Back" : "Kembali",
                      style: const TextStyle(fontSize: 18, color: Colors.white),
                    ),
                  ),
                ),
              ),
            Expanded(
              child: Center(
                child: !_isCheckupActive && _latestCheckupData == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(50),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                              child: Container(
                                padding: const EdgeInsets.all(40),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: 0.04),
                                  border: Border.all(
                                    color: Colors.lightBlue.withValues(alpha: 0.3),
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.lightBlue.withValues(alpha: 0.2),
                                      blurRadius: 40,
                                      spreadRadius: 10,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.monitor_heart,
                                  size: 100,
                                  color: Colors.lightBlueAccent,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 40),
                          Text(
                            widget.isEnglish
                                ? "SELF-CHECKUP"
                                : "PEMERIKSAAN KENDIRI",
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 2.0,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            widget.isEnglish
                                ? "Measure your Weight, Height, Temperature,\nHeart Rate, and Blood Oxygen (SpO2)."
                                : "Ukur Berat, Tinggi, Suhu, Kadar Jantung,\ndan Oksigen Darah (SpO2) anda.",
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 20,
                              color: Colors.white70,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 60),
                          SizedBox(
                            width: 320,
                            height: 70,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.lightBlue.withValues(
                                  alpha: 0.2,
                                ),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(35),
                                  side: BorderSide(
                                    color: Colors.lightBlueAccent.withValues(
                                      alpha: 0.5,
                                    ),
                                    width: 1,
                                  ),
                                ),
                                elevation: 0,
                                shadowColor: Colors.lightBlueAccent.withValues(
                                  alpha: 0.4,
                                ),
                              ),
                              onPressed: _startSelfCheckup,
                              child: Text(
                                widget.isEnglish
                                    ? "START SCAN"
                                    : "MULA IMBASAN",
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                  color: Colors.lightBlueAccent,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : _isCheckupActive
                    ? _buildCheckupProgressUI()
                    : _buildCheckupResults(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
