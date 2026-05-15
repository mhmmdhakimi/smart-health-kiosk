import 'package:flutter/material.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:firebase_database/firebase_database.dart';

class SelfCheckupScreen extends StatefulWidget {
  final String userId;
  final String userName;
  final bool isEnglish;
  final VoidCallback onBack;
  final Function(bool) onStateChanged;

  const SelfCheckupScreen({super.key, required this.userId, required this.userName, required this.isEnglish, required this.onBack, required this.onStateChanged});

  @override
  State<SelfCheckupScreen> createState() => _SelfCheckupScreenState();
}

class _SelfCheckupScreenState extends State<SelfCheckupScreen> {
  bool _isCheckupActive = false;
  String _currentPhase = "WAIT_PERSON";
  int _scanPercentage = 0; // NEW: Tracks Phase 2 Progress
  
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

    await FirebaseDatabase.instance.ref('kiosk_control/checkup_phase').set("WAIT_PERSON");
    await FirebaseDatabase.instance.ref('kiosk_control/session_active').set(true);
    await FirebaseDatabase.instance.ref('kiosk_control/scan_percentage').set(0);

    // Track Current Step Phase
    _phaseSub?.cancel();
    _phaseSub = FirebaseDatabase.instance.ref('kiosk_control/checkup_phase').onValue.listen((event) {
      if (event.snapshot.exists && mounted) {
        setState(() => _currentPhase = event.snapshot.value.toString());
      }
    });

    // Track Real-time Scanning Percentage
    _percentSub?.cancel();
    _percentSub = FirebaseDatabase.instance.ref('kiosk_control/scan_percentage').onValue.listen((event) {
      if (event.snapshot.exists && mounted) {
        setState(() => _scanPercentage = int.tryParse(event.snapshot.value.toString()) ?? 0);
      }
    });

    // Track Session Finish
    _sessionSub?.cancel();
    _sessionSub = FirebaseDatabase.instance.ref('kiosk_control/session_active').onValue.listen((event) async {
      if (event.snapshot.exists && event.snapshot.value == false) {
        _sessionSub?.cancel();

        var query = await FirebaseDatabase.instance.ref('checkups').orderByChild('timestamp').limitToLast(1).once();
        if (query.snapshot.exists) {
          var map = query.snapshot.value as Map<dynamic, dynamic>;
          var newKey = map.keys.first;
          var newData = map[newKey] as Map<dynamic, dynamic>;

          double weight = (newData['weight'] ?? 0).toDouble();
          double height = (newData['height'] ?? 0).toDouble();
          double temp = (newData['temp'] ?? 0).toDouble();
          double bmi = height > 0 ? weight / ((height / 100) * (height / 100)) : 0;

          String todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
          String todayTime = DateFormat('hh:mm a').format(DateTime.now());

          await FirebaseDatabase.instance.ref('checkups').child(newKey.toString()).update({
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
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.isEnglish ? "Error retrieving data." : "Ralat mengambil data.")));
          }
        }
      }
    });
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
      title = widget.isEnglish ? "PLACE FINGER ON SENSOR" : "LETAKKAN JARI PADA SENSOR";
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
       // Graceful catch for FINISHED phase
      activeStep = 2;
      title = widget.isEnglish ? "FINALIZING..." : "MENYIAPKAN...";
      instructions = widget.isEnglish ? "Processing your health data." : "Memproses data kesihatan anda.";
      icon = Icons.check_circle;
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildStepDot(0, activeStep, Icons.accessibility_new, widget.isEnglish ? "Body" : "Badan"), _buildStepLine(0, activeStep),
            _buildStepDot(1, activeStep, Icons.touch_app, widget.isEnglish ? "Finger" : "Jari"), _buildStepLine(1, activeStep),
            _buildStepDot(2, activeStep, Icons.favorite, widget.isEnglish ? "Vitals" : "Vital"),
          ],
        ),
        const SizedBox(height: 60),
        
        Container(
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white, boxShadow: [BoxShadow(color: const Color(0xFF133F85).withOpacity(0.2), blurRadius: 20, spreadRadius: 5)]),
          child: Icon(icon, size: 100, color: const Color(0xFF133F85)),
        ),
        const SizedBox(height: 40),
        
        Text(title, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF133F85), letterSpacing: 1.2)),
        const SizedBox(height: 20),
        
        Container(
          width: 600, padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 30),
          decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.blue.shade200)),
          child: Column(
            children: [
              if (_currentPhase == "SCANNING" || _currentPhase == "STABILIZING") 
                Padding(
                  padding: const EdgeInsets.only(bottom: 20), 
                  child: Column(
                    children: [
                      if (_currentPhase == "SCANNING") ...[
                        Text("$_scanPercentage%", style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF133F85))),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: _scanPercentage / 100.0, 
                            color: const Color(0xFF133F85), 
                            backgroundColor: Colors.white, 
                            minHeight: 12
                          ),
                        ),
                      ] else ...[
                        const LinearProgressIndicator(color: Color(0xFF133F85), backgroundColor: Colors.white),
                      ]
                    ],
                  )
                ),
              Text(instructions, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, color: Colors.black87, height: 1.5, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepDot(int stepIndex, int activeStep, IconData icon, String label) {
    bool isCompleted = activeStep > stepIndex; 
    bool isActive = activeStep == stepIndex;
    Color color = isCompleted ? Colors.green : (isActive ? const Color(0xFF133F85) : Colors.grey.shade300);
    return Column(
      children: [
        Container(width: 50, height: 50, decoration: BoxDecoration(color: color, shape: BoxShape.circle), child: Icon(isCompleted ? Icons.check : icon, color: Colors.white, size: 24)),
        const SizedBox(height: 10), Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }

  Widget _buildStepLine(int stepIndex, int activeStep) {
    return Container(width: 100, height: 4, margin: const EdgeInsets.only(bottom: 25), color: activeStep > stepIndex ? Colors.green : Colors.grey.shade300);
  }

  Widget _buildCheckupResults() {
    if (_latestCheckupData == null) return const SizedBox();
    
    double weight = (_latestCheckupData!['weight'] ?? 0).toDouble();
    double height = (_latestCheckupData!['height'] ?? 0).toDouble();
    double temp = (_latestCheckupData!['temp'] ?? 0).toDouble();
    double bmi = (_latestCheckupData!['bmi'] ?? 0).toDouble();
    int bpm = (_latestCheckupData!['heart_rate'] ?? 0).toInt();
    int spo2 = (_latestCheckupData!['spo2'] ?? 0).toInt();

    String bmiCategory = widget.isEnglish ? "Normal" : "Normal"; 
    Color bmiColor = Colors.green;
    
    if (bmi < 18.5) { 
      bmiCategory = widget.isEnglish ? "Underweight" : "Kurang Berat"; 
      bmiColor = Colors.blue; 
    }
    else if (bmi >= 25 && bmi < 30) { 
      bmiCategory = widget.isEnglish ? "Overweight" : "Lebih Berat"; 
      bmiColor = Colors.orange; 
    }
    else if (bmi >= 30) { 
      bmiCategory = widget.isEnglish ? "Obese" : "Obesiti"; 
      bmiColor = Colors.red; 
    }

    return SingleChildScrollView(
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            children: [
              const SizedBox(height: 20),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 45), const SizedBox(width: 15),
                Text(widget.isEnglish ? "HEALTH DASHBOARD" : "PAPARAN KESIHATAN", style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF133F85))),
              ]),
              const SizedBox(height: 30),
              Container(
                padding: const EdgeInsets.all(25), decoration: BoxDecoration(gradient: LinearGradient(colors: [bmiColor.withOpacity(0.8), bmiColor]), borderRadius: BorderRadius.circular(20), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 5))]),
                child: Row(
                  children: [
                    Container(padding: const EdgeInsets.all(15), decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle), child: const Icon(Icons.monitor_weight, color: Colors.white, size: 50)),
                    const SizedBox(width: 25),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(widget.isEnglish ? "Body Mass Index (BMI)" : "Indeks Jisim Badan (BMI)", style: const TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.bold)), Text(bmi.toStringAsFixed(2), style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold))])),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30)), child: Text(bmiCategory.toUpperCase(), style: TextStyle(color: bmiColor, fontWeight: FontWeight.bold, fontSize: 18)))
                  ],
                ),
              ),
              const SizedBox(height: 25),
              Row(children: [
                Expanded(child: _buildMetricCard(widget.isEnglish ? "Weight" : "Berat", "${weight.toStringAsFixed(2)} kg", Icons.scale, Colors.blue)), const SizedBox(width: 20),
                Expanded(child: _buildMetricCard(widget.isEnglish ? "Height" : "Tinggi", "${height.toStringAsFixed(2)} cm", Icons.height, Colors.purple)),
              ]),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(child: _buildMetricCard(widget.isEnglish ? "Heart Rate" : "Kadar Jantung", "$bpm bpm", Icons.favorite, Colors.pink)), const SizedBox(width: 20),
                Expanded(child: _buildMetricCard("Blood Oxygen", "$spo2 %", Icons.bloodtype, Colors.redAccent)), const SizedBox(width: 20),
                Expanded(child: _buildMetricCard(widget.isEnglish ? "Body Temp" : "Suhu Badan", "${temp.toStringAsFixed(1)} °C", Icons.thermostat, Colors.deepOrange)),
              ]),
              const SizedBox(height: 40),
              SizedBox(
                width: 300, height: 60,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF133F85), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                  onPressed: widget.onBack,
                  child: Text(widget.isEnglish ? "FINISH" : "SELESAI", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 20),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(15), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3))]),
      child: Column(
        children: [
          Icon(icon, color: color, size: 40), const SizedBox(height: 15),
          Text(title, style: const TextStyle(fontSize: 16, color: Colors.black54, fontWeight: FontWeight.bold)), const SizedBox(height: 5),
          Text(value, style: TextStyle(fontSize: 28, color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!_isCheckupActive) 
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                _sessionSub?.cancel(); 
                _phaseSub?.cancel();
                _percentSub?.cancel();
                FirebaseDatabase.instance.ref('kiosk_control/session_active').set(false);
                widget.onStateChanged(false);
                widget.onBack();
              },
              icon: const Icon(Icons.arrow_back, size: 28),
              label: Text(widget.isEnglish ? "Back" : "Kembali", style: const TextStyle(fontSize: 18))
            ),
          ),
        Expanded(
          child: Center(
            child: !_isCheckupActive && _latestCheckupData == null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(padding: const EdgeInsets.all(30), decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle), child: const Icon(Icons.monitor_heart, size: 100, color: Color(0xFF133F85))),
                      const SizedBox(height: 30), Text(widget.isEnglish ? "SELF-CHECKUP" : "PEMERIKSAAN KENDIRI", style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF133F85))),
                      const SizedBox(height: 20), Text(widget.isEnglish ? "Measure your Weight, Height, Temperature,\nHeart Rate, and Blood Oxygen (SpO2)." : "Ukur Berat, Tinggi, Suhu, Kadar Jantung,\ndan Oksigen Darah (SpO2) anda.", textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, color: Colors.black54, height: 1.5)),
                      const SizedBox(height: 50),
                      SizedBox(width: 300, height: 65, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF133F85), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))), onPressed: _startSelfCheckup, child: Text(widget.isEnglish ? "START SCAN" : "MULA IMBASAN", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1.5)))),
                    ],
                  )
                : _isCheckupActive ? _buildCheckupProgressUI() : _buildCheckupResults(),
          ),
        ),
      ],
    );
  }
}