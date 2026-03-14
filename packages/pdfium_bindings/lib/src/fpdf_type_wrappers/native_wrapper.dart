import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:pdfium_bindings/pdfium_bindings.dart';

abstract class NativeWrapper<T extends Pointer<NativeType>> implements Finalizable {
  final T _ptr;
  final Arena _arena;
  bool _wasDisposed = false;
  final Pdfium _pdfium;

  // Pointer to the native finalizer function, symbol-address needs to be exposed via ffigen
  late final NativeFinalizer _finalizer;
  // Cleanup function supplied by child class,
  late final void Function(T ptr) _cleanupFunction;

  NativeWrapper(this._ptr, this._arena, this._cleanupFunction, Pointer<NativeFunction<Void Function(T)>> _finalizerFunction, {Pdfium? pdfiumInstance})
      : _pdfium = pdfiumInstance ?? Pdfium.defaultInstance {
    if (_ptr.address == nullptr.address) {
      final err = pdfium.bindings.FPDF_GetLastError();
      throw PdfiumException.fromErrorCode(err);
    }

    _finalizer = NativeFinalizer(_finalizerFunction.cast());

    _finalizer.attach(this, _ptr.cast(), detach: this);
  }

  T get handle {
    if (wasDisposed || isDisposed) {
      throw StateError('Object has been disposed');
    }
    return _ptr;
  }

  Pdfium get pdfium => _pdfium;

  int get size => sizeOf<Pointer>();

  Arena get wrapperArena => _arena;

  void dispose() {
    if (!_wasDisposed) {
      _cleanupFunction(_ptr);
      _wasDisposed = true;
      // Detach the finalizer when manually disposing
      _finalizer.detach(this);
      _arena.releaseAll();
    } else {
      throw StateError('Object has already been disposed');
    }
  }

  bool get wasDisposed => _wasDisposed;
  bool get isDisposed => _ptr.address == nullptr.address;
}
