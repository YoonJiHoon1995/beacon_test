package com.example.beacon_test.beacon_test


import android.bluetooth.BluetoothAdapter
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertisingSet
import android.bluetooth.le.AdvertisingSetCallback
import android.bluetooth.le.AdvertisingSetParameters
import android.bluetooth.le.BluetoothLeAdvertiser
import android.os.ParcelUuid
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel


class MainActivity: FlutterActivity() {
    private val CHANNEL = "ble_advertiser_aos"

    private var advertiser: BluetoothLeAdvertiser? = null
    private var advertisingCallback: AdvertisingSetCallback? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startAdvertising" -> {
                    val uuid = call.argument<String>("uuid")
                    if(uuid == null) {
                        result.error("INVALID_ARGUMENT", "uuid is required", null)
                    } else {
                        startAdvertising(uuid)
                        result.success(null)
                    }
                }
                "stopAdvertising" -> {
                    stopAdvertising()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun startAdvertising(uuid: String) {
        val bluetoothAdapter = BluetoothAdapter.getDefaultAdapter()
        if (bluetoothAdapter == null || !bluetoothAdapter.isEnabled) {
            Log.e("BLE", "❌ Bluetooth not available or disabled")
            return
        }

        advertiser = bluetoothAdapter.bluetoothLeAdvertiser

        // ⚙️ 광고 파라미터 (최소 전력/최대 절전 설정 가능)
        val parameters = AdvertisingSetParameters.Builder()
            .setInterval(AdvertisingSetParameters.INTERVAL_LOW) // 가장 긴 주기 (배터리 절약)
            .setTxPowerLevel(AdvertisingSetParameters.TX_POWER_ULTRA_LOW) // 최소 전력
            .build()

        // 📡 광고 데이터 (UUID + manufacturerData)
        val advertiseData = AdvertiseData.Builder()
            .setIncludeDeviceName(false) // 기기 이름은 빼기
            .addServiceUuid(ParcelUuid.fromString(uuid)) // 지정한 UUID
            .addManufacturerData(0x1377, "b2tech".toByteArray(Charsets.UTF_8))
            .build()

        advertisingCallback = object : AdvertisingSetCallback() {
            override fun onAdvertisingSetStarted(
                advertisingSet: AdvertisingSet?,
                txPower: Int,
                status: Int
            ) {
                Log.i("BLE", "✅ AdvertisingSet started: txPower=$txPower, status=$status")
            }

            override fun onAdvertisingDataSet(advertisingSet: AdvertisingSet?, status: Int) {
                Log.i("BLE", "📡 Advertising data set: status=$status")
            }

            override fun onAdvertisingSetStopped(advertisingSet: AdvertisingSet?) {
                Log.i("BLE", "🛑 AdvertisingSet stopped")
            }
        }

        advertiser?.startAdvertisingSet(
            parameters,
            advertiseData,
            null,  // ScanResponse (필요시 추가 가능)
            null,  // PeriodicParameters
            null,  // PeriodicData
            advertisingCallback
        )
    }


    private fun stopAdvertising() {
        advertiser?.stopAdvertisingSet(advertisingCallback)
        Log.i("BLE", "Advertising stopped")
    }
}
