import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:beacon_test/eddystone_decoder.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import 'notification.dart';
import 'package:flutter/services.dart';

Future<void> main() async {

  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();

  runApp(const MyApp());
}



class BleAdvertiser {
  static const MethodChannel _channelAos = MethodChannel('ble_advertiser_aos');
  static const MethodChannel _channelIos = MethodChannel('ble_advertiser_ios');

  static Future<bool> _checkPermissions() async {
    if (Platform.isAndroid) {
      final statuses = await [
        Permission.bluetoothAdvertise,
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.locationWhenInUse,
      ].request();

      return statuses.values.every((status) => status.isGranted);
    } else if (Platform.isIOS) {
      // iOS는 앱 실행 시 자동 프롬프트가 뜨므로 Bluetooth 권한만 확인
      final status = await Permission.bluetooth.request();
      return status.isGranted;
    }
    return false;
  }

  /// 플랫폼에 맞게 Advertising 시작
  static Future<void> startAdvertising(String uuid) async {
    final hasPermission = await _checkPermissions();
    if (!hasPermission) {
      debugPrint("❌ Bluetooth permission not granted");
      return;
    }


    try {
      if (Platform.isAndroid) {
        await _channelAos.invokeMethod('startAdvertising', {'uuid': uuid});
        debugPrint("✅ Android Advertising started with $uuid");
      } else if (Platform.isIOS) {
        await _channelIos.invokeMethod('startAdvertising', {'uuid': uuid});
        debugPrint("✅ iOS Advertising started with $uuid");
      } else {
        debugPrint("⚠️ Unsupported platform: cannot start advertising");
      }
    } on PlatformException catch (e) {
      debugPrint("❌ Failed to start advertising: ${e.message}");
    }
  }

  /// 플랫폼에 맞게 Advertising 중지
  static Future<void> stopAdvertising() async {
    try {
      if (Platform.isAndroid) {
        await _channelAos.invokeMethod('stopAdvertising');
        debugPrint("🛑 Android Advertising stopped");
      } else if (Platform.isIOS) {
        await _channelIos.invokeMethod('stopAdvertising');
        debugPrint("🛑 iOS Advertising stopped");
      } else {
        debugPrint("⚠️ Unsupported platform: cannot stop advertising");
      }
    } on PlatformException catch (e) {
      debugPrint("❌ Failed to stop advertising: ${e.message}");
    }
  }
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
  final FlutterBlePeripheral blePeripheral = FlutterBlePeripheral();


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
  Timer? _scanTimer;

  /// 5분마다 10초 동안만 스캔
  void startPeriodicScan() {
    _scanTimer?.cancel();

    _doScan();

    _scanTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _doScan();
    });
  }

  void _doScan() async {

    // 기존 구독 취소
    scanSubscription?.cancel();

    // 스캔 시작
    await FlutterBluePlus.startScan(
      androidScanMode: AndroidScanMode.lowLatency,
      removeIfGone: const Duration(seconds: 5),
      continuousUpdates: true,
    );

    scanSubscription = FlutterBluePlus.scanResults.listen((results) async {
      for (ScanResult r in results) {
        final md = r.advertisementData.manufacturerData;

        if (md.containsKey(0x1377)) {
          final data = md[0x1377];
          final expectedData = "b2tech".codeUnits;

          if (data != null && listEquals(data, expectedData) && r.rssi >= -80) {
            final uuid = r.advertisementData.serviceUuids;


            scanSubscription?.cancel();
            await FlutterBluePlus.stopScan();

            print(
                "🎯 Found target beacon: $data "
                    "// RSSI: ${r.rssi} dBm "
                    "// uuid: ${uuid.isNotEmpty ? uuid.first : 'N/A'}"
            );


          }
        }
      }
    });

    // 10초 뒤에 자동으로 스캔 종료
    Future.delayed(const Duration(seconds: 10), () async {
      await FlutterBluePlus.stopScan();
      await scanSubscription?.cancel();
      print("🛑 스캔 종료");
    });
  }

  /// 종료 시 호출
  void stopPeriodicScan() {
    _scanTimer?.cancel();
    _scanTimer = null;
    scanSubscription?.cancel();
    FlutterBluePlus.stopScan();
  }

  void _stopScan() {
    scanSubscription?.cancel();
  }

  bool listEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
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
            ElevatedButton(onPressed: () async {
              await BleAdvertiser.stopAdvertising();
              await BleAdvertiser.startAdvertising("66c6a4b0-095d-488f-8a4a-5606fa2bd4e3");
            }, child: Text('start')),

            ElevatedButton(onPressed: () async {
              await BleAdvertiser.stopAdvertising();
            }, child: Text('stop')),
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
