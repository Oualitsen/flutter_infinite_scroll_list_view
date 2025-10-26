import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_scroll_list_view/reactive_value.dart'; // adjust path accordingly

void main() {
  group('ReactiveValue', () {
    test('initial value is null when not seeded', () {
      final reactive = ReactiveValue<int>();
      expect(reactive.valueOrNull, isNull);
    });

    test('initial value is set when seeded', () {
      final reactive = ReactiveValue<int>(42);
      expect(reactive.valueOrNull, 42);
    });

    test('add updates current value', () {
      final reactive = ReactiveValue<String>();
      reactive.add('hello');
      expect(reactive.valueOrNull, 'hello');
    });

    test('stream emits added values', () async {
      final reactive = ReactiveValue<int>();
      final values = <int>[];
      final sub = reactive.stream.listen(values.add);

      reactive.add(1);
      reactive.add(2);
      reactive.add(3);

      await Future.delayed(const Duration(milliseconds: 10));
      await sub.cancel();

      expect(values, [1, 2, 3]);
    });

    test('stream replays latest value to new listeners', () async {
      final data = <String>[];
      final reactive = ReactiveValue<String>('start');

      reactive.stream.listen(data.add);
      reactive.add('next');
      await Future.delayed(const Duration(milliseconds: 10));

      expect(data, ['start', 'next']);
    });

    test('does not emit after close', () async {
      final reactive = ReactiveValue<int>();
      final values = <int>[];
      final sub = reactive.stream.listen(values.add);

      reactive.add(1);
      await reactive.close();
      reactive.add(2); // should be ignored

      await Future.delayed(const Duration(milliseconds: 10));
      await sub.cancel();

      expect(values, [1]);
    });
  });
}
