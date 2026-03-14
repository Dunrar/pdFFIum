import 'dart:collection';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:image/image.dart';
import 'package:pdfium_bindings/pdfium_bindings.dart';
import 'package:pdfium_bindings/src/fpdf_type_wrappers/native_wrapper.dart';

class PdfPage extends NativeWrapper<FPDF_PAGE> {
  final PdfDocument document;
  final int index;

  factory PdfPage(PdfDocument document, int index) {
    final PDFiumBindings pdfium = document.pdfium.bindings;
    final pageHandle = pdfium.FPDF_LoadPage(document.handle, index);
    final cleanupFunction = pdfium.FPDF_ClosePage;
    final finalizerFunction = pdfium.addresses.FPDF_ClosePage;
    return PdfPage._(pageHandle, Arena(), cleanupFunction, finalizerFunction, document, index);
  }

  PdfPage._(
    super._ptr,
    super._arena,
    super._cleanupFunction,
    super._finalizer,
    this.document,
    this.index,
  );

  int get rotation => pdfium.bindings.FPDFPage_GetRotation(handle);

  double get width => pdfium.bindings.FPDF_GetPageWidthF(handle);

  double get height => pdfium.bindings.FPDF_GetPageHeightF(handle);

  /// Create empty bitmap and render page onto it
  /// The bitmap always uses 4 bytes per pixel. The first byte is always
  /// double word aligned.
  /// The byte order is BGRx (the last byte unused if no alpha channel) or
  /// BGRA. flags FPDF_ANNOT | FPDF_LCD_TEXT
  PdfBitmap renderToBitmap(
    int width,
    int height, {
    int backgroundColor = 268435455,
    int rotate = 0,
    int flags = 0,
  }) {
    final w = width;
    final h = height;
    const startX = 0;
    final sizeX = w;
    const startY = 0;
    final sizeY = h;

    final bitmap = PdfBitmap(this, w, h, 0);
    bitmap.fillRect(0, 0, w, h, backgroundColor);
    bitmap.renderPage(
      handle,
      startX,
      startY,
      sizeX,
      sizeY,
      rotate,
      flags,
    );

    return bitmap;
  }

  /// Saves the loaded page as png or jpg image
  void savePageAsImage(
    String outPath,
    String format, {
    int? width,
    int? height,
    int backgroundColor = 268435455,
    double scale = 1,
    int rotate = 0,
    int flags = 0,
    bool flush = false,
    int pngLevel = 6,
    int qualityJpg = 100,
  }) {
    final w = ((width ?? this.width) * scale).round();
    final h = ((height ?? this.height) * scale).round();

    final bitmap = renderToBitmap(
      w,
      h,
      backgroundColor: backgroundColor,
      rotate: rotate,
      flags: flags,
    );

    final bytes = bitmap.bufferAsImageData;

    final Image image = Image.fromBytes(
      width: w,
      height: h,
      bytes: bytes.buffer,
      order: ChannelOrder.bgra,
      numChannels: 4,
    );

    // Save bitmap as PNG or JPG based on the given file type.
    switch (format) {
      case "png":
        File(outPath).writeAsBytesSync(encodePng(image, level: pngLevel), flush: flush);
      case "jpg":
        File(outPath).writeAsBytesSync(encodeJpg(image, quality: qualityJpg), flush: flush);
      default:
        throw ArgumentError('Invalid image format: $format. Expected "png" or "jpg".');
    }
  }
}

class PdfPageCollection extends ListMixin<PdfPage?> {
  final PdfDocument _document;
  final List<PdfPage?> _pages;

  PdfPageCollection(this._document, int length) : _pages = List<PdfPage?>.filled(length, null);

  @override
  PdfPage? operator [](int index) {
    if (index < 0 || index >= _pages.length) {
      throw RangeError.range(index, 0, _pages.length - 1);
    }
    if (_pages[index] == null) {
      _pages[index] = PdfPage(_document, index);
    }
    return _pages[index];
  }

  @override
  void operator []=(int index, PdfPage? page) {
    if (index < 0 || index >= _pages.length) {
      throw RangeError.range(index, 0, _pages.length - 1);
    }
    _pages[index] = page;
  }

  @override
  int get length => _pages.length;

  @override
  set length(int newLength) {
    _pages.length = newLength;
  }
}
