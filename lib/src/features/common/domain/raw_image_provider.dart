import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Decodes the given [image] (raw image pixel data) as an image ('dart:ui')
class RawImageProvider extends ImageProvider<RawImageKey> {
  final RawImageData image;
  final double? scale;
  final int? targetWidth;
  final int? targetHeight;
  RawImageProvider(
    this.image, {
    this.scale = 1.0,
    this.targetWidth,
    this.targetHeight,
  });

  @override
  ImageStreamCompleter loadImage(RawImageKey key, ImageDecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key),
      scale: scale ?? 1.0,
      debugLabel: 'RawImageProvider(${describeIdentity(key)})',
    );
  }

  @override
  Future<RawImageKey> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture(image._obtainKey());
  }

  /// see [ui.decodeImageFromPixels]
  Future<ui.Codec> _loadAsync(RawImageKey key) async {
    assert(key == image._obtainKey());
    // rgba8888 pixels
    final buffer = await ui.ImmutableBuffer.fromUint8List(image.pixels);

    final descriptor = ui.ImageDescriptor.raw(
      buffer,
      width: image.width,
      height: image.height,
      pixelFormat: image.pixelFormat,
    );
    assert(() {
      debugPrint('ImageDescriptor: ${descriptor.width}x${descriptor.height}');
      return true;
    }());
    return descriptor.instantiateCodec(targetWidth: targetWidth, targetHeight: targetHeight);
  }
}

class RawImageKey {
  final int w;
  final int h;
  final int format;
  final Digest dataHash;
  RawImageKey._(this.w, this.h, this.format, this.dataHash);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is RawImageKey && other.w == w && other.h == h && other.format == format && other.dataHash == dataHash;
  }

  @override
  int get hashCode {
    return Object.hash(w, h, format, dataHash.hashCode);
  }
}

/// Raw pixels data of an image
class RawImageData {
  final Uint8List pixels;
  final int width;
  final int height;
  final ui.PixelFormat pixelFormat;

  RawImageData(
    this.pixels,
    this.width,
    this.height, {
    this.pixelFormat = ui.PixelFormat.bgra8888,
  });

  RawImageKey? _key;
  RawImageKey _obtainKey() {
    return _key ??= RawImageKey._(width, height, pixelFormat.index, md5.convert(pixels));
  }
}
