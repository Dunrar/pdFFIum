import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:pdfium_bindings/pdfium_bindings.dart';
import 'package:pdfium_bindings/src/fpdf_type_wrappers/native_wrapper.dart';

class PdfDocument extends NativeWrapper<FPDF_DOCUMENT> {
  late final PdfPageCollection pages;

  /// Loads a document from [filePath], and if necessary, a [password] can be
  /// specified.
  ///
  /// Throws an [PdfiumException] if no document is loaded.
  factory PdfDocument.fromFile(String filePath, {String? password, Pdfium? pdfiumInstance}) {
    final Pdfium pdfium = pdfiumInstance ?? Pdfium.defaultInstance;
    final documentHandle = pdfium.bindings.FPDF_LoadDocument(
      stringToNativeChar(filePath),
      password != null ? stringToNativeChar(password) : nullptr,
    );
    return PdfDocument._init(documentHandle, pdfium: pdfium);
  }

  /// Loads a document from [bytes], and if necessary, a [password] can be
  /// specified.
  ///
  /// Throws an [PdfiumException] if the document is null.
  factory PdfDocument.fromMemory(Uint8List bytes, {String? password, Pdfium? pdfiumInstance}) {
    final Pdfium pdfium = pdfiumInstance ?? Pdfium.defaultInstance;
    return using((Arena methodArena) {
      final Arena wrapperArena = Arena();
      final frameData = wrapperArena.allocate<Uint8>(bytes.length);
      final pointerList = frameData.asTypedList(bytes.length);
      pointerList.setAll(0, bytes);

      final documentHandle = pdfium.bindings.FPDF_LoadMemDocument64(
        frameData.cast<Void>(),
        bytes.length,
        password != null ? stringToNativeChar(password, allocator: methodArena) : nullptr,
      );
      return PdfDocument._init(documentHandle, wrapperArena: wrapperArena, pdfium: pdfium);
    });
  }

  static PdfDocument _init(FPDF_DOCUMENT documentHandle, {Arena? wrapperArena, required Pdfium pdfium}) {
    final pageCount = pdfium.bindings.FPDF_GetPageCount(documentHandle);
    final pdfDocument =
        PdfDocument._(documentHandle, wrapperArena ?? Arena(), pdfium.bindings.FPDF_CloseDocument, pdfium.bindings.addresses.FPDF_CloseDocument);
    pdfDocument.pages = PdfPageCollection(pdfDocument, pageCount);
    return pdfDocument;
  }

  /// Returns a pages size (width and height) by index using PDFiums FPDF_GetPageSizeByIndex.
  ///
  /// /// Throws an [PdfiumException] if the document is null or the index is out of
  /// bounds.
  ({double width, double height}) getPageSizeByIndex(int index) {
    return using((Arena arena) {
      final width = arena<Double>();
      final height = arena<Double>();
      final result = pdfium.bindings.FPDF_GetPageSizeByIndex(
        handle,
        index,
        width,
        height,
      );
      if (result == 0) {
        throw PdfiumException.fromErrorCode(pdfium.bindings.FPDF_GetLastError());
      }
      return (width: width.value, height: height.value);
    });
  }

  PdfDocument._(super._ptr, super._arena, super._cleanupFunction, super._finalizer);
}
