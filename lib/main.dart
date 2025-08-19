import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Beacon RSSI Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Beacon Signal Strength'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int? lastRssi;
  StreamSubscription<List<ScanResult>>? scanSubscription;
  String targetMac = 'C3:00:00:23:80:CE'; // 원하는 비콘 MAC 주소로 수정

  int rssiToLevel(int rssi) {
    if (rssi >= -60) return 4;
    if (rssi >= -75) return 3;
    if (rssi >= -85) return 2;
    if (rssi >= -100) return 1;
    return 0;
  }

  // 신호 강도에 맞는 아이콘 반환
  String rssiIcon(int level) {
    switch (level) {
      case 4: return 'rssi 4';
      case 3: return 'rssi 3';
      case 2: return 'rssi 2';
      case 1: return 'rssi 1';
      default: return 'rssi 0';
    }
  }

  // 스캔 시작
  void _startScan() async {
    // 블루투스 및 권한 체크 생략(위에서 이미 설명)
    await FlutterBluePlus.startScan(androidScanMode: AndroidScanMode.lowLatency);

    scanSubscription?.cancel(); // 기존 구독 취소

    scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      int? foundRssi;
      for (ScanResult r in results) {
        // print('123 ${r.device.remoteId.str}');
        if (r.device.remoteId.str.toUpperCase() == targetMac.toUpperCase()) {
          foundRssi = r.rssi;
          break;
        }
      }
      setState(() {
        lastRssi = foundRssi; // 원하는 비콘 없으면 null이 되어 "신호 없음" 표시됨
      });
    });
  }

  @override
  void dispose() {
    scanSubscription?.cancel();
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    int signalLevel = lastRssi != null ? rssiToLevel(lastRssi!) : 0;
    String signalIcon = rssiIcon(signalLevel);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(signalIcon),
            SizedBox(height: 20),
            Text(
              lastRssi != null
                  ? 'RSSI: ${lastRssi!} dBm'
                  : '신호 없음',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            SizedBox(height: 10),
            Text(
              lastRssi != null
                  ? '신호 등급: $signalLevel / 4'
                  : '',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _startScan,
        child: const Icon(Icons.search),
        tooltip: '비콘 탐색',
      ),
    );
  }
}
