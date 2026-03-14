import 'dart:math' as math;

import 'package:pdffium/src/features/pdf/presentation/pdf_page_viewer.dart';
import 'package:flutter/material.dart';
import 'package:pdfium_bindings/pdfium_bindings.dart';
import 'package:vector_math/vector_math_64.dart' show Quad, Matrix4;

class PdfDocumentViewer extends StatefulWidget {
  const PdfDocumentViewer({
    super.key,
    required this.filePath,
    this.pageDecoration,
    this.documentController,
    this.pageMargin = EdgeInsets.zero,
    this.viewerOverlayBuilder,
    this.minScale = 0.1,
    this.maxScale = 5.0,
    this.cacheExtent,
  });

  final String filePath;
  final double minScale;
  final double maxScale;
  final EdgeInsetsGeometry pageMargin;
  final PdfViewerOverlaysBuilder? viewerOverlayBuilder;
  final double? cacheExtent;
  final BoxDecoration? pageDecoration;
  final PdfDocumentViewController? documentController;

  @override
  State<PdfDocumentViewer> createState() => _PdfDocumentViewState();
}

class _PdfDocumentViewState extends State<PdfDocumentViewer> {
  late final PdfDocumentViewController _documentController;

  late final PdfDocument _document;
  late final List<Rect> _pageRects;
  late List<int> _pagesInViewport;
  late List<int> _pagesInCacheExtent;

  Size? _layoutBuilderSize;

  Rect? _previousViewport;

  @override
  void initState() {
    super.initState();

    _documentController = widget.documentController ?? PdfDocumentViewController();
    _documentController._attach(this);

    _document = PdfDocument.fromFile(widget.filePath);

    double cumulativeTop = 0.0;
    _pageRects = List.generate(
      _document.pages.length,
      (index) {
        final border = widget.pageDecoration?.border;
        final topBorderWidth = border?.top.width ?? 0.0;
        final bottomBorderWidth = border?.bottom.width ?? 0.0;
        final leftBorderWidth = border is Border ? border.left.width : 0.0;
        final rightBorderWidth = border is Border ? border.right.width : 0.0;
        final pageSize = _document.getPageSizeByIndex(index);
        final pageHeight = pageSize.height + widget.pageMargin.vertical + topBorderWidth + bottomBorderWidth;
        final pageWidth = pageSize.width + widget.pageMargin.horizontal + leftBorderWidth + rightBorderWidth;
        final rect = Rect.fromLTWH(0, cumulativeTop, pageWidth, pageHeight);
        cumulativeTop += pageHeight;
        return rect;
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        for (int i = 0; i < _pageRects.length; i++) {
          _pageRects[i] = _pageRects[i].translate((_layoutBuilderSize!.width - _pageRects[i].width) / 2, 0);
        }
      });
    });
  }

  @override
  void didUpdateWidget(PdfDocumentViewer oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.documentController != oldWidget.documentController) {
      oldWidget.documentController?._attach(null);
      _documentController = widget.documentController ?? PdfDocumentViewController();
      _documentController._attach(this);
    }
  }

  @override
  void dispose() {
    _document.dispose();
    super.dispose();
  }

  /// Restrict new matrix to the safe range. Used before setting the controllers value.
  Matrix4 _makeMatrixInSafeRange(Matrix4 matrix) {
    final scale = matrix.getMaxScaleOnAxis();
    final translation = matrix.getTranslation();
    final viewportWidth = _layoutBuilderSize!.width;
    final viewportCenterX = viewportWidth / 2;

    final maxVisiblePageWidth = _pagesInViewport.map((i) => _pageRects[i].width).reduce(math.max);
    final scaledMaxVisiblePageWidth = maxVisiblePageWidth * scale;

    double newX;
    if (scaledMaxVisiblePageWidth < viewportWidth) {
      // If content is smaller than viewport, center it
      newX = viewportCenterX * (1 - scale);
    } else {
      // If content is larger than viewport, keep it within bounds
      final leftDocumentEdge = viewportCenterX - maxVisiblePageWidth / 2;
      final rightDocumentEdge = viewportCenterX + maxVisiblePageWidth / 2;

      final transformedLeftEdge = leftDocumentEdge * scale + translation.x;
      final transformedRightEdge = rightDocumentEdge * scale + translation.x;

      newX = translation.x;
      if (transformedLeftEdge > 0) {
        newX -= transformedLeftEdge;
      } else if (transformedRightEdge < viewportWidth) {
        newX += (viewportWidth - transformedRightEdge);
      }
    }

    matrix.setTranslationRaw(newX, translation.y, 0.0);
    return matrix;
  }

  void _determineVisiblePages(Rect viewport) {
    if (_previousViewport == viewport) return;

    final bool movedUp = _previousViewport != null && viewport.top < _previousViewport!.top;
    final bool movedDown = _previousViewport != null && viewport.top > _previousViewport!.top;
    final inflatedViewport = viewport.inflate(widget.cacheExtent ?? 0.0);
    int firstVisiblePageIndex = 0;
    int lastVisiblePageIndex = 0;
    int firstCachePageIndex = 0;
    int lastCachePageIndex = 0;
    if (movedUp) {
      lastVisiblePageIndex = _pageRects.lastIndexWhere((pageRect) => pageRect.overlaps(viewport), _pagesInViewport.last);
      firstVisiblePageIndex = _pageRects.lastIndexWhere((pageRect) => !pageRect.overlaps(viewport), lastVisiblePageIndex) + 1;
      lastCachePageIndex = _pageRects.lastIndexWhere((pageRect) => pageRect.overlaps(inflatedViewport), _pagesInCacheExtent.last);
      firstCachePageIndex = _pageRects.lastIndexWhere((pageRect) => !pageRect.overlaps(inflatedViewport), lastCachePageIndex) + 1;
    } else if (movedDown) {
      firstVisiblePageIndex = _pageRects.indexWhere((pageRect) => pageRect.overlaps(viewport), _pagesInViewport.first);
      lastVisiblePageIndex = _pageRects.indexWhere((pageRect) => !pageRect.overlaps(viewport), firstVisiblePageIndex);
      lastVisiblePageIndex = lastVisiblePageIndex == -1 ? _pageRects.length - 1 : lastVisiblePageIndex - 1;
      firstCachePageIndex = _pageRects.indexWhere((pageRect) => pageRect.overlaps(inflatedViewport), _pagesInCacheExtent.first);
      lastCachePageIndex = _pageRects.indexWhere((pageRect) => !pageRect.overlaps(inflatedViewport), firstCachePageIndex);
      lastCachePageIndex = lastCachePageIndex == -1 ? _pageRects.length - 1 : lastCachePageIndex - 1;
    } else if (_previousViewport == null || (!movedUp && !movedDown)) {
      firstVisiblePageIndex = _pageRects.indexWhere((pageRect) => pageRect.overlaps(viewport));
      lastVisiblePageIndex = _pageRects.lastIndexWhere((pageRect) => pageRect.overlaps(viewport));
      firstCachePageIndex = _pageRects.indexWhere((pageRect) => pageRect.overlaps(inflatedViewport));
      lastCachePageIndex = _pageRects.lastIndexWhere((pageRect) => pageRect.overlaps(inflatedViewport));
    }
    _pagesInViewport = List.generate(lastVisiblePageIndex - firstVisiblePageIndex + 1, (index) => firstVisiblePageIndex + index);
    _pagesInCacheExtent = List.generate(lastCachePageIndex - firstCachePageIndex + 1, (index) => firstCachePageIndex + index);
    _previousViewport = viewport;
  }

  @override
  Widget build(BuildContext context) {
    Widget pageBuilder(BuildContext context, int pageIndex) {
      final PdfPage page = _document.pages[pageIndex]!;
      return Container(
        decoration: widget.pageDecoration,
        margin: widget.pageMargin,
        child: PdfPageViewer(
          page: page,
          zoomLevel: _documentController.value.getMaxScaleOnAxis(),
        ),
      );
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        _layoutBuilderSize = constraints.biggest;
        return Container(
            color: Colors.grey[300],
            child: Stack(children: [
              InteractiveViewer.builder(
                boundaryMargin: EdgeInsets.fromLTRB(
                  0,
                  0,
                  0,
                  _pageRects.last.top,
                ),
                transformationController: _documentController,
                minScale: widget.minScale,
                maxScale: widget.maxScale,
                builder: (BuildContext context, Quad viewport) {
                  final currentViewport = Rect.fromLTRB(viewport.point0.x, viewport.point0.y, viewport.point2.x, viewport.point2.y);
                  _determineVisiblePages(currentViewport);
                  return _DocumentBuilder(
                    constraints: constraints,
                    pagesInCacheExtent: _pagesInCacheExtent,
                    pageBuilder: pageBuilder,
                    pageRects: _pageRects,
                  );
                },
              ),
              if (widget.viewerOverlayBuilder != null) ...widget.viewerOverlayBuilder!(context, constraints.biggest),
            ]));
      },
    );
  }
}

class _DocumentBuilder extends StatelessWidget {
  const _DocumentBuilder({
    required this.pageBuilder,
    required this.pagesInCacheExtent,
    required this.constraints,
    required this.pageRects,
  });

  final PageBuilder pageBuilder;
  final List<int> pagesInCacheExtent;
  final BoxConstraints constraints;
  final List<Rect> pageRects;

  @override
  Widget build(BuildContext context) {
    final startIndex = pagesInCacheExtent.first;
    final endIndex = pagesInCacheExtent.last;

    return SizedBox(
      height: constraints.maxHeight,
      width: constraints.maxWidth,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: <Widget>[
          for (int i = startIndex; i <= endIndex; i++)
            Positioned(
              key: ValueKey(i),
              top: pageRects[i].top,
              child: pageBuilder(context, i),
            ),
        ],
      ),
    );
  }
}

class PdfDocumentViewController extends TransformationController {
  _PdfDocumentViewState? __state;

  _PdfDocumentViewState get _state => __state!;

  void _attach(_PdfDocumentViewState? state) {
    __state = state;
  }

  Size get documentSize => Size(0.0, _state._pageRects.last.bottom);

  @override
  set value(Matrix4 newValue) {
    super.value = _state._makeMatrixInSafeRange(newValue);
  }
}

/// Function to build viewer overlays.
///
/// [size] is the size of the viewer widget.
typedef PdfViewerOverlaysBuilder = List<Widget> Function(BuildContext context, Size size);

typedef PageBuilder = Widget Function(BuildContext context, int pageIndex);
