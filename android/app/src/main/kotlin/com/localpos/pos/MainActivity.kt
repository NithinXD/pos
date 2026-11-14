package com.localpos.pos

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothSocket
import android.content.Context
import android.content.Intent
import android.hardware.usb.UsbConstants
import android.hardware.usb.UsbEndpoint
import android.hardware.usb.UsbInterface
import android.hardware.usb.UsbManager
import android.net.Uri
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.UUID

class MainActivity : FlutterActivity() {
    private val CHANNEL = "rawbt.intent.channel"
    private val DIRECT_CHANNEL = "direct.printer.channel"
    private val SPP_UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 1. Direct Thermal Printer Channel (No RawBT, 100% Direct Driver)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DIRECT_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getBluetoothDevices" -> {
                    try {
                        val devices = getPairedBluetoothDevices()
                        result.success(devices)
                    } catch (e: Exception) {
                        result.error("BT_ERROR", e.localizedMessage, null)
                    }
                }
                "getBluetoothDiagnostics" -> {
                    try {
                        val diag = getBluetoothDiagnosticsInfo()
                        result.success(diag)
                    } catch (e: Exception) {
                        result.error("BT_DIAG_ERROR", e.localizedMessage, null)
                    }
                }
                "requestBluetoothPermissions" -> {
                    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
                        val hasConnect = checkSelfPermission(android.Manifest.permission.BLUETOOTH_CONNECT) == android.content.pm.PackageManager.PERMISSION_GRANTED
                        if (!hasConnect) {
                            requestPermissions(
                                arrayOf(
                                    android.Manifest.permission.BLUETOOTH_CONNECT,
                                    android.Manifest.permission.BLUETOOTH_SCAN
                                ),
                                101
                            )
                            result.success(false)
                        } else {
                            result.success(true)
                        }
                    } else {
                        result.success(true)
                    }
                }
                "openAppSettings" -> {
                    try {
                        val intent = Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                            data = Uri.fromParts("package", packageName, null)
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", e.localizedMessage, null)
                    }
                }
                "printBluetoothDirect" -> {
                    val address = call.argument<String>("address")
                    val bytes = call.argument<ByteArray>("bytes")

                    if (address.isNullOrEmpty() || bytes == null) {
                        result.error("INVALID_ARGS", "Device address and bytes are required", null)
                        return@setMethodCallHandler
                    }

                    Thread {
                        try {
                            val msg = printBluetoothDirect(address, bytes)
                            runOnUiThread { result.success(msg) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("BT_PRINT_FAILED", e.localizedMessage, null) }
                        }
                    }.start()
                }
                "getUsbPrinters" -> {
                    try {
                        val devices = getAttachedUsbPrinters()
                        result.success(devices)
                    } catch (e: Exception) {
                        result.error("USB_ERROR", e.localizedMessage, null)
                    }
                }
                "printUsbDirect" -> {
                    val deviceId = call.argument<Int>("deviceId")
                    val bytes = call.argument<ByteArray>("bytes")

                    if (deviceId == null || bytes == null) {
                        result.error("INVALID_ARGS", "Device ID and bytes are required", null)
                        return@setMethodCallHandler
                    }

                    Thread {
                        try {
                            val msg = printUsbDirect(deviceId, bytes)
                            runOnUiThread { result.success(msg) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("USB_PRINT_FAILED", e.localizedMessage, null) }
                        }
                    }.start()
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // 2. Legacy / RawBT Channel (kept for backward compatibility)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "sendToRawBT" -> {
                    val text = call.argument<String>("text") ?: ""
                    val type = call.argument<String>("type") ?: "text/plain"

                    val intent = Intent(Intent.ACTION_SEND).apply {
                        setType(type)
                        putExtra(Intent.EXTRA_TEXT, text)
                        setPackage("ru.a402d.rawbtprinter")
                    }

                    if (intent.resolveActivity(packageManager) != null) {
                        startActivity(intent)
                        result.success("Sent to RawBT")
                    } else {
                        result.error("UNAVAILABLE", "RawBT app not found", null)
                    }
                }
                "openRawBtPlayStore" -> {
                    try {
                        val marketIntent = Intent(Intent.ACTION_VIEW, Uri.parse("market://details?id=ru.a402d.rawbtprinter"))
                        if (marketIntent.resolveActivity(packageManager) != null) {
                            startActivity(marketIntent)
                            result.success(true)
                        } else {
                            val webIntent = Intent(Intent.ACTION_VIEW, Uri.parse("https://play.google.com/store/apps/details?id=ru.a402d.rawbtprinter"))
                            startActivity(webIntent)
                            result.success(true)
                        }
                    } catch (e: Exception) {
                        result.error("ERROR", e.localizedMessage, null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun getBluetoothDiagnosticsInfo(): Map<String, Any?> {
        val bluetoothManager = getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
        val adapter = bluetoothManager?.adapter ?: BluetoothAdapter.getDefaultAdapter()

        val sdkInt = android.os.Build.VERSION.SDK_INT
        var permissionConnect = true
        var permissionScan = true

        if (sdkInt >= android.os.Build.VERSION_CODES.S) {
            permissionConnect = checkSelfPermission(android.Manifest.permission.BLUETOOTH_CONNECT) == android.content.pm.PackageManager.PERMISSION_GRANTED
            permissionScan = checkSelfPermission(android.Manifest.permission.BLUETOOTH_SCAN) == android.content.pm.PackageManager.PERMISSION_GRANTED
        }

        val adapterAvailable = adapter != null
        val adapterEnabled = adapter?.isEnabled ?: false

        val devices = mutableListOf<Map<String, String>>()
        var bondedCount = 0
        var errorMsg: String? = null

        if (adapter != null) {
            try {
                val paired = adapter.bondedDevices
                if (paired != null) {
                    bondedCount = paired.size
                    for (d in paired) {
                        devices.add(mapOf(
                            "name" to (d.name ?: "Unknown"),
                            "address" to d.address,
                            "type" to d.type.toString()
                        ))
                    }
                }
            } catch (se: SecurityException) {
                errorMsg = "SecurityException: ${se.message}"
                Log.e("POS_BT", "Diagnostics SecurityException: ${se.message}", se)
            } catch (e: Exception) {
                errorMsg = "Exception: ${e.message}"
                Log.e("POS_BT", "Diagnostics Exception: ${e.message}", e)
            }
        }

        return mapOf(
            "sdkInt" to sdkInt,
            "adapterAvailable" to adapterAvailable,
            "adapterEnabled" to adapterEnabled,
            "permissionConnect" to permissionConnect,
            "permissionScan" to permissionScan,
            "bondedCount" to bondedCount,
            "devices" to devices,
            "error" to errorMsg
        )
    }

    private fun getPairedBluetoothDevices(): List<Map<String, String>> {
        Log.d("POS_BT", "getPairedBluetoothDevices() called on Android SDK: ${android.os.Build.VERSION.SDK_INT}")
        val bluetoothManager = getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
        val adapter = bluetoothManager?.adapter ?: BluetoothAdapter.getDefaultAdapter()
        if (adapter == null) {
            Log.e("POS_BT", "BluetoothAdapter is null on this device")
            return emptyList()
        }
        if (!adapter.isEnabled) {
            Log.w("POS_BT", "Bluetooth is turned OFF in Android settings")
            return emptyList()
        }

        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
            val hasConnect = checkSelfPermission(android.Manifest.permission.BLUETOOTH_CONNECT) == android.content.pm.PackageManager.PERMISSION_GRANTED
            Log.d("POS_BT", "BLUETOOTH_CONNECT granted: $hasConnect")
            if (!hasConnect) {
                Log.d("POS_BT", "Triggering requestPermissions for BLUETOOTH_CONNECT & SCAN")
                runOnUiThread {
                    requestPermissions(
                        arrayOf(
                            android.Manifest.permission.BLUETOOTH_CONNECT,
                            android.Manifest.permission.BLUETOOTH_SCAN
                        ),
                        101
                    )
                }
                return emptyList()
            }
        }

        val list = mutableListOf<Map<String, String>>()
        try {
            val paired = adapter.bondedDevices
            Log.d("POS_BT", "adapter.bondedDevices count: ${paired?.size ?: 0}")
            if (paired != null) {
                for (device in paired) {
                    val name = device.name ?: "Bluetooth Printer"
                    val address = device.address
                    Log.d("POS_BT", " -> Device: '$name' ($address), Type: ${device.type}, BondState: ${device.bondState}")
                    list.add(mapOf("name" to name, "address" to address))
                }
            }
        } catch (se: SecurityException) {
            Log.e("POS_BT", "SecurityException reading bonded devices: ${se.message}", se)
        } catch (e: Exception) {
            Log.e("POS_BT", "General error reading bonded devices: ${e.message}", e)
        }
        return list
    }

    private fun printBluetoothDirect(address: String, bytes: ByteArray): String {
        Log.d("POS_BT", "printBluetoothDirect target: $address, byte count: ${bytes.size}")
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
            val hasConnect = checkSelfPermission(android.Manifest.permission.BLUETOOTH_CONNECT) == android.content.pm.PackageManager.PERMISSION_GRANTED
            if (!hasConnect) {
                runOnUiThread {
                    requestPermissions(
                        arrayOf(
                            android.Manifest.permission.BLUETOOTH_CONNECT,
                            android.Manifest.permission.BLUETOOTH_SCAN
                        ),
                        101
                    )
                }
                throw Exception("Bluetooth permission required. Please allow Nearby Devices permission and try again.")
            }
        }

        val bluetoothManager = getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
        val adapter = bluetoothManager?.adapter ?: BluetoothAdapter.getDefaultAdapter()
            ?: throw Exception("Bluetooth adapter unavailable on this device")

        val device = adapter.getRemoteDevice(address)
        try {
            Log.d("POS_BT", "Canceling discovery before connect...")
            adapter.cancelDiscovery()
        } catch (_: Exception) {}

        var socket: BluetoothSocket? = null
        var lastException: Exception? = null

        // Attempt 1: Standard Insecure RFCOMM SPP Socket (matches Chinese ESC/POS thermal printers)
        try {
            Log.d("POS_BT", "Attempt 1: createInsecureRfcommSocketToServiceRecord ($SPP_UUID)")
            socket = device.createInsecureRfcommSocketToServiceRecord(SPP_UUID)
            socket.connect()
            Log.d("POS_BT", "Attempt 1 SUCCESS: Insecure RFCOMM connected.")
        } catch (e1: Exception) {
            Log.w("POS_BT", "Attempt 1 FAILED: ${e1.message}")
            lastException = e1
            try { socket?.close() } catch (_: Exception) {}
            socket = null

            // Attempt 2: Standard Secure RFCOMM SPP Socket
            try {
                Log.d("POS_BT", "Attempt 2: createRfcommSocketToServiceRecord ($SPP_UUID)")
                socket = device.createRfcommSocketToServiceRecord(SPP_UUID)
                socket.connect()
                Log.d("POS_BT", "Attempt 2 SUCCESS: Secure RFCOMM connected.")
            } catch (e2: Exception) {
                Log.w("POS_BT", "Attempt 2 FAILED: ${e2.message}")
                lastException = e2
                try { socket?.close() } catch (_: Exception) {}
                socket = null

                // Attempt 3: Reflection fallback to port 1 (common Android workaround for stubborn BT thermal printers)
                try {
                    Log.d("POS_BT", "Attempt 3: reflection createRfcommSocket(1)")
                    val m = device.javaClass.getMethod("createRfcommSocket", Int::class.javaPrimitiveType)
                    socket = m.invoke(device, 1) as? BluetoothSocket
                    socket?.connect()
                    Log.d("POS_BT", "Attempt 3 SUCCESS: Reflection port 1 connected.")
                } catch (e3: Exception) {
                    Log.e("POS_BT", "Attempt 3 FAILED: ${e3.message}")
                    lastException = e3
                    try { socket?.close() } catch (_: Exception) {}
                    socket = null
                }
            }
        }

        if (socket == null || !socket.isConnected) {
            val errMsg = lastException?.localizedMessage ?: "Unknown Bluetooth connection failure"
            Log.e("POS_BT", "ALL 3 connection attempts failed: $errMsg")
            throw Exception("Could not connect to ${device.name ?: address}. Ensure printer is turned on and paired: $errMsg")
        }

        try {
            Log.d("POS_BT", "Writing ${bytes.size} bytes to printer socket...")
            val out = socket.outputStream
            out.write(bytes)
            out.flush()
            // Allow printer hardware buffer time to process ESC/POS print & cut before socket teardown
            Thread.sleep(350)
            Log.d("POS_BT", "Write complete and flushed successfully.")
            return "Printed directly via Bluetooth to ${device.name ?: address}"
        } finally {
            try {
                socket.close()
                Log.d("POS_BT", "Socket closed cleanly.")
            } catch (_: Exception) {}
        }
    }

    private fun getAttachedUsbPrinters(): List<Map<String, Any>> {
        val usbManager = getSystemService(Context.USB_SERVICE) as? UsbManager ?: return emptyList()
        val list = mutableListOf<Map<String, Any>>()
        for ((_, device) in usbManager.deviceList) {
            list.add(mapOf(
                "name" to (device.productName ?: "USB Printer (${device.deviceName})"),
                "deviceId" to device.deviceId,
                "vendorId" to device.vendorId,
                "productId" to device.productId
            ))
        }
        return list
    }

    private fun printUsbDirect(deviceId: Int, bytes: ByteArray): String {
        val usbManager = getSystemService(Context.USB_SERVICE) as? UsbManager
            ?: throw Exception("USB service unavailable")
        val device = usbManager.deviceList.values.firstOrNull { it.deviceId == deviceId }
            ?: throw Exception("USB device with ID $deviceId not found")

        val connection = usbManager.openDevice(device)
            ?: throw Exception("Could not open USB device. Ensure USB permission is granted.")

        try {
            var targetInterface: UsbInterface? = null
            var targetEndpoint: UsbEndpoint? = null

            for (i in 0 until device.interfaceCount) {
                val intf = device.getInterface(i)
                for (e in 0 until intf.endpointCount) {
                    val ep = intf.getEndpoint(e)
                    if (ep.type == UsbConstants.USB_ENDPOINT_XFER_BULK && ep.direction == UsbConstants.USB_DIR_OUT) {
                        targetInterface = intf
                        targetEndpoint = ep
                        break
                    }
                }
                if (targetEndpoint != null) break
            }

            if (targetInterface == null || targetEndpoint == null) {
                throw Exception("No bulk OUT endpoint found on USB printer")
            }

            connection.claimInterface(targetInterface, true)
            val transferred = connection.bulkTransfer(targetEndpoint, bytes, bytes.size, 5000)
            if (transferred < 0) {
                throw Exception("USB bulk transfer failed with code: $transferred")
            }
            return "Printed directly via USB ($transferred bytes transferred)"
        } finally {
            connection.close()
        }
    }
}
