import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:pdfium_bindings/pdfium_bindings.dart';
import 'package:pdfium_bindings/src/fpdf_type_wrappers/native_wrapper.dart';

class PdfBitmap extends NativeWrapper<FPDF_BITMAP> {
  final PdfPage page;

  factory PdfBitmap(PdfPage page, int width, int height, int alpha) {
    final handle = page.pdfium.bindings.FPDFBitmap_Create(
      width,
      height,
      alpha,
    );
    if (handle.address == nullptr.address) {
      throw Exception('Failed to create PDF bitmap');
    }
    return PdfBitmap._(handle, page: page);
  }

  PdfBitmap._(Pointer<fpdf_bitmap_t__> handle, {required this.page})
      : super(
          handle,
          Arena(),
          page.pdfium.bindings.FPDFBitmap_Destroy,
          page.pdfium.bindings.addresses.FPDFBitmap_Destroy,
        );

  int get width => page.pdfium.bindings.FPDFBitmap_GetWidth(handle);

  int get height => page.pdfium.bindings.FPDFBitmap_GetHeight(handle);

  int get stride => page.pdfium.bindings.FPDFBitmap_GetStride(handle);

  Pointer<Uint8> get buffer => page.pdfium.bindings.FPDFBitmap_GetBuffer(handle).cast<Uint8>();

  // The pointer to the first byte of the bitmap buffer. The data is in BGRA format.
  Uint8List get bufferAsImageData => buffer.asTypedList(width * height * 4);

  void fillRect(int left, int top, int width, int height, int color) {
    page.pdfium.bindings.FPDFBitmap_FillRect(
      handle,
      left,
      top,
      width,
      height,
      color,
    );
  }

  void renderPage(
    FPDF_PAGE pagePointer,
    int startX,
    int startY,
    int sizeX,
    int sizeY,
    int rotate,
    int flags,
  ) {
    page.pdfium.bindings.FPDF_RenderPageBitmap(
      handle,
      pagePointer,
      startX,
      startY,
      sizeX,
      sizeY,
      rotate,
      flags,
    );
  }
}
