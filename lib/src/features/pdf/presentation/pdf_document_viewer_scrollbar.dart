import 'package:pdffium/src/features/pdf/presentation/pdf_document_viewer.dart';
import 'package:flutter/material.dart';

class PdfDocumentViewerScrollbar extends StatefulWidget {
  final PdfDocumentViewController controller;
  final BoxConstraints constraints;

  const PdfDocumentViewerScrollbar({super.key, required this.controller, required this.constraints});

  @override
  State<PdfDocumentViewerScrollbar> createState() => _PdfDocumentViewerScrollbarState();
}

class _PdfDocumentViewerScrollbarState extends State<PdfDocumentViewerScrollbar> {
  double _initialThumbPosition = 0.0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_update);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_update);
    super.dispose();
  }

  void _update() {
    setState(() {});
  }

  void _updatePosition(double newPosition) {
    setState(() {
      newPosition = newPosition.clamp(0.0, 1.0);

      double newOffset = -newPosition * widget.controller.documentSize.height * widget.controller.value.getMaxScaleOnAxis();

      if (newOffset > 0) newOffset = 0;
      if (newOffset < -widget.controller.documentSize.height * widget.controller.value.getMaxScaleOnAxis() + widget.constraints.maxHeight) {
        newOffset = -widget.controller.documentSize.height * widget.controller.value.getMaxScaleOnAxis() + widget.constraints.maxHeight;
      }

      widget.controller.value = widget.controller.value.clone()..setTranslationRaw(widget.controller.value.getTranslation().x, newOffset, 0.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scale = widget.controller.value.getMaxScaleOnAxis();
    final position = -widget.controller.value.getTranslation().y / (widget.controller.documentSize.height * scale);
    final double thumbHeight = widget.constraints.maxHeight * widget.constraints.maxHeight / (widget.controller.documentSize.height * scale);

    return GestureDetector(
      onVerticalDragStart: (details) {
        _initialThumbPosition = details.localPosition.dy / widget.constraints.maxHeight;

        if (_initialThumbPosition >= position && _initialThumbPosition <= position + thumbHeight / widget.constraints.maxHeight) {
          _initialThumbPosition -= position;
        } else {
          _initialThumbPosition = thumbHeight / (2 * widget.constraints.maxHeight);
          _updatePosition(details.localPosition.dy / widget.constraints.maxHeight - _initialThumbPosition);
        }
      },
      onVerticalDragUpdate: (details) {
        _updatePosition(details.localPosition.dy / widget.constraints.maxHeight - _initialThumbPosition);
      },
      child: CustomPaint(
        size: Size(20.0, widget.constraints.maxHeight),
        painter: _ScrollbarPainter(position, scale, widget.controller.documentSize.height),
      ),
    );
  }
}

class _ScrollbarPainter extends CustomPainter {
  final double position;
  final double scale;
  final double documentHeight;

  _ScrollbarPainter(this.position, this.scale, this.documentHeight);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;

    final double thumbHeight = size.height * size.height / (documentHeight * scale);
    final double thumbY = position * size.height;

    canvas.drawRect(
      Rect.fromLTWH(0, thumbY, size.width, thumbHeight),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _ScrollbarPainter oldDelegate) {
    return oldDelegate.position != position || oldDelegate.scale != scale || oldDelegate.documentHeight != documentHeight;
  }
}
