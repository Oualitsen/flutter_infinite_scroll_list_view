import 'dart:async';

class ReactiveValue<T> {
  late final _innterCtrl;
  late T _value;
  bool _hasValue = false;

  ReactiveValue([T? initial]) {
    if (initial != null) {
      _value = initial;
      _hasValue = true;
    }
    _innterCtrl = StreamController<T>.broadcast();
  }

  Stream<T> get stream => Stream.multi((controller) {
        // replay last value
        if (_hasValue) controller.add(_value);
        final sub = _innterCtrl.stream.listen(
          controller.add,
          onError: controller.addError,
          onDone: controller.close,
        );
        controller.onCancel = sub.cancel;
      }, isBroadcast: true);

  T? get valueOrNull => _hasValue ? _value : null;
  T get value => valueOrNull!;
  bool get isClosed => _innterCtrl.isClosed;

  void add(T value) {
    _value = value;
    _hasValue = true;
    if (!_innterCtrl.isClosed) _innterCtrl.add(value);
  }

  Future<void> close() => _innterCtrl.close();
}
