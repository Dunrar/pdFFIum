import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as path;
import 'package:pdfium_bindings/pdfium_bindings.dart';

class Pdfium {
  late final PDFiumBindings _pdfium;
  late final DynamicLibrary _dylib;
  final Future<BackgroundWorker> _worker = BackgroundWorker.create();
  late Pointer<FPDF_LIBRARY_CONFIG> config;

  Pdfium({String? libraryPath}) {
    using((Arena arena) {
      var libPath = path.join(Directory.current.path, 'pdfium.dll');

      if (Platform.isMacOS) {
        libPath = path.join(Directory.current.path, 'libpdfium.dylib');
      } else if (Platform.isLinux) {
        libPath = path.join(Directory.current.path, 'packages/pdfium_bindings/src/pdfium-binaries/Linux/x86_64/lib/libpdfium.so');
      } else if (Platform.isAndroid) {
        libPath = 'libpdfium.so';
      }
      if (libraryPath != null) {
        libPath = libraryPath;
      }
      if (Platform.isIOS) {
        DynamicLibrary.process();
      } else {
        _dylib = DynamicLibrary.open(libPath);
      }
      _pdfium = PDFiumBindings(_dylib);

      config = arena<FPDF_LIBRARY_CONFIG>();
      config.ref.version = 2;
      config.ref.m_pUserFontPaths = nullptr;
      config.ref.m_pIsolate = nullptr;
      config.ref.m_v8EmbedderSlot = 0;
      _pdfium.FPDF_InitLibraryWithConfig(config);
    });
  }

  static final Pdfium _defaultInstance = Pdfium();

  Future<BackgroundWorker> get worker => _worker;

  static Pdfium get defaultInstance => _defaultInstance;

  PDFiumBindings get bindings {
    return _pdfium;
  }

  /// Destroys and releases the memory allocated for the library when is not longer used
  void dispose() {
    _pdfium.FPDF_DestroyLibrary();
  }
}
