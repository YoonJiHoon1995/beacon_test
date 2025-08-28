import 'dart:async';

import 'package:beacon_test/eddystone_decoder.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'notification.dart';

Future<void> main() async {

  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Beacon Test',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Beacon Test'),
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
  final eddystoneUuid = Guid('0000feaa-0000-1000-8000-00805f9b34fb');


  // DB 관련
  final DatabaseReference dbRef = FirebaseDatabase.instance.ref("test");
  StreamSubscription<DatabaseEvent>? dbSubscription;

  int? dbLevel;
  String? dbType;
  String targetMac = 'C3:00:00:23:80:CE';

  @override
  void initState() {
    super.initState();
  }

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
    await FlutterBluePlus.startScan(androidScanMode: AndroidScanMode.lowLatency);

    scanSubscription?.cancel();
    dbSubscription?.cancel();

    scanSubscription = FlutterBluePlus.scanResults.listen((results) async {
      for (ScanResult r in results) {
        if (r.device.remoteId.str.toUpperCase() != targetMac.toUpperCase()) continue;

        final foundRssi = r.rssi;
        // setState(() {
        //   lastRssi = foundRssi;
        // });

        // print("Device ID: ${r.device.remoteId}");
        // print("Name: ${r.device.platformName}");
        // print("RSSI: ${r.rssi}");
        // print("Connectable: ${r.advertisementData.connectable}");
        // print("Advertised Service ${r.advertisementData.toString()}");
        //
        // final serviceData = r.advertisementData.serviceData;
        //
        // // URL 디코딩
        // String? url = EddystoneDecoder.decodeEddystoneUrl(serviceData);
        // if (url != null) {
        //   print('URL: $url');
        // }
        //
        // // TLM 디코딩
        // EddystoneTlm? tlm = EddystoneDecoder.decodeEddystoneTlm(serviceData);
        // if (tlm != null) {
        //   print('TLM: $tlm');
        // }
        //
        // // 프레임 타입 확인
        // EddystoneFrameType? frameType = EddystoneDecoder.getFrameType(serviceData);
        // print('Frame Type: $frameType');


        break; // targetMac 찾았으면 루프 종료
      }
    });

    // DB 구독
    dbSubscription = dbRef.onValue.listen((event) {
      final data = event.snapshot.value as Map?;
      if (data != null) {
        // setState(() {
        //   dbLevel = data["level"];
        //   dbType = data["type"];
        // });

        final signalLevel = lastRssi != null ? rssiToLevel(lastRssi!) : 0;
        if (dbLevel == signalLevel) {
          //_showNotification(dbType);
        }
      }
    });
  }


  void _showNotification(String? type) {
    switch (type) {
      case "A":
        NotificationService.showLocalNotification('알람 $type', '기기를 흔들어서 알람 종료');
        _stopScan();
        break;
      case "B":
        NotificationService.showLocalNotification('알람 $type', '버튼을 3초간 클릭하여 알람 종료');
        _stopScan();
        break;
      default:
    }
  }

  void _dismissNotification() {

  }

  void _stopScan() {
    scanSubscription?.cancel();
    dbSubscription?.cancel();
    FlutterBluePlus.stopScan();
  }

  @override
  void dispose() {
    _stopScan();
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
        tooltip: '비콘 탐색',
        child: const Icon(Icons.search),
      ),
    );
  }
}
