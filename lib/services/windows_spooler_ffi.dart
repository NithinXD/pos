// ignore_for_file: camel_case_types, non_constant_identifier_names
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

// Win32 Struct for StartDocPrinter
final class DOC_INFO_1W extends Struct {
  external Pointer<Utf16> pDocName;
  external Pointer<Utf16> pOutputFile;
  external Pointer<Utf16> pDatatype;
}

typedef OpenPrinterWNative = Int32 Function(
    Pointer<Utf16> pPrinterName,
    Pointer<IntPtr> phPrinter,
    Pointer<Void> pDefault);
typedef OpenPrinterWDart = int Function(
    Pointer<Utf16> pPrinterName,
    Pointer<IntPtr> phPrinter,
    Pointer<Void> pDefault);

typedef StartDocPrinterWNative = Uint32 Function(
    IntPtr hPrinter,
    Uint32 Level,
    Pointer<DOC_INFO_1W> pDocInfo);
typedef StartDocPrinterWDart = int Function(
    int hPrinter,
    int Level,
    Pointer<DOC_INFO_1W> pDocInfo);

typedef StartPagePrinterNative = Int32 Function(IntPtr hPrinter);
typedef StartPagePrinterDart = int Function(int hPrinter);

typedef WritePrinterNative = Int32 Function(
    IntPtr hPrinter,
    Pointer<Uint8> pBuf,
    Uint32 cbBuf,
    Pointer<Uint32> pcWritten);
typedef WritePrinterDart = int Function(
    int hPrinter,
    Pointer<Uint8> pBuf,
    int cbBuf,
    Pointer<Uint32> pcWritten);

typedef EndPagePrinterNative = Int32 Function(IntPtr hPrinter);
typedef EndPagePrinterDart = int Function(int hPrinter);

typedef EndDocPrinterNative = Int32 Function(IntPtr hPrinter);
typedef EndDocPrinterDart = int Function(int hPrinter);

typedef ClosePrinterNative = Int32 Function(IntPtr hPrinter);
typedef ClosePrinterDart = int Function(int hPrinter);

/// Direct Win32 Print Spooler service for Windows desktop via FFI.
class WindowsDirectSpooler {
  WindowsDirectSpooler._();

  static DynamicLibrary? _winspoolLib;
  static OpenPrinterWDart? _openPrinter;
  static ClosePrinterDart? _closePrinter;
  static StartDocPrinterWDart? _startDocPrinter;
  static StartPagePrinterDart? _startPagePrinter;
  static WritePrinterDart? _writePrinter;
  static EndPagePrinterDart? _endPagePrinter;
  static EndDocPrinterDart? _endDocPrinter;

  static void _init() {
    if (!kIsWeb && Platform.isWindows && _winspoolLib == null) {
      try {
        final lib = DynamicLibrary.open('winspool.drv');
        _winspoolLib = lib;
        _openPrinter = lib.lookupFunction<OpenPrinterWNative, OpenPrinterWDart>('OpenPrinterW');
        _closePrinter = lib.lookupFunction<ClosePrinterNative, ClosePrinterDart>('ClosePrinter');
        _startDocPrinter = lib.lookupFunction<StartDocPrinterWNative, StartDocPrinterWDart>('StartDocPrinterW');
        _startPagePrinter = lib.lookupFunction<StartPagePrinterNative, StartPagePrinterDart>('StartPagePrinter');
        _writePrinter = lib.lookupFunction<WritePrinterNative, WritePrinterDart>('WritePrinter');
        _endPagePrinter = lib.lookupFunction<EndPagePrinterNative, EndPagePrinterDart>('EndPagePrinter');
        _endDocPrinter = lib.lookupFunction<EndDocPrinterNative, EndDocPrinterDart>('EndDocPrinter');
      } catch (e) {
        debugPrint('WindowsDirectSpooler: failed to load winspool.drv: $e');
      }
    }
  }

  /// Enumerate all installed Windows printers (USB, Network, Virtual)
  static List<String> getInstalledPrinters() {
    if (kIsWeb || !Platform.isWindows) return [];
    final printers = <String>[];
    try {
      final result = Process.runSync('reg', [
        'query',
        r'HKEY_CURRENT_USER\Software\Microsoft\Windows NT\CurrentVersion\Devices'
      ]);
      if (result.exitCode == 0) {
        final lines = (result.stdout as String).split('\n');
        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.isEmpty || trimmed.startsWith('HKEY_')) continue;
          final parts = trimmed.split(RegExp(r'\s{4,}'));
          if (parts.isNotEmpty && parts[0].trim().isNotEmpty) {
            printers.add(parts[0].trim());
          }
        }
      }
    } catch (e) {
      debugPrint('WindowsDirectSpooler: error getting printers: $e');
    }
    return printers;
  }

  /// Get Windows default printer name
  static String? getDefaultPrinter() {
    if (kIsWeb || !Platform.isWindows) return null;
    try {
      final result = Process.runSync('reg', [
        'query',
        r'HKEY_CURRENT_USER\Software\Microsoft\Windows NT\CurrentVersion\Windows',
        '/v',
        'Device'
      ]);
      if (result.exitCode == 0) {
        final lines = (result.stdout as String).split('\n');
        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.startsWith('Device') && trimmed.contains('REG_SZ')) {
            final afterRegSz = trimmed.split('REG_SZ').last.trim();
            final printerName = afterRegSz.split(',').first.trim();
            if (printerName.isNotEmpty) return printerName;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  /// Send raw ESC/POS byte sequence directly to the specified Windows printer
  static bool printRawBytes({
    required String printerName,
    required Uint8List bytes,
    String docTitle = 'POS Thermal Receipt',
  }) {
    if (kIsWeb || !Platform.isWindows) return false;
    _init();

    if (_openPrinter == null || _writePrinter == null) {
      debugPrint('WindowsDirectSpooler: winspool functions not available');
      return false;
    }

    final phPrinter = calloc<IntPtr>();
    final pPrinterName = printerName.toNativeUtf16();

    try {
      final openRes = _openPrinter!(pPrinterName, phPrinter, nullptr);
      if (openRes == 0) {
        debugPrint('WindowsDirectSpooler: OpenPrinter failed for $printerName');
        return false;
      }

      final hPrinter = phPrinter.value;
      final docInfo = calloc<DOC_INFO_1W>();
      docInfo.ref.pDocName = docTitle.toNativeUtf16();
      docInfo.ref.pOutputFile = nullptr;
      docInfo.ref.pDatatype = 'RAW'.toNativeUtf16();

      try {
        final jobId = _startDocPrinter!(hPrinter, 1, docInfo);
        if (jobId == 0) {
          debugPrint('WindowsDirectSpooler: StartDocPrinter failed for $printerName');
          return false;
        }

        try {
          _startPagePrinter!(hPrinter);

          final pBuf = calloc<Uint8>(bytes.length);
          pBuf.asTypedList(bytes.length).setAll(0, bytes);
          final pcWritten = calloc<Uint32>();

          try {
            final writeRes = _writePrinter!(hPrinter, pBuf, bytes.length, pcWritten);
            final written = pcWritten.value;
            debugPrint('WindowsDirectSpooler: WritePrinter res=$writeRes, written=$written/${bytes.length} bytes to $printerName');
            return writeRes != 0 && written > 0;
          } finally {
            calloc.free(pBuf);
            calloc.free(pcWritten);
            _endPagePrinter!(hPrinter);
          }
        } finally {
          _endDocPrinter!(hPrinter);
        }
      } finally {
        if (docInfo.ref.pDocName != nullptr) calloc.free(docInfo.ref.pDocName);
        if (docInfo.ref.pDatatype != nullptr) calloc.free(docInfo.ref.pDatatype);
        calloc.free(docInfo);
        _closePrinter!(hPrinter);
      }
    } finally {
      calloc.free(pPrinterName);
      calloc.free(phPrinter);
    }
  }
}

