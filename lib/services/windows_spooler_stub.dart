import 'package:flutter/foundation.dart';

/// Web / non-FFI stub for WindowsDirectSpooler
class WindowsDirectSpooler {
  WindowsDirectSpooler._();

  static List<String> getInstalledPrinters() => [];

  static String? getDefaultPrinter() => null;

  static bool printRawBytes({
    required String printerName,
    required Uint8List bytes,
    String docTitle = 'POS Thermal Receipt',
  }) {
    debugPrint('WindowsDirectSpooler is only supported on Windows native desktop.');
    return false;
  }
}

