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

    private fun getPairedBluetoothDevices(): List<Map<String, String>> {
        val bluetoothManager = getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
        val adapter = bluetoothManager?.adapter ?: BluetoothAdapter.getDefaultAdapter() ?: return emptyList()

        val list = mutableListOf<Map<String, String>>()
        try {
            val paired = adapter.bondedDevices
            if (paired != null) {
                for (device in paired) {
                    list.add(mapOf("name" to (device.name ?: "Bluetooth Printer"), "address" to device.address))
                }
            }
        } catch (_: SecurityException) {}
        return list
    }

    private fun printBluetoothDirect(address: String, bytes: ByteArray): String {
        val bluetoothManager = getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
        val adapter = bluetoothManager?.adapter ?: BluetoothAdapter.getDefaultAdapter()
            ?: throw Exception("Bluetooth adapter unavailable on this device")

        val device = adapter.getRemoteDevice(address)
        try {
            adapter.cancelDiscovery()
        } catch (_: Exception) {}

        var socket: BluetoothSocket? = null
        var lastException: Exception? = null

        // Attempt 1: Standard Insecure RFCOMM SPP Socket (matches Chinese ESC/POS thermal printers)
        try {
            socket = device.createInsecureRfcommSocketToServiceRecord(SPP_UUID)
            socket.connect()
        } catch (e1: Exception) {
            lastException = e1
            try { socket?.close() } catch (_: Exception) {}
            socket = null

            // Attempt 2: Standard Secure RFCOMM SPP Socket
            try {
                socket = device.createRfcommSocketToServiceRecord(SPP_UUID)
                socket.connect()
            } catch (e2: Exception) {
                lastException = e2
                try { socket?.close() } catch (_: Exception) {}
                socket = null

                // Attempt 3: Reflection fallback to port 1 (common Android workaround for stubborn BT thermal printers)
                try {
                    val m = device.javaClass.getMethod("createRfcommSocket", Int::class.javaPrimitiveType)
                    socket = m.invoke(device, 1) as? BluetoothSocket
                    socket?.connect()
                } catch (e3: Exception) {
                    lastException = e3
                    try { socket?.close() } catch (_: Exception) {}
                    socket = null
                }
            }
        }

        if (socket == null || !socket.isConnected) {
            val errMsg = lastException?.localizedMessage ?: "Unknown Bluetooth connection failure"
            throw Exception("Could not connect to ${device.name ?: address}. Ensure printer is turned on and paired: $errMsg")
        }

        try {
            val out = socket.outputStream
            out.write(bytes)
            out.flush()
            // Allow printer hardware buffer time to process ESC/POS print & cut before socket teardown
            Thread.sleep(350)
            return "Printed directly via Bluetooth to ${device.name ?: address}"
        } finally {
            try {
                socket.close()
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
