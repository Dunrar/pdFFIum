import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:pdfium_bindings/pdfium_bindings.dart';
import 'package:pdffium/src/features/common/domain/raw_image_provider.dart';

class PdfPageViewer extends StatefulWidget {
  final PdfPage page;
  final double zoomLevel;

  const PdfPageViewer({
    super.key,
    required this.page,
    required this.zoomLevel,
  });

  @override
  State<PdfPageViewer> createState() => _PdfPageViewerState();
}

class _PdfPageViewerState extends State<PdfPageViewer> {
  late ImageProvider imageProvider;
  Widget? oldImage;
  double? oldZoomLevel;
  Timer? _renderDelayTimer;

  @override
  void initState() {
    super.initState();
    imageProvider = _renderPage();
  }

  @override
  void didUpdateWidget(covariant PdfPageViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.zoomLevel != widget.zoomLevel) {
      _renderDelayTimer?.cancel();
      _renderDelayTimer = Timer(const Duration(milliseconds: 200), () {
        setState(() {
          imageProvider = _renderPage();
        });
      });
    }
  }

  ImageProvider _renderPage() {
    final w = (widget.page.width * widget.zoomLevel).toInt();
    final h = (widget.page.height * widget.zoomLevel).toInt();

    final pageBitmap = widget.page.renderToBitmap(w, h);
    final imageData = Uint8List.fromList(pageBitmap.bufferAsImageData);
    pageBitmap.dispose();
    final raw = RawImageData(
      imageData,
      w,
      h,
      pixelFormat: PixelFormat.bgra8888,
    );

    oldZoomLevel = widget.zoomLevel;
    return RawImageProvider(raw);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Image(
        image: imageProvider,
        frameBuilder: (BuildContext context, Widget child, int? frame, bool wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded || frame != null) {
            oldImage = child;
            return SizedBox(
              width: widget.page.width,
              height: widget.page.height,
              child: FittedBox(
                fit: BoxFit.contain,
                child: child,
              ),
            );
          } else {
            return SizedBox(
              width: widget.page.width,
              height: widget.page.height,
              child: oldImage != null
                  ? FittedBox(
                      fit: BoxFit.contain,
                      child: oldImage!,
                    )
                  : const DecoratedBox(
                      decoration: BoxDecoration(color: Colors.white),
                    ),
            );
          }
        },
      ),
    );
  }

  @override
  void dispose() {
    _renderDelayTimer?.cancel();

    if (!widget.page.wasDisposed) {
      widget.page.dispose();
      widget.page.document.pages[widget.page.index] = null;
    }

    super.dispose();
  }
}
