import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class EddystoneDecoder {
  // Eddystone UUID: 0000FEAA-0000-1000-8000-00805F9B34FB
  static final Guid eddystoneUuid = Guid("0000FEAA-0000-1000-8000-00805F9B34FB");

  static const Map<int, String> _urlSchemes = {
    0x00: 'http://www.',
    0x01: 'https://www.',
    0x02: 'http://',
    0x03: 'https://',
  };

  static const Map<int, String> _urlEncodings = {
    0x00: '.com/',
    0x01: '.org/',
    0x02: '.edu/',
    0x03: '.net/',
    0x04: '.info/',
    0x05: '.biz/',
    0x06: '.gov/',
    0x07: '.com',
    0x08: '.org',
    0x09: '.edu',
    0x0A: '.net',
    0x0B: '.info',
    0x0C: '.biz',
    0x0D: '.gov',
  };

  // URL 디코딩 (프레임 타입 0x10)
  static String? decodeEddystoneUrl(Map<Guid, List<int>> serviceData) {
    List<int>? data = _findEddystoneData(serviceData);
    if (data == null || data.length < 3 || data[0] != 0x10) return null;

    String? urlScheme = _urlSchemes[data[2]];
    if (urlScheme == null) return null;

    StringBuffer url = StringBuffer(urlScheme);
    for (int i = 3; i < data.length; i++) {
      int byte = data[i];
      if (_urlEncodings.containsKey(byte)) {
        url.write(_urlEncodings[byte]!);
      } else if (byte >= 32 && byte <= 126) {
        url.write(String.fromCharCode(byte));
      }
    }
    return url.toString();
  }

  // TLM 텔레메트리 디코딩 (프레임 타입 0x20)
  static EddystoneTlm? decodeEddystoneTlm(Map<Guid, List<int>> serviceData) {
    List<int>? data = _findEddystoneData(serviceData);
    if (data == null || data.length < 14 || data[0] != 0x20) return null;

    // TLM 버전 확인 (현재 0x00만 지원)
    if (data[1] != 0x00) return null;

    // 배터리 전압 (mV) - Big Endian
    int batteryVoltage = (data[2] << 8) | data[3];

    // 온도 (0.0625도 단위) - Big Endian, signed
    int tempRaw = (data[4] << 8) | data[5];
    if (tempRaw > 32767) tempRaw -= 65536; // signed 16-bit 변환
    double temperature = tempRaw / 16.0;

    // 광고 카운트 - Big Endian 32-bit
    int advCount = (data[6] << 24) | (data[7] << 16) | (data[8] << 8) | data[9];

    // 가동 시간 (0.1초 단위) - Big Endian 32-bit
    int uptimeRaw = (data[10] << 24) | (data[11] << 16) | (data[12] << 8) | data[13];
    double uptimeSeconds = uptimeRaw / 10.0;

    return EddystoneTlm(
      batteryVoltage: batteryVoltage,
      temperature: temperature,
      advertisementCount: advCount,
      uptimeSeconds: uptimeSeconds,
    );
  }

  // Eddystone 프레임 타입 확인
  static EddystoneFrameType? getFrameType(Map<Guid, List<int>> serviceData) {
    List<int>? data = _findEddystoneData(serviceData);
    if (data == null || data.isEmpty) return null;

    switch (data[0]) {
      case 0x00: return EddystoneFrameType.uid;
      case 0x10: return EddystoneFrameType.url;
      case 0x20: return EddystoneFrameType.tlm;
      default: return EddystoneFrameType.unknown;
    }
  }

  // FEAA UUID로 Eddystone 데이터 찾기
  static List<int>? _findEddystoneData(Map<Guid, List<int>> serviceData) {
    for (var entry in serviceData.entries) {
      // FEAA UUID 찾기 (대소문자 구분 없이)
      if (entry.key.str.toUpperCase().contains('FEAA')) {
        return entry.value;
      }
    }
    return null;
  }
}

// TLM 데이터 클래스
class EddystoneTlm {
  final int batteryVoltage; // mV
  final double temperature; // 섭씨
  final int advertisementCount;
  final double uptimeSeconds;

  EddystoneTlm({
    required this.batteryVoltage,
    required this.temperature,
    required this.advertisementCount,
    required this.uptimeSeconds,
  });

  @override
  String toString() {
    return 'EddystoneTlm{'
        'battery: ${batteryVoltage}mV, '
        'temp: ${temperature.toStringAsFixed(1)}°C, '
        'advCount: $advertisementCount, '
        'uptime: ${uptimeSeconds.toStringAsFixed(1)}s'
        '}';
  }
}

// 프레임 타입 열거형
enum EddystoneFrameType {
  uid,    // 0x00
  url,    // 0x10
  tlm,    // 0x20
  unknown
}

// 사용 예시
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